-- Run on a disposable database. Fixtures are rolled back.
BEGIN;
CREATE FUNCTION pg_temp.assert_condition(ok BOOLEAN, label TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %', label; END IF;
END;
$$;

INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('00000000-0000-0000-0000-000000000601', 'starter-one@example.invalid', '{}'),
  ('00000000-0000-0000-0000-000000000602', 'starter-two@example.invalid', '{}');

SELECT pg_temp.assert_condition(NOT has_function_privilege('anon', 'public.save_course_learning_plan(text,text,integer,text)', 'execute'),
  'anonymous users cannot save an onboarding plan');
SELECT pg_temp.assert_condition((
  SELECT count(*) FROM public.courses c JOIN public.lessons l ON l.id = c.starter_lesson_id
  WHERE c.id = l.course_id AND l.is_published AND NOT l.is_archived
) = 4, 'four courses have an accessible starter in their own curriculum');

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000601', true);
SET LOCAL ROLE authenticated;
SELECT public.save_course_learning_plan('course_math_01', 'mastery', 15, 'intermediate');
UPDATE public.learner_profiles SET selected_course_id = 'course_eng_01' WHERE user_id = auth.uid();
SELECT public.save_course_learning_plan('course_eng_01', 'mastery', 30, 'beginner');
SELECT pg_temp.assert_condition((
  SELECT course_levels = '{"course_math_01":"intermediate","course_eng_01":"beginner"}'::jsonb AND daily_minutes = 30
  FROM public.learner_profiles WHERE user_id = auth.uid()
), 'switching courses preserves both levels');
SELECT pg_temp.assert_condition((
  SELECT steps->0->>'type' = 'concept' AND steps->1->>'type' = 'audio_simulation'
    AND steps->2->>'type' = 'interactive_question' AND steps::TEXT NOT LIKE '%correctIndex%'
  FROM public.learner_lessons WHERE id = 'lesson_eng_starter'
), 'English starts with explanation and example before a sanitized exercise');
SELECT pg_temp.assert_condition(NOT EXISTS (SELECT 1 FROM public.placement_attempts WHERE user_id = auth.uid()),
  'saving a plan never starts or scores a diagnostic');

DO $$
BEGIN
  BEGIN
    PERFORM public.save_course_learning_plan('course_math_01', 'mastery', 15, 'beginner');
    RAISE EXCEPTION 'ASSERT: a stale course selection was accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
    PERFORM public.save_course_learning_plan('course_eng_01', 'mastery', 15, 'unrecognized');
    RAISE EXCEPTION 'ASSERT: an invalid level was accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END;
$$;
SELECT pg_temp.assert_condition((
  public.submit_answer_attempt(auth.uid(), 'course_eng_01', 'skill_eng_vocab', 'lesson_eng_starter',
    'q_lesson_eng_starter_quiz', 1, 'Hello')->>'is_correct'
)::BOOLEAN, 'the starter exercise is scored by the existing trusted lesson grader');
SELECT pg_temp.assert_condition((public.complete_lesson('lesson_eng_starter', 'course_eng_01')->>'completed')::BOOLEAN,
  'a starter lesson can be completed through the standard learner flow');
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000602', true);
SELECT pg_temp.assert_condition(NOT EXISTS (SELECT 1 FROM public.learner_profiles
  WHERE user_id = '00000000-0000-0000-0000-000000000601'), 'learner plans remain private');
RESET ROLE;
ROLLBACK;
