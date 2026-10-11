-- ==============================================================================
-- BILIMYO‘L SMART EDU - MIGRATION 20260817000012
-- File: supabase/migrations/20260817000012_server_side_scoring_and_anticheat.sql
--
-- SERVER-SIDE SCORING, ANTI-CHEAT & ADMIN CMS GOVERNANCE
-- 1. Enhances answer_attempts with course_id, skill_id, and idempotency_key.
-- 2. Creates authoritative lessons table with RLS.
-- 3. Grants full Admin CMS permissions (courses, skills, questions, lessons).
-- 4. Replaces submit_answer_attempt() with an atomic, anti-cheat, idempotent RPC.
-- ==============================================================================

-- 1. ENHANCE ANSWER_ATTEMPTS FOR DIRECT STATS AGGREGATION & IDEMPOTENCY
ALTER TABLE public.answer_attempts
  ADD COLUMN IF NOT EXISTS course_id TEXT,
  ADD COLUMN IF NOT EXISTS skill_id TEXT,
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

CREATE INDEX IF NOT EXISTS idx_answer_attempts_user_skill
  ON public.answer_attempts(user_id, skill_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_answer_attempts_idempotency
  ON public.answer_attempts(user_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- 2. CREATE AUTHORITATIVE LESSONS TABLE
CREATE TABLE IF NOT EXISTS public.lessons (
  id TEXT PRIMARY KEY,
  course_id TEXT NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  skill_id TEXT NOT NULL REFERENCES public.skills(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  summary TEXT NOT NULL DEFAULT '',
  estimated_minutes INT NOT NULL DEFAULT 15,
  steps JSONB NOT NULL DEFAULT '[]'::jsonb,
  reinforcement_exercise JSONB,
  is_published BOOLEAN NOT NULL DEFAULT true,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lessons_course_skill
  ON public.lessons(course_id, skill_id, is_published, is_archived);

ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;

-- Lesson Read Policy: Active learners can read published, non-archived lessons
DROP POLICY IF EXISTS "Active learners can read published lessons" ON public.lessons;
CREATE POLICY "Active learners can read published lessons"
  ON public.lessons
  FOR SELECT
  TO authenticated
  USING (is_published = true AND is_archived = false);

-- Lesson Admin Policy: Administrators can manage all lessons
DROP POLICY IF EXISTS "Admins can manage all lessons" ON public.lessons;
CREATE POLICY "Admins can manage all lessons"
  ON public.lessons
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 3. ADMIN CMS RLS POLICIES FOR COURSES, SKILLS, QUESTIONS & ROADMAP
-- Courses
DROP POLICY IF EXISTS "Admins can manage courses" ON public.courses;
CREATE POLICY "Admins can manage courses"
  ON public.courses
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Skills
DROP POLICY IF EXISTS "Admins can manage skills" ON public.skills;
CREATE POLICY "Admins can manage skills"
  ON public.skills
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Questions
DROP POLICY IF EXISTS "Admins can manage questions" ON public.questions;
CREATE POLICY "Admins can manage questions"
  ON public.questions
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Roadmap Nodes
DROP POLICY IF EXISTS "Admins can manage roadmap nodes" ON public.roadmap_nodes;
CREATE POLICY "Admins can manage roadmap nodes"
  ON public.roadmap_nodes
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 4. ATOMIC, ANTI-CHEAT & IDEMPOTENT ANSWER EVALUATION RPC
CREATE OR REPLACE FUNCTION public.submit_answer_attempt(
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
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_uid UUID;
  v_existing_id UUID;
  v_existing_is_correct BOOLEAN;
  v_correct_index INT;
  v_explanation TEXT;
  v_options JSONB;
  v_correct_option TEXT := '';
  v_is_correct BOOLEAN := false;
  v_total_count INT;
  v_correct_count INT;
  v_new_skill_score INT;
  v_overall_score INT := 0;
  v_mastery_level TEXT;
  v_xp_delta INT := 0;
  v_total_xp INT := 0;
  v_eff_idempotency TEXT;
BEGIN
  -- 1. Security Check: Validate authenticated caller identity
  v_caller_uid := auth.uid();
  IF v_caller_uid IS NOT NULL AND v_caller_uid <> p_user_id AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Xavfsizlik qoidasi: boshqa foydalanuvchi nomidan javob topshirish taqiqlanadi.'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Idempotency Check: Prevent duplicate attempt processing
  v_eff_idempotency := COALESCE(p_idempotency_key, p_lesson_id || ':' || p_question_id || ':' || p_selected_index::text);

  SELECT id, is_correct
  INTO v_existing_id, v_existing_is_correct
  FROM public.answer_attempts
  WHERE user_id = p_user_id AND idempotency_key = v_eff_idempotency
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    -- Return existing status without double awarding XP or recalculating
    SELECT COALESCE(score, 50) INTO v_new_skill_score
    FROM public.learner_skill_scores
    WHERE user_id = p_user_id AND course_id = p_course_id AND skill_id = p_skill_id;

    SELECT COALESCE(ROUND(AVG(score)), 50) INTO v_overall_score
    FROM public.learner_skill_scores
    WHERE user_id = p_user_id AND course_id = p_course_id;

    SELECT COALESCE(xp, 0) INTO v_total_xp
    FROM public.gamification_profiles
    WHERE user_id = p_user_id;

    -- Fetch question explanation
    SELECT explanation INTO v_explanation
    FROM public.questions WHERE id = p_question_id;

    RETURN jsonb_build_object(
      'is_correct', v_existing_is_correct,
      'explanation', COALESCE(v_explanation, 'Javob avval qayd etilgan.'),
      'new_skill_score', COALESCE(v_new_skill_score, 50),
      'overall_score', COALESCE(v_overall_score, 50),
      'xp_awarded', 0,
      'total_xp', v_total_xp,
      'already_processed', true
    );
  END IF;

  -- 3. Server-Side Correct Answer Lookup (Authoritative DB records)
  SELECT correct_index, explanation, options
  INTO v_correct_index, v_explanation, v_options
  FROM public.questions
  WHERE id = p_question_id;

  -- Fallback check in generated_lessons if not in static questions table
  IF v_correct_index IS NULL THEN
    SELECT (elem->>'correct_index')::INT, elem->>'explanation', elem->'options'
    INTO v_correct_index, v_explanation, v_options
    FROM public.generated_lessons gl,
         jsonb_array_elements(gl.questions) AS elem
    WHERE elem->>'id' = p_question_id
    LIMIT 1;
  END IF;

  -- Strict Anti-Cheat Rule: If question is missing from trusted DB, DO NOT default to index 0!
  IF v_correct_index IS NOT NULL THEN
    v_is_correct := (p_selected_index = v_correct_index);
    IF v_options IS NOT NULL AND jsonb_array_length(v_options) > v_correct_index THEN
      v_correct_option := COALESCE(v_options->>v_correct_index, '');
    END IF;
  ELSE
    v_is_correct := false;
    v_explanation := 'Savol server bazasida topilmadi. Xavfsizlik yuzasidan noto‘g‘ri deb belgilandi.';
  END IF;

  -- 4. Audit Log Entry in answer_attempts
  INSERT INTO public.answer_attempts (
    user_id,
    course_id,
    skill_id,
    lesson_id,
    question_id,
    selected_index,
    selected_answer,
    is_correct,
    idempotency_key,
    created_at
  )
  VALUES (
    p_user_id,
    p_course_id,
    p_skill_id,
    p_lesson_id,
    p_question_id,
    p_selected_index,
    p_selected_text,
    v_is_correct,
    v_eff_idempotency,
    now()
  );

  -- 5. Calculate Real Cumulative Skill Stats for this User & Skill
  SELECT COUNT(*), COUNT(*) FILTER (WHERE is_correct = true)
  INTO v_total_count, v_correct_count
  FROM public.answer_attempts
  WHERE user_id = p_user_id AND skill_id = p_skill_id;

  IF v_total_count > 0 THEN
    v_new_skill_score := ROUND((v_correct_count::NUMERIC / v_total_count::NUMERIC) * 100);
  ELSE
    v_new_skill_score := CASE WHEN v_is_correct THEN 100 ELSE 0 END;
  END IF;

  v_new_skill_score := GREATEST(0, LEAST(100, v_new_skill_score));

  -- Mastery classification
  IF v_new_skill_score < 40 THEN
    v_mastery_level := 'needs_remediation';
  ELSIF v_new_skill_score < 60 THEN
    v_mastery_level := 'developing';
  ELSIF v_new_skill_score < 80 THEN
    v_mastery_level := 'proficient';
  ELSE
    v_mastery_level := 'mastered';
  END IF;

  -- 6. Upsert into learner_skill_scores
  INSERT INTO public.learner_skill_scores (
    user_id, course_id, skill_id, score, mastery_level, attempt_count, last_updated
  )
  VALUES (
    p_user_id, p_course_id, p_skill_id, v_new_skill_score, v_mastery_level, v_total_count, now()
  )
  ON CONFLICT (user_id, course_id, skill_id) DO UPDATE SET
    score = EXCLUDED.score,
    mastery_level = EXCLUDED.mastery_level,
    attempt_count = EXCLUDED.attempt_count,
    last_updated = now();

  -- 7. Compute Aggregate Overall Knowledge Score Across Course
  SELECT COALESCE(ROUND(AVG(score)), v_new_skill_score)
  INTO v_overall_score
  FROM public.learner_skill_scores
  WHERE user_id = p_user_id AND course_id = p_course_id;

  -- 8. Award XP Server-Side (+2 XP for correct answers)
  IF v_is_correct THEN
    v_xp_delta := 2;
  ELSE
    v_xp_delta := 0;
  END IF;

  INSERT INTO public.gamification_profiles (user_id, xp, streak_days, last_activity_date, updated_at)
  VALUES (p_user_id, v_xp_delta, 1, CURRENT_DATE, now())
  ON CONFLICT (user_id) DO UPDATE SET
    xp = gamification_profiles.xp + v_xp_delta,
    last_activity_date = CURRENT_DATE,
    updated_at = now();

  SELECT xp INTO v_total_xp
  FROM public.gamification_profiles
  WHERE user_id = p_user_id;

  -- 9. Upsert Daily Learning Stats Atomically
  INSERT INTO public.daily_learning_stats (
    user_id,
    activity_date,
    questions_answered,
    correct_answers,
    accuracy_percent,
    xp_earned,
    overall_score,
    updated_at
  )
  VALUES (
    p_user_id,
    CURRENT_DATE,
    1,
    (CASE WHEN v_is_correct THEN 1 ELSE 0 END),
    (CASE WHEN v_is_correct THEN 100 ELSE 0 END),
    v_xp_delta,
    v_overall_score,
    now()
  )
  ON CONFLICT (user_id, activity_date) DO UPDATE SET
    questions_answered = daily_learning_stats.questions_answered + 1,
    correct_answers = daily_learning_stats.correct_answers + (CASE WHEN v_is_correct THEN 1 ELSE 0 END),
    accuracy_percent = ROUND(((daily_learning_stats.correct_answers + (CASE WHEN v_is_correct THEN 1 ELSE 0 END))::NUMERIC / (daily_learning_stats.questions_answered + 1)::NUMERIC) * 100),
    xp_earned = daily_learning_stats.xp_earned + v_xp_delta,
    overall_score = v_overall_score,
    updated_at = now();

  -- 10. Return Authoritative Result Payload to Client
  RETURN jsonb_build_object(
    'is_correct', v_is_correct,
    'correct_index', v_correct_index,
    'correct_option', v_correct_option,
    'explanation', COALESCE(v_explanation, 'To‘g‘ri yechim.'),
    'new_skill_score', v_new_skill_score,
    'overall_score', v_overall_score,
    'xp_awarded', v_xp_delta,
    'total_xp', v_total_xp,
    'total_attempts', v_total_count,
    'correct_attempts', v_correct_count,
    'already_processed', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_answer_attempt(UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT) TO authenticated, service_role;

-- 5. SEED INITIAL CURATED LESSONS IF MISSING
INSERT INTO public.lessons (
  id, course_id, skill_id, title, summary, estimated_minutes, steps, reinforcement_exercise, is_published, is_archived
)
VALUES (
  'lesson_math_functions_01',
  'course_math_01',
  'skill_math_functions',
  'Funksiya nima? Asosiy tushunchalar',
  'Funksiya tushunchasi, argument o‘rniga son qo‘yish va qiymatni to‘g‘ri hisoblash qoidalari.',
  10,
  '[
    {"id": "math_step_1", "stepNumber": 1, "type": "concept", "title": "1. Funksiya nima?", "content": "Funksiya — bu bitta to‘plamdagi har bir elementga ikkinchi to‘plamdagi yagona elementni mos qo‘yuvchi qoidadir."},
    {"id": "math_step_2", "stepNumber": 2, "type": "formula", "title": "2. Chiziqli Funksiya Formulasi", "content": "Chiziqli funksiyada f(x) = ax + b umumiy ko‘rinishga ega."},
    {"id": "math_step_3", "stepNumber": 3, "type": "visual_example", "title": "3. Vizual Nuqtalar va Moslik", "content": "Agar x = 1 bo‘lsa: f(1) = 2(1) + 3 = 5. Nuqta: (1, 5)."},
    {"id": "math_step_4", "stepNumber": 4, "type": "interactive_question", "title": "4. Interaktiv Savol", "content": "Funksiya qiymatini hisoblang"}
  ]'::jsonb,
  '{"id": "q_math_func_01", "courseId": "course_math_01", "skillId": "skill_math_functions", "text": "f(x) = 2x + 3 berilgan. f(4) ni hisoblang.", "options": ["11", "9", "10", "12"], "difficulty": "medium", "explanation": "f(4) = 2(4) + 3 = 8 + 3 = 11"}'::jsonb,
  true,
  false
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  summary = EXCLUDED.summary,
  steps = EXCLUDED.steps,
  reinforcement_exercise = EXCLUDED.reinforcement_exercise,
  is_published = EXCLUDED.is_published;
