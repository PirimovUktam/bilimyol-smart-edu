-- Run only on a disposable database. All fixtures roll back.
BEGIN;
CREATE FUNCTION pg_temp.assert_condition(value BOOLEAN, label TEXT) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF value IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %', label; END IF;
END;
$$;

INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('00000000-0000-0000-0000-000000000501', 'placement-one@example.invalid', '{}'),
  ('00000000-0000-0000-0000-000000000502', 'placement-two@example.invalid', '{}');
SELECT pg_temp.assert_condition(NOT has_function_privilege('anon', 'public.advance_placement(text,uuid,text,integer,boolean)', 'execute'),
  'anonymous access denied');
SELECT pg_temp.assert_condition(NOT has_function_privilege('authenticated', 'public.evaluate_placement_answer(text,text,integer)', 'execute')
  AND NOT has_function_privilege('authenticated', 'public.save_placement_attempt(text,jsonb,text)', 'execute'),
  'arbitrary evaluation and incomplete finalization denied');
SELECT pg_temp.assert_condition(NOT has_schema_privilege('authenticated', 'bilimyol_private', 'USAGE'),
  'private question and answer state is inaccessible');
SELECT pg_temp.assert_condition((SELECT count(*) = 12 FROM (
  SELECT course_id, skill_id FROM bilimyol_private.placement_question_bank
  GROUP BY course_id, skill_id HAVING count(DISTINCT difficulty) = 3
) covered), 'twelve starter skills have separate questions at all three difficulties');
SELECT pg_temp.assert_condition(NOT EXISTS (
  SELECT 1 FROM bilimyol_private.placement_question_bank
  WHERE id IN ('q_eng_p1', 'q_it_py_01', 'q_logic_pat_01', 'q_math_alg_01')
), 'bundled seeds are excluded even if loaded after migrations');
DO $$
DECLARE
  history JSONB := '[{"question_id":"q_live_math_alg_square","is_correct":true},
    {"question_id":"q_live_math_eq_fraction","is_correct":true},
    {"question_id":"q_live_math_func_compose","is_correct":true},
    {"question_id":"q_live_math_graph_slope","is_correct":true}]';
BEGIN
  PERFORM pg_temp.assert_condition(
    bilimyol_private.next_placement_question('course_math_01', history) = 'q_live_math_alg_difference'
      AND bilimyol_private.next_placement_question('course_math_01',
        jsonb_set(history, '{0,is_correct}', 'false'::jsonb)) = 'q_live_math_alg_distribute',
    'identical skill coverage adapts to the previous answer');
END;
$$;

SET LOCAL ROLE authenticated;
DO $$
DECLARE
  current_state JSONB;
  first_state JSONB;
  retry_state JSONB;
  session_id UUID;
  answer_count INT;
  last_question TEXT;
  lesson_question TEXT;
  course_id TEXT := 'course_eng_01';
  original_user UUID := '00000000-0000-0000-0000-000000000501';
  other_user UUID := '00000000-0000-0000-0000-000000000502';
BEGIN
  PERFORM set_config('request.jwt.claim.sub', original_user::TEXT, true);
  PERFORM pg_temp.assert_condition(NOT EXISTS (SELECT 1 FROM public.learner_questions WHERE is_placement),
    'a student cannot enumerate the private question bank');

  first_state := public.advance_placement(course_id);
  session_id := (first_state->>'session_id')::UUID;
  answer_count := (first_state->>'total_questions')::INT;
  last_question := first_state->'question'->>'id';
  PERFORM pg_temp.assert_condition(answer_count = 8 AND last_question IS NOT NULL
    AND first_state->'result' = 'null'::jsonb AND NOT (first_state->'question') ?| ARRAY['correct_index', 'explanation', 'difficulty'],
    'start returns one sanitized question');

  BEGIN
    PERFORM public.submit_answer_attempt(original_user, course_id, first_state->'question'->>'skill_id',
      'invented-lesson', last_question, 0, 'forged');
    RAISE EXCEPTION 'ASSERT: a diagnostic question was graded as a lesson';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.advance_placement(course_id, session_id, 'unasked-question', 0);
    RAISE EXCEPTION 'ASSERT: a user selected the next question';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  PERFORM set_config('request.jwt.claim.sub', other_user::TEXT, true);
  BEGIN
    PERFORM public.advance_placement(course_id, session_id, last_question, 0);
    RAISE EXCEPTION 'ASSERT: a foreign learner advanced the session';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claim.sub', original_user::TEXT, true);

  current_state := public.advance_placement(course_id, session_id, last_question, 0);
  PERFORM pg_temp.assert_condition((current_state->>'question_number')::INT = 2
    AND current_state->'result' = 'null'::jsonb, 'one answer advances without revealing its grade');
  retry_state := public.advance_placement(course_id, session_id, last_question, 0);
  PERFORM pg_temp.assert_condition(retry_state = current_state AND public.advance_placement(course_id) = current_state,
    'replayed requests and reloads do not advance twice');
  BEGIN
    PERFORM public.advance_placement(course_id, session_id, last_question, 1);
    RAISE EXCEPTION 'ASSERT: a committed choice was changed';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  PERFORM pg_temp.assert_condition(NOT EXISTS (SELECT 1 FROM public.placement_attempts WHERE user_id = original_user),
    'partial sessions have no published assessment');

  FOR i IN 2..answer_count LOOP
    last_question := current_state->'question'->>'id';
    current_state := public.advance_placement(course_id, session_id, last_question, 0);
  END LOOP;
  PERFORM pg_temp.assert_condition(current_state->'question' = 'null'::jsonb
    AND jsonb_array_length(current_state->'result'->'answers') = answer_count
    AND (current_state->'result'->'answers'->0) ? 'correct_option', 'review is delivered after the final answer');
  PERFORM pg_temp.assert_condition(NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(current_state->'result'->'answers') answer
    WHERE answer->>'question_id' NOT LIKE 'q_live_%'
  ), 'diagnostic never scores bundled sample questions');
  retry_state := public.advance_placement(course_id, session_id, last_question, 0);
  PERFORM pg_temp.assert_condition(retry_state = current_state
    AND public.advance_placement(course_id, p_restart => true) = current_state,
    'finalization is idempotent and cannot be restarted the same day');
  PERFORM pg_temp.assert_condition((SELECT count(*) FROM public.placement_attempts WHERE user_id = original_user) = 1
    AND (SELECT count(*) FROM public.placement_answers WHERE user_id = original_user) = answer_count,
    'one authoritative assessment and its complete answer set are persisted');
  PERFORM pg_temp.assert_condition((SELECT count(*) FROM public.learner_skill_scores
      WHERE user_id = original_user AND learner_skill_scores.course_id = 'course_eng_01') = 4,
    'diagnostic result persists all four course skill scores for the roadmap');
END;
$$;
RESET ROLE;
ROLLBACK;
