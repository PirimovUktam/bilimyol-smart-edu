-- Disposable PostgreSQL/Supabase only. The test accounts and their activity roll back.
BEGIN;

CREATE FUNCTION pg_temp.check_scenario(condition BOOLEAN, label TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %', label; END IF;
  RAISE NOTICE 'OK: %', label;
END;
$$;

INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('00000000-0000-0000-0000-000000000561', 'math-beginner@example.invalid', '{}'),
  ('00000000-0000-0000-0000-000000000562', 'math-returning@example.invalid', '{}'),
  ('00000000-0000-0000-0000-000000000563', 'math-placed@example.invalid', '{}');

INSERT INTO public.lesson_progress (user_id, lesson_id, course_id, status, progress_percent, completed_at)
VALUES ('00000000-0000-0000-0000-000000000562', 'lesson_math_starter', 'course_math_01', 'completed', 100, now() - interval '30 days');

INSERT INTO public.generated_lessons (id, course_id, skill_id, topic, level, difficulty, title, summary, objective, steps, questions)
VALUES ('lesson_test_math_draft', 'course_math_01', 'skill_math_graphs', 'Grafik', 'advanced', 'hard', 'AI draft', '', '', '[]', '[]');

SELECT pg_temp.check_scenario(NOT has_function_privilege('anon', 'public.get_math_progression()', 'execute'),
  'anonymous users cannot read the mastery roadmap');

SET LOCAL ROLE authenticated;
DO $$
DECLARE
  state JSONB;
  lesson JSONB;
  nodes JSONB;
  qid TEXT;
  idx INT;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000561', true);
  nodes := public.get_math_progression();
  PERFORM pg_temp.check_scenario(nodes->0->>'target_lesson_id' = 'lesson_math_starter'
    AND nodes->0->>'status' = 'available'
    AND (SELECT count(*) FROM jsonb_array_elements(nodes) n WHERE n->>'status' <> 'locked') = 1,
    'A: a fresh learner opens a single foundational objective');
  SELECT steps INTO lesson FROM public.learner_lessons WHERE id = 'lesson_math_starter';
  PERFORM pg_temp.check_scenario(lesson->0->>'type' = 'concept' AND lesson->1->>'type' = 'visual_example'
    AND lesson::TEXT !~ 'correctIndex|explanation'
    AND (SELECT bool_and(s->'interactiveQuestion'->>'difficulty' = 'easy')
      FROM jsonb_array_elements(lesson) s WHERE s ? 'interactiveQuestion')
    AND (SELECT is_locked AND steps = '[]'::jsonb FROM public.learner_lessons WHERE id = 'lesson_math_functions_03'),
    'A: foundational content is easy and advanced content is gated');
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000563', true);
  state := public.advance_placement('course_math_01');
  IF state->'question'->>'id' IS DISTINCT FROM 'q_math_pilot_place_add_01' THEN
    RAISE EXCEPTION 'Expected an arithmetic foundation question, received: %', state->'question'->>'text';
  END IF;
  FOR i IN 1..4 LOOP
    qid := state->'question'->>'id';
    idx := CASE qid WHEN 'q_math_pilot_place_add_01' THEN 1 WHEN 'q_math_pilot_place_add_02' THEN 0
      WHEN 'q_math_pilot_place_mul_01' THEN 2 WHEN 'q_math_pilot_place_mul_02' THEN 0 END;
    IF idx IS NULL OR state->'question' ? 'correct_index' THEN
      RAISE EXCEPTION 'Expected a safe foundation item, received %', qid;
    END IF;
    state := public.advance_placement('course_math_01', (state->>'session_id')::UUID, qid, idx);
  END LOOP;
  PERFORM pg_temp.check_scenario(state->>'total_questions' = '4' AND state->'result'->>'score' = '100'
    AND (SELECT count(*) FROM jsonb_array_elements(public.get_math_progression()) n WHERE n->>'status' = 'completed') = 0
    AND public.get_math_progression()->0->>'status' = 'available'
    AND public.get_math_progression()->1->>'status' = 'available'
    AND public.get_math_progression()->2->>'status' = 'available'
    AND public.get_math_progression()->3->>'status' = 'locked'
    AND (SELECT count(*) FROM public.learner_skill_scores WHERE user_id = auth.uid()
      AND course_id = 'course_math_01' AND score = 100 AND skill_id IN ('skill_math_addition', 'skill_math_multiplication')) = 2,
    'B: perfect placement unlocks foundation arithmetic without fabricating completed objectives or opening advanced gates');

  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000561', true);

  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter',
    'q_pilot_lesson_math_starter_1', 0, '', 'pilot-first');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter',
    'q_pilot_lesson_math_starter_1', 0, '', 'pilot-first');
  nodes := public.get_math_progression();
  PERFORM pg_temp.check_scenario(nodes->0->>'answered' = '1' AND nodes->0->>'mastery_state' = 'practicing'
    AND nodes->1->>'status' = 'locked', 'C: one correct answer and its retry remain one piece of evidence');
  BEGIN
    PERFORM public.complete_lesson('lesson_math_starter', 'course_math_01');
    RAISE EXCEPTION 'C: a single correct response must not complete the objective';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.complete_lesson('lesson_math_functions_03', 'course_math_01');
    RAISE EXCEPTION 'C: a locked objective must not complete';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter',
    'q_pilot_lesson_math_starter_2', 0, '', 'pilot-wrong-a');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter',
    'q_pilot_lesson_math_starter_3', 0, '', 'pilot-wrong-b');
  nodes := public.get_math_progression();
  PERFORM pg_temp.check_scenario(nodes->0->>'mastery_state' = 'needs_review' AND nodes->0->>'status' = 'reinforcement'
    AND nodes->1->>'status' = 'locked'
    AND (public.get_mistake_feedback('course_math_01', 'skill_math_addition', 'q_pilot_lesson_math_starter_2')->>'correctOption') = '5'
    AND EXISTS (SELECT 1 FROM jsonb_array_elements(lesson) s WHERE s->>'id' = 'lesson_math_starter_pilot_guided'),
    'D: mistakes recommend guided practice and provide verified feedback');
END;
$$;
RESET ROLE;

-- Emulate the earlier request timestamp inside this rollback-only transaction.
UPDATE public.answer_attempts SET created_at = now() - interval '10 minutes'
WHERE user_id = '00000000-0000-0000-0000-000000000561' AND idempotency_key = 'pilot-wrong-a';

SET LOCAL ROLE authenticated;
DO $$
DECLARE
  nodes JSONB := public.get_math_progression();
  award JSONB;
  objective RECORD;
BEGIN
  PERFORM pg_temp.check_scenario(NOT EXISTS (SELECT 1 FROM public.learner_generated_lessons WHERE id = 'lesson_test_math_draft')
    AND NOT public.can_open_math_lesson('lesson_test_math_draft') AND nodes = public.get_math_progression(),
    'G: an unreviewed draft stays outside the learner catalogue and cannot change mastery');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter',
    'q_pilot_lesson_math_starter_2', 2, '', 'pilot-reassessment');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter',
    'q_pilot_lesson_math_starter_4', 2, '', 'pilot-retrieval-a');
  PERFORM pg_temp.check_scenario(public.get_math_progression()->1->>'status' = 'locked',
    'E: evidence falls short before the fifth distinct assessment');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter',
    'q_pilot_lesson_math_starter_5', 0, '', 'pilot-retrieval-b');
  nodes := public.get_math_progression();
  PERFORM pg_temp.check_scenario(nodes->0->>'mastery_state' = 'mastered' AND nodes->0->>'correct' = '4'
    AND nodes->0->>'passed_checkpoints' = '2' AND nodes->1->>'status' = 'available'
    AND (SELECT count(*) FROM jsonb_array_elements(nodes) n WHERE n->>'status' = 'locked') = 5
    AND (SELECT NOT is_locked AND jsonb_array_length(steps) > 2 FROM public.learner_lessons WHERE id = 'lesson_math_foundation_02'),
    'E: four of five across two checkpoints unlocks only multiplication');
  award := public.complete_lesson('lesson_math_starter', 'course_math_01');
  PERFORM pg_temp.check_scenario(award->>'xp_awarded' = '20'
    AND (public.complete_lesson('lesson_math_starter', 'course_math_01')->>'xp_awarded') = '0'
    AND EXISTS (SELECT 1 FROM public.lesson_progress WHERE user_id = auth.uid() AND lesson_id = 'lesson_math_starter' AND status = 'completed'),
    'E: completion persists and grants XP once');

  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000562', true);
  nodes := public.get_math_progression();
  PERFORM pg_temp.check_scenario(nodes->0->>'mastery_state' = 'needs_review' AND nodes->0->>'answered' = '0'
    AND nodes->1->>'status' = 'locked'
    AND EXISTS (SELECT 1 FROM public.lesson_progress WHERE user_id = auth.uid() AND lesson_id = 'lesson_math_starter' AND status = 'completed'),
    'C/F: historical completion survives and evidence is isolated by learner');
  FOR objective IN SELECT * FROM (VALUES
    ('lesson_math_starter', 'skill_math_addition', ARRAY[0,2,1,2,0]),
    ('lesson_math_foundation_02', 'skill_math_multiplication', ARRAY[1,0,1,2,1]),
    ('lesson_math_expressions_intro', 'skill_math_algebra', ARRAY[1,2,0,1,2]),
    ('lesson_math_equations_01', 'skill_math_equations', ARRAY[0,1,2,0,1])
  ) objectives(lesson_id, skill_id, correct_indices)
  LOOP
    IF NOT public.can_open_math_lesson(objective.lesson_id) THEN
      RAISE EXCEPTION 'Sequentially eligible objective remained locked: %', objective.lesson_id;
    END IF;
    FOR i IN 1..5 LOOP
      PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', objective.skill_id, objective.lesson_id,
        'q_pilot_' || objective.lesson_id || '_' || i, objective.correct_indices[i], '', 'chain:' || objective.lesson_id || ':' || i);
    END LOOP;
  END LOOP;
  nodes := public.get_math_progression();
  PERFORM pg_temp.check_scenario(nodes->4->>'status' = 'available' AND nodes->5->>'status' = 'locked'
    AND nodes->6->>'is_optional' = 'true' AND nodes->6->>'mastery_state' = 'not_started',
    'E: foundation through equations opens functions without requiring the optional square challenge');
END;
$$;
RESET ROLE;

UPDATE public.answer_attempts SET created_at = created_at - interval '8 days'
WHERE user_id = '00000000-0000-0000-0000-000000000561' AND lesson_id = 'lesson_math_starter';

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000561', true);
SELECT pg_temp.check_scenario(public.get_math_progression()->0->>'review_due' = 'true'
  AND public.get_math_progression()->0->>'mastery_state' = 'mastered'
  AND public.get_math_progression()->1->>'status' = 'available',
  'F: retention review is advised without retracting a valid unlock');
SELECT public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter',
  'q_pilot_lesson_math_starter_4', 0, '', 'pilot-forgotten');
SELECT pg_temp.check_scenario(public.get_math_progression()->0->>'mastery_state' = 'needs_review'
  AND public.get_math_progression()->0->>'status' = 'reinforcement'
  AND public.get_math_progression()->1->>'status' = 'available'
  AND EXISTS (SELECT 1 FROM public.lesson_progress WHERE user_id = auth.uid() AND lesson_id = 'lesson_math_starter' AND status = 'completed'),
  'F: recent weak evidence recommends practice on the slipped node without re-locking downstream chapters');
RESET ROLE;

ROLLBACK;
