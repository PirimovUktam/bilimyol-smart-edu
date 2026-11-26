-- ============================================================================
-- BILIMYO'L SMART EDU - WAVE 1 · BATCH W1-B1 REGRESSION SUITE
-- File: supabase/tests/w1_b1_idempotency_constraints_and_daily_stats_regression.sql
-- Run ONLY on disposable local PostgreSQL after all migrations:
--   psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/w1_b1_idempotency_constraints_and_daily_stats_regression.sql
-- Plain PostgreSQL assertions; rolls back all fixtures.
-- ============================================================================
BEGIN;

CREATE FUNCTION pg_temp.assert_w1b1(value BOOLEAN, label TEXT)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF value IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'ASSERT [W1-B1]: %', label;
  END IF;
END;
$$;

INSERT INTO auth.users (id, email, email_confirmed_at, raw_user_meta_data) VALUES
  ('00000000-0000-0000-0000-000000001101', 'w1b1-learner@example.invalid', now(), '{"first_name":"Sardor","last_name":"Karimov","avatar_url":"javascript:alert(1)"}'),
  ('00000000-0000-0000-0000-000000001102', 'w1b1-reinf@example.invalid', now(), '{"first_name":"Aziza","last_name":"Rahimova","avatar_url":"https://cdn.example.invalid/avatar.png"}'),
  ('00000000-0000-0000-0000-000000001103', 'w1b1-stats@example.invalid', now(), '{"first_name":"Jasur","last_name":"Aliyev"}');

-- Verify handle_new_user stripped unsafe javascript: avatar_url while keeping valid https:// avatar_url
SELECT pg_temp.assert_w1b1(
  (SELECT avatar_url IS NULL FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000001101')
  AND (SELECT avatar_url = 'https://cdn.example.invalid/avatar.png' FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000001102'),
  'FIX-P2-23: handle_new_user strips non-https avatar_url while preserving valid https avatar_url'
);

-- Fixture lesson & roadmap node (including order_index >= 1000 to verify widened NUMERIC)
INSERT INTO public.lessons (id, course_id, skill_id, title, steps, reinforcement_exercise, is_published, is_archived)
VALUES (
  'lesson_w1b1_cwc',
  'course_eng_01',
  'skill_eng_vocab',
  'W1-B1 Idempotency Fixture',
  '[
    {"id":"s1","stepNumber":1,"type":"interactive_question","title":"Q1","content":"Pick B","interactiveQuestion":{"id":"q_w1b1_1","courseId":"course_eng_01","skillId":"skill_eng_vocab","text":"Pick B","options":["Wrong A","Correct B"],"correctIndex":1,"difficulty":"easy","explanation":"B is right."}},
    {"id":"s2","stepNumber":2,"type":"interactive_question","title":"Q2","content":"Pick A","interactiveQuestion":{"id":"q_w1b1_2","courseId":"course_eng_01","skillId":"skill_eng_vocab","text":"Pick A","options":["Correct A","Wrong B"],"correctIndex":0,"difficulty":"easy","explanation":"A is right."}}
  ]'::jsonb,
  '{"id":"q_w1b1_reinf","courseId":"course_eng_01","skillId":"skill_eng_vocab","text":"Reinforce B","options":["No","Yes"],"correctIndex":1,"difficulty":"easy","explanation":"Yes reinforces."}'::jsonb,
  true,
  false
);

INSERT INTO public.roadmap_nodes (
  id, course_id, skill_id, title, description, target_lesson_id, required_score, order_index, is_active
) VALUES (
  'node_w1b1_cwc', 'course_eng_01', 'skill_eng_vocab', 'W1-B1 Node', 'Desc', 'lesson_w1b1_cwc', 70, 1250.5, true
);

-- ============================================================================
-- 1. FIX-P0-24: Per-attempt UUID idempotency, replay safety & Correct -> Wrong -> Correct
-- ============================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000001101', true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_r1 JSONB;
  v_r1_replay JSONB;
  v_r_wrong JSONB;
  v_r_wrong_replay JSONB;
  v_r_recover JSONB;
  v_r_same_val_new_uuid JSONB;
  v_comp JSONB;
  v_xp_after_first INT;
BEGIN
  -- 1a. First correct attempt with uuid-1
  v_r1 := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_w1b1_cwc', 'q_w1b1_1', 1, 'Correct B',
    '11111111-1111-4111-8111-111111111101'
  );
  PERFORM pg_temp.assert_w1b1(
    (v_r1->>'is_correct')::BOOLEAN = true
    AND (v_r1->>'already_processed')::BOOLEAN = false
    AND (v_r1->>'xp_awarded')::INT = 2,
    'FIX-P0-24: initial correct UUID awards +2 XP and marks already_processed=false'
  );

  SELECT xp INTO v_xp_after_first FROM public.gamification_profiles WHERE user_id = auth.uid();
  PERFORM pg_temp.assert_w1b1(v_xp_after_first = 2, 'FIX-P0-24: profile XP is 2 after first correct answer');

  -- 1b. Exact same UUID sent a second time (transport retry): zero duplicate row, zero duplicate XP
  v_r1_replay := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_w1b1_cwc', 'q_w1b1_1', 1, 'Correct B',
    '11111111-1111-4111-8111-111111111101'
  );
  PERFORM pg_temp.assert_w1b1(
    (v_r1_replay->>'is_correct')::BOOLEAN = true
    AND (v_r1_replay->>'already_processed')::BOOLEAN = true
    AND (v_r1_replay->>'xp_awarded')::INT = 0
    AND (v_r1_replay->>'explanation') = 'B is right.'
    AND (SELECT count(*) = 1 FROM public.answer_attempts WHERE user_id = auth.uid() AND question_id = 'q_w1b1_1')
    AND (SELECT xp = 2 FROM public.gamification_profiles WHERE user_id = auth.uid()),
    'FIX-P0-24: replaying same UUID returns already_processed=true, preserves explanation on correct replay, and does not insert duplicate row or XP'
  );

  -- 1c. Reusing same UUID for different selected_answer or selected_index raises 22023
  BEGIN
    PERFORM public.submit_answer_attempt(
      auth.uid(), 'course_eng_01', 'skill_eng_vocab',
      'lesson_w1b1_cwc', 'q_w1b1_1', 1, 'Mutated Text Payload',
      '11111111-1111-4111-8111-111111111101'
    );
    RAISE EXCEPTION 'ASSERT [W1-B1]: expected 22023 on mutated selected_text with reused idempotency_key';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;

  -- 1d. Wrong attempt with uuid-2 (Correct -> Wrong)
  v_r_wrong := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_w1b1_cwc', 'q_w1b1_1', 0, 'Wrong A',
    '11111111-1111-4111-8111-111111111102'
  );
  PERFORM pg_temp.assert_w1b1(
    (v_r_wrong->>'is_correct')::BOOLEAN = false
    AND (v_r_wrong->>'already_processed')::BOOLEAN = false
    AND (v_r_wrong->>'new_skill_score')::INT = 0,
    'FIX-P0-24: wrong attempt with new UUID updates latest outcome to incorrect'
  );

  -- Wrong replay must NOT leak answer explanation
  v_r_wrong_replay := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_w1b1_cwc', 'q_w1b1_1', 0, 'Wrong A',
    '11111111-1111-4111-8111-111111111102'
  );
  PERFORM pg_temp.assert_w1b1(
    (v_r_wrong_replay->>'already_processed')::BOOLEAN = true
    AND (v_r_wrong_replay->>'explanation') = 'Javob avval qayd etilgan.',
    'FIX-P0-24: wrong idempotent replay withholds explanation'
  );

  -- 1e. Recovery correct attempt with uuid-3 (Correct -> Wrong -> Correct!)
  v_r_recover := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_w1b1_cwc', 'q_w1b1_1', 1, 'Correct B',
    '11111111-1111-4111-8111-111111111103'
  );
  PERFORM pg_temp.assert_w1b1(
    (v_r_recover->>'is_correct')::BOOLEAN = true
    AND (v_r_recover->>'already_processed')::BOOLEAN = false
    AND (v_r_recover->>'xp_awarded')::INT = 0
    AND (v_r_recover->>'new_skill_score')::INT = 100,
    'FIX-P0-24: Correct -> Wrong -> Correct with fresh UUID records newest correct attempt and restores 100% score without double XP'
  );

  -- 1f. Same answer value with a new UUID (uuid-4) still inserts a new logical attempt without double XP
  v_r_same_val_new_uuid := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_w1b1_cwc', 'q_w1b1_1', 1, 'Correct B',
    '11111111-1111-4111-8111-111111111104'
  );
  PERFORM pg_temp.assert_w1b1(
    (v_r_same_val_new_uuid->>'already_processed')::BOOLEAN = false
    AND (v_r_same_val_new_uuid->>'xp_awarded')::INT = 0
    AND (SELECT count(*) = 4 FROM public.answer_attempts WHERE user_id = auth.uid() AND question_id = 'q_w1b1_1'),
    'FIX-P0-24: same answer value with new UUID creates new attempt row with 0 extra XP'
  );

  -- 1g. Omitted p_idempotency_key (NULL) also supports Correct -> Wrong -> Correct without static-key collision
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_w1b1_cwc', 'q_w1b1_2', 0, 'Correct A', NULL
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_w1b1_cwc', 'q_w1b1_2', 1, 'Wrong B', NULL
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_w1b1_cwc', 'q_w1b1_2', 0, 'Correct A', NULL
  );

  -- 1h. complete_lesson succeeds after Correct -> Wrong -> Correct on both questions!
  v_comp := public.complete_lesson('lesson_w1b1_cwc', 'course_eng_01');
  PERFORM pg_temp.assert_w1b1(
    (v_comp->>'completed')::BOOLEAN = true AND (v_comp->>'xp_awarded')::INT = 20,
    'FIX-P0-24: complete_lesson succeeds cleanly after Correct -> Wrong -> Correct'
  );
END;
$$;
RESET ROLE;

-- ============================================================================
-- 2. FIX-P0-24: Reinforcement Correct -> Wrong -> Correct -> complete_reinforcement
-- ============================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000001102', true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_reinf_comp JSONB;
BEGIN
  -- Seed a wrong lesson attempt so skill_eng_vocab < 70 (eligible for reinforcement)
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_w1b1_cwc', 'q_w1b1_1', 0, 'Wrong A',
    '22222222-2222-4222-8222-222222222201'
  );

  -- Reinforcement Correct -> Wrong -> Correct with per-click UUIDs
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'reinf_node_w1b1_cwc', 'q_w1b1_reinf', 1, 'Yes',
    '22222222-2222-4222-8222-222222222202'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'reinf_node_w1b1_cwc', 'q_w1b1_reinf', 0, 'No',
    '22222222-2222-4222-8222-222222222203'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'reinf_node_w1b1_cwc', 'q_w1b1_reinf', 1, 'Yes',
    '22222222-2222-4222-8222-222222222204'
  );

  v_reinf_comp := public.complete_reinforcement(
    'reinf_node_w1b1_cwc', 'course_eng_01', 'skill_eng_vocab', 'q_w1b1_reinf', 30
  );
  PERFORM pg_temp.assert_w1b1(
    (v_reinf_comp->>'already_processed')::BOOLEAN = false
    AND (v_reinf_comp->>'xp_awarded')::INT = 30
    AND (v_reinf_comp->>'new_score')::INT > (v_reinf_comp->>'old_score')::INT,
    'FIX-P0-24: complete_reinforcement succeeds after Correct -> Wrong -> Correct'
  );
END;
$$;
RESET ROLE;

-- ============================================================================
-- 3. FIX-P2-23: Daily question statistics deduplication & anti-farming
-- ============================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000001103', true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_stats RECORD;
  v_today DATE := (now() AT TIME ZONE 'Asia/Tashkent')::date;
  i INT;
BEGIN
  -- Q1 wrong
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_w1b1_cwc', 'q_w1b1_1', 0, 'Wrong A',
    '33333333-3333-4333-8333-333333333300'
  );

  -- Spam Q2 correct 15 times with 15 distinct UUIDs!
  FOR i IN 1..15 LOOP
    PERFORM public.submit_answer_attempt(
      auth.uid(), 'course_eng_01', 'skill_eng_vocab',
      'lesson_w1b1_cwc', 'q_w1b1_2', 0, 'Correct A',
      '33333333-3333-4333-8333-' || lpad(i::TEXT, 12, '0')
    );
  END LOOP;

  SELECT questions_answered, correct_answers, accuracy_percent, xp_earned
  INTO v_stats
  FROM public.daily_learning_stats
  WHERE user_id = auth.uid() AND activity_date = v_today;

  PERFORM pg_temp.assert_w1b1(
    v_stats.questions_answered = 2
    AND v_stats.correct_answers = 1
    AND v_stats.accuracy_percent = 50
    AND v_stats.xp_earned = 2,
    'FIX-P2-23: daily_learning_stats deduplicates (user_id, activity_date, question_id) and blocks accuracy farming (expected 2/1/50%, got '
      || COALESCE(v_stats.questions_answered::TEXT, 'null') || '/'
      || COALESCE(v_stats.correct_answers::TEXT, 'null') || '/'
      || COALESCE(v_stats.accuracy_percent::TEXT, 'null') || '%)'
  );

  -- Now learner fixes Q1 on the same day -> questions_answered stays 2, correct_answers becomes 2, accuracy becomes 100%
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_w1b1_cwc', 'q_w1b1_1', 1, 'Correct B',
    '33333333-3333-4333-8333-333333333399'
  );

  SELECT questions_answered, correct_answers, accuracy_percent, xp_earned
  INTO v_stats
  FROM public.daily_learning_stats
  WHERE user_id = auth.uid() AND activity_date = v_today;

  PERFORM pg_temp.assert_w1b1(
    v_stats.questions_answered = 2
    AND v_stats.correct_answers = 2
    AND v_stats.accuracy_percent = 100
    AND v_stats.xp_earned = 4,
    'FIX-P2-23: correcting Q1 updates same-day deduplicated accuracy to 2/2 (100%) without inflating questions_answered'
  );

  -- Completing the lesson increments lessons_completed (+1) and xp_earned (+20 -> 24) without altering question accuracy
  PERFORM public.complete_lesson('lesson_w1b1_cwc', 'course_eng_01');
  SELECT questions_answered, correct_answers, accuracy_percent, xp_earned, lessons_completed
  INTO v_stats
  FROM public.daily_learning_stats
  WHERE user_id = auth.uid() AND activity_date = v_today;

  PERFORM pg_temp.assert_w1b1(
    v_stats.questions_answered = 2
    AND v_stats.correct_answers = 2
    AND v_stats.accuracy_percent = 100
    AND v_stats.xp_earned = 24
    AND v_stats.lessons_completed = 1,
    'FIX-P2-23: lesson completion adds +20 XP and lessons_completed=1 in daily_learning_stats while preserving deduplicated accuracy'
  );
END;
$$;

-- ============================================================================
-- 4. FIX-P2-23: CHECK constraints, input size caps (no 54000 crash) & session cap
-- ============================================================================
DO $$
DECLARE
  i INT;
BEGIN
  -- 4a. Negative daily_minutes rejected with 23514
  BEGIN
    UPDATE public.learner_profiles SET daily_minutes = -99999 WHERE user_id = auth.uid();
    RAISE EXCEPTION 'ASSERT [W1-B1]: negative daily_minutes accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- 4b. Invalid goal / 7000-char prompt-injection goal rejected with 23514
  BEGIN
    UPDATE public.learner_profiles SET goal = repeat('A', 7000) WHERE user_id = auth.uid();
    RAISE EXCEPTION 'ASSERT [W1-B1]: invalid 7000-char goal accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- 4c. Invalid initial_level rejected with 23514
  BEGIN
    UPDATE public.learner_profiles SET initial_level = 'UNVALIDATED_LEVEL' WHERE user_id = auth.uid();
    RAISE EXCEPTION 'ASSERT [W1-B1]: invalid initial_level accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- 4d. Invalid course_levels value rejected with 23514
  BEGIN
    UPDATE public.learner_profiles SET course_levels = '{"course_math_01":"god_mode"}'::jsonb WHERE user_id = auth.uid();
    RAISE EXCEPTION 'ASSERT [W1-B1]: invalid course_levels enum accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- 4e. javascript: avatar_url rejected with 23514 on profiles UPDATE
  BEGIN
    UPDATE public.profiles SET avatar_url = 'javascript:alert(1)' WHERE id = auth.uid();
    RAISE EXCEPTION 'ASSERT [W1-B1]: javascript: avatar_url accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- 4f. >128-char p_idempotency_key (including 3500-byte B-tree killer) rejected with 23514 (never 54000!)
  BEGIN
    PERFORM public.submit_answer_attempt(
      auth.uid(), 'course_eng_01', 'skill_eng_vocab',
      'lesson_w1b1_cwc', 'q_w1b1_1', 1, 'Correct B',
      repeat('k', 3500)
    );
    RAISE EXCEPTION 'ASSERT [W1-B1]: >128-char p_idempotency_key accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- 4g. >4000-char p_selected_text rejected with 23514
  BEGIN
    PERFORM public.submit_answer_attempt(
      auth.uid(), 'course_eng_01', 'skill_eng_vocab',
      'lesson_w1b1_cwc', 'q_w1b1_1', 1, repeat('x', 4001),
      '44444444-4444-4444-8444-444444444401'
    );
    RAISE EXCEPTION 'ASSERT [W1-B1]: >4000-char p_selected_text accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- 4h. Hourly learning_sessions cap enforced in record_session_heartbeat
  FOR i IN 1..60 LOOP
    PERFORM public.record_session_heartbeat(
      ('55555555-5555-4555-8555-' || lpad(i::TEXT, 12, '0'))::UUID,
      'course_eng_01',
      'lesson_w1b1_cwc',
      'web'
    );
  END LOOP;
  BEGIN
    PERFORM public.record_session_heartbeat(
      '55555555-5555-4555-8555-000000000061'::UUID,
      'course_eng_01',
      'lesson_w1b1_cwc',
      'web'
    );
    RAISE EXCEPTION 'ASSERT [W1-B1]: 61st session within 1 hour was accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
END;
$$;

RESET ROLE;
ROLLBACK;
