-- ============================================================================
-- BILIMYO'L SMART EDU - WAVE 0 · BATCH W0-B1
-- Migration: 20261124000100_w0_b1_rpc_authz_reinforcement_and_xp_hardening.sql
-- Scope:
--   * FIX-P0-27: Strict (p_lesson_id, p_question_id) binding, published/archived
--                CMS draft isolation, and Math Pilot reinf_* unlock resolution.
--   * FIX-P0-28: Canonical single-claim reinforcement, pre-attempt v_before,
--                timestamp-bounded reinforcement score floor, unknown question_id
--                22023 rejection (zero free streak), and 1st-mistake Math
--                checkpoint answer/explanation oracle suppression.
--   * FIX-P2-22: Internal bilimyol_private.award_xp with learning-lock &
--                consistent daily_learning_stats -> gamification_profiles
--                lock order + REVOKE EXECUTE on public.award_xp,
--                public.sync_profile, public.promote_user_to_admin,
--                public.evaluate_placement_answer, and anon access on is_admin().
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Reconcile Math Pilot reinforcement_exercise metadata with parent lessons
-- ----------------------------------------------------------------------------
UPDATE public.lessons
SET reinforcement_exercise = pg_catalog.jsonb_set(
      reinforcement_exercise,
      '{skillId}',
      pg_catalog.to_jsonb(skill_id),
      true
    ),
    updated_at = pg_catalog.now()
WHERE course_id = 'course_math_01'
  AND pg_catalog.jsonb_typeof(reinforcement_exercise) = 'object'
  AND reinforcement_exercise->>'skillId' IS DISTINCT FROM skill_id;

UPDATE public.lessons
SET reinforcement_exercise = '{
      "id": "q_lesson_math_expressions_intro_practice",
      "courseId": "course_math_01",
      "skillId": "skill_math_algebra",
      "text": "3(x + 2) qavsini oching.",
      "options": ["3x + 2", "3x + 6", "x + 6", "5x"],
      "correctIndex": 1,
      "difficulty": "easy",
      "explanation": "Har bir hadni 3 ga ko‘paytiramiz: 3 · x + 3 · 2 = 3x + 6."
    }'::jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_math_expressions_intro'
  AND course_id = 'course_math_01'
  AND reinforcement_exercise IS NULL;

-- 20261106150620_publish_curated_lesson_paths authored q_live_math_functions_01_practice,
-- but ON CONFLICT DO NOTHING left lesson_math_functions_01 pointing to placement item q_math_func_01.
UPDATE public.lessons
SET reinforcement_exercise = '{
      "id": "q_live_math_functions_01_practice",
      "courseId": "course_math_01",
      "skillId": "skill_math_functions",
      "text": "g(x) = 2x + 6 uchun g(−1) ni toping.",
      "options": ["−8", "4", "8", "5"],
      "correctIndex": 1,
      "difficulty": "medium",
      "explanation": "2 · (−1) + 6 = 4."
    }'::jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_math_functions_01'
  AND course_id = 'course_math_01'
  AND reinforcement_exercise->>'id' = 'q_math_func_01';

-- ----------------------------------------------------------------------------
-- 2. Canonical reinforcement node/lesson resolver (internal private helper)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION bilimyol_private.resolve_reinforcement_target(
  p_course_id TEXT,
  p_skill_id TEXT,
  p_reinf_id TEXT
)
RETURNS TABLE (
  canonical_reinf_id TEXT,
  target_lesson_id TEXT,
  required_score INT
)
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  v_rn RECORD;
  v_lesson RECORD;
  v_lesson_id TEXT;
BEGIN
  IF p_reinf_id IS NULL
     OR NULLIF(pg_catalog.btrim(p_reinf_id), '') IS NULL
     OR NOT pg_catalog.starts_with(p_reinf_id, 'reinf_') THEN
    RETURN;
  END IF;

  -- Priority 1: Active roadmap node matching reinf_<node_id> or explicit reinforcement node id
  SELECT rn.id, rn.is_reinforcement, rn.target_lesson_id, rn.required_score
  INTO v_rn
  FROM public.roadmap_nodes rn
  WHERE rn.course_id = p_course_id
    AND rn.skill_id = p_skill_id
    AND rn.is_active
    AND (
      p_reinf_id = 'reinf_' || rn.id
      OR (rn.is_reinforcement AND p_reinf_id = rn.id)
    )
  ORDER BY rn.order_index ASC, rn.id ASC
  LIMIT 1;

  IF FOUND THEN
    v_lesson_id := NULLIF(pg_catalog.btrim(v_rn.target_lesson_id), '');
    IF v_lesson_id IS NULL THEN
      SELECT l.id
      INTO v_lesson_id
      FROM public.lessons l
      WHERE l.course_id = p_course_id
        AND l.skill_id = p_skill_id
        AND l.is_published
        AND NOT l.is_archived
      ORDER BY l.created_at ASC, l.id ASC
      LIMIT 1;
    END IF;

    IF v_lesson_id IS NOT NULL THEN
      canonical_reinf_id := CASE
        WHEN v_rn.is_reinforcement THEN v_rn.id
        ELSE 'reinf_' || v_rn.id
      END;
      target_lesson_id := v_lesson_id;
      required_score := GREATEST(COALESCE(v_rn.required_score, 70), 70);
      RETURN NEXT;
    END IF;
    RETURN;
  END IF;

  -- Priority 2: Lesson-scoped fallback reinf_lesson_<lesson_id>
  IF pg_catalog.starts_with(p_reinf_id, 'reinf_lesson_') THEN
    v_lesson_id := pg_catalog.substr(p_reinf_id, 14);
    IF NULLIF(pg_catalog.btrim(v_lesson_id), '') IS NULL THEN
      RETURN;
    END IF;

    SELECT l.id, l.course_id, l.skill_id
    INTO v_lesson
    FROM public.lessons l
    WHERE l.id = v_lesson_id
      AND l.course_id = p_course_id
      AND l.is_published
      AND NOT l.is_archived
      AND (
        l.skill_id = p_skill_id
        OR COALESCE(l.reinforcement_exercise->>'skillId', l.reinforcement_exercise->>'skill_id') = p_skill_id
        OR COALESCE(
          pg_catalog.to_jsonb(l)->'alternate_exercise'->>'skillId',
          pg_catalog.to_jsonb(l)->'alternate_exercise'->>'skill_id',
          pg_catalog.to_jsonb(l)->'alternateExercise'->>'skillId',
          pg_catalog.to_jsonb(l)->'alternateExercise'->>'skill_id'
        ) = p_skill_id
      )
    LIMIT 1;

    IF FOUND THEN
      SELECT rn.id, rn.is_reinforcement, rn.required_score
      INTO v_rn
      FROM public.roadmap_nodes rn
      WHERE rn.course_id = p_course_id
        AND rn.target_lesson_id = v_lesson.id
        AND rn.is_active
      ORDER BY (rn.skill_id = p_skill_id) DESC, rn.order_index ASC, rn.id ASC
      LIMIT 1;

      canonical_reinf_id := CASE
        WHEN v_rn.id IS NOT NULL THEN
          CASE WHEN v_rn.is_reinforcement THEN v_rn.id ELSE 'reinf_' || v_rn.id END
        ELSE 'reinf_lesson_' || v_lesson.id
      END;
      target_lesson_id := v_lesson.id;
      required_score := GREATEST(COALESCE(v_rn.required_score, 70), 70);
      RETURN NEXT;
    END IF;
  END IF;

  RETURN;
END;
$$;

REVOKE ALL ON FUNCTION bilimyol_private.resolve_reinforcement_target(TEXT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Internal deadlock-free bilimyol_private.award_xp + public surface lockdown
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION bilimyol_private.award_xp(
  p_user_id UUID,
  p_amount INT,
  p_action_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_inserted BOOLEAN := false;
  v_xp INT := 0;
  v_amount INT;
  v_action_id TEXT;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  IF p_action_key IS NULL OR pg_catalog.btrim(p_action_key) = '' THEN
    RAISE EXCEPTION 'XP action key bo‘sh bo‘lishi mumkin emas.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('learning:' || p_user_id::TEXT, 0)
  );

  IF pg_catalog.starts_with(p_action_key, 'answer_correct_') THEN
    v_action_id := pg_catalog.substr(p_action_key, pg_catalog.length('answer_correct_') + 1);
    IF EXISTS (
      SELECT 1 FROM public.answer_attempts aa
      WHERE aa.user_id = p_user_id AND aa.question_id = v_action_id AND aa.is_correct
    ) THEN
      v_amount := 2;
    END IF;
  ELSIF pg_catalog.starts_with(p_action_key, 'placement_completed_') THEN
    v_action_id := pg_catalog.substr(p_action_key, pg_catalog.length('placement_completed_') + 1);
    IF EXISTS (
      SELECT 1 FROM public.placement_attempts pa
      WHERE pa.user_id = p_user_id AND pa.course_id = v_action_id
    ) THEN
      v_amount := 20;
    END IF;
  ELSIF pg_catalog.starts_with(p_action_key, 'reinforcement_completed_') THEN
    v_action_id := pg_catalog.substr(p_action_key, pg_catalog.length('reinforcement_completed_') + 1);
    IF EXISTS (
      SELECT 1 FROM public.reinforcement_attempts ra
      WHERE ra.user_id = p_user_id AND ra.reinforcement_node_id = v_action_id AND ra.is_correct
    ) THEN
      v_amount := 30;
    END IF;
  ELSIF pg_catalog.starts_with(p_action_key, 'lesson_completed_') THEN
    v_action_id := pg_catalog.substr(p_action_key, pg_catalog.length('lesson_completed_') + 1);
    IF EXISTS (
      SELECT 1
      FROM public.lesson_progress lp
      JOIN public.answer_attempts aa
        ON aa.user_id = lp.user_id AND aa.lesson_id = lp.lesson_id AND aa.course_id = lp.course_id
      WHERE lp.user_id = p_user_id
        AND lp.lesson_id = v_action_id
        AND lp.status = 'completed'
        AND aa.is_correct
    ) THEN
      v_amount := 20;
    END IF;
  END IF;

  IF v_amount IS NULL THEN
    RAISE EXCEPTION 'XP uchun serverda tasdiqlangan harakat topilmadi.' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.gamification_events (user_id, action_key, xp_delta)
  VALUES (p_user_id, p_action_key, v_amount)
  ON CONFLICT (user_id, action_key) DO NOTHING;
  v_inserted := FOUND;

  IF v_inserted THEN
    -- Consistent table lock order: daily_learning_stats -> gamification_profiles.
    IF NOT pg_catalog.starts_with(p_action_key, 'answer_correct_') THEN
      INSERT INTO public.daily_learning_stats (
        user_id, activity_date, xp_earned, lessons_completed, updated_at
      )
      VALUES (
        p_user_id,
        (pg_catalog.now() AT TIME ZONE 'Asia/Tashkent')::date,
        v_amount,
        CASE WHEN pg_catalog.starts_with(p_action_key, 'lesson_completed_') THEN 1 ELSE 0 END,
        pg_catalog.now()
      )
      ON CONFLICT (user_id, activity_date) DO UPDATE SET
        xp_earned = public.daily_learning_stats.xp_earned + EXCLUDED.xp_earned,
        lessons_completed = public.daily_learning_stats.lessons_completed + EXCLUDED.lessons_completed,
        updated_at = pg_catalog.now();
    END IF;

    INSERT INTO public.gamification_profiles (user_id, xp, updated_at)
    VALUES (p_user_id, v_amount, pg_catalog.now())
    ON CONFLICT (user_id) DO UPDATE SET
      xp = public.gamification_profiles.xp + EXCLUDED.xp,
      updated_at = pg_catalog.now();
  END IF;

  SELECT COALESCE(gp.xp, 0)
  INTO v_xp
  FROM public.gamification_profiles gp
  WHERE gp.user_id = p_user_id;

  RETURN pg_catalog.jsonb_build_object(
    'xp', COALESCE(v_xp, 0),
    'awarded', v_inserted
  );
END;
$$;

REVOKE ALL ON FUNCTION bilimyol_private.award_xp(UUID, INT, TEXT)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.award_xp(
  p_amount INT,
  p_action_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN bilimyol_private.award_xp(auth.uid(), p_amount, p_action_key);
END;
$$;

REVOKE ALL ON FUNCTION public.award_xp(INT, TEXT) FROM PUBLIC, anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Update save_placement_attempt & complete_lesson to use bilimyol_private.award_xp
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.save_placement_attempt(
  p_course_id TEXT,
  p_submissions JSONB,
  p_idempotency_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_attempt_id UUID;
  v_existing_score INT;
  v_existing_weakest TEXT;
  v_total INT := 0;
  v_correct INT := 0;
  v_submission JSONB;
  v_question RECORD;
  v_selected INT;
  v_is_correct BOOLEAN;
  v_score INT;
  v_existing_payload JSONB;
  v_request_payload JSONB;
  v_award JSONB;
  v_answer_xp INT := 0;
  v_correct_qids TEXT[] := '{}';
  v_qid TEXT;
  v_today DATE := (pg_catalog.now() AT TIME ZONE 'Asia/Tashkent')::date;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  IF p_submissions IS NULL OR pg_catalog.jsonb_typeof(p_submissions) <> 'array'
     OR pg_catalog.jsonb_array_length(p_submissions) = 0 THEN
    RAISE EXCEPTION 'Placement javoblari bo‘sh bo‘lishi mumkin emas.' USING ERRCODE = '22023';
  END IF;
  IF NULLIF(pg_catalog.btrim(p_idempotency_key), '') IS NULL THEN
    RAISE EXCEPTION 'Placement idempotency kaliti talab qilinadi.' USING ERRCODE = '22023';
  END IF;
  IF pg_catalog.jsonb_array_length(p_submissions) > 100 OR EXISTS (
    SELECT 1 FROM pg_catalog.jsonb_array_elements(p_submissions) AS item
    GROUP BY item->>'question_id' HAVING pg_catalog.count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Placement savollari takrorlangan yoki soni ortiqcha.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('learning:' || v_uid::TEXT, 0)
  );
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_uid::TEXT || ':' || p_course_id || ':' || p_idempotency_key, 0)
  );

  SELECT pa.id, pa.score, pa.weakest_skill_id
  INTO v_attempt_id, v_existing_score, v_existing_weakest
  FROM public.placement_attempts pa
  WHERE pa.user_id = v_uid
    AND pa.course_id = p_course_id
    AND pa.idempotency_key = p_idempotency_key
  LIMIT 1;

  IF v_attempt_id IS NOT NULL THEN
    SELECT pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object('question_id', pa.question_id, 'selected_index', pa.selected_index)
      ORDER BY pa.question_id
    )
    INTO v_existing_payload
    FROM public.placement_answers pa
    WHERE pa.attempt_id = v_attempt_id;

    SELECT pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object('question_id', item->>'question_id', 'selected_index', item->'selected_index')
      ORDER BY item->>'question_id'
    )
    INTO v_request_payload
    FROM pg_catalog.jsonb_array_elements(p_submissions) AS item;

    IF v_request_payload IS DISTINCT FROM v_existing_payload THEN
      RAISE EXCEPTION 'Idempotency kaliti boshqa placement javoblari uchun ishlatilgan.' USING ERRCODE = '22023';
    END IF;
    RETURN pg_catalog.jsonb_build_object(
      'attempt_id', v_attempt_id,
      'score', v_existing_score,
      'weakest_skill_id', v_existing_weakest,
      'already_processed', true
    );
  END IF;

  FOR v_submission IN SELECT * FROM pg_catalog.jsonb_array_elements(p_submissions) LOOP
    SELECT q.id, q.skill_id, q.correct_index, q.options
    INTO v_question
    FROM public.questions q
    WHERE q.id = v_submission->>'question_id'
      AND q.course_id = p_course_id
      AND q.is_placement = true;

    IF v_question.id IS NULL THEN
      RAISE EXCEPTION 'Placement savoli kurs bilan mos emas.' USING ERRCODE = '22023';
    END IF;
    IF NOT COALESCE((v_submission->>'selected_index') ~ '^[0-9]+$', false) THEN
      RAISE EXCEPTION 'Tanlangan javob indeksi noto‘g‘ri.' USING ERRCODE = '22023';
    END IF;
    v_selected := (v_submission->>'selected_index')::INT;
    IF v_selected IS NULL OR v_selected < 0
       OR v_selected >= pg_catalog.jsonb_array_length(v_question.options) THEN
      RAISE EXCEPTION 'Tanlangan javob indeksi noto‘g‘ri.' USING ERRCODE = '22023';
    END IF;

    v_is_correct := (v_selected = v_question.correct_index);
    v_total := v_total + 1;
    IF v_is_correct THEN v_correct := v_correct + 1; END IF;
  END LOOP;

  v_score := pg_catalog.round((v_correct::NUMERIC / NULLIF(v_total, 0)::NUMERIC) * 100)::INT;

  INSERT INTO public.placement_attempts (
    user_id, course_id, score, weakest_skill_id, idempotency_key, started_at, completed_at
  )
  VALUES (
    v_uid, p_course_id, v_score, NULL, p_idempotency_key, pg_catalog.now(), pg_catalog.now()
  )
  RETURNING id INTO v_attempt_id;

  FOR v_submission IN SELECT * FROM pg_catalog.jsonb_array_elements(p_submissions) LOOP
    SELECT q.skill_id, q.correct_index, q.options
    INTO v_question
    FROM public.questions q
    WHERE q.id = v_submission->>'question_id'
      AND q.course_id = p_course_id
      AND q.is_placement = true;

    v_selected := (v_submission->>'selected_index')::INT;
    v_is_correct := (v_selected = v_question.correct_index);

    INSERT INTO public.placement_answers (
      attempt_id, user_id, question_id, selected_index, is_correct, created_at
    )
    VALUES (
      v_attempt_id, v_uid, v_submission->>'question_id', v_selected, v_is_correct, pg_catalog.now()
    );

    INSERT INTO public.answer_attempts (
      user_id, course_id, skill_id, lesson_id, question_id,
      selected_index, selected_answer, is_correct, idempotency_key, created_at
    )
    VALUES (
      v_uid,
      p_course_id,
      v_question.skill_id,
      'placement_test',
      v_submission->>'question_id',
      v_selected,
      COALESCE(v_question.options->>v_selected, ''),
      v_is_correct,
      'placement:' || p_course_id || ':' || p_idempotency_key || ':' || (v_submission->>'question_id'),
      pg_catalog.now()
    )
    ON CONFLICT (user_id, idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

    IF v_is_correct THEN
      v_correct_qids := pg_catalog.array_append(v_correct_qids, v_submission->>'question_id');
    END IF;
  END LOOP;

  SELECT weakest.skill_id
  INTO v_existing_weakest
  FROM (
    SELECT q.skill_id,
           pg_catalog.round(pg_catalog.avg(CASE WHEN pa.is_correct THEN 100 ELSE 0 END)) AS skill_score
    FROM public.placement_answers pa
    JOIN public.questions q ON q.id = pa.question_id
    WHERE pa.attempt_id = v_attempt_id
    GROUP BY q.skill_id
    ORDER BY skill_score ASC, q.skill_id ASC
    LIMIT 1
  ) weakest;

  UPDATE public.placement_attempts
  SET weakest_skill_id = v_existing_weakest
  WHERE id = v_attempt_id;

  PERFORM public.recalculate_skill_scores(p_course_id);

  -- Acquire daily_learning_stats row lock before any gamification_profiles writes.
  INSERT INTO public.daily_learning_stats (
    user_id, activity_date, questions_answered, correct_answers, accuracy_percent, xp_earned, updated_at
  )
  VALUES (v_uid, v_today, v_total, v_correct, v_score, 0, pg_catalog.now())
  ON CONFLICT (user_id, activity_date) DO UPDATE SET
    questions_answered = public.daily_learning_stats.questions_answered + EXCLUDED.questions_answered,
    correct_answers = public.daily_learning_stats.correct_answers + EXCLUDED.correct_answers,
    accuracy_percent = pg_catalog.round(
      (public.daily_learning_stats.correct_answers + EXCLUDED.correct_answers)::NUMERIC * 100 /
      (public.daily_learning_stats.questions_answered + EXCLUDED.questions_answered)
    ),
    updated_at = pg_catalog.now();

  FOREACH v_qid IN ARRAY v_correct_qids LOOP
    v_award := bilimyol_private.award_xp(v_uid, 2, 'answer_correct_' || v_qid);
    IF (v_award->>'awarded')::BOOLEAN THEN
      v_answer_xp := v_answer_xp + 2;
    END IF;
  END LOOP;

  IF v_answer_xp > 0 THEN
    UPDATE public.daily_learning_stats
    SET xp_earned = public.daily_learning_stats.xp_earned + v_answer_xp,
        updated_at = pg_catalog.now()
    WHERE user_id = v_uid AND activity_date = v_today;
  END IF;

  PERFORM public.record_learning_activity(v_today);
  PERFORM bilimyol_private.award_xp(v_uid, 20, 'placement_completed_' || p_course_id);

  RETURN pg_catalog.jsonb_build_object(
    'attempt_id', v_attempt_id,
    'score', v_score,
    'weakest_skill_id', v_existing_weakest,
    'already_processed', false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.save_placement_attempt(TEXT, JSONB, TEXT)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.complete_lesson(p_lesson_id TEXT, p_course_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_course TEXT;
  v_skill TEXT;
  v_questions TEXT[];
  v_question TEXT;
  v_award JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('learning:' || v_uid::TEXT, 0)
  );

  IF p_course_id = 'course_math_01' THEN
    SELECT n.course_id
    INTO v_course
    FROM bilimyol_private.math_progression(v_uid) n
    WHERE n.target_lesson_id = p_lesson_id AND n.status = 'completed';

    IF v_course IS NULL THEN
      IF public.can_open_math_lesson(p_lesson_id) THEN
        RAISE EXCEPTION 'Darsni yakunlash uchun ikkala tekshiruvdagi mashqlarni bajaring va ishlangan misolni qayta ko‘ring.' USING ERRCODE = '42501';
      END IF;
      RAISE EXCEPTION 'Avval tayanch mavzularni o‘zlashtiring.' USING ERRCODE = '42501';
    END IF;
  ELSE
    SELECT l.course_id, l.skill_id, ARRAY(
      SELECT COALESCE(step->'interactiveQuestion', step->'interactive_question')->>'id'
      FROM pg_catalog.jsonb_array_elements(l.steps) AS step
      WHERE NULLIF(COALESCE(step->'interactiveQuestion', step->'interactive_question')->>'id', '') IS NOT NULL
    )
    INTO v_course, v_skill, v_questions
    FROM public.lessons l
    WHERE l.id = p_lesson_id AND l.is_published AND NOT l.is_archived;

    IF v_course IS NOT NULL AND COALESCE(pg_catalog.cardinality(v_questions), 0) = 0 THEN
      SELECT ARRAY[l.reinforcement_exercise->>'id']
      INTO v_questions
      FROM public.lessons l
      WHERE l.id = p_lesson_id AND NULLIF(l.reinforcement_exercise->>'id', '') IS NOT NULL;
    END IF;

    IF v_course IS NULL THEN
      SELECT gl.course_id, gl.skill_id, ARRAY[gl.questions->0->>'id']
      INTO v_course, v_skill, v_questions
      FROM public.generated_lessons gl
      WHERE gl.id = p_lesson_id;
    END IF;

    IF v_course IS NULL OR v_course IS DISTINCT FROM p_course_id THEN
      RAISE EXCEPTION 'Dars kursda topilmadi.' USING ERRCODE = '22023';
    END IF;
    IF COALESCE(pg_catalog.cardinality(v_questions), 0) = 0 THEN
      RAISE EXCEPTION 'Darsning baholanadigan savollari topilmadi.' USING ERRCODE = '22023';
    END IF;

    FOREACH v_question IN ARRAY v_questions LOOP
      IF v_question IS NULL OR NOT COALESCE((
        SELECT aa.is_correct
        FROM public.answer_attempts aa
        WHERE aa.user_id = v_uid
          AND aa.course_id = v_course
          AND aa.skill_id = v_skill
          AND aa.lesson_id = p_lesson_id
          AND aa.question_id = v_question
        ORDER BY aa.created_at DESC, aa.id DESC
        LIMIT 1
      ), false) THEN
        RAISE EXCEPTION 'Dars javoblari serverda tasdiqlanmagan.' USING ERRCODE = '42501';
      END IF;
    END LOOP;
  END IF;

  INSERT INTO public.lesson_progress (
    user_id, lesson_id, course_id, status, progress_percent, completed_at, updated_at
  )
  VALUES (v_uid, p_lesson_id, v_course, 'completed', 100, pg_catalog.now(), pg_catalog.now())
  ON CONFLICT (user_id, lesson_id) DO UPDATE SET
    status = 'completed',
    progress_percent = 100,
    completed_at = COALESCE(public.lesson_progress.completed_at, pg_catalog.now()),
    updated_at = pg_catalog.now();

  v_award := bilimyol_private.award_xp(v_uid, 20, 'lesson_completed_' || p_lesson_id);
  PERFORM public.record_learning_activity();

  RETURN pg_catalog.jsonb_build_object(
    'completed', true,
    'xp_awarded', CASE WHEN (v_award->>'awarded')::BOOLEAN THEN 20 ELSE 0 END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_lesson(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_lesson(TEXT, TEXT) TO authenticated, service_role;

-- Revoke over-granted legacy SECURITY DEFINER helpers and anon access to is_admin().
REVOKE ALL ON FUNCTION public.evaluate_placement_answer(TEXT, TEXT, INT)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.sync_profile(TEXT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.promote_user_to_admin(TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.enforce_profile_role_protection()
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 5. Timestamp-bounded reinforcement floor in recalculate_skill_scores
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recalculate_skill_scores(p_course_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_skill RECORD;
  v_total INT;
  v_correct INT;
  v_score INT;
  v_mastery TEXT;
  v_result JSONB := '{}'::jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('learning:' || v_uid::TEXT, 0)
  );

  FOR v_skill IN
    SELECT DISTINCT aa.skill_id
    FROM public.answer_attempts aa
    WHERE aa.user_id = v_uid AND aa.course_id = p_course_id
  LOOP
    SELECT pg_catalog.count(*)::INT,
           pg_catalog.count(*) FILTER (WHERE latest.is_correct)::INT
    INTO v_total, v_correct
    FROM (
      SELECT DISTINCT ON (aa.question_id) aa.is_correct
      FROM public.answer_attempts aa
      WHERE aa.user_id = v_uid AND aa.course_id = p_course_id AND aa.skill_id = v_skill.skill_id
      ORDER BY aa.question_id, aa.created_at DESC, aa.id DESC
    ) latest;

    v_score := COALESCE(
      pg_catalog.round((v_correct::NUMERIC / NULLIF(v_total, 0)::NUMERIC) * 100)::INT,
      0
    );

    -- Apply verified reinforcement floor only until a strictly newer wrong attempt
    -- supersedes it (prevents eternal 94%-100% score lock after subsequent failures).
    SELECT GREATEST(v_score, COALESCE(pg_catalog.max(ra.after_score), 0))
    INTO v_score
    FROM public.reinforcement_attempts ra
    WHERE ra.user_id = v_uid
      AND ra.course_id = p_course_id
      AND ra.skill_id = v_skill.skill_id
      AND ra.is_correct = true
      AND NOT EXISTS (
        SELECT 1 FROM public.answer_attempts newer_wrong
        WHERE newer_wrong.user_id = v_uid
          AND newer_wrong.course_id = p_course_id
          AND newer_wrong.skill_id = v_skill.skill_id
          AND newer_wrong.is_correct = false
          AND newer_wrong.created_at > ra.created_at
      );

    v_mastery := CASE
      WHEN v_score < 40 THEN 'needs_remediation'
      WHEN v_score < 60 THEN 'developing'
      WHEN v_score < 80 THEN 'proficient'
      ELSE 'mastered'
    END;

    INSERT INTO public.learner_skill_scores (
      user_id, course_id, skill_id, score, mastery_level, attempt_count, last_updated
    )
    VALUES (v_uid, p_course_id, v_skill.skill_id, v_score, v_mastery, v_total, pg_catalog.now())
    ON CONFLICT (user_id, course_id, skill_id) DO UPDATE SET
      score = EXCLUDED.score,
      mastery_level = EXCLUDED.mastery_level,
      attempt_count = EXCLUDED.attempt_count,
      last_updated = pg_catalog.now();

    v_result := v_result || pg_catalog.jsonb_build_object(
      v_skill.skill_id,
      pg_catalog.jsonb_build_object('score', v_score, 'attempt_count', v_total, 'mastery_level', v_mastery)
    );
  END LOOP;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.recalculate_skill_scores(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recalculate_skill_scores(TEXT) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 6. Hardened bilimyol_private.submit_answer_attempt & public.submit_answer_attempt
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION bilimyol_private.submit_answer_attempt(
  p_user_id UUID,
  p_course_id TEXT,
  p_skill_id TEXT,
  p_lesson_id TEXT,
  p_question_id TEXT,
  p_selected_index INT,
  p_selected_text TEXT,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_uid UUID;
  v_existing_id UUID;
  v_existing_is_correct BOOLEAN;
  v_question_course TEXT;
  v_question_skill TEXT;
  v_correct_index INT;
  v_explanation TEXT;
  v_options JSONB;
  v_is_correct BOOLEAN := false;
  v_unique_total INT;
  v_unique_correct INT;
  v_new_skill_score INT;
  v_overall_score INT := 0;
  v_mastery_level TEXT;
  v_xp_delta INT := 0;
  v_pending_answer_xp INT := 0;
  v_total_xp INT := 0;
  v_award JSONB;
  v_eff_idempotency TEXT;
  v_today DATE;
  v_reinf_target RECORD;
  v_wrong_count INT := 0;
  v_hide_mistake_spoiler BOOLEAN := false;
  v_q_row RECORD;
BEGIN
  v_caller_uid := auth.uid();
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'Xavfsizlik qoidasi: javob topshirish uchun autentifikatsiya talab qilinadi.'
      USING ERRCODE = '42501';
  END IF;
  IF p_user_id IS DISTINCT FROM v_caller_uid THEN
    RAISE EXCEPTION 'Xavfsizlik qoidasi: boshqa foydalanuvchi nomidan javob topshirish taqiqlanadi.'
      USING ERRCODE = '42501';
  END IF;

  v_today := (pg_catalog.now() AT TIME ZONE 'Asia/Tashkent')::date;
  IF NULLIF(pg_catalog.btrim(p_course_id), '') IS NULL
     OR NULLIF(pg_catalog.btrim(p_skill_id), '') IS NULL
     OR NULLIF(pg_catalog.btrim(p_lesson_id), '') IS NULL
     OR NULLIF(pg_catalog.btrim(p_question_id), '') IS NULL
     OR p_selected_index IS NULL
     OR p_selected_index < 0 THEN
    RAISE EXCEPTION 'Javob konteksti yoki indeksi noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('learning:' || p_user_id::TEXT, 0)
  );

  v_eff_idempotency := COALESCE(
    p_idempotency_key,
    p_lesson_id || ':' || p_question_id || ':' || p_selected_index::TEXT
  );

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::TEXT || ':' || v_eff_idempotency, 0)
  );

  SELECT aa.id, aa.is_correct
  INTO v_existing_id, v_existing_is_correct
  FROM public.answer_attempts aa
  WHERE aa.user_id = p_user_id AND aa.idempotency_key = v_eff_idempotency
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.answer_attempts aa
      WHERE aa.id = v_existing_id
        AND (
          aa.course_id IS DISTINCT FROM p_course_id
          OR aa.skill_id IS DISTINCT FROM p_skill_id
          OR aa.lesson_id IS DISTINCT FROM p_lesson_id
          OR aa.question_id IS DISTINCT FROM p_question_id
          OR aa.selected_index IS DISTINCT FROM p_selected_index
        )
    ) THEN
      RAISE EXCEPTION 'Idempotency kaliti boshqa javob uchun ishlatilgan.' USING ERRCODE = '22023';
    END IF;

    SELECT COALESCE(lss.score, 50)
    INTO v_new_skill_score
    FROM public.learner_skill_scores lss
    WHERE lss.user_id = p_user_id AND lss.course_id = p_course_id AND lss.skill_id = p_skill_id;

    SELECT COALESCE(pg_catalog.round(pg_catalog.avg(lss.score))::INT, 50)
    INTO v_overall_score
    FROM public.learner_skill_scores lss
    WHERE lss.user_id = p_user_id AND lss.course_id = p_course_id;

    SELECT COALESCE(gp.xp, 0)
    INTO v_total_xp
    FROM public.gamification_profiles gp
    WHERE gp.user_id = p_user_id;

    -- Do not leak answer explanation on an idempotent replay of an incorrect answer.
    IF v_existing_is_correct = true THEN
      SELECT q.explanation INTO v_explanation
      FROM public.questions q WHERE q.id = p_question_id AND NOT q.is_placement;
    ELSE
      v_explanation := 'Javob avval qayd etilgan.';
    END IF;

    RETURN pg_catalog.jsonb_build_object(
      'is_correct', v_existing_is_correct,
      'explanation', COALESCE(v_explanation, 'Javob avval qayd etilgan.'),
      'new_skill_score', COALESCE(v_new_skill_score, 50),
      'overall_score', COALESCE(v_overall_score, 50),
      'xp_awarded', 0,
      'total_xp', COALESCE(v_total_xp, 0),
      'already_processed', true
    );
  END IF;

  -- Authoritative (p_lesson_id, p_question_id) resolution against published content only.
  IF pg_catalog.starts_with(p_lesson_id, 'reinf_') THEN
    SELECT rt.canonical_reinf_id, rt.target_lesson_id, rt.required_score
    INTO v_reinf_target
    FROM bilimyol_private.resolve_reinforcement_target(p_course_id, p_skill_id, p_lesson_id) rt
    LIMIT 1;

    IF v_reinf_target.target_lesson_id IS NULL THEN
      RAISE EXCEPTION 'Mustahkamlash tuguni kurs va ko‘nikmaga mos emas.' USING ERRCODE = '22023';
    END IF;

    SELECT l.course_id,
           CASE
             WHEN l.skill_id = p_skill_id THEN l.skill_id
             ELSE COALESCE(NULLIF(COALESCE(cand.elem->>'skillId', cand.elem->>'skill_id'), ''), l.skill_id)
           END AS resolved_skill,
           COALESCE(cand.elem->>'correct_index', cand.elem->>'correctIndex')::INT AS resolved_ci,
           cand.elem->>'explanation' AS resolved_exp,
           cand.elem->'options' AS resolved_opts
    INTO v_question_course, v_question_skill, v_correct_index, v_explanation, v_options
    FROM public.lessons l
    CROSS JOIN LATERAL (
      SELECT l.reinforcement_exercise AS elem
      WHERE pg_catalog.jsonb_typeof(l.reinforcement_exercise) = 'object'
      UNION ALL
      SELECT COALESCE(
        pg_catalog.to_jsonb(l)->'alternate_exercise',
        pg_catalog.to_jsonb(l)->'alternateExercise'
      ) AS elem
      WHERE pg_catalog.jsonb_typeof(
        COALESCE(
          pg_catalog.to_jsonb(l)->'alternate_exercise',
          pg_catalog.to_jsonb(l)->'alternateExercise'
        )
      ) = 'object'
    ) cand
    WHERE l.id = v_reinf_target.target_lesson_id
      AND l.course_id = p_course_id
      AND l.is_published
      AND NOT l.is_archived
      AND cand.elem->>'id' = p_question_id
    LIMIT 1;

    IF v_question_course IS NULL THEN
      RAISE EXCEPTION 'Savol ushbu mustahkamlash mashqiga tegishli emas.' USING ERRCODE = '22023';
    END IF;

    IF v_correct_index IS NULL THEN
      SELECT q.correct_index, q.explanation, q.options
      INTO v_q_row
      FROM public.questions q
      WHERE q.id = p_question_id
        AND NOT q.is_placement
        AND q.course_id = p_course_id
        AND q.skill_id = v_question_skill;
      v_correct_index := COALESCE(v_correct_index, v_q_row.correct_index);
      v_explanation := COALESCE(v_explanation, v_q_row.explanation);
      v_options := COALESCE(v_options, v_q_row.options);
    END IF;
  ELSE
    -- Regular published, non-archived curated lesson bound strictly by l.id = p_lesson_id
    SELECT l.course_id,
           CASE
             WHEN l.skill_id = p_skill_id THEN l.skill_id
             ELSE COALESCE(NULLIF(COALESCE(cand.elem->>'skillId', cand.elem->>'skill_id'), ''), l.skill_id)
           END AS resolved_skill,
           COALESCE(cand.elem->>'correct_index', cand.elem->>'correctIndex')::INT AS resolved_ci,
           cand.elem->>'explanation' AS resolved_exp,
           cand.elem->'options' AS resolved_opts
    INTO v_question_course, v_question_skill, v_correct_index, v_explanation, v_options
    FROM public.lessons l
    CROSS JOIN LATERAL (
      SELECT COALESCE(step_elem->'interactiveQuestion', step_elem->'interactive_question') AS elem
      FROM pg_catalog.jsonb_array_elements(
        CASE WHEN pg_catalog.jsonb_typeof(l.steps) = 'array' THEN l.steps ELSE '[]'::jsonb END
      ) AS step_elem
      UNION ALL
      SELECT COALESCE(
        pg_catalog.to_jsonb(l)->'alternate_exercise',
        pg_catalog.to_jsonb(l)->'alternateExercise'
      ) AS elem
      WHERE pg_catalog.jsonb_typeof(
        COALESCE(
          pg_catalog.to_jsonb(l)->'alternate_exercise',
          pg_catalog.to_jsonb(l)->'alternateExercise'
        )
      ) = 'object'
      UNION ALL
      SELECT l.reinforcement_exercise AS elem
      WHERE pg_catalog.jsonb_typeof(l.reinforcement_exercise) = 'object'
        AND NOT EXISTS (
          SELECT 1
          FROM pg_catalog.jsonb_array_elements(
            CASE WHEN pg_catalog.jsonb_typeof(l.steps) = 'array' THEN l.steps ELSE '[]'::jsonb END
          ) AS s_chk
          WHERE NULLIF(COALESCE(s_chk->'interactiveQuestion', s_chk->'interactive_question')->>'id', '') IS NOT NULL
        )
    ) cand
    WHERE l.id = p_lesson_id
      AND l.is_published
      AND NOT l.is_archived
      AND pg_catalog.jsonb_typeof(cand.elem) = 'object'
      AND cand.elem->>'id' = p_question_id
    LIMIT 1;

    IF v_question_course IS NOT NULL AND v_correct_index IS NULL THEN
      SELECT q.correct_index, q.explanation, q.options
      INTO v_q_row
      FROM public.questions q
      WHERE q.id = p_question_id
        AND NOT q.is_placement
        AND q.course_id = v_question_course
        AND q.skill_id = v_question_skill;
      v_correct_index := COALESCE(v_correct_index, v_q_row.correct_index);
      v_explanation := COALESCE(v_explanation, v_q_row.explanation);
      v_options := COALESCE(v_options, v_q_row.options);
    END IF;

    -- AI-generated lesson (non-math only, matching learner_generated_lessons view)
    IF v_question_course IS NULL AND NOT EXISTS (
      SELECT 1 FROM public.lessons existing_l WHERE existing_l.id = p_lesson_id
    ) THEN
      SELECT gl.course_id,
             gl.skill_id,
             COALESCE(cand.elem->>'correct_index', cand.elem->>'correctIndex')::INT,
             cand.elem->>'explanation',
             cand.elem->'options'
      INTO v_question_course, v_question_skill, v_correct_index, v_explanation, v_options
      FROM public.generated_lessons gl
      CROSS JOIN LATERAL (
        SELECT elem
        FROM pg_catalog.jsonb_array_elements(
          CASE WHEN pg_catalog.jsonb_typeof(gl.questions) = 'array' THEN gl.questions ELSE '[]'::jsonb END
        ) AS elem
        UNION ALL
        SELECT COALESCE(step_elem->'interactiveQuestion', step_elem->'interactive_question') AS elem
        FROM pg_catalog.jsonb_array_elements(
          CASE WHEN pg_catalog.jsonb_typeof(gl.steps) = 'array' THEN gl.steps ELSE '[]'::jsonb END
        ) AS step_elem
      ) cand
      WHERE gl.id = p_lesson_id
        AND gl.course_id <> 'course_math_01'
        AND pg_catalog.jsonb_typeof(cand.elem) = 'object'
        AND cand.elem->>'id' = p_question_id
      LIMIT 1;

      IF v_question_course IS NOT NULL AND v_correct_index IS NULL THEN
        SELECT q.correct_index, q.explanation, q.options
        INTO v_q_row
        FROM public.questions q
        WHERE q.id = p_question_id
          AND NOT q.is_placement
          AND q.course_id = v_question_course
          AND q.skill_id = v_question_skill;
        v_correct_index := COALESCE(v_correct_index, v_q_row.correct_index);
        v_explanation := COALESCE(v_explanation, v_q_row.explanation);
        v_options := COALESCE(v_options, v_q_row.options);
      END IF;
    END IF;
  END IF;

  IF v_question_course IS NULL THEN
    RAISE EXCEPTION 'Savol dars tarkibida yoki chop etilgan bazada topilmadi.' USING ERRCODE = '22023';
  ELSIF v_question_course <> p_course_id OR v_question_skill <> p_skill_id THEN
    RAISE EXCEPTION 'Savol kurs yoki ko‘nikma kontekstiga mos emas.' USING ERRCODE = '22023';
  ELSIF v_correct_index IS NOT NULL THEN
    IF v_options IS NULL
       OR pg_catalog.jsonb_typeof(v_options) <> 'array'
       OR p_selected_index IS NULL
       OR p_selected_index < 0
       OR p_selected_index >= pg_catalog.jsonb_array_length(v_options) THEN
      RAISE EXCEPTION 'Tanlangan javob indeksi noto‘g‘ri.' USING ERRCODE = '22023';
    END IF;
    v_is_correct := (p_selected_index = v_correct_index);
  ELSE
    RAISE EXCEPTION 'Savol server bazasida to‘liq sozlanmagan.' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.answer_attempts (
    user_id, course_id, skill_id, lesson_id, question_id,
    selected_index, selected_answer, is_correct, idempotency_key, created_at
  )
  VALUES (
    p_user_id, p_course_id, p_skill_id, p_lesson_id, p_question_id,
    p_selected_index, p_selected_text, v_is_correct, v_eff_idempotency, pg_catalog.now()
  );

  SELECT pg_catalog.count(*)::INT,
         pg_catalog.count(*) FILTER (WHERE latest.is_correct = true)::INT
  INTO v_unique_total, v_unique_correct
  FROM (
    SELECT DISTINCT ON (aa.question_id) aa.question_id, aa.is_correct
    FROM public.answer_attempts aa
    WHERE aa.user_id = p_user_id AND aa.course_id = p_course_id AND aa.skill_id = p_skill_id
    ORDER BY aa.question_id, aa.created_at DESC, aa.id DESC
  ) latest;

  IF v_unique_total > 0 THEN
    v_new_skill_score := pg_catalog.round((v_unique_correct::NUMERIC / v_unique_total::NUMERIC) * 100)::INT;
  ELSE
    v_new_skill_score := CASE WHEN v_is_correct THEN 100 ELSE 0 END;
  END IF;
  v_new_skill_score := GREATEST(0, LEAST(100, v_new_skill_score));

  -- Apply verified reinforcement floor only until a strictly newer wrong attempt supersedes it.
  SELECT GREATEST(v_new_skill_score, COALESCE(pg_catalog.max(ra.after_score), 0))
  INTO v_new_skill_score
  FROM public.reinforcement_attempts ra
  WHERE ra.user_id = p_user_id
    AND ra.course_id = p_course_id
    AND ra.skill_id = p_skill_id
    AND ra.is_correct = true
    AND NOT EXISTS (
      SELECT 1 FROM public.answer_attempts newer_wrong
      WHERE newer_wrong.user_id = p_user_id
        AND newer_wrong.course_id = p_course_id
        AND newer_wrong.skill_id = p_skill_id
        AND newer_wrong.is_correct = false
        AND newer_wrong.created_at > ra.created_at
    );

  IF v_new_skill_score < 40 THEN
    v_mastery_level := 'needs_remediation';
  ELSIF v_new_skill_score < 60 THEN
    v_mastery_level := 'developing';
  ELSIF v_new_skill_score < 80 THEN
    v_mastery_level := 'proficient';
  ELSE
    v_mastery_level := 'mastered';
  END IF;

  INSERT INTO public.learner_skill_scores (
    user_id, course_id, skill_id, score, mastery_level, attempt_count, last_updated
  )
  VALUES (
    p_user_id, p_course_id, p_skill_id, v_new_skill_score, v_mastery_level, v_unique_total, pg_catalog.now()
  )
  ON CONFLICT (user_id, course_id, skill_id) DO UPDATE SET
    score = EXCLUDED.score,
    mastery_level = EXCLUDED.mastery_level,
    attempt_count = EXCLUDED.attempt_count,
    last_updated = pg_catalog.now();

  SELECT COALESCE(pg_catalog.round(pg_catalog.avg(lss.score))::INT, v_new_skill_score)
  INTO v_overall_score
  FROM public.learner_skill_scores lss
  WHERE lss.user_id = p_user_id AND lss.course_id = p_course_id;

  IF v_is_correct AND NOT EXISTS (
    SELECT 1 FROM public.gamification_events ge
    WHERE ge.user_id = p_user_id AND ge.action_key = 'answer_correct_' || p_question_id
  ) THEN
    v_pending_answer_xp := 2;
  END IF;

  -- Lock daily_learning_stats BEFORE any gamification_profiles write, and delegate
  -- streak updates to record_learning_activity().
  INSERT INTO public.daily_learning_stats (
    user_id, activity_date, questions_answered, correct_answers,
    accuracy_percent, xp_earned, overall_score, updated_at
  )
  VALUES (
    p_user_id, v_today, 1,
    (CASE WHEN v_is_correct THEN 1 ELSE 0 END),
    (CASE WHEN v_is_correct THEN 100 ELSE 0 END),
    v_pending_answer_xp, v_overall_score, pg_catalog.now()
  )
  ON CONFLICT (user_id, activity_date) DO UPDATE SET
    questions_answered = public.daily_learning_stats.questions_answered + 1,
    correct_answers = public.daily_learning_stats.correct_answers + (CASE WHEN v_is_correct THEN 1 ELSE 0 END),
    accuracy_percent = pg_catalog.round(
      ((public.daily_learning_stats.correct_answers + (CASE WHEN v_is_correct THEN 1 ELSE 0 END))::NUMERIC /
       (public.daily_learning_stats.questions_answered + 1)::NUMERIC) * 100
    )::INT,
    xp_earned = public.daily_learning_stats.xp_earned + EXCLUDED.xp_earned,
    overall_score = v_overall_score,
    updated_at = pg_catalog.now();

  IF v_is_correct THEN
    v_award := bilimyol_private.award_xp(p_user_id, 2, 'answer_correct_' || p_question_id);
    v_xp_delta := CASE WHEN (v_award->>'awarded')::BOOLEAN THEN 2 ELSE 0 END;
  ELSE
    v_xp_delta := 0;
  END IF;

  PERFORM public.record_learning_activity(v_today);

  SELECT COALESCE(gp.xp, 0)
  INTO v_total_xp
  FROM public.gamification_profiles gp
  WHERE gp.user_id = p_user_id;

  -- Suppress answer-spoiling explanation on the 1st mistake of an active Math Pilot checkpoint.
  IF NOT v_is_correct AND p_course_id = 'course_math_01' AND EXISTS (
    SELECT 1 FROM bilimyol_private.math_pilot_items mpi
    WHERE mpi.lesson_id = p_lesson_id AND mpi.question_id = p_question_id
  ) THEN
    SELECT pg_catalog.count(*)::INT
    INTO v_wrong_count
    FROM public.answer_attempts aa
    WHERE aa.user_id = p_user_id
      AND aa.course_id = p_course_id
      AND aa.skill_id = p_skill_id
      AND aa.lesson_id = p_lesson_id
      AND aa.question_id = p_question_id
      AND aa.is_correct = false;

    IF v_wrong_count < 2 AND NOT EXISTS (
      SELECT 1 FROM bilimyol_private.math_progression(p_user_id) mp
      WHERE mp.target_lesson_id = p_lesson_id
        AND mp.mastery_state IN ('needs_review', 'mastered')
    ) THEN
      v_hide_mistake_spoiler := true;
    END IF;
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'is_correct', v_is_correct,
    'explanation', CASE
      WHEN v_hide_mistake_spoiler THEN 'Ishlangan misolni ko‘rib chiqing va qayta urinib ko‘ring.'
      ELSE COALESCE(v_explanation, 'To‘g‘ri yechim.')
    END,
    'new_skill_score', v_new_skill_score,
    'overall_score', v_overall_score,
    'xp_awarded', v_xp_delta,
    'total_xp', COALESCE(v_total_xp, 0),
    'total_attempts', v_unique_total,
    'correct_attempts', v_unique_correct,
    'already_processed', false
  );
END;
$$;

REVOKE ALL ON FUNCTION bilimyol_private.submit_answer_attempt(
  UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT
) FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.submit_answer_attempt(
  p_user_id UUID, p_course_id TEXT, p_skill_id TEXT, p_lesson_id TEXT, p_question_id TEXT,
  p_selected_index INT, p_selected_text TEXT, p_idempotency_key TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reinf_target RECORD;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_user_id OR p_lesson_id = 'placement_test'
    OR EXISTS (SELECT 1 FROM public.questions WHERE id = p_question_id AND is_placement) THEN
    RAISE EXCEPTION 'Ushbu javobni bu yo‘l orqali topshirib bo‘lmaydi.' USING ERRCODE = '42501';
  END IF;

  IF p_course_id = 'course_math_01' THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('learning:' || p_user_id::TEXT, 0)
    );
    IF pg_catalog.starts_with(COALESCE(p_lesson_id, ''), 'reinf_') THEN
      SELECT rt.target_lesson_id
      INTO v_reinf_target
      FROM bilimyol_private.resolve_reinforcement_target(p_course_id, p_skill_id, p_lesson_id) rt
      LIMIT 1;

      IF v_reinf_target.target_lesson_id IS NULL THEN
        RAISE EXCEPTION 'Mustahkamlash tuguni kurs va ko‘nikmaga mos emas.' USING ERRCODE = '22023';
      END IF;
      IF NOT public.can_open_math_lesson(v_reinf_target.target_lesson_id) THEN
        RAISE EXCEPTION 'Avval tayanch mavzularni o‘zlashtiring.' USING ERRCODE = '42501';
      END IF;
    ELSE
      IF NOT public.can_open_math_lesson(p_lesson_id) THEN
        RAISE EXCEPTION 'Avval tayanch mavzularni o‘zlashtiring.' USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;

  RETURN bilimyol_private.submit_answer_attempt(
    p_user_id, p_course_id, p_skill_id,
    p_lesson_id, p_question_id, p_selected_index, p_selected_text, p_idempotency_key
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_answer_attempt(
  UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_answer_attempt(
  UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT
) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 7. Hardened public.complete_reinforcement (FIX-P0-27 & FIX-P0-28)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_reinforcement(
  p_reinforcement_node_id TEXT,
  p_course_id TEXT,
  p_skill_id TEXT,
  p_question_id TEXT,
  p_xp_awarded INT DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_target RECORD;
  v_before INT := 0;
  v_current_raw INT := 0;
  v_after INT := 22;
  v_unique_total INT := 0;
  v_unique_correct INT := 0;
  v_server_xp_awarded INT := 30;
  v_existing RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.skills s
    WHERE s.id = p_skill_id AND s.course_id = p_course_id
  ) THEN
    RAISE EXCEPTION 'Ko‘nikma kurs bilan mos emas.' USING ERRCODE = '22023';
  END IF;

  SELECT rt.canonical_reinf_id, rt.target_lesson_id, rt.required_score
  INTO v_target
  FROM bilimyol_private.resolve_reinforcement_target(p_course_id, p_skill_id, p_reinforcement_node_id) rt
  LIMIT 1;

  IF v_target.target_lesson_id IS NULL THEN
    RAISE EXCEPTION 'Mustahkamlash tuguni kurs va ko‘nikmaga mos emas.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('learning:' || v_uid::TEXT, 0)
  );
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_uid::TEXT || ':' || v_target.canonical_reinf_id, 0)
  );

  IF p_course_id = 'course_math_01' AND NOT public.can_open_math_lesson(v_target.target_lesson_id) THEN
    RAISE EXCEPTION 'Avval tayanch mavzularni o‘zlashtiring.' USING ERRCODE = '42501';
  END IF;

  -- Must use the lesson's dedicated reinforcement (or alternate) exercise, not a regular step quiz.
  IF NOT EXISTS (
    SELECT 1
    FROM public.lessons l
    CROSS JOIN LATERAL (
      SELECT l.reinforcement_exercise AS elem
      WHERE pg_catalog.jsonb_typeof(l.reinforcement_exercise) = 'object'
      UNION ALL
      SELECT COALESCE(
        pg_catalog.to_jsonb(l)->'alternate_exercise',
        pg_catalog.to_jsonb(l)->'alternateExercise'
      ) AS elem
      WHERE pg_catalog.jsonb_typeof(
        COALESCE(
          pg_catalog.to_jsonb(l)->'alternate_exercise',
          pg_catalog.to_jsonb(l)->'alternateExercise'
        )
      ) = 'object'
    ) cand
    WHERE l.id = v_target.target_lesson_id
      AND l.course_id = p_course_id
      AND l.is_published
      AND NOT l.is_archived
      AND cand.elem->>'id' = p_question_id
      AND COALESCE(NULLIF(COALESCE(cand.elem->>'skillId', cand.elem->>'skill_id'), ''), l.skill_id) = p_skill_id
  ) THEN
    RAISE EXCEPTION 'Mustahkamlash savoli darsning ruxsat etilgan mashqiga mos emas.' USING ERRCODE = '22023';
  END IF;

  -- Exact same node id retry stays idempotent.
  SELECT * INTO v_existing
  FROM public.reinforcement_attempts ra
  WHERE ra.user_id = v_uid AND ra.reinforcement_node_id = p_reinforcement_node_id;

  IF FOUND THEN
    RETURN pg_catalog.jsonb_build_object(
      'already_processed', true,
      'old_score', v_existing.before_score,
      'new_score', v_existing.after_score,
      'xp_awarded', 0
    );
  END IF;

  -- Block double-dipping across aliases referencing the same canonical node or target lesson.
  IF EXISTS (
    SELECT 1
    FROM public.reinforcement_attempts ra
    WHERE ra.user_id = v_uid
      AND ra.course_id = p_course_id
      AND ra.skill_id = p_skill_id
      AND (
        ra.reinforcement_node_id = v_target.canonical_reinf_id
        OR ra.reinforcement_node_id = 'reinf_lesson_' || v_target.target_lesson_id
        OR ra.reinforcement_node_id = 'reinf_' || p_course_id || '_' || p_skill_id
        OR EXISTS (
          SELECT 1
          FROM bilimyol_private.resolve_reinforcement_target(
            p_course_id, p_skill_id, ra.reinforcement_node_id
          ) existing_t
          WHERE existing_t.target_lesson_id = v_target.target_lesson_id
        )
      )
  ) THEN
    RAISE EXCEPTION 'Ushbu dars bo‘yicha mustahkamlash mashqi allaqachon yakunlangan.' USING ERRCODE = '42501';
  END IF;

  IF NOT COALESCE((
    SELECT aa.is_correct
    FROM public.answer_attempts aa
    WHERE aa.user_id = v_uid
      AND aa.course_id = p_course_id
      AND aa.skill_id = p_skill_id
      AND aa.lesson_id = p_reinforcement_node_id
      AND aa.question_id = p_question_id
    ORDER BY aa.created_at DESC, aa.id DESC
    LIMIT 1
  ), false) THEN
    RAISE EXCEPTION 'Mustahkamlash javobi serverda to‘g‘ri deb tasdiqlanmagan.'
      USING ERRCODE = '42501';
  END IF;

  -- Compute true pre-reinforcement score excluding the reinforcement submission itself
  -- (prevents 2-RPC self-lockout when submit_answer_attempt already boosted learner_skill_scores).
  SELECT pg_catalog.count(*)::INT,
         pg_catalog.count(*) FILTER (WHERE latest.is_correct)::INT
  INTO v_unique_total, v_unique_correct
  FROM (
    SELECT DISTINCT ON (aa.question_id) aa.is_correct
    FROM public.answer_attempts aa
    WHERE aa.user_id = v_uid
      AND aa.course_id = p_course_id
      AND aa.skill_id = p_skill_id
      AND aa.lesson_id NOT IN (
        p_reinforcement_node_id,
        v_target.canonical_reinf_id,
        'reinf_lesson_' || v_target.target_lesson_id
      )
    ORDER BY aa.question_id, aa.created_at DESC, aa.id DESC
  ) latest;

  v_before := COALESCE(
    pg_catalog.round((v_unique_correct::NUMERIC / NULLIF(v_unique_total, 0)::NUMERIC) * 100)::INT,
    0
  );

  SELECT GREATEST(v_before, COALESCE(pg_catalog.max(ra.after_score), 0))
  INTO v_before
  FROM public.reinforcement_attempts ra
  WHERE ra.user_id = v_uid
    AND ra.course_id = p_course_id
    AND ra.skill_id = p_skill_id
    AND ra.is_correct = true
    AND NOT EXISTS (
      SELECT 1 FROM public.answer_attempts newer_wrong
      WHERE newer_wrong.user_id = v_uid
        AND newer_wrong.course_id = p_course_id
        AND newer_wrong.skill_id = p_skill_id
        AND newer_wrong.is_correct = false
        AND newer_wrong.created_at > ra.created_at
    );

  IF v_before >= v_target.required_score THEN
    RAISE EXCEPTION 'Ushbu ko‘nikma allaqachon yetarli darajada o‘zlashtirilgan.' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(lss.score, 0)
  INTO v_current_raw
  FROM public.learner_skill_scores lss
  WHERE lss.user_id = v_uid AND lss.course_id = p_course_id AND lss.skill_id = p_skill_id;

  v_after := LEAST(100, GREATEST(COALESCE(v_current_raw, 0), v_before + 22));

  INSERT INTO public.reinforcement_attempts (
    user_id, course_id, skill_id, reinforcement_node_id,
    before_score, after_score, is_correct, xp_awarded, created_at
  )
  VALUES (
    v_uid, p_course_id, p_skill_id, p_reinforcement_node_id,
    v_before, v_after, true, v_server_xp_awarded, pg_catalog.now()
  );

  INSERT INTO public.learner_skill_scores (
    user_id, course_id, skill_id, score, mastery_level, attempt_count, last_updated
  )
  VALUES (
    v_uid, p_course_id, p_skill_id, v_after,
    CASE
      WHEN v_after < 40 THEN 'needs_remediation'
      WHEN v_after < 60 THEN 'developing'
      WHEN v_after < 80 THEN 'proficient'
      ELSE 'mastered'
    END,
    1, pg_catalog.now()
  )
  ON CONFLICT (user_id, course_id, skill_id) DO UPDATE SET
    score = EXCLUDED.score,
    mastery_level = EXCLUDED.mastery_level,
    last_updated = pg_catalog.now();

  PERFORM bilimyol_private.award_xp(
    v_uid,
    v_server_xp_awarded,
    'reinforcement_completed_' || p_reinforcement_node_id
  );
  PERFORM public.record_learning_activity();

  RETURN pg_catalog.jsonb_build_object(
    'already_processed', false,
    'old_score', v_before,
    'new_score', v_after,
    'xp_awarded', v_server_xp_awarded
  );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_reinforcement(TEXT, TEXT, TEXT, TEXT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_reinforcement(TEXT, TEXT, TEXT, TEXT, INT)
  TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 8. Tutor mistake context & 1st-mistake Math checkpoint feedback guard
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.tutor_mistake_context(
  p_user_id UUID, p_course_id TEXT, p_skill_id TEXT, p_question_id TEXT
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH attempt AS (
    SELECT aa.lesson_id, aa.selected_index
    FROM public.answer_attempts aa
    WHERE aa.user_id = p_user_id
      AND aa.course_id = p_course_id
      AND aa.skill_id = p_skill_id
      AND aa.question_id = p_question_id
      AND NOT aa.is_correct
    ORDER BY aa.created_at DESC, aa.id DESC
    LIMIT 1
  ), question AS (
    SELECT pg_catalog.to_jsonb(q) AS body
    FROM public.questions q
    WHERE q.id = p_question_id
      AND q.course_id = p_course_id
      AND q.skill_id = p_skill_id
      AND NOT q.is_placement
    UNION ALL
    SELECT item AS body
    FROM attempt a
    JOIN public.generated_lessons l ON l.id = a.lesson_id
    CROSS JOIN LATERAL pg_catalog.jsonb_array_elements(l.questions) AS item
    WHERE l.course_id = p_course_id
      AND l.skill_id = p_skill_id
      AND item->>'id' = p_question_id
    UNION ALL
    SELECT items.item AS body
    FROM attempt a
    JOIN public.lessons l
      ON l.id = a.lesson_id
      OR (
        pg_catalog.starts_with(a.lesson_id, 'reinf_')
        AND l.id = (
          SELECT rt.target_lesson_id
          FROM bilimyol_private.resolve_reinforcement_target(p_course_id, p_skill_id, a.lesson_id) rt
          LIMIT 1
        )
      )
    CROSS JOIN LATERAL (
      SELECT COALESCE(step->'interactiveQuestion', step->'interactive_question') AS item
      FROM pg_catalog.jsonb_array_elements(l.steps) AS step
      UNION ALL
      SELECT l.reinforcement_exercise AS item
      UNION ALL
      SELECT COALESCE(
        pg_catalog.to_jsonb(l)->'alternate_exercise',
        pg_catalog.to_jsonb(l)->'alternateExercise'
      ) AS item
    ) AS items
    WHERE l.course_id = p_course_id
      AND (
        l.skill_id = p_skill_id
        OR COALESCE(items.item->>'skillId', items.item->>'skill_id') = p_skill_id
      )
      AND l.is_published
      AND NOT l.is_archived
      AND items.item->>'id' = p_question_id
  ), context AS (
    SELECT q.body->>'text' AS question_text,
           q.body->'options'->>a.selected_index AS selected_option,
           q.body->'options'->>CASE
             WHEN COALESCE(q.body->>'correct_index', q.body->>'correctIndex') ~ '^[0-9]{1,3}$'
             THEN COALESCE(q.body->>'correct_index', q.body->>'correctIndex')::INT
           END AS correct_option,
           q.body->>'explanation' AS explanation
    FROM attempt a
    CROSS JOIN (SELECT q2.body FROM question q2 LIMIT 1) q
  )
  SELECT pg_catalog.jsonb_build_object(
    'questionText', context.question_text,
    'selectedOption', context.selected_option,
    'correctOption', context.correct_option,
    'explanation', context.explanation
  )
  FROM context
  WHERE context.question_text IS NOT NULL
    AND context.selected_option IS NOT NULL
    AND context.correct_option IS NOT NULL
    AND context.selected_option <> context.correct_option;
$$;

REVOKE ALL ON FUNCTION public.tutor_mistake_context(UUID, TEXT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tutor_mistake_context(UUID, TEXT, TEXT, TEXT)
  TO service_role;

CREATE OR REPLACE FUNCTION public.get_mistake_feedback(
  p_course_id TEXT, p_skill_id TEXT, p_question_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_ctx JSONB;
  v_lesson_id TEXT;
  v_wrong_count INT := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  v_ctx := public.tutor_mistake_context(v_uid, p_course_id, p_skill_id, p_question_id);
  IF v_ctx IS NULL THEN
    RETURN NULL;
  END IF;

  IF p_course_id = 'course_math_01' THEN
    SELECT aa.lesson_id
    INTO v_lesson_id
    FROM public.answer_attempts aa
    WHERE aa.user_id = v_uid
      AND aa.course_id = p_course_id
      AND aa.skill_id = p_skill_id
      AND aa.question_id = p_question_id
      AND aa.is_correct = false
    ORDER BY aa.created_at DESC, aa.id DESC
    LIMIT 1;

    IF v_lesson_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM bilimyol_private.math_pilot_items mpi
      WHERE mpi.lesson_id = v_lesson_id AND mpi.question_id = p_question_id
    ) THEN
      SELECT pg_catalog.count(*)::INT
      INTO v_wrong_count
      FROM public.answer_attempts aa
      WHERE aa.user_id = v_uid
        AND aa.course_id = p_course_id
        AND aa.skill_id = p_skill_id
        AND aa.lesson_id = v_lesson_id
        AND aa.question_id = p_question_id
        AND aa.is_correct = false;

      IF v_wrong_count < 2 AND NOT EXISTS (
        SELECT 1 FROM bilimyol_private.math_progression(v_uid) mp
        WHERE mp.target_lesson_id = v_lesson_id
          AND mp.mastery_state IN ('needs_review', 'mastered')
      ) THEN
        RETURN pg_catalog.jsonb_build_object(
          'questionText', v_ctx->>'questionText',
          'selectedOption', v_ctx->>'selectedOption',
          'correctOption', NULL,
          'explanation', 'Ishlangan misolni ko‘rib chiqing va qayta urinib ko‘ring.'
        );
      END IF;
    END IF;
  END IF;

  RETURN v_ctx;
END;
$$;

REVOKE ALL ON FUNCTION public.get_mistake_feedback(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_mistake_feedback(TEXT, TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
