-- ============================================================================
-- BILIMYO'L SMART EDU - WAVE 1 · BATCH W1-B1
-- Migration: 20261126000100_w1_b1_idempotency_constraints_and_daily_stats.sql
-- Scope:
--   * FIX-P0-24: Per-attempt UUID idempotency without static content-key
--                fallback when p_idempotency_key IS NULL; strict payload
--                (including selected_answer) verification on replay; curated
--                and table explanation resolution gated strictly on
--                v_existing_is_correct = true.
--   * FIX-P2-23: Bounded RPC/column sizes (<=128 idempotency_key, <=4000
--                selected_answer, preventing 54000 B-tree crashes), domain
--                CHECK constraints across profiles, learner_profiles,
--                questions, lesson_progress, gamification_profiles,
--                gamification_events, daily_learning_stats, answer_attempts,
--                placement_attempts, and learning_sessions; widened
--                roadmap_nodes.order_index NUMERIC(8,2); sanitized
--                handle_new_user(); hourly learning_sessions cap; and
--                (user_id, activity_date, question_id) daily question
--                statistics deduplication via bilimyol_private.daily_question_outcomes.
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS bilimyol_private;
REVOKE ALL ON SCHEMA bilimyol_private FROM PUBLIC, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 1. Safely widen public.roadmap_nodes.order_index from NUMERIC(4,1) to NUMERIC(8,2)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_numeric_precision INT;
BEGIN
  SELECT c.numeric_precision
  INTO v_numeric_precision
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'roadmap_nodes'
    AND c.column_name = 'order_index';

  IF v_numeric_precision IS NOT NULL AND v_numeric_precision < 8 THEN
    DROP VIEW IF EXISTS bilimyol_private.math_pilot_items;
    DROP VIEW IF EXISTS bilimyol_private.math_pilot_objectives;

    ALTER TABLE public.roadmap_nodes
      ALTER COLUMN order_index TYPE NUMERIC(8,2);

    CREATE VIEW bilimyol_private.math_pilot_objectives AS
    SELECT n.*, n.id = 'node_math_alg' AS is_optional
    FROM public.roadmap_nodes n
    JOIN public.lessons l ON l.id = n.target_lesson_id AND l.course_id = n.course_id
    WHERE n.course_id = 'course_math_01'
      AND n.is_active
      AND NOT n.is_reinforcement
      AND l.is_published
      AND NOT l.is_archived
      AND n.id IN (
        'node_math_addition',
        'node_math_multiplication',
        'node_math_expressions',
        'node_math_eq',
        'node_math_func',
        'node_math_graphs',
        'node_math_alg'
      );

    CREATE VIEW bilimyol_private.math_pilot_items AS
    SELECT l.id AS lesson_id,
           l.skill_id,
           step->>'masteryCheckpoint' AS checkpoint,
           step->'interactiveQuestion'->>'id' AS question_id
    FROM bilimyol_private.math_pilot_objectives n
    JOIN public.lessons l ON l.id = n.target_lesson_id
    CROSS JOIN LATERAL pg_catalog.jsonb_array_elements(l.steps) AS step
    WHERE step->>'masteryCheckpoint' IN ('application', 'retrieval')
      AND pg_catalog.starts_with(step->'interactiveQuestion'->>'id', 'q_pilot_' || l.id || '_');

    REVOKE ALL ON bilimyol_private.math_pilot_objectives, bilimyol_private.math_pilot_items
      FROM PUBLIC, anon, authenticated;
  END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. Normalize any legacy out-of-bounds rows before adding CHECK constraints
-- ----------------------------------------------------------------------------
UPDATE public.profiles
SET first_name = COALESCE(NULLIF(pg_catalog.left(pg_catalog.btrim(first_name), 120), ''), 'Foydalanuvchi'),
    last_name = pg_catalog.left(COALESCE(last_name, ''), 120),
    display_name = CASE
      WHEN display_name IS NULL THEN NULL
      ELSE pg_catalog.left(display_name, 250)
    END,
    email = pg_catalog.left(COALESCE(email, ''), 320),
    avatar_url = CASE
      WHEN avatar_url IS NULL OR avatar_url = '' THEN avatar_url
      WHEN pg_catalog.char_length(avatar_url) <= 2048 AND avatar_url ~ '^https://[^\s<>"]+$' THEN avatar_url
      ELSE NULL
    END
WHERE pg_catalog.btrim(first_name) = ''
   OR pg_catalog.char_length(first_name) > 120
   OR pg_catalog.char_length(last_name) > 120
   OR (display_name IS NOT NULL AND pg_catalog.char_length(display_name) > 250)
   OR pg_catalog.char_length(email) > 320
   OR (
     avatar_url IS NOT NULL
     AND avatar_url <> ''
     AND (pg_catalog.char_length(avatar_url) > 2048 OR avatar_url !~ '^https://[^\s<>"]+$')
   );

UPDATE public.learner_profiles
SET goal = CASE WHEN goal IN ('mastery', 'exam_prep', 'skills_boost') THEN goal ELSE 'mastery' END,
    daily_minutes = CASE WHEN daily_minutes IN (15, 30, 60) THEN daily_minutes ELSE 15 END,
    initial_level = CASE WHEN initial_level IN ('beginner', 'intermediate', 'advanced') THEN initial_level ELSE 'intermediate' END,
    course_levels = CASE
      WHEN pg_catalog.jsonb_typeof(course_levels) = 'object'
        AND pg_catalog.octet_length(course_levels::text) <= 4096
        AND NOT pg_catalog.jsonb_path_exists(
          course_levels,
          '$.* ? (@.type() != "string" || (@ != "beginner" && @ != "intermediate" && @ != "advanced"))'
        )
      THEN course_levels
      ELSE '{}'::jsonb
    END
WHERE goal NOT IN ('mastery', 'exam_prep', 'skills_boost')
   OR daily_minutes NOT IN (15, 30, 60)
   OR initial_level NOT IN ('beginner', 'intermediate', 'advanced')
   OR pg_catalog.jsonb_typeof(course_levels) <> 'object'
   OR pg_catalog.octet_length(course_levels::text) > 4096
   OR pg_catalog.jsonb_path_exists(
        course_levels,
        '$.* ? (@.type() != "string" || (@ != "beginner" && @ != "intermediate" && @ != "advanced"))'
      );

UPDATE public.answer_attempts
SET idempotency_key = CASE
      WHEN idempotency_key IS NULL THEN NULL
      WHEN pg_catalog.btrim(idempotency_key) = '' THEN NULL
      ELSE pg_catalog.left(idempotency_key, 128)
    END,
    selected_answer = pg_catalog.left(COALESCE(selected_answer, ''), 4000),
    lesson_id = COALESCE(NULLIF(pg_catalog.left(pg_catalog.btrim(lesson_id), 160), ''), 'general'),
    question_id = COALESCE(NULLIF(pg_catalog.left(pg_catalog.btrim(question_id), 160), ''), 'unknown'),
    selected_index = GREATEST(0, LEAST(100, selected_index))
WHERE (idempotency_key IS NOT NULL AND (pg_catalog.btrim(idempotency_key) = '' OR pg_catalog.char_length(idempotency_key) > 128))
   OR pg_catalog.char_length(selected_answer) > 4000
   OR pg_catalog.btrim(lesson_id) = ''
   OR pg_catalog.char_length(lesson_id) > 160
   OR pg_catalog.btrim(question_id) = ''
   OR pg_catalog.char_length(question_id) > 160
   OR selected_index < 0
   OR selected_index > 100;

UPDATE public.placement_attempts
SET idempotency_key = CASE
      WHEN idempotency_key IS NULL THEN NULL
      WHEN pg_catalog.btrim(idempotency_key) = '' THEN NULL
      ELSE pg_catalog.left(idempotency_key, 128)
    END,
    score = GREATEST(0, LEAST(100, score))
WHERE (idempotency_key IS NOT NULL AND (pg_catalog.btrim(idempotency_key) = '' OR pg_catalog.char_length(idempotency_key) > 128))
   OR score < 0
   OR score > 100;

-- ----------------------------------------------------------------------------
-- 3. Domain CHECK constraints & partial unique email index (FIX-P2-23)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  -- Duplicate non-empty emails cleanup guard before unique index creation
  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE pg_catalog.btrim(email) <> ''
    GROUP BY pg_catalog.lower(pg_catalog.btrim(email))
    HAVING pg_catalog.count(*) > 1
  ) THEN
    CREATE UNIQUE INDEX IF NOT EXISTS uq_profiles_email_nonempty
      ON public.profiles (pg_catalog.lower(pg_catalog.btrim(email)))
      WHERE pg_catalog.btrim(email) <> '';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_text_bounds_and_avatar_check') THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_text_bounds_and_avatar_check CHECK (
        pg_catalog.btrim(first_name) <> ''
        AND pg_catalog.char_length(first_name) <= 120
        AND pg_catalog.char_length(last_name) <= 120
        AND (display_name IS NULL OR pg_catalog.char_length(display_name) <= 250)
        AND pg_catalog.char_length(email) <= 320
        AND (
          avatar_url IS NULL
          OR avatar_url = ''
          OR (pg_catalog.char_length(avatar_url) <= 2048 AND avatar_url ~ '^https://[^\s<>"]+$')
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learner_profiles_domain_bounds_check') THEN
    ALTER TABLE public.learner_profiles
      ADD CONSTRAINT learner_profiles_domain_bounds_check CHECK (
        goal IN ('mastery', 'exam_prep', 'skills_boost')
        AND daily_minutes IN (15, 30, 60)
        AND initial_level IN ('beginner', 'intermediate', 'advanced')
        AND pg_catalog.jsonb_typeof(course_levels) = 'object'
        AND pg_catalog.octet_length(course_levels::text) <= 4096
        AND NOT pg_catalog.jsonb_path_exists(
          course_levels,
          '$.* ? (@.type() != "string" || (@ != "beginner" && @ != "intermediate" && @ != "advanced"))'
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'questions_domain_bounds_check') THEN
    ALTER TABLE public.questions
      ADD CONSTRAINT questions_domain_bounds_check CHECK (
        pg_catalog.btrim(id) <> ''
        AND pg_catalog.char_length(id) <= 160
        AND pg_catalog.btrim(text) <> ''
        AND pg_catalog.char_length(text) <= 4000
        AND (context_snippet IS NULL OR pg_catalog.char_length(context_snippet) <= 8000)
        AND pg_catalog.char_length(explanation) <= 8000
        AND (formula_latex IS NULL OR pg_catalog.char_length(formula_latex) <= 2000)
        AND difficulty IN ('easy', 'medium', 'hard')
        AND pg_catalog.jsonb_typeof(options) = 'array'
        AND correct_index >= 0
        AND (
          pg_catalog.jsonb_array_length(options) = 0
          OR correct_index < pg_catalog.jsonb_array_length(options)
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'lesson_progress_domain_bounds_check') THEN
    ALTER TABLE public.lesson_progress
      ADD CONSTRAINT lesson_progress_domain_bounds_check CHECK (
        status IN ('in_progress', 'completed')
        AND progress_percent >= 0
        AND progress_percent <= 100
        AND pg_catalog.btrim(lesson_id) <> ''
        AND pg_catalog.char_length(lesson_id) <= 160
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'gamification_profiles_nonnegative_check') THEN
    ALTER TABLE public.gamification_profiles
      ADD CONSTRAINT gamification_profiles_nonnegative_check CHECK (
        xp >= 0 AND streak_days >= 0
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'gamification_events_bounds_check') THEN
    ALTER TABLE public.gamification_events
      ADD CONSTRAINT gamification_events_bounds_check CHECK (
        xp_delta > 0
        AND xp_delta <= 1000
        AND pg_catalog.btrim(action_key) <> ''
        AND pg_catalog.char_length(action_key) <= 200
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'answer_attempts_bounds_check') THEN
    ALTER TABLE public.answer_attempts
      ADD CONSTRAINT answer_attempts_bounds_check CHECK (
        (
          idempotency_key IS NULL
          OR (pg_catalog.btrim(idempotency_key) <> '' AND pg_catalog.char_length(idempotency_key) <= 128)
        )
        AND pg_catalog.char_length(selected_answer) <= 4000
        AND pg_catalog.btrim(lesson_id) <> ''
        AND pg_catalog.char_length(lesson_id) <= 160
        AND pg_catalog.btrim(question_id) <> ''
        AND pg_catalog.char_length(question_id) <= 160
        AND selected_index >= 0
        AND selected_index <= 100
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'placement_attempts_bounds_check') THEN
    ALTER TABLE public.placement_attempts
      ADD CONSTRAINT placement_attempts_bounds_check CHECK (
        (
          idempotency_key IS NULL
          OR (pg_catalog.btrim(idempotency_key) <> '' AND pg_catalog.char_length(idempotency_key) <= 128)
        )
        AND score >= 0
        AND score <= 100
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_sessions_bounds_check') THEN
    ALTER TABLE public.learning_sessions
      ADD CONSTRAINT learning_sessions_bounds_check CHECK (
        active_seconds >= 0
        AND pg_catalog.btrim(course_id) <> ''
        AND pg_catalog.char_length(course_id) <= 64
        AND (lesson_id IS NULL OR (pg_catalog.btrim(lesson_id) <> '' AND pg_catalog.char_length(lesson_id) <= 160))
      );
  END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. Private Daily Question Deduplication Table + Backfill (FIX-P2-23)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bilimyol_private.daily_question_outcomes (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_date DATE NOT NULL,
  question_id TEXT NOT NULL CHECK (
    pg_catalog.btrim(question_id) <> ''
    AND pg_catalog.char_length(question_id) <= 160
  ),
  is_correct BOOLEAN NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
  PRIMARY KEY (user_id, activity_date, question_id)
);

ALTER TABLE bilimyol_private.daily_question_outcomes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE bilimyol_private.daily_question_outcomes
  FROM PUBLIC, anon, authenticated, service_role;

INSERT INTO bilimyol_private.daily_question_outcomes (
  user_id, activity_date, question_id, is_correct, updated_at
)
SELECT DISTINCT ON (
  aa.user_id,
  (aa.created_at AT TIME ZONE 'Asia/Tashkent')::date,
  aa.question_id
)
  aa.user_id,
  (aa.created_at AT TIME ZONE 'Asia/Tashkent')::date AS activity_date,
  aa.question_id,
  aa.is_correct,
  aa.created_at
FROM public.answer_attempts aa
WHERE pg_catalog.btrim(aa.question_id) <> ''
  AND pg_catalog.char_length(aa.question_id) <= 160
ORDER BY
  aa.user_id,
  (aa.created_at AT TIME ZONE 'Asia/Tashkent')::date,
  aa.question_id,
  aa.created_at DESC,
  aa.id DESC
ON CONFLICT (user_id, activity_date, question_id) DO UPDATE SET
  is_correct = EXCLUDED.is_correct,
  updated_at = GREATEST(bilimyol_private.daily_question_outcomes.updated_at, EXCLUDED.updated_at);

WITH recomputed AS (
  SELECT dqo.user_id,
         dqo.activity_date,
         pg_catalog.count(*)::INT AS q_total,
         pg_catalog.count(*) FILTER (WHERE dqo.is_correct)::INT AS q_correct
  FROM bilimyol_private.daily_question_outcomes dqo
  GROUP BY dqo.user_id, dqo.activity_date
)
UPDATE public.daily_learning_stats dls
SET questions_answered = recomputed.q_total,
    correct_answers = recomputed.q_correct,
    accuracy_percent = CASE
      WHEN recomputed.q_total > 0
      THEN pg_catalog.round((recomputed.q_correct::NUMERIC * 100) / recomputed.q_total::NUMERIC)::INT
      ELSE 0
    END
FROM recomputed
WHERE dls.user_id = recomputed.user_id
  AND dls.activity_date = recomputed.activity_date;

UPDATE public.daily_learning_stats
SET active_seconds = GREATEST(0, LEAST(86400, active_seconds)),
    lessons_completed = GREATEST(0, lessons_completed),
    questions_answered = GREATEST(0, questions_answered),
    correct_answers = GREATEST(0, LEAST(GREATEST(0, questions_answered), correct_answers)),
    accuracy_percent = GREATEST(0, LEAST(100, accuracy_percent)),
    xp_earned = GREATEST(0, xp_earned),
    overall_score = GREATEST(0, LEAST(100, overall_score))
WHERE active_seconds < 0
   OR active_seconds > 86400
   OR lessons_completed < 0
   OR questions_answered < 0
   OR correct_answers < 0
   OR correct_answers > questions_answered
   OR accuracy_percent < 0
   OR accuracy_percent > 100
   OR xp_earned < 0
   OR overall_score < 0
   OR overall_score > 100;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'daily_learning_stats_bounds_check') THEN
    ALTER TABLE public.daily_learning_stats
      ADD CONSTRAINT daily_learning_stats_bounds_check CHECK (
        active_seconds >= 0
        AND active_seconds <= 86400
        AND lessons_completed >= 0
        AND questions_answered >= 0
        AND correct_answers >= 0
        AND correct_answers <= questions_answered
        AND accuracy_percent >= 0
        AND accuracy_percent <= 100
        AND xp_earned >= 0
        AND overall_score >= 0
        AND overall_score <= 100
      );
  END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. Sanitized public.handle_new_user() matching profiles CHECK constraints
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_first_name TEXT;
  v_last_name TEXT;
  v_display_name TEXT;
  v_avatar_url TEXT;
  v_email TEXT;
  v_valid_course_id TEXT;
BEGIN
  v_first_name := COALESCE(
    NULLIF(pg_catalog.left(pg_catalog.btrim(COALESCE(NEW.raw_user_meta_data->>'first_name', '')), 120), ''),
    'Foydalanuvchi'
  );
  v_last_name := pg_catalog.left(pg_catalog.btrim(COALESCE(NEW.raw_user_meta_data->>'last_name', '')), 120);
  v_display_name := pg_catalog.left(
    CASE
      WHEN v_last_name <> '' THEN v_first_name || ' ' || v_last_name
      ELSE v_first_name
    END,
    250
  );
  v_email := pg_catalog.left(pg_catalog.btrim(COALESCE(NEW.email, '')), 320);
  v_avatar_url := NULLIF(pg_catalog.btrim(COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')), '');
  IF v_avatar_url IS NOT NULL AND (
    pg_catalog.char_length(v_avatar_url) > 2048
    OR v_avatar_url !~ '^https://[^\s<>"]+$'
  ) THEN
    v_avatar_url := NULL;
  END IF;

  INSERT INTO public.profiles (
    id, first_name, last_name, email, avatar_url, display_name, role, created_at, updated_at
  )
  VALUES (
    NEW.id,
    v_first_name,
    v_last_name,
    v_email,
    v_avatar_url,
    v_display_name,
    'student',
    pg_catalog.now(),
    pg_catalog.now()
  )
  ON CONFLICT (id) DO UPDATE SET
    first_name = CASE
      WHEN public.profiles.first_name = 'Foydalanuvchi'
        AND EXCLUDED.first_name <> 'Foydalanuvchi'
      THEN EXCLUDED.first_name
      ELSE public.profiles.first_name
    END,
    last_name = CASE
      WHEN public.profiles.last_name = '' AND EXCLUDED.last_name <> ''
      THEN EXCLUDED.last_name
      ELSE public.profiles.last_name
    END,
    display_name = CASE
      WHEN public.profiles.display_name = 'Foydalanuvchi'
        AND EXCLUDED.display_name <> 'Foydalanuvchi'
      THEN EXCLUDED.display_name
      ELSE public.profiles.display_name
    END,
    email = EXCLUDED.email,
    avatar_url = COALESCE(public.profiles.avatar_url, EXCLUDED.avatar_url),
    updated_at = pg_catalog.now();

  BEGIN
    SELECT c.id INTO v_valid_course_id
    FROM public.courses c
    WHERE c.id = 'course_math_01'
    LIMIT 1;

    INSERT INTO public.learner_profiles (
      user_id, selected_course_id, goal, daily_minutes, initial_level, created_at, updated_at
    )
    VALUES (
      NEW.id, v_valid_course_id, 'mastery', 15, 'intermediate', pg_catalog.now(), pg_catalog.now()
    )
    ON CONFLICT (user_id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: learner_profiles insert warning: %', SQLERRM;
  END;

  BEGIN
    INSERT INTO public.gamification_profiles (
      user_id, xp, streak_days, last_activity_date, updated_at
    )
    VALUES (
      NEW.id, 0, 0, NULL, pg_catalog.now()
    )
    ON CONFLICT (user_id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: gamification_profiles insert warning: %', SQLERRM;
  END;

  BEGIN
    INSERT INTO public.user_preferences (
      user_id, dark_mode, notifications_enabled, language, updated_at
    )
    VALUES (NEW.id, false, true, 'uz', pg_catalog.now())
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

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 6. Hardened save_placement_attempt with input bounds & daily question dedup
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
  v_daily_total INT := 0;
  v_daily_correct INT := 0;
  v_daily_accuracy INT := 0;
  v_answer_idem_key TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  IF p_course_id IS NULL OR NULLIF(pg_catalog.btrim(p_course_id), '') IS NULL THEN
    RAISE EXCEPTION 'Placement kursi noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;
  IF pg_catalog.char_length(p_course_id) > 64 THEN
    RAISE EXCEPTION 'Placement kursi identifikatori haddan tashqari uzun.' USING ERRCODE = '23514';
  END IF;
  IF p_submissions IS NULL OR pg_catalog.jsonb_typeof(p_submissions) <> 'array'
     OR pg_catalog.jsonb_array_length(p_submissions) = 0 THEN
    RAISE EXCEPTION 'Placement javoblari bo‘sh bo‘lishi mumkin emas.' USING ERRCODE = '22023';
  END IF;
  IF NULLIF(pg_catalog.btrim(p_idempotency_key), '') IS NULL THEN
    RAISE EXCEPTION 'Placement idempotency kaliti talab qilinadi.' USING ERRCODE = '22023';
  END IF;
  IF pg_catalog.char_length(p_idempotency_key) > 128 THEN
    RAISE EXCEPTION 'Idempotency kaliti uzunligi 128 belgidan oshmasligi shart.' USING ERRCODE = '23514';
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
    v_answer_idem_key := pg_catalog.left(
      'plc:' || v_attempt_id::TEXT || ':' || (v_submission->>'question_id'),
      128
    );

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
      pg_catalog.left(COALESCE(v_question.options->>v_selected, ''), 4000),
      v_is_correct,
      v_answer_idem_key,
      pg_catalog.now()
    )
    ON CONFLICT (user_id, idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

    INSERT INTO bilimyol_private.daily_question_outcomes (
      user_id, activity_date, question_id, is_correct, updated_at
    )
    VALUES (
      v_uid, v_today, v_submission->>'question_id', v_is_correct, pg_catalog.now()
    )
    ON CONFLICT (user_id, activity_date, question_id) DO UPDATE SET
      is_correct = EXCLUDED.is_correct,
      updated_at = EXCLUDED.updated_at;

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

  SELECT pg_catalog.count(*)::INT,
         pg_catalog.count(*) FILTER (WHERE dqo.is_correct)::INT
  INTO v_daily_total, v_daily_correct
  FROM bilimyol_private.daily_question_outcomes dqo
  WHERE dqo.user_id = v_uid AND dqo.activity_date = v_today;

  v_daily_accuracy := CASE
    WHEN v_daily_total > 0
    THEN pg_catalog.round((v_daily_correct::NUMERIC * 100) / v_daily_total::NUMERIC)::INT
    ELSE 0
  END;

  -- Acquire daily_learning_stats row lock before any gamification_profiles writes.
  INSERT INTO public.daily_learning_stats (
    user_id, activity_date, questions_answered, correct_answers, accuracy_percent, xp_earned, updated_at
  )
  VALUES (v_uid, v_today, v_daily_total, v_daily_correct, v_daily_accuracy, 0, pg_catalog.now())
  ON CONFLICT (user_id, activity_date) DO UPDATE SET
    questions_answered = EXCLUDED.questions_answered,
    correct_answers = EXCLUDED.correct_answers,
    accuracy_percent = EXCLUDED.accuracy_percent,
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

-- ----------------------------------------------------------------------------
-- 7. Hardened bilimyol_private.submit_answer_attempt & public.submit_answer_attempt
--    (FIX-P0-24 & FIX-P2-23)
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
  v_clean_text TEXT;
  v_today DATE;
  v_daily_total INT := 0;
  v_daily_correct INT := 0;
  v_daily_accuracy INT := 0;
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
     OR p_selected_index < 0
     OR p_selected_index > 100 THEN
    RAISE EXCEPTION 'Javob konteksti yoki indeksi noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;

  IF pg_catalog.char_length(p_course_id) > 64
     OR pg_catalog.char_length(p_skill_id) > 64
     OR pg_catalog.char_length(p_lesson_id) > 160
     OR pg_catalog.char_length(p_question_id) > 160 THEN
    RAISE EXCEPTION 'Javob identifikatorlari ruxsat etilgan hajmdan oshib ketdi.' USING ERRCODE = '23514';
  END IF;

  v_clean_text := COALESCE(p_selected_text, '');
  IF pg_catalog.char_length(v_clean_text) > 4000 THEN
    RAISE EXCEPTION 'Javob matni 4000 belgidan oshmasligi shart.' USING ERRCODE = '23514';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    IF pg_catalog.btrim(p_idempotency_key) = '' THEN
      RAISE EXCEPTION 'Idempotency kaliti bo‘sh satr bo‘lishi mumkin emas.' USING ERRCODE = '22023';
    END IF;
    IF pg_catalog.char_length(p_idempotency_key) > 128 THEN
      RAISE EXCEPTION 'Idempotency kaliti uzunligi 128 belgidan oshmasligi shart.' USING ERRCODE = '23514';
    END IF;
    v_eff_idempotency := p_idempotency_key;
  ELSE
    -- Never synthesize a static content-hashed key when p_idempotency_key is omitted.
    v_eff_idempotency := NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.skills s
    WHERE s.id = p_skill_id AND s.course_id = p_course_id
  ) THEN
    RAISE EXCEPTION 'Ko‘nikma kurs bilan mos emas.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('learning:' || p_user_id::TEXT, 0)
  );

  IF v_eff_idempotency IS NOT NULL THEN
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
            OR aa.selected_answer IS DISTINCT FROM v_clean_text
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

      -- Gate explanation strictly on v_existing_is_correct = true (never leak on wrong replay).
      IF v_existing_is_correct = true THEN
        SELECT exp_cand.explanation
        INTO v_explanation
        FROM (
          SELECT q.explanation AS explanation
          FROM public.questions q
          WHERE q.id = p_question_id AND NOT q.is_placement
          UNION ALL
          SELECT items.elem->>'explanation' AS explanation
          FROM public.lessons l
          CROSS JOIN LATERAL (
            SELECT COALESCE(step_elem->'interactiveQuestion', step_elem->'interactive_question') AS elem
            FROM pg_catalog.jsonb_array_elements(
              CASE WHEN pg_catalog.jsonb_typeof(l.steps) = 'array' THEN l.steps ELSE '[]'::jsonb END
            ) AS step_elem
            UNION ALL
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
          ) items
          WHERE l.course_id = p_course_id
            AND l.is_published
            AND NOT l.is_archived
            AND pg_catalog.jsonb_typeof(items.elem) = 'object'
            AND items.elem->>'id' = p_question_id
          UNION ALL
          SELECT g_items.elem->>'explanation' AS explanation
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
          ) g_items
          WHERE gl.course_id = p_course_id
            AND gl.course_id <> 'course_math_01'
            AND pg_catalog.jsonb_typeof(g_items.elem) = 'object'
            AND g_items.elem->>'id' = p_question_id
        ) exp_cand
        WHERE NULLIF(pg_catalog.btrim(COALESCE(exp_cand.explanation, '')), '') IS NOT NULL
        LIMIT 1;
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
           COALESCE(NULLIF(COALESCE(cand.elem->>'skillId', cand.elem->>'skill_id'), ''), l.skill_id) AS resolved_skill,
           CASE
             WHEN COALESCE(cand.elem->>'correct_index', cand.elem->>'correctIndex') ~ '^[0-9]{1,3}$'
             THEN COALESCE(cand.elem->>'correct_index', cand.elem->>'correctIndex')::INT
           END AS resolved_ci,
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

    IF v_question_course IS NULL AND NOT EXISTS (
      SELECT 1 FROM public.lessons existing_l WHERE existing_l.id = v_reinf_target.target_lesson_id
    ) THEN
      SELECT gl.course_id,
             COALESCE(NULLIF(COALESCE(cand.elem->>'skillId', cand.elem->>'skill_id'), ''), gl.skill_id),
             CASE
               WHEN COALESCE(cand.elem->>'correct_index', cand.elem->>'correctIndex') ~ '^[0-9]{1,3}$'
               THEN COALESCE(cand.elem->>'correct_index', cand.elem->>'correctIndex')::INT
             END,
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
      WHERE gl.id = v_reinf_target.target_lesson_id
        AND gl.course_id = p_course_id
        AND gl.course_id <> 'course_math_01'
        AND gl.skill_id = p_skill_id
        AND pg_catalog.jsonb_typeof(cand.elem) = 'object'
        AND cand.elem->>'id' = p_question_id
      LIMIT 1;
    END IF;

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
    SELECT l.course_id,
           COALESCE(NULLIF(COALESCE(cand.elem->>'skillId', cand.elem->>'skill_id'), ''), l.skill_id) AS resolved_skill,
           CASE
             WHEN COALESCE(cand.elem->>'correct_index', cand.elem->>'correctIndex') ~ '^[0-9]{1,3}$'
             THEN COALESCE(cand.elem->>'correct_index', cand.elem->>'correctIndex')::INT
           END AS resolved_ci,
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

    IF v_question_course IS NULL AND NOT EXISTS (
      SELECT 1 FROM public.lessons existing_l WHERE existing_l.id = p_lesson_id
    ) THEN
      SELECT gl.course_id,
             gl.skill_id,
             CASE
               WHEN COALESCE(cand.elem->>'correct_index', cand.elem->>'correctIndex') ~ '^[0-9]{1,3}$'
               THEN COALESCE(cand.elem->>'correct_index', cand.elem->>'correctIndex')::INT
             END,
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
    p_selected_index, v_clean_text, v_is_correct, v_eff_idempotency,
    GREATEST(
      pg_catalog.clock_timestamp(),
      COALESCE(
        (SELECT pg_catalog.max(aa_prev.created_at) + interval '1 microsecond'
         FROM public.answer_attempts aa_prev
         WHERE aa_prev.user_id = p_user_id),
        pg_catalog.clock_timestamp()
      ),
      COALESCE(
        (SELECT pg_catalog.max(ra_prev.created_at) + interval '1 microsecond'
         FROM public.reinforcement_attempts ra_prev
         WHERE ra_prev.user_id = p_user_id),
        pg_catalog.clock_timestamp()
      )
    )
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

  -- Deduplicate daily question statistics by (user_id, activity_date, question_id).
  INSERT INTO bilimyol_private.daily_question_outcomes (
    user_id, activity_date, question_id, is_correct, updated_at
  )
  VALUES (
    p_user_id, v_today, p_question_id, v_is_correct, pg_catalog.now()
  )
  ON CONFLICT (user_id, activity_date, question_id) DO UPDATE SET
    is_correct = EXCLUDED.is_correct,
    updated_at = EXCLUDED.updated_at;

  SELECT pg_catalog.count(*)::INT,
         pg_catalog.count(*) FILTER (WHERE dqo.is_correct)::INT
  INTO v_daily_total, v_daily_correct
  FROM bilimyol_private.daily_question_outcomes dqo
  WHERE dqo.user_id = p_user_id AND dqo.activity_date = v_today;

  v_daily_accuracy := CASE
    WHEN v_daily_total > 0
    THEN pg_catalog.round((v_daily_correct::NUMERIC * 100) / v_daily_total::NUMERIC)::INT
    ELSE 0
  END;

  -- Lock daily_learning_stats BEFORE any gamification_profiles write.
  INSERT INTO public.daily_learning_stats (
    user_id, activity_date, questions_answered, correct_answers,
    accuracy_percent, xp_earned, overall_score, updated_at
  )
  VALUES (
    p_user_id, v_today, v_daily_total, v_daily_correct,
    v_daily_accuracy, v_pending_answer_xp, v_overall_score, pg_catalog.now()
  )
  ON CONFLICT (user_id, activity_date) DO UPDATE SET
    questions_answered = EXCLUDED.questions_answered,
    correct_answers = EXCLUDED.correct_answers,
    accuracy_percent = EXCLUDED.accuracy_percent,
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
  IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_user_id OR p_lesson_id = 'placement_test' THEN
    RAISE EXCEPTION 'Ushbu javobni bu yo‘l orqali topshirib bo‘lmaydi.' USING ERRCODE = '42501';
  END IF;

  IF p_idempotency_key IS NOT NULL AND pg_catalog.char_length(p_idempotency_key) > 128 THEN
    RAISE EXCEPTION 'Idempotency kaliti uzunligi 128 belgidan oshmasligi shart.' USING ERRCODE = '23514';
  END IF;
  IF p_selected_text IS NOT NULL AND pg_catalog.char_length(p_selected_text) > 4000 THEN
    RAISE EXCEPTION 'Javob matni 4000 belgidan oshmasligi shart.' USING ERRCODE = '23514';
  END IF;
  IF COALESCE(pg_catalog.char_length(p_course_id), 0) > 64
     OR COALESCE(pg_catalog.char_length(p_skill_id), 0) > 64
     OR COALESCE(pg_catalog.char_length(p_lesson_id), 0) > 160
     OR COALESCE(pg_catalog.char_length(p_question_id), 0) > 160 THEN
    RAISE EXCEPTION 'Javob identifikatorlari ruxsat etilgan hajmdan oshib ketdi.' USING ERRCODE = '23514';
  END IF;

  IF EXISTS (SELECT 1 FROM public.questions WHERE id = p_question_id AND is_placement) THEN
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
-- 8. Bounded public.record_session_heartbeat (hourly session creation cap)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_session_heartbeat(
  p_session_id UUID,
  p_course_id TEXT DEFAULT 'course_math_01',
  p_lesson_id TEXT DEFAULT NULL,
  p_platform TEXT DEFAULT 'web'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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
  v_recent_sessions INT := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  IF p_session_id IS NULL
    OR p_course_id IS NULL
    OR pg_catalog.char_length(p_course_id) > 64
    OR (p_lesson_id IS NOT NULL AND pg_catalog.char_length(p_lesson_id) > 160)
    OR p_platform IS NULL
    OR p_platform NOT IN ('web', 'ios', 'android')
    OR NOT EXISTS (SELECT 1 FROM public.courses WHERE id = p_course_id AND is_active)
    OR (
      p_lesson_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.lessons
        WHERE id = p_lesson_id AND course_id = p_course_id AND is_published AND NOT is_archived
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.generated_lessons
        WHERE id = p_lesson_id AND course_id = p_course_id
      )
    )
  THEN
    RAISE EXCEPTION 'Mashg‘ulot konteksti noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('heartbeat:' || v_uid::TEXT, 0)
  );
  v_now := pg_catalog.clock_timestamp();
  v_today := (v_now AT TIME ZONE 'Asia/Tashkent')::date;

  SELECT * INTO v_session FROM public.learning_sessions WHERE id = p_session_id;
  IF NOT FOUND THEN
    SELECT pg_catalog.count(*)::INT
    INTO v_recent_sessions
    FROM public.learning_sessions ls
    WHERE ls.user_id = v_uid
      AND ls.created_at >= v_now - interval '1 hour';

    IF v_recent_sessions >= 60 THEN
      RAISE EXCEPTION 'Soatlik mashg‘ulot sessiyalari cheklovidan oshildi.' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.learning_sessions (
      id, user_id, course_id, lesson_id, started_at, last_heartbeat_at, platform, created_at
    ) VALUES (
      p_session_id, v_uid, p_course_id, p_lesson_id, v_now, v_now, p_platform, v_now
    );
  ELSE
    IF v_session.user_id <> v_uid THEN
      RAISE EXCEPTION 'Sessiyaga ruxsat yo‘q.' USING ERRCODE = '42501';
    END IF;
    SELECT ls.last_heartbeat_at
    INTO v_latest
    FROM public.learning_sessions ls
    WHERE ls.user_id = v_uid
    ORDER BY ls.last_heartbeat_at DESC
    LIMIT 1;

    v_elapsed := pg_catalog.floor(EXTRACT(EPOCH FROM v_now - v_latest));
    IF v_elapsed > 0 AND v_elapsed <= 300 AND v_now - v_session.last_heartbeat_at <= interval '5 minutes' THEN
      v_added := LEAST(60, v_elapsed);
    END IF;

    UPDATE public.learning_sessions
    SET last_heartbeat_at = v_now,
        active_seconds = active_seconds + v_added,
        course_id = p_course_id,
        lesson_id = p_lesson_id
    WHERE id = p_session_id
    RETURNING active_seconds INTO v_total;
  END IF;

  IF v_added > 0 THEN
    INSERT INTO public.daily_learning_stats AS stats (user_id, activity_date, active_seconds, updated_at)
    VALUES (v_uid, v_today, v_added, v_now)
    ON CONFLICT (user_id, activity_date) DO UPDATE SET
      active_seconds = LEAST(86400, stats.active_seconds + EXCLUDED.active_seconds),
      updated_at = EXCLUDED.updated_at;
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'session_id', p_session_id,
    'added_active_seconds', v_added,
    'total_session_active_seconds', v_total
  );
END;
$$;

REVOKE ALL ON FUNCTION public.record_session_heartbeat(UUID, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_session_heartbeat(UUID, TEXT, TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
