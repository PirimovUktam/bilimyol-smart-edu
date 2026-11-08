-- Run only on the disposable database. Fixture rows roll back.
BEGIN;
CREATE FUNCTION pg_temp.assert_condition(value boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF value IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %', label; END IF;
END;
$$;

INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('00000000-0000-0000-0000-000000000401', 'tutor-one@example.invalid', '{}'),
  ('00000000-0000-0000-0000-000000000402', 'tutor-two@example.invalid', '{}');

SELECT pg_temp.assert_condition(NOT has_function_privilege('anon', 'public.provision_missing_profiles()', 'execute'),
  'anonymous cannot backfill profiles');
SELECT pg_temp.assert_condition(NOT has_function_privilege('authenticated', 'public.consume_tutor_quota(uuid,boolean)', 'execute'),
  'learners cannot consume a quota for another account');

SET LOCAL ROLE service_role;
DO $$
BEGIN
  FOR i IN 1..5 LOOP
    PERFORM pg_temp.assert_condition(public.consume_tutor_quota('00000000-0000-0000-0000-000000000401', true),
      'lesson request below shared limit');
  END LOOP;
  PERFORM pg_temp.assert_condition(NOT public.consume_tutor_quota('00000000-0000-0000-0000-000000000401', true),
    'sixth lesson call denied');
  PERFORM pg_temp.assert_condition(public.consume_tutor_quota('00000000-0000-0000-0000-000000000401', false),
    'general tutor quota is separate');
END;
$$;
RESET ROLE;

INSERT INTO public.learning_sessions (id, user_id, course_id, started_at, last_heartbeat_at)
VALUES
  ('00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-000000000401', 'course_math_01', now() - interval '60 seconds', now() - interval '30 seconds'),
  ('00000000-0000-0000-0000-000000000412', '00000000-0000-0000-0000-000000000401', 'course_math_01', now() - interval '60 seconds', now() - interval '30 seconds');

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000401', true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_condition(
  (public.record_learning_activity()->>'streak_days')::INT = 0,
  'a new learner cannot create a streak by directly invoking the activity function');
SELECT pg_temp.assert_condition(
  public.get_mistake_feedback('course_math_01', 'skill_math_algebra', 'q_live_math_algebra_01_quiz') IS NULL,
  'a quiz has no public answer key before evaluation');
SELECT public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_algebra',
  'lesson_math_algebra_01', 'q_live_math_algebra_01_quiz', 0, 'untrusted text', 'tutor-fixture');
SELECT pg_temp.assert_condition(
  public.get_mistake_feedback('course_math_01', 'skill_math_algebra', 'q_live_math_algebra_01_quiz')->>'correctOption' = '8',
  'own verified mistake provides an authoritative answer');
SELECT pg_temp.assert_condition(
  public.get_mistake_feedback('course_math_01', 'skill_math_algebra', 'q_live_math_algebra_01_quiz')->>'selectedOption' = '4',
  'client submitted text does not control the explanation');
SELECT pg_temp.assert_condition(public.set_learning_reminders(false) = false, 'learner reminder setting persisted');
SELECT pg_temp.assert_condition(
  (public.record_session_heartbeat('00000000-0000-0000-0000-000000000411', 'course_math_01', 'lesson_math_algebra_01')->>'added_active_seconds')::int BETWEEN 30 AND 60,
  'heartbeat adds elapsed active time');
SELECT pg_temp.assert_condition(
  (public.record_session_heartbeat('00000000-0000-0000-0000-000000000412', 'course_math_01')->>'added_active_seconds')::int < 2,
  'second tab does not add overlapping time');
SELECT pg_temp.assert_condition(EXISTS (
  SELECT 1 FROM public.daily_learning_stats WHERE user_id=auth.uid()
    AND activity_date=(now() AT TIME ZONE 'Asia/Tashkent')::date AND active_seconds >= 30
), 'daily activity uses the Tashkent day');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000402', true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_condition(
  public.get_mistake_feedback('course_math_01', 'skill_math_algebra', 'q_live_math_algebra_01_quiz') IS NULL,
  'another learner cannot read the submitted answer');
SELECT pg_temp.assert_condition(
  NOT EXISTS (SELECT 1 FROM public.user_preferences WHERE user_id='00000000-0000-0000-0000-000000000401'),
  'another learner cannot read preferences');
DO $$
BEGIN
  BEGIN
    PERFORM public.record_session_heartbeat('00000000-0000-0000-0000-000000000411', 'course_math_01');
    RAISE EXCEPTION 'ASSERT: foreign session accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;
$$;
RESET ROLE;
ROLLBACK;
