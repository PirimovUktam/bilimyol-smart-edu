-- ============================================================================
-- BilimYo‘l Smart Edu - follow-up security and persistence hardening
--
-- This migration closes the remaining client-trust boundaries identified by
-- the audit. Learner clients receive question content without answer keys;
-- placement answers, score recalculation, XP and activity writes happen in
-- SECURITY DEFINER functions after auth and ownership validation.
-- ============================================================================

BEGIN;

-- Remove the legacy seven-argument RPC. It predates caller/idempotency
-- validation and returned answer-key fields, so leaving the overload callable
-- would bypass the hardened eight-argument contract below.
DROP FUNCTION IF EXISTS public.submit_answer_attempt(UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT);

-- --------------------------------------------------------------------------
-- 1. Answer-key isolation
-- --------------------------------------------------------------------------

-- Strip answer metadata recursively, including camelCase/snake_case questions
-- and unexpected nested objects. Sanitizing only a step's top level is not a
-- boundary: PostgREST returns the complete JSON value before a client maps it.
CREATE OR REPLACE FUNCTION public.sanitize_learner_content(p_value JSONB)
RETURNS JSONB
LANGUAGE plpgsql IMMUTABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF jsonb_typeof(p_value) = 'object' THEN
    RETURN COALESCE((
      SELECT jsonb_object_agg(key, public.sanitize_learner_content(value))
      FROM jsonb_each(p_value)
      WHERE key NOT IN (
        'correct_index', 'correctIndex', 'correct_option', 'correctOption',
        'correct_option_id', 'correctOptionId', 'correct_answer', 'correctAnswer',
        'answer_index', 'answerIndex', 'answer', 'explanation'
      )
    ), '{}'::jsonb);
  ELSIF jsonb_typeof(p_value) = 'array' THEN
    RETURN COALESCE((
      SELECT jsonb_agg(public.sanitize_learner_content(value) ORDER BY ordinal)
      FROM jsonb_array_elements(p_value) WITH ORDINALITY AS item(value, ordinal)
    ), '[]'::jsonb);
  END IF;
  RETURN p_value;
END;
$$;

REVOKE ALL ON FUNCTION public.sanitize_learner_content(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sanitize_learner_content(JSONB) TO authenticated, service_role;

DROP POLICY IF EXISTS "Allow public read on questions" ON public.questions;
DROP POLICY IF EXISTS "Authenticated learners can read questions" ON public.questions;
CREATE POLICY "Authenticated learners can read questions"
  ON public.questions
  FOR SELECT
  TO authenticated
  USING (true);

-- Remove broad read access, then grant only learner-safe columns. The answer
-- key remains readable by SECURITY DEFINER scoring functions and admin view.
REVOKE SELECT ON public.questions FROM PUBLIC, anon, authenticated;
GRANT SELECT (
  id, course_id, skill_id, text, context_snippet, options, difficulty,
  formula_latex, audio_sim_text, audio_sim_speaker, is_placement, created_at
) ON public.questions TO authenticated;

DROP VIEW IF EXISTS public.learner_questions;
CREATE VIEW public.learner_questions
  WITH (security_invoker = true)
AS
SELECT
  id, course_id, skill_id, text, context_snippet, options, difficulty,
  formula_latex, audio_sim_text, audio_sim_speaker, is_placement, created_at
FROM public.questions;

GRANT SELECT ON public.learner_questions TO authenticated;
REVOKE ALL ON public.learner_questions FROM anon;

-- Admin content management needs the answer key, but only for an admin JWT.
DROP VIEW IF EXISTS public.admin_questions;
CREATE VIEW public.admin_questions AS
SELECT
  q.id, q.course_id, q.skill_id, q.text, q.context_snippet, q.options,
  q.correct_index, q.difficulty, q.explanation, q.formula_latex,
  q.audio_sim_text, q.audio_sim_speaker, q.is_placement, q.created_at
FROM public.questions q
WHERE public.is_admin();

GRANT SELECT ON public.admin_questions TO authenticated;
REVOKE ALL ON public.admin_questions FROM anon;

-- Generated lesson cache contains question answer keys in JSONB. Expose a
-- sanitized learner view and keep the raw cache service-role/admin only.
DROP POLICY IF EXISTS "Authenticated users can read generated lessons" ON public.generated_lessons;
REVOKE SELECT ON public.generated_lessons FROM PUBLIC, anon, authenticated;

DROP VIEW IF EXISTS public.learner_generated_lessons;
CREATE VIEW public.learner_generated_lessons AS
SELECT
  gl.id,
  gl.course_id,
  gl.skill_id,
  gl.topic,
  gl.level,
  gl.difficulty,
  gl.title,
  gl.summary,
  gl.objective,
  gl.estimated_minutes,
  public.sanitize_learner_content(gl.steps) AS steps,
  public.sanitize_learner_content(gl.questions) AS questions,
  gl.generation_model,
  gl.created_at
FROM public.generated_lessons gl;

GRANT SELECT ON public.learner_generated_lessons TO authenticated;
REVOKE ALL ON public.learner_generated_lessons FROM anon;

-- Curated lessons can contain answer keys inside steps and the reinforcement
-- JSONB. Learners must read the sanitized view, while administrators retain a
-- separate role-gated view for CMS reads. Raw table SELECT is removed so a
-- learner cannot bypass the view with a direct PostgREST request.
REVOKE SELECT ON public.lessons FROM PUBLIC, anon, authenticated;
GRANT SELECT (id) ON public.lessons TO authenticated;

DROP VIEW IF EXISTS public.learner_lessons;
CREATE VIEW public.learner_lessons AS
SELECT
  l.id,
  l.course_id,
  l.skill_id,
  l.title,
  l.summary,
  l.estimated_minutes,
  public.sanitize_learner_content(l.steps) AS steps,
  public.sanitize_learner_content(l.reinforcement_exercise) AS reinforcement_exercise,
  l.is_published,
  l.is_archived,
  l.created_at,
  l.updated_at
FROM public.lessons l
WHERE l.is_published = true AND l.is_archived = false;

GRANT SELECT ON public.learner_lessons TO authenticated;
REVOKE ALL ON public.learner_lessons FROM anon;

DROP VIEW IF EXISTS public.admin_lessons;
CREATE VIEW public.admin_lessons AS
SELECT l.*
FROM public.lessons l
WHERE public.is_admin();

GRANT SELECT ON public.admin_lessons TO authenticated;
REVOKE ALL ON public.admin_lessons FROM anon;

-- ON CONFLICT UPDATE requires SELECT privileges on the updated values, so
-- granting only safe columns also blocks raw CMS upserts. Keep those writes
-- behind explicitly authorized RPCs instead of re-granting learner answer keys.
CREATE OR REPLACE FUNCTION public.admin_save_question(p_question JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_index INT;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Faqat administrator savol saqlay oladi.' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_question) IS DISTINCT FROM 'object'
     OR NULLIF(btrim(p_question->>'id'), '') IS NULL
     OR jsonb_typeof(p_question->'options') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Savol ma’lumotlari noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;
  v_index := (p_question->>'correct_index')::INT;
  IF v_index IS NULL OR v_index < 0 OR v_index >= jsonb_array_length(p_question->'options')
     OR NOT EXISTS (SELECT 1 FROM public.skills
       WHERE id = p_question->>'skill_id' AND course_id = p_question->>'course_id') THEN
    RAISE EXCEPTION 'Savol kaliti yoki kurs/ko‘nikma konteksti noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.questions (
    id, course_id, skill_id, text, options, correct_index, difficulty, explanation, formula_latex, is_placement
  ) VALUES (
    p_question->>'id', p_question->>'course_id', p_question->>'skill_id', p_question->>'text',
    p_question->'options', v_index, COALESCE(p_question->>'difficulty', 'medium'),
    COALESCE(p_question->>'explanation', ''), p_question->>'formula_latex',
    COALESCE((p_question->>'is_placement')::BOOLEAN, false)
  ) ON CONFLICT (id) DO UPDATE SET
    course_id = EXCLUDED.course_id, skill_id = EXCLUDED.skill_id, text = EXCLUDED.text,
    options = EXCLUDED.options, correct_index = EXCLUDED.correct_index,
    difficulty = EXCLUDED.difficulty, explanation = EXCLUDED.explanation,
    formula_latex = EXCLUDED.formula_latex, is_placement = EXCLUDED.is_placement;
  RETURN jsonb_build_object('saved', true, 'id', p_question->>'id');
END;
$$;
REVOKE ALL ON FUNCTION public.admin_save_question(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_save_question(JSONB) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_save_lesson(p_lesson JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Faqat administrator dars saqlay oladi.' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_lesson) IS DISTINCT FROM 'object'
     OR NULLIF(btrim(p_lesson->>'id'), '') IS NULL
     OR jsonb_typeof(p_lesson->'steps') IS DISTINCT FROM 'array'
     OR NOT EXISTS (SELECT 1 FROM public.skills
       WHERE id = p_lesson->>'skill_id' AND course_id = p_lesson->>'course_id') THEN
    RAISE EXCEPTION 'Dars ma’lumotlari yoki kurs/ko‘nikma konteksti noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.lessons (
    id, course_id, skill_id, title, summary, estimated_minutes, steps,
    reinforcement_exercise, is_published, is_archived, updated_at
  ) VALUES (
    p_lesson->>'id', p_lesson->>'course_id', p_lesson->>'skill_id', p_lesson->>'title',
    COALESCE(p_lesson->>'summary', ''), COALESCE((p_lesson->>'estimated_minutes')::INT, 15),
    p_lesson->'steps', p_lesson->'reinforcement_exercise',
    COALESCE((p_lesson->>'is_published')::BOOLEAN, true),
    COALESCE((p_lesson->>'is_archived')::BOOLEAN, false), now()
  ) ON CONFLICT (id) DO UPDATE SET
    course_id = EXCLUDED.course_id, skill_id = EXCLUDED.skill_id, title = EXCLUDED.title,
    summary = EXCLUDED.summary, estimated_minutes = EXCLUDED.estimated_minutes,
    steps = EXCLUDED.steps, reinforcement_exercise = EXCLUDED.reinforcement_exercise,
    is_published = EXCLUDED.is_published, is_archived = EXCLUDED.is_archived, updated_at = now();
  RETURN jsonb_build_object('saved', true, 'id', p_lesson->>'id');
END;
$$;
REVOKE ALL ON FUNCTION public.admin_save_lesson(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_save_lesson(JSONB) TO authenticated, service_role;

-- --------------------------------------------------------------------------
-- 2. Remove direct learner writes to derived/scored tables
-- --------------------------------------------------------------------------

-- Fabricated is_correct audit rows must not satisfy score/reinforcement RPCs.
DROP POLICY IF EXISTS "User can CRUD own answer attempts" ON public.answer_attempts;
CREATE POLICY "Learners can read own answer attempts"
  ON public.answer_attempts FOR SELECT TO authenticated
  USING (user_id = auth.uid());
REVOKE INSERT, UPDATE, DELETE ON public.answer_attempts FROM PUBLIC, anon, authenticated;

DROP POLICY IF EXISTS "User can CRUD own skill scores" ON public.learner_skill_scores;
DROP POLICY IF EXISTS "Skill scores self view" ON public.learner_skill_scores;
CREATE POLICY "Learners can read own skill scores"
  ON public.learner_skill_scores
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "User can CRUD own placement attempts" ON public.placement_attempts;
CREATE POLICY "Learners can read own placement attempts"
  ON public.placement_attempts
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "User can CRUD own placement answers" ON public.placement_answers;
CREATE POLICY "Learners can read own placement answers"
  ON public.placement_answers
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "User can CRUD own gamification profile" ON public.gamification_profiles;
CREATE POLICY "Learners can read own gamification profile"
  ON public.gamification_profiles
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "User can CRUD own daily activity" ON public.daily_activity;
CREATE POLICY "Learners can read own daily activity"
  ON public.daily_activity
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Daily stats self management" ON public.daily_learning_stats;
CREATE POLICY "Learners can read own daily learning stats"
  ON public.daily_learning_stats
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Reinforcement rows are derived evidence, not client-owned state.
DROP POLICY IF EXISTS "User can CRUD own reinforcement attempts" ON public.reinforcement_attempts;
CREATE POLICY "Learners can read own reinforcement attempts"
  ON public.reinforcement_attempts
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- --------------------------------------------------------------------------
-- 3. Atomic XP and activity operations
-- --------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.gamification_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_key TEXT NOT NULL,
  xp_delta INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_gamification_event_key UNIQUE (user_id, action_key)
);

ALTER TABLE public.gamification_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Learners can read own gamification events" ON public.gamification_events;
CREATE POLICY "Learners can read own gamification events"
  ON public.gamification_events
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.award_xp(
  p_amount INT,
  p_action_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_inserted BOOLEAN := false;
  v_xp INT := 0;
  v_amount INT;
  v_action_id TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  IF p_action_key IS NULL OR btrim(p_action_key) = '' THEN
    RAISE EXCEPTION 'XP action key bo‘sh bo‘lishi mumkin emas.' USING ERRCODE = '22023';
  END IF;

  -- Direct RPC callers may request an earned event, never pick its amount.
  IF starts_with(p_action_key, 'answer_correct_') THEN
    v_action_id := substring(p_action_key FROM length('answer_correct_') + 1);
    IF EXISTS (SELECT 1 FROM public.answer_attempts
      WHERE user_id = v_uid AND question_id = v_action_id AND is_correct) THEN
      v_amount := 2;
    END IF;
  ELSIF starts_with(p_action_key, 'placement_completed_') THEN
    v_action_id := substring(p_action_key FROM length('placement_completed_') + 1);
    IF EXISTS (SELECT 1 FROM public.placement_attempts
      WHERE user_id = v_uid AND course_id = v_action_id) THEN
      v_amount := 20;
    END IF;
  ELSIF starts_with(p_action_key, 'reinforcement_completed_') THEN
    v_action_id := substring(p_action_key FROM length('reinforcement_completed_') + 1);
    IF EXISTS (SELECT 1 FROM public.reinforcement_attempts
      WHERE user_id = v_uid AND reinforcement_node_id = v_action_id AND is_correct) THEN
      v_amount := 30;
    END IF;
  ELSIF starts_with(p_action_key, 'lesson_completed_') THEN
    v_action_id := substring(p_action_key FROM length('lesson_completed_') + 1);
    IF EXISTS (SELECT 1 FROM public.lesson_progress lp
      JOIN public.answer_attempts aa ON aa.user_id = lp.user_id
        AND aa.lesson_id = lp.lesson_id AND aa.course_id = lp.course_id
      WHERE lp.user_id = v_uid AND lp.lesson_id = v_action_id
        AND lp.status = 'completed' AND aa.is_correct) THEN
      v_amount := 20;
    END IF;
  END IF;
  IF v_amount IS NULL THEN
    RAISE EXCEPTION 'XP uchun serverda tasdiqlangan harakat topilmadi.' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.gamification_events (user_id, action_key, xp_delta)
  VALUES (v_uid, p_action_key, v_amount)
  ON CONFLICT (user_id, action_key) DO NOTHING;
  v_inserted := FOUND;

  IF v_inserted THEN
    INSERT INTO public.gamification_profiles (user_id, xp, updated_at)
    VALUES (v_uid, v_amount, now())
    ON CONFLICT (user_id) DO UPDATE SET
      xp = public.gamification_profiles.xp + EXCLUDED.xp,
      updated_at = now();

    IF NOT starts_with(p_action_key, 'answer_correct_') THEN
      INSERT INTO public.daily_learning_stats (
        user_id, activity_date, xp_earned, lessons_completed, updated_at
      ) VALUES (
        v_uid, (now() AT TIME ZONE 'Asia/Tashkent')::date, v_amount,
        CASE WHEN starts_with(p_action_key, 'lesson_completed_') THEN 1 ELSE 0 END, now()
      ) ON CONFLICT (user_id, activity_date) DO UPDATE SET
        xp_earned = daily_learning_stats.xp_earned + EXCLUDED.xp_earned,
        lessons_completed = daily_learning_stats.lessons_completed + EXCLUDED.lessons_completed,
        updated_at = now();
    END IF;
  END IF;

  SELECT COALESCE(xp, 0) INTO v_xp
  FROM public.gamification_profiles
  WHERE user_id = v_uid;

  RETURN jsonb_build_object(
    'xp', v_xp,
    'awarded', v_inserted
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.record_learning_activity(
  p_activity_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_today DATE := (now() AT TIME ZONE 'Asia/Tashkent')::date;
  v_streak INT := 1;
  v_last DATE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;

  IF p_activity_date IS NOT NULL AND p_activity_date <> v_today THEN
    RAISE EXCEPTION 'Faollik sanasi serverning joriy kuniga mos emas.' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('learning:' || v_uid::TEXT, 0));

  SELECT streak_days, last_activity_date
  INTO v_streak, v_last
  FROM public.gamification_profiles
  WHERE user_id = v_uid
  FOR UPDATE;

  v_streak := COALESCE(v_streak, 0);
  IF v_last = v_today THEN
    v_streak := GREATEST(v_streak, 1);
  ELSIF v_last = v_today - 1 THEN
    v_streak := v_streak + 1;
  ELSE
    v_streak := 1;
  END IF;

  INSERT INTO public.gamification_profiles (user_id, streak_days, last_activity_date, updated_at)
  VALUES (v_uid, v_streak, v_today, now())
  ON CONFLICT (user_id) DO UPDATE SET
    streak_days = EXCLUDED.streak_days,
    last_activity_date = EXCLUDED.last_activity_date,
    updated_at = now();

  RETURN jsonb_build_object('streak_days', v_streak, 'activity_date', v_today);
END;
$$;

REVOKE ALL ON FUNCTION public.award_xp(INT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.award_xp(INT, TEXT) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.record_learning_activity(DATE) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_learning_activity(DATE) TO authenticated, service_role;

-- --------------------------------------------------------------------------
-- 4. Server-authoritative placement evaluation and persistence
-- --------------------------------------------------------------------------

ALTER TABLE public.placement_attempts
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS uq_placement_attempt_idempotency
  ON public.placement_attempts(user_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE OR REPLACE FUNCTION public.evaluate_placement_answer(
  p_course_id TEXT,
  p_question_id TEXT,
  p_selected_index INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_correct_index INT;
  v_options JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;

  SELECT correct_index, options INTO v_correct_index, v_options
  FROM public.questions
  WHERE id = p_question_id
    AND course_id = p_course_id
    AND is_placement = true;

  IF v_correct_index IS NULL THEN
    RAISE EXCEPTION 'Placement savoli topilmadi yoki kursga tegishli emas.' USING ERRCODE = '22023';
  END IF;
  IF p_selected_index IS NULL OR p_selected_index < 0
     OR p_selected_index >= jsonb_array_length(v_options) THEN
    RAISE EXCEPTION 'Tanlangan javob indeksi noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;

  RETURN jsonb_build_object('is_correct', p_selected_index = v_correct_index);
END;
$$;

CREATE OR REPLACE FUNCTION public.save_placement_attempt(
  p_course_id TEXT,
  p_submissions JSONB,
  p_idempotency_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
  v_today DATE := (now() AT TIME ZONE 'Asia/Tashkent')::date;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  IF p_submissions IS NULL OR jsonb_typeof(p_submissions) <> 'array' OR jsonb_array_length(p_submissions) = 0 THEN
    RAISE EXCEPTION 'Placement javoblari bo‘sh bo‘lishi mumkin emas.' USING ERRCODE = '22023';
  END IF;
  IF NULLIF(TRIM(p_idempotency_key), '') IS NULL THEN
    RAISE EXCEPTION 'Placement idempotency kaliti talab qilinadi.' USING ERRCODE = '22023';
  END IF;
  IF jsonb_array_length(p_submissions) > 100 OR EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_submissions) AS item
    GROUP BY item->>'question_id' HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Placement savollari takrorlangan yoki soni ortiqcha.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('learning:' || v_uid::TEXT, 0));
  PERFORM pg_advisory_xact_lock(
    hashtextextended(v_uid::TEXT || ':' || p_course_id || ':' || p_idempotency_key, 0)
  );

  SELECT id, score, weakest_skill_id
  INTO v_attempt_id, v_existing_score, v_existing_weakest
  FROM public.placement_attempts
  WHERE user_id = v_uid AND course_id = p_course_id
    AND idempotency_key = p_idempotency_key
  LIMIT 1;

  IF v_attempt_id IS NOT NULL THEN
    SELECT jsonb_agg(jsonb_build_object('question_id', question_id,
      'selected_index', selected_index) ORDER BY question_id)
    INTO v_existing_payload FROM public.placement_answers WHERE attempt_id = v_attempt_id;
    SELECT jsonb_agg(jsonb_build_object('question_id', item->>'question_id',
      'selected_index', item->'selected_index') ORDER BY item->>'question_id')
    INTO v_request_payload FROM jsonb_array_elements(p_submissions) AS item;
    IF v_request_payload IS DISTINCT FROM v_existing_payload THEN
      RAISE EXCEPTION 'Idempotency kaliti boshqa placement javoblari uchun ishlatilgan.' USING ERRCODE = '22023';
    END IF;
    RETURN jsonb_build_object(
      'attempt_id', v_attempt_id,
      'score', v_existing_score,
      'weakest_skill_id', v_existing_weakest,
      'already_processed', true
    );
  END IF;

  FOR v_submission IN SELECT * FROM jsonb_array_elements(p_submissions) LOOP
    SELECT id, skill_id, correct_index, options
    INTO v_question
    FROM public.questions
    WHERE id = v_submission->>'question_id'
      AND course_id = p_course_id
      AND is_placement = true;

    IF v_question.id IS NULL THEN
      RAISE EXCEPTION 'Placement savoli kurs bilan mos emas.' USING ERRCODE = '22023';
    END IF;

    IF NOT COALESCE((v_submission->>'selected_index') ~ '^[0-9]+$', false) THEN
      RAISE EXCEPTION 'Tanlangan javob indeksi noto‘g‘ri.' USING ERRCODE = '22023';
    END IF;
    v_selected := (v_submission->>'selected_index')::INT;
    IF v_selected IS NULL OR v_selected < 0 OR v_selected >= jsonb_array_length(v_question.options) THEN
      RAISE EXCEPTION 'Tanlangan javob indeksi noto‘g‘ri.' USING ERRCODE = '22023';
    END IF;

    v_is_correct := (v_selected = v_question.correct_index);
    v_total := v_total + 1;
    IF v_is_correct THEN v_correct := v_correct + 1; END IF;
  END LOOP;

  v_score := ROUND((v_correct::NUMERIC / NULLIF(v_total, 0)::NUMERIC) * 100);

  INSERT INTO public.placement_attempts (
    user_id, course_id, score, weakest_skill_id, idempotency_key, started_at, completed_at
  )
  VALUES (
    v_uid, p_course_id, v_score, NULL, p_idempotency_key, now(), now()
  )
  RETURNING id INTO v_attempt_id;

  FOR v_submission IN SELECT * FROM jsonb_array_elements(p_submissions) LOOP
    SELECT skill_id, correct_index, options
    INTO v_question
    FROM public.questions
    WHERE id = v_submission->>'question_id'
      AND course_id = p_course_id
      AND is_placement = true;

    v_selected := (v_submission->>'selected_index')::INT;
    v_is_correct := (v_selected = v_question.correct_index);

    INSERT INTO public.placement_answers (
      attempt_id, user_id, question_id, selected_index, is_correct, created_at
    )
    VALUES (
      v_attempt_id, v_uid, v_submission->>'question_id', v_selected, v_is_correct, now()
    );

    -- Feed the same server-verified answers into the learner scoring audit.
    -- This replaces the old client loop that submitted each placement answer
    -- separately and could award XP/activity twice.
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
      now()
    )
    ON CONFLICT (user_id, idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

    IF v_is_correct THEN
      v_award := public.award_xp(2, 'answer_correct_' || (v_submission->>'question_id'));
      IF (v_award->>'awarded')::BOOLEAN THEN v_answer_xp := v_answer_xp + 2; END IF;
    END IF;
  END LOOP;

  SELECT skill_id
  INTO v_existing_weakest
  FROM (
    SELECT q.skill_id,
           ROUND(AVG(CASE WHEN pa.is_correct THEN 100 ELSE 0 END)) AS skill_score
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
  INSERT INTO public.daily_learning_stats (
    user_id, activity_date, questions_answered, correct_answers, accuracy_percent, xp_earned, updated_at
  ) VALUES (v_uid, v_today, v_total, v_correct, v_score, v_answer_xp, now())
  ON CONFLICT (user_id, activity_date) DO UPDATE SET
    questions_answered = daily_learning_stats.questions_answered + v_total,
    correct_answers = daily_learning_stats.correct_answers + v_correct,
    accuracy_percent = ROUND(
      (daily_learning_stats.correct_answers + v_correct)::NUMERIC * 100 /
      (daily_learning_stats.questions_answered + v_total)),
    xp_earned = daily_learning_stats.xp_earned + v_answer_xp,
    updated_at = now();

  -- Placement answer writes are authoritative and do not trust client is_correct.
  -- Skill rows are recalculated from the answer-attempt audit by the existing
  -- scoring RPC; the explicit placement score remains available for reporting.
  PERFORM public.record_learning_activity(v_today);
  PERFORM public.award_xp(20, 'placement_completed_' || p_course_id);

  RETURN jsonb_build_object(
    'attempt_id', v_attempt_id,
    'score', v_score,
    'weakest_skill_id', v_existing_weakest,
    'already_processed', false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.evaluate_placement_answer(TEXT, TEXT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.evaluate_placement_answer(TEXT, TEXT, INT) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.save_placement_attempt(TEXT, JSONB, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_placement_attempt(TEXT, JSONB, TEXT) TO authenticated, service_role;

-- Recompute derived skill rows from server-verified answer attempts. The
-- client may request a recalculation, but it cannot provide the score values.
CREATE OR REPLACE FUNCTION public.recalculate_skill_scores(p_course_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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

  PERFORM pg_advisory_xact_lock(hashtextextended('learning:' || v_uid::TEXT, 0));
  FOR v_skill IN
    SELECT DISTINCT skill_id
    FROM public.answer_attempts
    WHERE user_id = v_uid AND course_id = p_course_id
  LOOP
    SELECT COUNT(*), COUNT(*) FILTER (WHERE latest.is_correct)
    INTO v_total, v_correct
    FROM (
      SELECT DISTINCT ON (question_id) is_correct
      FROM public.answer_attempts
      WHERE user_id = v_uid AND course_id = p_course_id AND skill_id = v_skill.skill_id
      ORDER BY question_id, created_at DESC, id DESC
    ) latest;

    v_score := COALESCE(ROUND((v_correct::NUMERIC / NULLIF(v_total, 0)::NUMERIC) * 100), 0);
    SELECT GREATEST(
      v_score,
      COALESCE(MAX(after_score), 0)
    ) INTO v_score
    FROM public.reinforcement_attempts
    WHERE user_id = v_uid
      AND course_id = p_course_id
      AND skill_id = v_skill.skill_id
      AND is_correct = true;
    v_mastery := CASE
      WHEN v_score < 40 THEN 'needs_remediation'
      WHEN v_score < 60 THEN 'developing'
      WHEN v_score < 80 THEN 'proficient'
      ELSE 'mastered'
    END;

    INSERT INTO public.learner_skill_scores (
      user_id, course_id, skill_id, score, mastery_level, attempt_count, last_updated
    )
    VALUES (v_uid, p_course_id, v_skill.skill_id, v_score, v_mastery, v_total, now())
    ON CONFLICT (user_id, course_id, skill_id) DO UPDATE SET
      score = EXCLUDED.score,
      mastery_level = EXCLUDED.mastery_level,
      attempt_count = EXCLUDED.attempt_count,
      last_updated = now();

    v_result := v_result || jsonb_build_object(
      v_skill.skill_id,
      jsonb_build_object('score', v_score, 'attempt_count', v_total, 'mastery_level', v_mastery)
    );
  END LOOP;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.recalculate_skill_scores(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recalculate_skill_scores(TEXT) TO authenticated, service_role;

-- Lesson completion is one transaction too: a client cannot forge a progress
-- row, or leave completed progress behind after an XP/activity write fails.
DROP POLICY IF EXISTS "User can CRUD own lesson progress" ON public.lesson_progress;
CREATE POLICY "Learners can read own lesson progress"
  ON public.lesson_progress FOR SELECT TO authenticated USING (user_id = auth.uid());
REVOKE INSERT, UPDATE, DELETE ON public.lesson_progress FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.complete_lesson(p_lesson_id TEXT, p_course_id TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
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
  PERFORM pg_advisory_xact_lock(hashtextextended('learning:' || v_uid::TEXT, 0));

  SELECT l.course_id, l.skill_id, ARRAY(
    SELECT COALESCE(step->'interactiveQuestion', step->'interactive_question')->>'id'
    FROM jsonb_array_elements(l.steps) AS step
    WHERE NULLIF(COALESCE(step->'interactiveQuestion', step->'interactive_question')->>'id', '') IS NOT NULL
  ) INTO v_course, v_skill, v_questions
  FROM public.lessons l WHERE l.id = p_lesson_id AND l.is_published AND NOT l.is_archived;

  IF v_course IS NULL THEN
    -- The generated lesson renderer currently delivers the first cached
    -- question as its interactive assessment on both clients.
    SELECT course_id, skill_id, ARRAY[questions->0->>'id']
    INTO v_course, v_skill, v_questions
    FROM public.generated_lessons WHERE id = p_lesson_id;
  END IF;
  IF v_course IS NULL OR v_course IS DISTINCT FROM p_course_id THEN
    RAISE EXCEPTION 'Dars kursda topilmadi.' USING ERRCODE = '22023';
  END IF;
  IF COALESCE(cardinality(v_questions), 0) = 0 THEN
    RAISE EXCEPTION 'Darsning baholanadigan savollari topilmadi.' USING ERRCODE = '22023';
  END IF;
  FOREACH v_question IN ARRAY v_questions LOOP
    IF v_question IS NULL OR NOT COALESCE((
      SELECT is_correct FROM public.answer_attempts
      WHERE user_id = v_uid AND course_id = v_course AND skill_id = v_skill
        AND lesson_id = p_lesson_id AND question_id = v_question
      ORDER BY created_at DESC, id DESC LIMIT 1
    ), false) THEN
      RAISE EXCEPTION 'Dars javoblari serverda tasdiqlanmagan.' USING ERRCODE = '42501';
    END IF;
  END LOOP;

  INSERT INTO public.lesson_progress (
    user_id, lesson_id, course_id, status, progress_percent, completed_at, updated_at
  ) VALUES (v_uid, p_lesson_id, v_course, 'completed', 100, now(), now())
  ON CONFLICT (user_id, lesson_id) DO UPDATE SET
    status = 'completed', progress_percent = 100,
    completed_at = COALESCE(lesson_progress.completed_at, now()), updated_at = now();
  v_award := public.award_xp(20, 'lesson_completed_' || p_lesson_id);
  PERFORM public.record_learning_activity();
  RETURN jsonb_build_object('completed', true, 'xp_awarded',
    CASE WHEN (v_award->>'awarded')::BOOLEAN THEN 20 ELSE 0 END);
END;
$$;
REVOKE ALL ON FUNCTION public.complete_lesson(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_lesson(TEXT, TEXT) TO authenticated, service_role;

-- Defense in depth for callers of submit_answer_attempt: caller-provided
-- course/skill values must match the authoritative question context.
CREATE OR REPLACE FUNCTION public.validate_answer_attempt_context()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_course TEXT;
  v_skill TEXT;
BEGIN
  SELECT course_id, skill_id INTO v_course, v_skill
  FROM public.questions
  WHERE id = NEW.question_id;

  IF v_course IS NOT NULL THEN
    IF NEW.course_id IS DISTINCT FROM v_course OR NEW.skill_id IS DISTINCT FROM v_skill THEN
      RAISE EXCEPTION 'Savol kurs yoki ko‘nikma kontekstiga mos emas.' USING ERRCODE = '22023';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_answer_attempt_context ON public.answer_attempts;
CREATE TRIGGER trg_validate_answer_attempt_context
  BEFORE INSERT ON public.answer_attempts
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_answer_attempt_context();

-- Reinforcement completion derives the score from the current server row;
-- before/after values supplied by the client are informational only.
DROP FUNCTION IF EXISTS public.complete_reinforcement(TEXT, TEXT, TEXT, INT);
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
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_before INT := 0;
  v_after INT := 22;
  v_server_xp_awarded INT := 30;
  v_target_lesson_id TEXT;
  v_existing RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.skills
    WHERE id = p_skill_id AND course_id = p_course_id
  ) THEN
    RAISE EXCEPTION 'Ko‘nikma kurs bilan mos emas.' USING ERRCODE = '22023';
  END IF;

  IF p_reinforcement_node_id IS NULL OR NOT (
    p_reinforcement_node_id = 'reinf_' || p_course_id || '_' || p_skill_id
    OR EXISTS (SELECT 1 FROM public.roadmap_nodes
      WHERE course_id = p_course_id AND skill_id = p_skill_id AND is_active
        AND (p_reinforcement_node_id = 'reinf_' || id
          OR (is_reinforcement AND p_reinforcement_node_id = id)))
  ) THEN
    RAISE EXCEPTION 'Mustahkamlash tuguni kurs va ko‘nikmaga mos emas.' USING ERRCODE = '22023';
  END IF;

  -- Serialize completion for this learner/node so two concurrent retries
  -- cannot both create a reinforcement row or award XP.
  PERFORM pg_advisory_xact_lock(hashtextextended('learning:' || v_uid::TEXT, 0));
  PERFORM pg_advisory_xact_lock(
    hashtextextended(v_uid::TEXT || ':' || p_reinforcement_node_id, 0)
  );

  SELECT score INTO v_before
  FROM public.learner_skill_scores
  WHERE user_id = v_uid AND course_id = p_course_id AND skill_id = p_skill_id
  FOR UPDATE;

  SELECT * INTO v_existing FROM public.reinforcement_attempts
  WHERE user_id = v_uid AND reinforcement_node_id = p_reinforcement_node_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'already_processed', true,
      'old_score', v_existing.before_score,
      'new_score', v_existing.after_score,
      'xp_awarded', 0
    );
  END IF;

  -- A reinforcement completion is valid only after the same authenticated
  -- learner has a server-evaluated correct answer for this exact question.
  -- p_xp_awarded is accepted for backwards-compatible RPC clients but is not
  -- trusted for derived state.
  IF NOT COALESCE((
    SELECT is_correct
    FROM public.answer_attempts
    WHERE user_id = v_uid
      AND course_id = p_course_id
      AND skill_id = p_skill_id
      AND lesson_id = p_reinforcement_node_id
      AND question_id = p_question_id
    ORDER BY created_at DESC, id DESC LIMIT 1
  ), false) THEN
    RAISE EXCEPTION 'Mustahkamlash javobi serverda to‘g‘ri deb tasdiqlanmagan.'
      USING ERRCODE = '42501';
  END IF;

  v_before := COALESCE(v_before, 0);
  v_after := LEAST(100, v_before + 22);

  SELECT target_lesson_id
  INTO v_target_lesson_id
  FROM public.roadmap_nodes
  WHERE (p_reinforcement_node_id = 'reinf_' || id OR p_reinforcement_node_id = id)
    AND course_id = p_course_id AND skill_id = p_skill_id AND is_active;

  INSERT INTO public.reinforcement_attempts (
    user_id, course_id, skill_id, reinforcement_node_id,
    before_score, after_score, is_correct, xp_awarded, created_at
  )
  VALUES (
    v_uid, p_course_id, p_skill_id, p_reinforcement_node_id,
    v_before, v_after, true, v_server_xp_awarded, now()
  );

  INSERT INTO public.learner_skill_scores (
    user_id, course_id, skill_id, score, mastery_level, attempt_count, last_updated
  )
  VALUES (
    v_uid, p_course_id, p_skill_id, v_after,
    CASE WHEN v_after < 40 THEN 'needs_remediation'
         WHEN v_after < 60 THEN 'developing'
         WHEN v_after < 80 THEN 'proficient'
         ELSE 'mastered' END,
    1, now()
  )
  ON CONFLICT (user_id, course_id, skill_id) DO UPDATE SET
    score = EXCLUDED.score,
    mastery_level = EXCLUDED.mastery_level,
    last_updated = now();

  -- The reinforcement RPC is the authoritative production path for the
  -- target node as well. Persist its linked lesson progress so the next
  -- profile/roadmap read can unlock downstream prerequisites without a local
  -- client-only node mutation.
  IF v_target_lesson_id IS NOT NULL THEN
    INSERT INTO public.lesson_progress (
      user_id, lesson_id, course_id, status, progress_percent, completed_at, updated_at
    )
    VALUES (
      v_uid, v_target_lesson_id, p_course_id, 'completed', 100, now(), now()
    )
    ON CONFLICT (user_id, lesson_id) DO UPDATE SET
      status = 'completed',
      progress_percent = 100,
      completed_at = now(),
      updated_at = now();
  END IF;

  PERFORM public.award_xp(v_server_xp_awarded,
    'reinforcement_completed_' || p_reinforcement_node_id);
  PERFORM public.record_learning_activity();

  RETURN jsonb_build_object(
    'already_processed', false,
    'old_score', v_before,
    'new_score', v_after,
    'xp_awarded', v_server_xp_awarded
  );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_reinforcement(TEXT, TEXT, TEXT, TEXT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_reinforcement(TEXT, TEXT, TEXT, TEXT, INT) TO authenticated, service_role;

-- --------------------------------------------------------------------------
-- 5. Relationship and role enforcement
-- --------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_teacher_or_admin(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_user_id AND role IN ('teacher', 'admin')
  );
$$;

DROP POLICY IF EXISTS "Parent links student view" ON public.parent_student_links;
DROP POLICY IF EXISTS "Parent links student update" ON public.parent_student_links;
DROP POLICY IF EXISTS "Parent links parent management" ON public.parent_student_links;
CREATE POLICY "Linked students can read own parent links"
  ON public.parent_student_links
  FOR SELECT TO authenticated
  USING (student_user_id = auth.uid() OR parent_user_id = auth.uid() OR public.is_admin());

-- Linking requires the student to redeem a code through the server RPC;
-- parents must not directly INSERT/UPDATE an active link to an arbitrary child.
REVOKE INSERT, UPDATE, DELETE ON public.parent_student_links FROM PUBLIC, anon, authenticated;

DROP POLICY IF EXISTS "Classes teacher management" ON public.classes;
CREATE POLICY "Verified teachers manage own classes"
  ON public.classes
  FOR ALL TO authenticated
  USING (
    (teacher_user_id = auth.uid() AND public.is_teacher_or_admin(auth.uid()))
    OR public.is_admin()
  )
  WITH CHECK (
    (teacher_user_id = auth.uid() AND public.is_teacher_or_admin(auth.uid()))
    OR public.is_admin()
  );

DROP POLICY IF EXISTS "Class members teacher management" ON public.class_members;
CREATE POLICY "Verified teachers manage class members"
  ON public.class_members
  FOR ALL TO authenticated
  USING (
    (public.is_teacher_of_class(class_id, auth.uid()) AND public.is_teacher_or_admin(auth.uid()))
    OR public.is_admin()
  )
  WITH CHECK (
    (public.is_teacher_of_class(class_id, auth.uid()) AND public.is_teacher_or_admin(auth.uid()))
    OR public.is_admin()
  );

CREATE OR REPLACE FUNCTION public.create_parent_link_code()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_code TEXT;
  v_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiyadan o‘tilmagan.' USING ERRCODE = '42501';
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = v_uid;
  IF v_role IS NULL OR v_role NOT IN ('parent', 'admin') THEN
    RAISE EXCEPTION 'Faqat tasdiqlangan ota-ona yoki administrator kod yarata oladi.'
      USING ERRCODE = '42501';
  END IF;

  v_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || clock_timestamp()::TEXT) FROM 1 FOR 6));
  INSERT INTO public.parent_student_links (parent_user_id, link_code, status, expires_at)
  VALUES (v_uid, v_code, 'pending', now() + INTERVAL '24 hours')
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'success', true,
    'id', v_id,
    'link_code', v_code,
    'expires_at', now() + INTERVAL '24 hours'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_parent_link_code() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_parent_link_code() TO authenticated, service_role;

-- --------------------------------------------------------------------------
-- 6. Explicit Data API privileges (no default table grants required)
-- --------------------------------------------------------------------------

-- RLS limits rows; it does not grant table access. Normalize the application's
-- named relations so both fresh projects and projects with legacy GRANT ALL
-- defaults get the same client boundary, including no TRUNCATE/REFERENCES/TRIGGER.
-- Re-establish the safe column grants explicitly after the reset; no table-level
-- INSERT/UPDATE on profiles or table-level SELECT on answer-key-bearing content
-- is restored below.
REVOKE ALL ON TABLE
  public.profiles, public.courses, public.skills, public.questions,
  public.learner_profiles, public.learner_skill_scores,
  public.placement_attempts, public.placement_answers, public.roadmap_nodes,
  public.lesson_progress, public.lesson_attempts, public.answer_attempts,
  public.ai_recommendations, public.reinforcement_attempts,
  public.gamification_profiles, public.gamification_events, public.daily_activity,
  public.user_preferences, public.parent_student_links, public.classes,
  public.class_members, public.learning_sessions, public.daily_learning_stats,
  public.student_alerts, public.teacher_invitation_codes,
  public.teacher_invitation_attempts, public.lessons, public.generated_lessons
FROM PUBLIC, anon, authenticated;

-- Views are read-only API contracts, even when a view is automatically updatable
-- and a legacy default previously granted it write privileges. In particular,
-- writes through an owner-executed view must not bypass the scoring/CMS RPCs.
REVOKE ALL ON TABLE
  public.learner_questions, public.learner_lessons,
  public.learner_generated_lessons, public.admin_questions, public.admin_lessons
FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE
  public.learner_questions, public.learner_lessons,
  public.learner_generated_lessons, public.admin_questions, public.admin_lessons
TO authenticated;
-- security_invoker learner_questions requires underlying safe-column access;
-- CMS lesson filters need id, but neither raw JSON nor answer keys are readable.
GRANT SELECT (
  id, course_id, skill_id, text, context_snippet, options, difficulty,
  formula_latex, audio_sim_text, audio_sim_speaker, is_placement, created_at
) ON public.questions TO authenticated;
GRANT SELECT (id) ON public.lessons TO authenticated;

-- Both repository implementations authenticate before reading the catalogue;
-- public pitch/demo screens do not require live catalogue access. Despite the
-- older public-read RLS policies, no anonymous table/view access is needed.
GRANT SELECT ON TABLE public.courses, public.skills, public.roadmap_nodes
TO authenticated;

-- Profile reads include role for AuthContext/admin monitoring. Creation and
-- edits remain restricted to the existing safe columns, with role/id/email
-- excluded from UPDATE and role excluded from INSERT.
GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT INSERT (
  id, first_name, last_name, display_name, email, avatar_url, created_at, updated_at
) ON public.profiles TO authenticated;
GRANT UPDATE (first_name, last_name, display_name, avatar_url, updated_at)
ON public.profiles TO authenticated;

-- Onboarding/course choice are client-owned preferences, not derived scores.
-- Upserts require SELECT plus INSERT/UPDATE, including the conflict key.
GRANT SELECT, INSERT, UPDATE ON TABLE public.learner_profiles TO authenticated;

-- All derived learning data and relationship reads still pass through the
-- existing self/linked-parent/verified-teacher/admin RLS policies. Writes to
-- attempts, placement, progress, XP, activity and scores remain RPC-only.
GRANT SELECT ON TABLE
  public.answer_attempts, public.placement_attempts, public.placement_answers,
  public.learner_skill_scores, public.lesson_progress,
  public.reinforcement_attempts, public.gamification_profiles,
  public.gamification_events, public.daily_activity, public.daily_learning_stats,
  public.parent_student_links, public.classes, public.class_members,
  public.student_alerts
TO authenticated;

-- Class creation normally uses create_teacher_class; the Web repository also
-- has a direct INSERT fallback. Its existing verified-teacher/admin RLS guard
-- remains authoritative. Membership and parent links are changed only by RPC.
GRANT INSERT (teacher_user_id, name, subject, grade_level, class_code)
ON public.classes TO authenticated;

-- CMS course/skill upserts and deletes use the existing admin-only write RLS.
-- Question/lesson saves instead use the authorized admin_save_* functions and
-- admin views, never raw answer-key SELECT or raw content INSERT/UPDATE grants.
GRANT INSERT, UPDATE, DELETE ON TABLE public.courses, public.skills TO authenticated;
GRANT DELETE ON TABLE public.questions, public.lessons TO authenticated;
GRANT UPDATE (is_published, is_archived, updated_at)
ON public.lessons TO authenticated;
-- The safe question SELECT columns and lesson SELECT(id) grants above
-- support CMS filters and the security-invoker learner_questions view.

-- BYPASSRLS is not a table privilege: Edge generation/cache/fallback persistence
-- explicitly needs raw SELECT and INSERT/ON CONFLICT UPDATE on these two tables.
-- Derived learner writes run as their SECURITY DEFINER RPC owner, so service_role
-- needs no new direct write grants on those tables. UUID/text keys need no
-- sequence grants. Existing privileged profile/RPC grants remain in effect.
GRANT SELECT, INSERT, UPDATE ON TABLE public.generated_lessons, public.questions
TO service_role;

-- --------------------------------------------------------------------------
-- 7. Repair the legacy idempotent bootstrap helper
-- --------------------------------------------------------------------------

-- The original helper referenced gamification_profiles.created_at, but that
-- table intentionally has no created_at column. Keep the helper available for
-- existing callers while making its provisioning path schema-valid and aligned
-- with the signup trigger's Tashkent activity date.
CREATE OR REPLACE FUNCTION public.provision_missing_profiles()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.profiles (id, first_name, last_name, email, avatar_url, display_name, created_at, updated_at)
  SELECT
    u.id,
    COALESCE(NULLIF(TRIM(u.raw_user_meta_data->>'first_name'), ''), 'Foydalanuvchi'),
    COALESCE(NULLIF(TRIM(u.raw_user_meta_data->>'last_name'), ''), ''),
    COALESCE(u.email, ''),
    u.raw_user_meta_data->>'avatar_url',
    COALESCE(
      NULLIF(TRIM(CONCAT(u.raw_user_meta_data->>'first_name', ' ', u.raw_user_meta_data->>'last_name')), ''),
      NULLIF(TRIM(u.raw_user_meta_data->>'first_name'), ''),
      'Foydalanuvchi'
    ),
    now(),
    now()
  FROM auth.users u
  LEFT JOIN public.profiles p ON u.id = p.id
  WHERE p.id IS NULL
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.learner_profiles (user_id, selected_course_id, goal, daily_minutes, initial_level, created_at, updated_at)
  SELECT u.id, 'course_math_01', 'mastery', 15, 'intermediate', now(), now()
  FROM auth.users u
  LEFT JOIN public.learner_profiles lp ON u.id = lp.user_id
  WHERE lp.user_id IS NULL
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.gamification_profiles (user_id, xp, streak_days, last_activity_date, updated_at)
  SELECT u.id, 0, 1, (now() AT TIME ZONE 'Asia/Tashkent')::date, now()
  FROM auth.users u
  LEFT JOIN public.gamification_profiles gp ON u.id = gp.user_id
  WHERE gp.user_id IS NULL
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.user_preferences (user_id, dark_mode, notifications_enabled, language, updated_at)
  SELECT u.id, false, true, 'uz', now()
  FROM auth.users u
  LEFT JOIN public.user_preferences up ON u.id = up.user_id
  WHERE up.user_id IS NULL
  ON CONFLICT (user_id) DO NOTHING;
END;
$$;

COMMIT;
