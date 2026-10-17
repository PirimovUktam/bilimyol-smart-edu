-- ==============================================================================
-- BILIMYO‘L SMART EDU - MIGRATION 20261014000001
-- File: supabase/migrations/20261014000001_zero_error_security_and_scoring_overhaul.sql
--
-- ZERO-ERROR SECURITY & SCORING OVERHAUL (P0 + P1 BACKEND)
--
-- 1. [P0-SEC-01] create_teacher_class(): remove self-escalation, require teacher/admin.
-- 2. Profiles role hardening: constraint allows all 4 roles; registration forces
--    'student'; INSERT/UPDATE trigger blocks unauthorized role changes.
-- 3. [P0-CHEAT-02] submit_answer_attempt(): strict NULL-proof auth guard,
--    unique-question latest-attempt scoring (anti-manipulation),
--    dynamic daily streak in Asia/Tashkent (UTC+5).
-- 4. [P1-ARCH-06] generated_lessons: remove client write policies
--    (global cache writes only via Edge Function / service_role).
--
-- IDEMPOTENT, NON-DESTRUCTIVE, DEPENDENCY-ORDERED.
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- 1. [P0-SEC-01] HARDENED TEACHER CLASS CREATION (NO SELF-ESCALATION)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.create_teacher_class(
  p_name TEXT,
  p_subject TEXT DEFAULT 'Matematika',
  p_grade_level TEXT DEFAULT '7-sinf'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_teacher_id UUID := auth.uid();
  v_role TEXT;
  v_code TEXT;
  v_class RECORD;
  v_attempts INT := 0;
BEGIN
  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Ruxsat yo''q: Autentifikatsiyadan o''tilmagan.'
      USING ERRCODE = '42501';
  END IF;

  -- Authoritative role verification: only confirmed teachers or admins may create classes.
  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = v_teacher_id;

  IF v_role IS NULL OR v_role NOT IN ('teacher', 'admin') THEN
    RAISE EXCEPTION 'Ruxsat yo''q: Faqat tasdiqlangan o''qituvchilar sinf yarata oladi.'
      USING ERRCODE = '42501';
  END IF;

  IF TRIM(p_name) = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Sinf nomi bo‘sh bo‘lishi mumkin emas.');
  END IF;

  -- Generate Collision-Safe 6-Character Class Code
  LOOP
    v_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || clock_timestamp()::TEXT) FROM 1 FOR 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.classes WHERE class_code = v_code);
    v_attempts := v_attempts + 1;
    IF v_attempts > 10 THEN
      RETURN jsonb_build_object('success', false, 'message', 'Sinf kodini generatsiya qilishda xatolik.');
    END IF;
  END LOOP;

  INSERT INTO public.classes (teacher_user_id, name, subject, grade_level, class_code, created_at, updated_at)
  VALUES (v_teacher_id, TRIM(p_name), COALESCE(p_subject, 'Matematika'), COALESCE(p_grade_level, '7-sinf'), v_code, now(), now())
  RETURNING * INTO v_class;

  RETURN jsonb_build_object(
    'success', true,
    'id', v_class.id,
    'teacher_user_id', v_class.teacher_user_id,
    'name', v_class.name,
    'subject', v_class.subject,
    'grade_level', v_class.grade_level,
    'class_code', v_class.class_code,
    'created_at', v_class.created_at,
    'message', 'Sinf muvaffaqiyatli yaratildi.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_teacher_class(TEXT, TEXT, TEXT) TO authenticated, service_role;

-- ==============================================================================
-- 2. PROFILES ROLE HARDENING
-- ==============================================================================

-- 2.1 Constraint allows all four roles.
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check CHECK (role IN ('student', 'parent', 'teacher', 'admin'));

-- 2.2 Registration trigger: role metadata is ignored; every new user starts as 'student'.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_first_name TEXT;
  v_last_name TEXT;
  v_display_name TEXT;
  v_valid_course_id TEXT;
BEGIN
  v_first_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), ''), 'Foydalanuvchi');
  v_last_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), ''), '');

  IF v_last_name <> '' THEN
    v_display_name := v_first_name || ' ' || v_last_name;
  ELSE
    v_display_name := v_first_name;
  END IF;

  -- SECURITY: role metadata is deliberately ignored. All new sign-ups are students.
  -- Elevation to teacher/parent/admin happens only via vetted server RPCs.
  INSERT INTO public.profiles (
    id, first_name, last_name, email, avatar_url, display_name, role, created_at, updated_at
  )
  VALUES (
    NEW.id, v_first_name, v_last_name, COALESCE(NEW.email, ''),
    NEW.raw_user_meta_data->>'avatar_url', v_display_name, 'student', now(), now()
  )
  ON CONFLICT (id) DO UPDATE SET
    first_name = CASE WHEN public.profiles.first_name = 'Foydalanuvchi' AND EXCLUDED.first_name <> 'Foydalanuvchi' THEN EXCLUDED.first_name ELSE public.profiles.first_name END,
    last_name = CASE WHEN public.profiles.last_name = '' AND EXCLUDED.last_name <> '' THEN EXCLUDED.last_name ELSE public.profiles.last_name END,
    display_name = CASE WHEN public.profiles.display_name = 'Foydalanuvchi' AND EXCLUDED.display_name <> 'Foydalanuvchi' THEN EXCLUDED.display_name ELSE public.profiles.display_name END,
    email = EXCLUDED.email,
    updated_at = now();

  BEGIN
    SELECT id INTO v_valid_course_id FROM public.courses WHERE id = 'course_math_01' LIMIT 1;
    INSERT INTO public.learner_profiles (user_id, selected_course_id, goal, daily_minutes, initial_level, created_at, updated_at)
    VALUES (NEW.id, v_valid_course_id, 'mastery', 15, 'intermediate', now(), now())
    ON CONFLICT (user_id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: learner_profiles insert warning: %', SQLERRM;
  END;

  BEGIN
    INSERT INTO public.gamification_profiles (user_id, xp, streak_days, last_activity_date, updated_at)
    VALUES (NEW.id, 0, 1, (now() AT TIME ZONE 'Asia/Tashkent')::date, now())
    ON CONFLICT (user_id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: gamification_profiles insert warning: %', SQLERRM;
  END;

  BEGIN
    INSERT INTO public.user_preferences (user_id, dark_mode, notifications_enabled, language, updated_at)
    VALUES (NEW.id, false, true, 'uz', now())
    ON CONFLICT (user_id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: user_preferences insert warning: %', SQLERRM;
  END;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_new_user FATAL: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2.3 Role protection trigger now covers INSERT and UPDATE.
CREATE OR REPLACE FUNCTION public.enforce_profile_role_protection()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    -- Role unchanged: allow the row through untouched.
    IF NEW.role IS NOT DISTINCT FROM OLD.role THEN
      RETURN NEW;
    END IF;

    -- Authorized server RPCs explicitly flag the transaction.
    IF current_setting('bilimyol.authorized_role_change', true) = 'true' THEN
      RETURN NEW;
    END IF;

    IF auth.uid() IS NOT NULL AND public.is_admin() THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Ruxsat etilmagan: Profil rolini to‘g‘ridan-to‘g‘ri o‘zgartirish taqiqlangan.'
      USING ERRCODE = '42501';
  END IF;

  -- INSERT: only authorized RPCs or admins may insert a non-student role.
  IF NEW.role IS NOT DISTINCT FROM 'student' THEN
    RETURN NEW;
  END IF;

  IF current_setting('bilimyol.authorized_role_change', true) = 'true' THEN
    RETURN NEW;
  END IF;

  IF auth.uid() IS NOT NULL AND public.is_admin() THEN
    RETURN NEW;
  END IF;

  -- Silently coerce to student rather than abort auth registration.
  NEW.role := 'student';
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_profile_role_protection ON public.profiles;
CREATE TRIGGER trg_enforce_profile_role_protection
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_profile_role_protection();

-- ==============================================================================
-- 3. [P0-CHEAT-02] ATOMIC, ANTI-CHEAT, UNIQUE-QUESTION-SCORING RPC
-- ==============================================================================
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
  v_total_xp INT := 0;
  v_award JSONB;
  v_eff_idempotency TEXT;
  v_today DATE;
BEGIN
  -- 1. Strict Auth Guard: NULL UID must NEVER pass.
  v_caller_uid := auth.uid();
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'Xavfsizlik qoidasi: javob topshirish uchun autentifikatsiya talab qilinadi.'
      USING ERRCODE = '42501';
  END IF;

  IF p_user_id IS DISTINCT FROM v_caller_uid THEN
    RAISE EXCEPTION 'Xavfsizlik qoidasi: boshqa foydalanuvchi nomidan javob topshirish taqiqlanadi.'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Local day in Uzbekistan time (UTC+5).
  v_today := (now() AT TIME ZONE 'Asia/Tashkent')::date;
  IF NULLIF(btrim(p_course_id), '') IS NULL OR NULLIF(btrim(p_skill_id), '') IS NULL
     OR NULLIF(btrim(p_lesson_id), '') IS NULL OR NULLIF(btrim(p_question_id), '') IS NULL
     OR p_selected_index IS NULL OR p_selected_index < 0 THEN
    RAISE EXCEPTION 'Javob konteksti yoki indeksi noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;
  -- Serialize all score-changing transactions for one learner, not just
  -- identical keys: different simultaneous answers must not overwrite scores.
  PERFORM pg_advisory_xact_lock(hashtextextended('learning:' || p_user_id::TEXT, 0));

  -- 3. Idempotency Check: prevent duplicate attempt processing.
  v_eff_idempotency := COALESCE(p_idempotency_key, p_lesson_id || ':' || p_question_id || ':' || p_selected_index::text);

  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_user_id::TEXT || ':' || v_eff_idempotency, 0)
  );

  SELECT id, is_correct
  INTO v_existing_id, v_existing_is_correct
  FROM public.answer_attempts
  WHERE user_id = p_user_id AND idempotency_key = v_eff_idempotency
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.answer_attempts WHERE id = v_existing_id
        AND (course_id IS DISTINCT FROM p_course_id OR skill_id IS DISTINCT FROM p_skill_id
          OR lesson_id IS DISTINCT FROM p_lesson_id OR question_id IS DISTINCT FROM p_question_id
          OR selected_index IS DISTINCT FROM p_selected_index)
    ) THEN
      RAISE EXCEPTION 'Idempotency kaliti boshqa javob uchun ishlatilgan.' USING ERRCODE = '22023';
    END IF;
    SELECT COALESCE(score, 50) INTO v_new_skill_score
    FROM public.learner_skill_scores
    WHERE user_id = p_user_id AND course_id = p_course_id AND skill_id = p_skill_id;

    SELECT COALESCE(ROUND(AVG(score)), 50) INTO v_overall_score
    FROM public.learner_skill_scores
    WHERE user_id = p_user_id AND course_id = p_course_id;

    SELECT COALESCE(xp, 0) INTO v_total_xp
    FROM public.gamification_profiles
    WHERE user_id = p_user_id;

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

  -- 4. Server-Side Correct Answer Lookup (Authoritative DB records).
  SELECT course_id, skill_id, correct_index, explanation, options
  INTO v_question_course, v_question_skill, v_correct_index, v_explanation, v_options
  FROM public.questions
  WHERE id = p_question_id;

  IF v_question_course IS NULL THEN
    SELECT gl.course_id, gl.skill_id,
           COALESCE(elem->>'correct_index', elem->>'correctIndex')::INT,
           elem->>'explanation',
           elem->'options'
    INTO v_question_course, v_question_skill, v_correct_index, v_explanation, v_options
    FROM public.generated_lessons gl,
         jsonb_array_elements(
           CASE WHEN jsonb_typeof(gl.questions) = 'array' THEN gl.questions ELSE '[]'::jsonb END
         ) AS elem
    WHERE elem->>'id' = p_question_id
    LIMIT 1;
  END IF;

  -- Curated lesson questions live inside lesson JSONB rather than the global
  -- questions table. Resolve them server-side as well, without exposing the
  -- embedded answer key to learners.
  IF v_question_course IS NULL THEN
    SELECT l.course_id, l.skill_id,
           COALESCE(
             nested.question_elem->>'correct_index',
             nested.question_elem->>'correctIndex'
           )::INT,
           nested.question_elem->>'explanation',
           nested.question_elem->'options'
    INTO v_question_course, v_question_skill, v_correct_index, v_explanation, v_options
    FROM public.lessons l,
         jsonb_array_elements(
           CASE WHEN jsonb_typeof(l.steps) = 'array' THEN l.steps ELSE '[]'::jsonb END
         ) AS step_elem,
         LATERAL (
           SELECT COALESCE(
             step_elem->'interactiveQuestion',
             step_elem->'interactive_question'
           ) AS question_elem
         ) nested
    WHERE jsonb_typeof(nested.question_elem) = 'object'
      AND nested.question_elem->>'id' = p_question_id
    LIMIT 1;
  END IF;

  IF v_question_course IS NULL THEN
    SELECT l.course_id, l.skill_id,
           COALESCE(
             l.reinforcement_exercise->>'correct_index',
             l.reinforcement_exercise->>'correctIndex'
           )::INT,
           l.reinforcement_exercise->>'explanation',
           l.reinforcement_exercise->'options'
    INTO v_question_course, v_question_skill, v_correct_index, v_explanation, v_options
    FROM public.lessons l
    WHERE jsonb_typeof(l.reinforcement_exercise) = 'object'
      AND l.reinforcement_exercise->>'id' = p_question_id
    LIMIT 1;
  END IF;

  IF v_question_course IS NULL THEN
    -- Strict Anti-Cheat: unknown question is marked wrong, never defaulted to index 0.
    v_is_correct := false;
    v_explanation := 'Savol server bazasida topilmadi. Xavfsizlik yuzasidan noto‘g‘ri deb belgilandi.';
  ELSIF v_question_course <> p_course_id OR v_question_skill <> p_skill_id THEN
    RAISE EXCEPTION 'Savol kurs yoki ko‘nikma kontekstiga mos emas.' USING ERRCODE = '22023';
  ELSIF v_correct_index IS NOT NULL THEN
    IF v_options IS NULL
       OR p_selected_index IS NULL
       OR p_selected_index < 0
       OR p_selected_index >= jsonb_array_length(v_options) THEN
      RAISE EXCEPTION 'Tanlangan javob indeksi noto‘g‘ri.' USING ERRCODE = '22023';
    END IF;
    v_is_correct := (p_selected_index = v_correct_index);
  ELSE
    v_is_correct := false;
    v_explanation := 'Savol server bazasida noto‘g‘ri sozlangan.';
  END IF;

  -- 5. Audit Log Entry.
  INSERT INTO public.answer_attempts (
    user_id, course_id, skill_id, lesson_id, question_id,
    selected_index, selected_answer, is_correct, idempotency_key, created_at
  )
  VALUES (
    p_user_id, p_course_id, p_skill_id, p_lesson_id, p_question_id,
    p_selected_index, p_selected_text, v_is_correct, v_eff_idempotency, now()
  );

  -- 6. Scoring over UNIQUE questions only, using each question's LATEST attempt.
  --    This blocks manipulation by repeatedly solving/unsolving the same question.
  SELECT COUNT(*), COUNT(*) FILTER (WHERE is_correct = true)
  INTO v_unique_total, v_unique_correct
  FROM (
    SELECT DISTINCT ON (question_id) question_id, is_correct
    FROM public.answer_attempts
    WHERE user_id = p_user_id AND course_id = p_course_id AND skill_id = p_skill_id
    ORDER BY question_id, created_at DESC, id DESC
  ) latest;

  IF v_unique_total > 0 THEN
    v_new_skill_score := ROUND((v_unique_correct::NUMERIC / v_unique_total::NUMERIC) * 100);
  ELSE
    v_new_skill_score := CASE WHEN v_is_correct THEN 100 ELSE 0 END;
  END IF;

  v_new_skill_score := GREATEST(0, LEAST(100, v_new_skill_score));

  -- Match recalculate_skill_scores: previously earned, server-verified
  -- reinforcement progress must not vanish on a harmless answer retry.
  SELECT GREATEST(v_new_skill_score, COALESCE(MAX(after_score), 0))
  INTO v_new_skill_score FROM public.reinforcement_attempts
  WHERE user_id = p_user_id AND course_id = p_course_id AND skill_id = p_skill_id AND is_correct;

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
    p_user_id, p_course_id, p_skill_id, v_new_skill_score, v_mastery_level, v_unique_total, now()
  )
  ON CONFLICT (user_id, course_id, skill_id) DO UPDATE SET
    score = EXCLUDED.score,
    mastery_level = EXCLUDED.mastery_level,
    attempt_count = EXCLUDED.attempt_count,
    last_updated = now();

  SELECT COALESCE(ROUND(AVG(score)), v_new_skill_score)
  INTO v_overall_score
  FROM public.learner_skill_scores
  WHERE user_id = p_user_id AND course_id = p_course_id;

  -- 7. Award XP (+2 for correct answers) and update daily streak (Asia/Tashkent).
  IF v_is_correct THEN
    -- Stable per-question reward key: changing request idempotency keys or
    -- lesson ids must not farm the same answer reward indefinitely.
    v_award := public.award_xp(2, 'answer_correct_' || p_question_id);
    v_xp_delta := CASE WHEN (v_award->>'awarded')::BOOLEAN THEN 2 ELSE 0 END;
  ELSE
    v_xp_delta := 0;
  END IF;

  INSERT INTO public.gamification_profiles (user_id, xp, streak_days, last_activity_date, updated_at)
  VALUES (p_user_id, 0, 1, v_today, now())
  ON CONFLICT (user_id) DO UPDATE SET
    streak_days = CASE
      WHEN gamification_profiles.last_activity_date = v_today
        THEN GREATEST(gamification_profiles.streak_days, 1)
      WHEN gamification_profiles.last_activity_date = (v_today - INTERVAL '1 day')
        THEN gamification_profiles.streak_days + 1
      ELSE 1
    END,
    last_activity_date = v_today,
    updated_at = now();

  SELECT xp INTO v_total_xp
  FROM public.gamification_profiles
  WHERE user_id = p_user_id;

  -- 8. Daily Learning Stats (atomic upsert, same local day).
  INSERT INTO public.daily_learning_stats (
    user_id, activity_date, questions_answered, correct_answers,
    accuracy_percent, xp_earned, overall_score, updated_at
  )
  VALUES (
    p_user_id, v_today, 1,
    (CASE WHEN v_is_correct THEN 1 ELSE 0 END),
    (CASE WHEN v_is_correct THEN 100 ELSE 0 END),
    v_xp_delta, v_overall_score, now()
  )
  ON CONFLICT (user_id, activity_date) DO UPDATE SET
    questions_answered = daily_learning_stats.questions_answered + 1,
    correct_answers = daily_learning_stats.correct_answers + (CASE WHEN v_is_correct THEN 1 ELSE 0 END),
    accuracy_percent = ROUND(((daily_learning_stats.correct_answers + (CASE WHEN v_is_correct THEN 1 ELSE 0 END))::NUMERIC / (daily_learning_stats.questions_answered + 1)::NUMERIC) * 100),
    xp_earned = daily_learning_stats.xp_earned + v_xp_delta,
    overall_score = v_overall_score,
    updated_at = now();

  RETURN jsonb_build_object(
    'is_correct', v_is_correct,
    'explanation', COALESCE(v_explanation, 'To‘g‘ri yechim.'),
    'new_skill_score', v_new_skill_score,
    'overall_score', v_overall_score,
    'xp_awarded', v_xp_delta,
    'total_xp', v_total_xp,
    'total_attempts', v_unique_total,
    'correct_attempts', v_unique_correct,
    'already_processed', false
  );
END;
$$;

REVOKE ALL PRIVILEGES
  ON FUNCTION public.submit_answer_attempt(UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE
  ON FUNCTION public.submit_answer_attempt(UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT)
  TO authenticated, service_role;

-- ==============================================================================
-- 4. [P1-ARCH-06] generated_lessons WRITE LOCKDOWN (service_role only)
-- ==============================================================================

-- Remove any client-facing INSERT/UPDATE policies. The global cache is written
-- exclusively by the yolchi-tutor Edge Function using the service_role key.
DROP POLICY IF EXISTS "Authenticated users can create generated lessons" ON public.generated_lessons;
DROP POLICY IF EXISTS "Authenticated users can update generated lessons" ON public.generated_lessons;

-- Keep read access for authenticated learners (course content, not personal data).
DROP POLICY IF EXISTS "Authenticated users can read generated lessons" ON public.generated_lessons;
CREATE POLICY "Authenticated users can read generated lessons"
  ON public.generated_lessons
  FOR SELECT
  TO authenticated
  USING (true);

-- Administrators retain full management.
DROP POLICY IF EXISTS "Admins can manage generated lessons" ON public.generated_lessons;
CREATE POLICY "Admins can manage generated lessons"
  ON public.generated_lessons
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

COMMIT;
