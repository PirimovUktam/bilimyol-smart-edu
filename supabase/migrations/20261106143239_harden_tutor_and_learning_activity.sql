BEGIN;

-- The backfill operates on every account. Trigger-only functions do not need
-- Data API grants, and the legacy profile sync remains callable by its owner.
REVOKE ALL ON FUNCTION public.provision_missing_profiles() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.provision_missing_profiles() TO service_role;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.validate_answer_attempt_context() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_profile(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
ALTER FUNCTION public.sync_profile(TEXT, TEXT, TEXT) SET search_path = public, pg_temp;

-- Existing notification preference controls the learner's in-app reminders.
GRANT SELECT (user_id, notifications_enabled) ON public.user_preferences TO authenticated;
CREATE FUNCTION public.set_learning_reminders(p_enabled BOOLEAN)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  IF p_enabled IS NULL THEN
    RAISE EXCEPTION 'Eslatma sozlamasi noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.user_preferences (user_id, notifications_enabled)
  VALUES (v_uid, p_enabled)
  ON CONFLICT (user_id) DO UPDATE
    SET notifications_enabled = EXCLUDED.notifications_enabled, updated_at = now();
  RETURN p_enabled;
END;
$$;
REVOKE ALL ON FUNCTION public.set_learning_reminders(BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_learning_reminders(BOOLEAN) TO authenticated;

-- One bounded row per learner and request category. The upsert makes the
-- quota shared across all Edge workers and regions.
CREATE SCHEMA IF NOT EXISTS bilimyol_private;
REVOKE ALL ON SCHEMA bilimyol_private FROM PUBLIC, anon, authenticated;
CREATE TABLE bilimyol_private.tutor_rate_limits (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson BOOLEAN NOT NULL,
  window_started_at TIMESTAMPTZ NOT NULL,
  used INT NOT NULL,
  PRIMARY KEY (user_id, lesson)
);
ALTER TABLE bilimyol_private.tutor_rate_limits ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION public.consume_tutor_quota(p_user_id UUID, p_lesson BOOLEAN)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_now TIMESTAMPTZ := clock_timestamp();
  v_expired_at TIMESTAMPTZ := v_now - interval '1 minute';
  v_limit INT := CASE WHEN p_lesson THEN 5 ELSE 30 END;
  v_allowed BOOLEAN;
BEGIN
  INSERT INTO bilimyol_private.tutor_rate_limits AS quota (user_id, lesson, window_started_at, used)
  VALUES (p_user_id, p_lesson, v_now, 1)
  ON CONFLICT (user_id, lesson) DO UPDATE SET
    used = CASE WHEN quota.window_started_at <= v_expired_at THEN 1 ELSE quota.used + 1 END,
    window_started_at = CASE WHEN quota.window_started_at <= v_expired_at THEN v_now ELSE quota.window_started_at END
  WHERE quota.window_started_at <= v_expired_at OR quota.used < v_limit
  RETURNING true INTO v_allowed;
  RETURN COALESCE(v_allowed, false);
END;
$$;
REVOKE ALL ON FUNCTION public.consume_tutor_quota(UUID, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_tutor_quota(UUID, BOOLEAN) TO service_role;

-- The Edge handler supplies the identity it verified with Auth. Neither the
-- submitted answer text nor an answer key supplied by the caller is trusted.
CREATE FUNCTION public.tutor_mistake_context(
  p_user_id UUID, p_course_id TEXT, p_skill_id TEXT, p_question_id TEXT
)
RETURNS JSONB LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  WITH attempt AS (
    SELECT lesson_id, selected_index
    FROM public.answer_attempts
    WHERE user_id = p_user_id AND course_id = p_course_id AND skill_id = p_skill_id
      AND question_id = p_question_id AND NOT is_correct
    ORDER BY created_at DESC, id DESC LIMIT 1
  ), question AS (
    SELECT to_jsonb(q) AS body
      FROM public.questions q
      WHERE q.id = p_question_id AND q.course_id = p_course_id AND q.skill_id = p_skill_id
        AND NOT q.is_placement
    UNION ALL
    SELECT item
      FROM attempt a JOIN public.generated_lessons l ON l.id = a.lesson_id
      CROSS JOIN LATERAL jsonb_array_elements(l.questions) AS item
      WHERE l.course_id = p_course_id AND l.skill_id = p_skill_id AND item->>'id' = p_question_id
    UNION ALL
    SELECT item
      FROM attempt a JOIN public.lessons l ON l.id = a.lesson_id
      CROSS JOIN LATERAL (
        SELECT COALESCE(step->'interactiveQuestion', step->'interactive_question')
          FROM jsonb_array_elements(l.steps) AS step
        UNION ALL SELECT l.reinforcement_exercise
      ) AS items(item)
      WHERE l.course_id = p_course_id AND l.skill_id = p_skill_id
        AND l.is_published AND NOT l.is_archived AND item->>'id' = p_question_id
  ), context AS (
    SELECT body->>'text' AS question_text,
      body->'options'->>a.selected_index AS selected_option,
      body->'options'->>CASE WHEN COALESCE(body->>'correct_index', body->>'correctIndex') ~ '^[0-9]{1,3}$'
        THEN COALESCE(body->>'correct_index', body->>'correctIndex')::INT END AS correct_option,
      body->>'explanation' AS explanation
    FROM attempt a CROSS JOIN (SELECT body FROM question LIMIT 1) q
  )
  SELECT jsonb_build_object('questionText', question_text, 'selectedOption', selected_option,
    'correctOption', correct_option, 'explanation', explanation)
  FROM context
  WHERE question_text IS NOT NULL AND selected_option IS NOT NULL AND correct_option IS NOT NULL
    AND selected_option <> correct_option;
$$;
REVOKE ALL ON FUNCTION public.tutor_mistake_context(UUID, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tutor_mistake_context(UUID, TEXT, TEXT, TEXT) TO service_role;

CREATE FUNCTION public.get_mistake_feedback(p_course_id TEXT, p_skill_id TEXT, p_question_id TEXT)
RETURNS JSONB LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT public.tutor_mistake_context(auth.uid(), p_course_id, p_skill_id, p_question_id);
$$;
REVOKE ALL ON FUNCTION public.get_mistake_feedback(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_mistake_feedback(TEXT, TEXT, TEXT) TO authenticated;

CREATE INDEX IF NOT EXISTS idx_sessions_user_heartbeat
  ON public.learning_sessions (user_id, last_heartbeat_at DESC);

CREATE OR REPLACE FUNCTION public.record_session_heartbeat(
  p_session_id UUID,
  p_course_id TEXT DEFAULT 'course_math_01',
  p_lesson_id TEXT DEFAULT NULL,
  p_platform TEXT DEFAULT 'web'
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_now TIMESTAMPTZ;
  v_today DATE;
  v_session public.learning_sessions;
  v_latest TIMESTAMPTZ;
  v_elapsed INT;
  v_added INT := 0;
  v_total INT := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  IF p_session_id IS NULL OR p_platform IS NULL OR p_platform NOT IN ('web', 'ios', 'android')
    OR NOT EXISTS (SELECT 1 FROM public.courses WHERE id = p_course_id AND is_active)
    OR (p_lesson_id IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM public.lessons
        WHERE id = p_lesson_id AND course_id = p_course_id AND is_published AND NOT is_archived)
      AND NOT EXISTS (SELECT 1 FROM public.generated_lessons WHERE id = p_lesson_id AND course_id = p_course_id))
  THEN
    RAISE EXCEPTION 'Mashg‘ulot konteksti noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('heartbeat:' || v_uid::TEXT, 0));
  v_now := clock_timestamp();
  v_today := (v_now AT TIME ZONE 'Asia/Tashkent')::date;

  SELECT * INTO v_session FROM public.learning_sessions WHERE id = p_session_id;
  IF NOT FOUND THEN
    INSERT INTO public.learning_sessions (
      id, user_id, course_id, lesson_id, started_at, last_heartbeat_at, platform
    ) VALUES (p_session_id, v_uid, p_course_id, p_lesson_id, v_now, v_now, p_platform);
  ELSE
    IF v_session.user_id <> v_uid THEN
      RAISE EXCEPTION 'Sessiyaga ruxsat yo‘q.' USING ERRCODE = '42501';
    END IF;
    SELECT last_heartbeat_at INTO v_latest FROM public.learning_sessions
      WHERE user_id = v_uid ORDER BY last_heartbeat_at DESC LIMIT 1;
    v_elapsed := floor(EXTRACT(EPOCH FROM v_now - v_latest));
    IF v_elapsed > 0 AND v_elapsed <= 300 AND v_now - v_session.last_heartbeat_at <= interval '5 minutes' THEN
      v_added := LEAST(60, v_elapsed);
    END IF;
    UPDATE public.learning_sessions
      SET last_heartbeat_at = v_now, active_seconds = active_seconds + v_added,
          course_id = p_course_id, lesson_id = p_lesson_id
      WHERE id = p_session_id
      RETURNING active_seconds INTO v_total;
  END IF;

  IF v_added > 0 THEN
    INSERT INTO public.daily_learning_stats AS stats (user_id, activity_date, active_seconds, updated_at)
    VALUES (v_uid, v_today, v_added, v_now)
    ON CONFLICT (user_id, activity_date) DO UPDATE SET
      active_seconds = stats.active_seconds + EXCLUDED.active_seconds, updated_at = EXCLUDED.updated_at;
  END IF;

  RETURN jsonb_build_object(
    'session_id', p_session_id,
    'added_active_seconds', v_added,
    'total_session_active_seconds', v_total
  );
END;
$$;
REVOKE ALL ON FUNCTION public.record_session_heartbeat(UUID, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_session_heartbeat(UUID, TEXT, TEXT, TEXT) TO authenticated;

COMMIT;
