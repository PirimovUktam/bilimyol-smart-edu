-- Run only against a disposable/local database after all migrations:
-- psql <local-connection> -v ON_ERROR_STOP=1 -f supabase/tests/p1_persistence_regression.sql
-- Plain PostgreSQL assertions (no pgTAP dependency). Every fixture rolls back.
BEGIN;

CREATE FUNCTION pg_temp.assert_true(value BOOLEAN, message TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF value IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %', message; END IF;
END;
$$;

INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('00000000-0000-0000-0000-000000000101', 'p1-student@example.invalid', '{}'),
  ('00000000-0000-0000-0000-000000000102', 'p1-parent@example.invalid', '{}'),
  ('00000000-0000-0000-0000-000000000103', 'p1-other@example.invalid', '{}');
SELECT set_config('bilimyol.authorized_role_change', 'true', true);
UPDATE public.profiles SET role = 'parent' WHERE id = '00000000-0000-0000-0000-000000000102';
SELECT set_config('bilimyol.authorized_role_change', 'false', true);

INSERT INTO public.questions (
  id, course_id, skill_id, text, options, correct_index, difficulty, explanation, is_placement
) VALUES
  ('q_p1_placement_a', 'course_math_01', 'skill_math_functions', 'A?', '["no", "yes"]', 1, 'easy', 'answer', true),
  ('q_p1_placement_b', 'course_math_01', 'skill_math_functions', 'B?', '["no", "yes"]', 1, 'easy', 'answer', true);

INSERT INTO public.lessons (id, course_id, skill_id, title, steps, reinforcement_exercise) VALUES (
  'lesson_p1_fixture', 'course_math_01', 'skill_math_functions', 'Fixture',
  '[{"id":"step","type":"interactive_question","interactive_question":{"id":"q_p1_curated","text":"Q?","options":["no","yes"],"correctIndex":1,"explanation":"secret","extra":{"correct_option":"yes"}}}]',
  '{"id":"q_p1_reinforcement","text":"R?","options":["no","yes"],"correct_index":1,"explanation":"secret"}'
);
INSERT INTO public.roadmap_nodes (
  id, course_id, skill_id, title, description, target_lesson_id, order_index
) VALUES ('node_p1_fixture', 'course_math_01', 'skill_math_functions', 'Fixture', '', 'lesson_p1_fixture', 9);

INSERT INTO public.generated_lessons (
  id, course_id, skill_id, topic, level, difficulty, title, summary, objective, steps, questions
) VALUES (
  'lesson_p1_generated', 'course_math_01', 'skill_math_functions', 'Fixture', 'intermediate', 'easy', 'Fixture', '', '',
  '[{"interactiveQuestion":{"id":"q_nested","correctIndex":1,"extra":[{"correct_option_id":"b"}]}},{"interactive_question":{"correct_index":0}}]',
  '[{"id":"q_generated","options":["a","b"],"correct_index":1,"explanation":"secret"}]'
);

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000101', true);
SET LOCAL ROLE authenticated;

-- Effective privileges must be identical with legacy GRANT ALL defaults and
-- fresh Supabase projects whose default table exposure is disabled.
SELECT pg_temp.assert_true(
  has_table_privilege('public.profiles', 'SELECT')
    AND has_table_privilege('public.courses', 'SELECT')
    AND has_table_privilege('public.learner_profiles', 'UPDATE'),
  'core profile/catalogue/preferences have explicit authenticated privileges');
SELECT pg_temp.assert_true(
  NOT has_column_privilege('public.profiles', 'role', 'UPDATE')
    AND NOT has_column_privilege('public.profiles', 'email', 'UPDATE')
    AND NOT has_table_privilege('public.profiles', 'TRUNCATE'),
  'profile privilege allowlist cannot mutate identity/role or truncate data');
SELECT pg_temp.assert_true(
  NOT has_table_privilege('public.learner_lessons', 'UPDATE')
    AND NOT has_table_privilege('public.learner_questions', 'INSERT')
    AND NOT has_table_privilege('public.admin_lessons', 'UPDATE'),
  'read views cannot be used as an owner-executed write bypass');
SELECT pg_temp.assert_true(
  NOT has_table_privilege('public.gamification_profiles', 'UPDATE')
    AND NOT has_table_privilege('public.learner_skill_scores', 'UPDATE')
    AND NOT has_table_privilege('public.lesson_progress', 'INSERT'),
  'derived state remains RPC-only even with legacy default privileges');

SELECT pg_temp.assert_true(
  to_regprocedure('public.submit_answer_attempt(uuid,text,text,text,text,integer,text)') IS NULL,
  'legacy unauthenticated answer overload is removed');
SELECT pg_temp.assert_true(
  NOT has_column_privilege('public.questions', 'correct_index', 'SELECT'), 'raw question answer key is inaccessible');
SELECT pg_temp.assert_true(
  (SELECT steps::TEXT !~ 'correct|secret' FROM public.learner_lessons WHERE id = 'lesson_p1_fixture'),
  'curated nested snake/camel answer keys are stripped');
SELECT pg_temp.assert_true(
  (SELECT steps::TEXT !~ 'correct' AND questions::TEXT !~ 'correct|secret'
   FROM public.learner_generated_lessons WHERE id = 'lesson_p1_generated'),
  'generated nested answer keys are stripped');
SELECT pg_temp.assert_true(
  (SELECT count(*) = 0 FROM public.admin_lessons), 'student cannot read admin lessons');

DO $$ BEGIN
  BEGIN
    PERFORM steps FROM public.lessons WHERE id = 'lesson_p1_fixture';
    RAISE EXCEPTION 'ASSERT: learner could read raw lesson JSON';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.answer_attempts (user_id, course_id, skill_id, lesson_id, question_id,
      selected_index, selected_answer, is_correct)
    VALUES (auth.uid(), 'course_math_01', 'skill_math_functions', 'reinf_node_p1_fixture', 'q_p1_reinforcement', 1, 'yes', true);
    RAISE EXCEPTION 'ASSERT: client forged answer evidence';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.award_xp(999999, 'invented-reward');
    RAISE EXCEPTION 'ASSERT: arbitrary XP accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.record_learning_activity((now() AT TIME ZONE 'Asia/Tashkent')::date - 1);
    RAISE EXCEPTION 'ASSERT: backdated streak accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
    PERFORM public.complete_reinforcement('reinf_node_p1_fixture', 'course_math_01', 'skill_math_functions', 'q_p1_reinforcement', 999999);
    RAISE EXCEPTION 'ASSERT: completion without verified answer accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.complete_lesson('lesson_p1_fixture', 'course_math_01');
    RAISE EXCEPTION 'ASSERT: lesson completed without a verified answer';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.lesson_progress (user_id, lesson_id, course_id, status)
      VALUES (auth.uid(), 'lesson_p1_fixture', 'course_math_01', 'completed');
    RAISE EXCEPTION 'ASSERT: client forged lesson progress';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END; $$;

DO $$
DECLARE
  payload JSONB := '[{"question_id":"q_p1_placement_a","selected_index":1,"is_correct":false},{"question_id":"q_p1_placement_b","selected_index":0,"is_correct":true}]';
  first_result JSONB;
  retry_result JSONB;
BEGIN
  BEGIN
    PERFORM public.save_placement_attempt('course_math_01',
      '[{"question_id":"q_p1_placement_a","selected_index":1},{"question_id":"q_p1_placement_a","selected_index":1}]', 'duplicate');
    RAISE EXCEPTION 'ASSERT: duplicate placement question accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
    PERFORM public.save_placement_attempt('course_math_01',
      '[{"question_id":"q_p1_placement_a","selected_index":null}]', 'null-index');
    RAISE EXCEPTION 'ASSERT: null placement answer accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;

  first_result := public.save_placement_attempt('course_math_01', payload, 'p1-placement');
  retry_result := public.save_placement_attempt('course_math_01', payload, 'p1-placement');
  PERFORM pg_temp.assert_true(first_result->>'score' = '50', 'placement ignores forged is_correct flags');
  PERFORM pg_temp.assert_true(first_result->>'attempt_id' = retry_result->>'attempt_id'
    AND (retry_result->>'already_processed')::BOOLEAN, 'placement retry returns the same row');
  PERFORM pg_temp.assert_true((SELECT score = 50 FROM public.learner_skill_scores
    WHERE user_id = auth.uid() AND skill_id = 'skill_math_functions'), 'atomic placement persists skill score');
  PERFORM pg_temp.assert_true((SELECT xp = 22 FROM public.gamification_profiles WHERE user_id = auth.uid()),
    'answer and placement XP awarded once');
  PERFORM pg_temp.assert_true((SELECT questions_answered = 2 AND correct_answers = 1 AND xp_earned = 22
    FROM public.daily_learning_stats WHERE user_id = auth.uid()
    AND activity_date = (now() AT TIME ZONE 'Asia/Tashkent')::date), 'daily stats not doubled');
  BEGIN
    PERFORM public.save_placement_attempt('course_math_01',
      '[{"question_id":"q_p1_placement_a","selected_index":0}]', 'p1-placement');
    RAISE EXCEPTION 'ASSERT: key reused with changed payload accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END; $$;

DO $$
DECLARE
  answer_result JSONB;
  first_result JSONB;
  retry_result JSONB;
  old_xp INT;
BEGIN
  answer_result := public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_functions',
    'lesson_p1_fixture', 'q_p1_curated', 1, 'yes', 'p1-curated-answer');
  PERFORM pg_temp.assert_true((answer_result->>'is_correct')::BOOLEAN, 'curated camelCase key resolves on server');
  PERFORM pg_temp.assert_true(NOT answer_result ? 'correct_index' AND NOT answer_result ? 'correct_option',
    'scoring result does not disclose an answer key');
  first_result := public.complete_lesson('lesson_p1_fixture', 'course_math_01');
  retry_result := public.complete_lesson('lesson_p1_fixture', 'course_math_01');
  PERFORM pg_temp.assert_true(first_result->>'xp_awarded' = '20' AND retry_result->>'xp_awarded' = '0',
    'atomic lesson completion awards XP once');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_functions',
    'reinf_node_p1_fixture', 'q_p1_reinforcement', 1, 'yes', 'p1-reinforcement-answer');
  first_result := public.complete_reinforcement('reinf_node_p1_fixture', 'course_math_01', 'skill_math_functions', 'q_p1_reinforcement', 999999);
  retry_result := public.complete_reinforcement('reinf_node_p1_fixture', 'course_math_01', 'skill_math_functions', 'q_p1_reinforcement', 999999);
  PERFORM pg_temp.assert_true(first_result->>'xp_awarded' = '30' AND retry_result->>'xp_awarded' = '0',
    'reinforcement XP fixed by server and not repeated');
  PERFORM pg_temp.assert_true(first_result->>'new_score' = retry_result->>'new_score'
    AND (retry_result->>'already_processed')::BOOLEAN, 'reinforcement retry returns persisted result');
  PERFORM pg_temp.assert_true((SELECT status = 'completed' FROM public.lesson_progress
    WHERE user_id = auth.uid() AND lesson_id = 'lesson_p1_fixture'), 'reinforcement persists linked lesson completion');

  SELECT xp INTO old_xp FROM public.gamification_profiles WHERE user_id = auth.uid();
  answer_result := public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_functions',
    'reinf_node_p1_fixture', 'q_p1_reinforcement', 1, 'yes', 'changed-idempotency-key');
  PERFORM pg_temp.assert_true(answer_result->>'xp_awarded' = '0'
    AND (SELECT xp = old_xp FROM public.gamification_profiles WHERE user_id = auth.uid()),
    'changing request keys cannot farm answer XP');
  PERFORM pg_temp.assert_true(answer_result->>'new_skill_score' = first_result->>'new_score',
    'retrying an unchanged answer preserves the persisted reinforcement score');
  BEGIN
    PERFORM public.complete_reinforcement('reinf_invented_node', 'course_math_01', 'skill_math_functions', 'q_p1_reinforcement');
    RAISE EXCEPTION 'ASSERT: invented reinforcement node accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
    PERFORM public.submit_answer_attempt(auth.uid(), 'course_eng_01', 'skill_eng_vocab',
      'lesson_p1_fixture', 'q_p1_curated', 1, 'yes', 'wrong-course');
    RAISE EXCEPTION 'ASSERT: cross-course question accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END; $$;

-- Parent can see their pending/active links but cannot forge consent.
RESET ROLE;
INSERT INTO public.parent_student_links (parent_user_id, link_code, status, expires_at) VALUES
  ('00000000-0000-0000-0000-000000000102', 'P1ONLY', 'pending', now() + interval '1 hour');
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true((SELECT count(*) = 1 FROM public.parent_student_links WHERE link_code = 'P1ONLY'),
  'parent retains own pending-link read access');
DO $$ BEGIN
  BEGIN
    INSERT INTO public.parent_student_links (parent_user_id, student_user_id, link_code, status)
      VALUES (auth.uid(), '00000000-0000-0000-0000-000000000101', 'FORGED', 'active');
    RAISE EXCEPTION 'ASSERT: parent forged child consent';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END; $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000103', true);
SELECT pg_temp.assert_true((SELECT count(*) = 0 FROM public.parent_student_links WHERE link_code = 'P1ONLY'),
  'unrelated student cannot enumerate pending parent codes');
SELECT pg_temp.assert_true((SELECT count(*) = 0 FROM public.answer_attempts), 'answer evidence remains user-isolated');
RESET ROLE;

-- CMS privileges must survive learner column/JSON restrictions.
SELECT set_config('bilimyol.authorized_role_change', 'true', true);
UPDATE public.profiles SET role = 'admin' WHERE id = '00000000-0000-0000-0000-000000000102';
SELECT set_config('bilimyol.authorized_role_change', 'false', true);
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000102', true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true((SELECT count(*) = 1 FROM public.admin_lessons WHERE id = 'lesson_p1_fixture'),
  'administrator can read raw lesson in gated CMS view');
SELECT pg_temp.assert_true((public.admin_save_question(
  '{"id":"q_p1_placement_a","course_id":"course_math_01","skill_id":"skill_math_functions","text":"Updated?","options":["no","yes"],"correct_index":1}'
)->>'saved')::BOOLEAN, 'administrator can upsert restricted question via RPC');
SELECT pg_temp.assert_true((public.admin_save_lesson(
  '{"id":"lesson_p1_fixture","course_id":"course_math_01","skill_id":"skill_math_functions","title":"Updated","steps":[]}'
)->>'saved')::BOOLEAN, 'administrator can upsert restricted lesson via RPC');
UPDATE public.lessons SET is_published = false WHERE id = 'lesson_p1_fixture';
SELECT pg_temp.assert_true((SELECT NOT is_published FROM public.admin_lessons WHERE id = 'lesson_p1_fixture'),
  'administrator can change publication status without raw JSON SELECT grants');
RESET ROLE;

-- Edge persistence needs actual table grants; BYPASSRLS alone is insufficient.
SET LOCAL ROLE service_role;
SELECT pg_temp.assert_true((SELECT correct_index = 1 FROM public.questions WHERE id = 'q_p1_placement_a'),
  'service role can resolve persisted answer keys');
INSERT INTO public.questions (id, course_id, skill_id, text, options, correct_index, difficulty, explanation)
VALUES ('q_p1_edge', 'course_math_01', 'skill_math_functions', 'Edge?', '["no","yes"]', 1, 'easy', '')
ON CONFLICT (id) DO UPDATE SET text = EXCLUDED.text;
UPDATE public.generated_lessons SET title = 'Edge persisted' WHERE id = 'lesson_p1_generated';
SELECT pg_temp.assert_true((SELECT title = 'Edge persisted' FROM public.generated_lessons WHERE id = 'lesson_p1_generated'),
  'service role retains generated-content write/read access without default grants');
RESET ROLE;
SET LOCAL ROLE anon;
SELECT pg_temp.assert_true(NOT has_table_privilege('public.profiles', 'SELECT')
  AND NOT has_table_privilege('public.learner_lessons', 'SELECT'),
  'anonymous clients cannot read learner/profile API relations');
RESET ROLE;
ROLLBACK;
