-- Disposable/local PostgreSQL only, after all migrations. Every fixture rolls back.
-- Regression suite for Wave 0 · Batch W0-B1: FIX-P0-27, FIX-P0-28, FIX-P2-22.
BEGIN;

CREATE FUNCTION pg_temp.assert_w0b1(ok BOOLEAN, label TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF ok IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'ASSERT [W0-B1]: %', label;
  END IF;
END;
$$;

INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('00000000-0000-0000-0000-000000000701', 'w0b1-math-beginner@example.invalid', '{}'),
  ('00000000-0000-0000-0000-000000000702', 'w0b1-it-student@example.invalid', '{}'),
  ('00000000-0000-0000-0000-000000000703', 'w0b1-unknown-q@example.invalid', '{}'),
  ('00000000-0000-0000-0000-000000000704', 'w0b1-reverse-alias@example.invalid', '{}');

-- Unpublished, archived, multi-skill, and AI-generated fixtures for FIX-P0-27/28 checks.
INSERT INTO public.lessons (
  id, course_id, skill_id, title, summary, steps, reinforcement_exercise, is_published, is_archived
) VALUES
  (
    'lesson_w0b1_unpub_draft',
    'course_it',
    'skill_it_python',
    'Unpublished Draft',
    '',
    '[{"id":"s1","type":"interactive_question","interactiveQuestion":{"id":"q_w0b1_unpub_step","text":"Draft?","options":["A","B"],"correctIndex":1,"explanation":"TOP_SECRET_UNPUBLISHED_DRAFT_EXPLANATION"}}]'::jsonb,
    '{"id":"q_w0b1_unpub_reinf","text":"Draft R?","options":["A","B"],"correctIndex":0,"explanation":"TOP_SECRET_DRAFT_REINF"}'::jsonb,
    false,
    false
  ),
  (
    'lesson_w0b1_archived',
    'course_it',
    'skill_it_python',
    'Archived Lesson',
    '',
    '[{"id":"s1","type":"interactive_question","interactiveQuestion":{"id":"q_w0b1_archived_step","text":"Arch?","options":["A","B"],"correctIndex":0,"explanation":"TOP_SECRET_ARCHIVED_EXPLANATION"}}]'::jsonb,
    NULL,
    true,
    true
  ),
  (
    'lesson_w0b1_multiskill',
    'course_eng_01',
    'skill_eng_vocab',
    'Multi-skill Fixture',
    '',
    '[{"id":"s1","type":"interactive_question","interactiveQuestion":{"id":"q_w0b1_ms_gram_step","skillId":"skill_eng_grammar","text":"She ___ happy.","options":["is","are"],"correctIndex":0,"explanation":"Singular she uses is."}}]'::jsonb,
    '{"id":"q_w0b1_ms_reinf","skillId":"skill_eng_grammar","text":"They ___ happy.","options":["is","are"],"correctIndex":1,"explanation":"Plural they uses are."}'::jsonb,
    true,
    false
  );

INSERT INTO public.generated_lessons (
  id, course_id, skill_id, topic, title, summary, objective, steps, questions
) VALUES (
  'gl_w0b1_it_reinf',
  'course_it',
  'skill_it_python',
  'Variables',
  'AI Lesson Fixture',
  'Summary',
  'Objective',
  '[]'::jsonb,
  '[{"id":"q_gl_w0b1_1","text":"x = 2; x + 3 = ?","options":["4","5","6"],"correctIndex":1,"explanation":"2 + 3 = 5."}]'::jsonb
);

-- ============================================================================
-- 1. FIX-P2-22: Least-privilege SECURITY DEFINER surface (Cloud + Legacy DBs)
-- ============================================================================
SELECT pg_temp.assert_w0b1(
  NOT has_function_privilege('anon', 'public.is_admin()', 'execute'),
  'FIX-P2-22: anon cannot execute public.is_admin() even on legacy-grant DBs'
);
SELECT pg_temp.assert_w0b1(
  has_function_privilege('authenticated', 'public.is_admin()', 'execute')
    AND has_function_privilege('service_role', 'public.is_admin()', 'execute'),
  'FIX-P2-22: authenticated and service_role retain public.is_admin() for RLS evaluation'
);
SELECT pg_temp.assert_w0b1(
  NOT has_function_privilege('authenticated', 'public.award_xp(integer,text)', 'execute')
    AND NOT has_function_privilege('anon', 'public.award_xp(integer,text)', 'execute'),
  'FIX-P2-22: public.award_xp is revoked from client roles'
);
SELECT pg_temp.assert_w0b1(
  to_regprocedure('public.sync_profile(text,text,text)') IS NULL,
  'FIX-P2-22: legacy public.sync_profile is dropped'
);
SELECT pg_temp.assert_w0b1(
  NOT has_function_privilege('authenticated', 'public.promote_user_to_admin(text)', 'execute')
    AND NOT has_function_privilege('service_role', 'public.promote_user_to_admin(text)', 'execute')
    AND NOT has_function_privilege('anon', 'public.promote_user_to_admin(text)', 'execute'),
  'FIX-P2-22: public.promote_user_to_admin is restricted to database owner bootstrap'
);
SELECT pg_temp.assert_w0b1(
  NOT has_function_privilege('authenticated', 'public.evaluate_placement_answer(text,text,integer)', 'execute')
    AND NOT has_function_privilege('service_role', 'public.evaluate_placement_answer(text,text,integer)', 'execute'),
  'FIX-P2-22: retired public.evaluate_placement_answer is revoked from all API roles'
);
SELECT pg_temp.assert_w0b1(
  NOT has_function_privilege('authenticated', 'public.enforce_profile_role_protection()', 'execute')
    AND NOT has_function_privilege('service_role', 'public.enforce_profile_role_protection()', 'execute')
    AND NOT has_function_privilege('anon', 'public.enforce_profile_role_protection()', 'execute'),
  'FIX-P2-22: trigger helper public.enforce_profile_role_protection() is revoked from API roles'
);
SELECT pg_temp.assert_w0b1(
  NOT has_schema_privilege('authenticated', 'bilimyol_private', 'USAGE')
    AND NOT has_schema_privilege('anon', 'bilimyol_private', 'USAGE')
    AND NOT has_function_privilege('authenticated', 'bilimyol_private.award_xp(uuid,integer,text)', 'execute')
    AND NOT has_function_privilege('service_role', 'bilimyol_private.award_xp(uuid,integer,text)', 'execute')
    AND NOT has_function_privilege('authenticated', 'bilimyol_private.submit_answer_attempt(uuid,text,text,text,text,integer,text,text)', 'execute')
    AND NOT has_function_privilege('service_role', 'bilimyol_private.submit_answer_attempt(uuid,text,text,text,text,integer,text,text)', 'execute')
    AND NOT has_function_privilege('authenticated', 'bilimyol_private.resolve_reinforcement_target(text,text,text)', 'execute')
    AND NOT has_function_privilege('service_role', 'bilimyol_private.resolve_reinforcement_target(text,text,text)', 'execute'),
  'FIX-P2-22: bilimyol_private schema and internal helpers are inaccessible to API roles'
);

-- ============================================================================
-- 2. FIX-P0-27: Cross-lesson prerequisite binding, CMS draft block, & Math reinf_*
-- ============================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000701', true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_res JSONB;
  v_reinf_done JSONB;
BEGIN
  -- 2a. Day-1 beginner cannot spoof unlocked lesson_math_starter to grade locked Chapter 6 question.
  BEGIN
    PERFORM public.submit_answer_attempt(
      auth.uid(), 'course_math_01', 'skill_math_graphs',
      'lesson_math_starter', 'q_pilot_lesson_math_functions_03_1', 1, '', 'w0b1-cross-lesson-bypass'
    );
    RAISE EXCEPTION 'ASSERT [W0-B1]: cross-lesson locked Chapter 6 question succeeded via lesson_math_starter';
  EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value THEN NULL;
  END;

  PERFORM pg_temp.assert_w0b1(
    NOT EXISTS (
      SELECT 1 FROM public.learner_skill_scores
      WHERE user_id = auth.uid() AND skill_id = 'skill_math_graphs'
    ),
    'FIX-P0-27: blocked cross-lesson attempt creates zero skill_math_graphs rows'
  );

  -- 2b. Learner cannot probe unpublished or archived CMS draft explanations.
  BEGIN
    PERFORM public.submit_answer_attempt(
      auth.uid(), 'course_it', 'skill_it_python',
      'lesson_w0b1_unpub_draft', 'q_w0b1_unpub_step', 1, 'B', 'w0b1-unpub-direct'
    );
    RAISE EXCEPTION 'ASSERT [W0-B1]: unpublished draft lesson accepted';
  EXCEPTION WHEN invalid_parameter_value OR insufficient_privilege THEN NULL;
  END;

  BEGIN
    PERFORM public.submit_answer_attempt(
      auth.uid(), 'course_it', 'skill_it_python',
      'lesson_it_starter', 'q_w0b1_unpub_step', 1, 'B', 'w0b1-unpub-cross'
    );
    RAISE EXCEPTION 'ASSERT [W0-B1]: unpublished draft question accepted via published starter lesson';
  EXCEPTION WHEN invalid_parameter_value OR insufficient_privilege THEN NULL;
  END;

  BEGIN
    PERFORM public.submit_answer_attempt(
      auth.uid(), 'course_it', 'skill_it_python',
      'lesson_w0b1_archived', 'q_w0b1_archived_step', 0, 'A', 'w0b1-archived-direct'
    );
    RAISE EXCEPTION 'ASSERT [W0-B1]: archived lesson accepted';
  EXCEPTION WHEN invalid_parameter_value OR insufficient_privilege THEN NULL;
  END;

  -- 2c. Locked Math reinforcement node remains blocked with 42501.
  BEGIN
    PERFORM public.submit_answer_attempt(
      auth.uid(), 'course_math_01', 'skill_math_graphs',
      'reinf_node_math_graphs', 'q_live_math_functions_03_practice', 2, '(3, 0)', 'w0b1-locked-math-reinf'
    );
    RAISE EXCEPTION 'ASSERT [W0-B1]: locked Math reinforcement node accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- 2d. FIX-P0-28 (1st-mistake Math Pilot checkpoint answer oracle):
  --     1st wrong guess on q_pilot_lesson_math_starter_1 must withhold correctOption.
  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_addition',
    'lesson_math_starter', 'q_pilot_lesson_math_starter_1', 1, 'untrusted-client-text', 'w0b1-math-wrong-1'
  );
  PERFORM pg_temp.assert_w0b1(
    (v_res->>'is_correct')::BOOLEAN = false,
    'FIX-P0-28: 1st wrong checkpoint attempt graded false'
  );
  PERFORM pg_temp.assert_w0b1(
    public.get_mistake_feedback('course_math_01', 'skill_math_addition', 'q_pilot_lesson_math_starter_1')->>'correctOption' IS NULL,
    'FIX-P0-28: 1st mistake on active Math checkpoint withholds correctOption'
  );
  PERFORM pg_temp.assert_w0b1(
    public.get_mistake_feedback('course_math_01', 'skill_math_addition', 'q_pilot_lesson_math_starter_1')->>'selectedOption' = '1',
    'FIX-P0-28: 1st mistake still records authoritative selectedOption'
  );
  RESET ROLE;
  SET LOCAL ROLE service_role;
  PERFORM pg_temp.assert_w0b1(
    public.tutor_mistake_context(
      '00000000-0000-0000-0000-000000000701',
      'course_math_01',
      'skill_math_addition',
      'q_pilot_lesson_math_starter_1'
    )->>'correctOption' IS NULL
    AND public.tutor_mistake_context(
      '00000000-0000-0000-0000-000000000701',
      'course_math_01',
      'skill_math_addition',
      'q_pilot_lesson_math_starter_1'
    )->>'explanation' = 'Ishlangan misolni ko‘rib chiqing va qayta urinib ko‘ring.',
    'FIX-P0-28: 1st mistake tutor_mistake_context withholds correctOption and explanation from Yolchi AI'
  );
  RESET ROLE;
  SET LOCAL ROLE authenticated;

  -- After 2nd wrong attempt exhausts the retry, both RPCs reveal correctOption ('7').
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_addition',
    'lesson_math_starter', 'q_pilot_lesson_math_starter_1', 2, '12', 'w0b1-math-wrong-2'
  );
  PERFORM pg_temp.assert_w0b1(
    public.get_mistake_feedback('course_math_01', 'skill_math_addition', 'q_pilot_lesson_math_starter_1')->>'correctOption' = '7',
    'FIX-P0-28: exhausted 2nd wrong attempt reveals authoritative correctOption'
  );
  RESET ROLE;
  SET LOCAL ROLE service_role;
  PERFORM pg_temp.assert_w0b1(
    public.tutor_mistake_context(
      '00000000-0000-0000-0000-000000000701',
      'course_math_01',
      'skill_math_addition',
      'q_pilot_lesson_math_starter_1'
    )->>'correctOption' = '7',
    'FIX-P0-28: exhausted 2nd wrong attempt reveals correctOption to tutor_mistake_context'
  );
  RESET ROLE;
  SET LOCAL ROLE authenticated;

  -- 2e. Unlocked Math reinforcement (reinf_node_math_addition & reinf_lesson_lesson_math_starter)
  --     now grades cleanly instead of failing with 42501, and completes without 2-RPC self-lockout!
  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_addition',
    'reinf_node_math_addition', 'q_lesson_math_starter_practice', 0, '4', 'w0b1-unlocked-math-reinf'
  );
  PERFORM pg_temp.assert_w0b1(
    (v_res->>'is_correct')::BOOLEAN = true,
    'FIX-P0-27: unlocked Math reinforcement node grades cleanly'
  );
  v_reinf_done := public.complete_reinforcement(
    'reinf_node_math_addition', 'course_math_01', 'skill_math_addition', 'q_lesson_math_starter_practice', 30
  );
  PERFORM pg_temp.assert_w0b1(
    (v_reinf_done->>'xp_awarded')::INT = 30 AND (v_reinf_done->>'already_processed')::BOOLEAN = false,
    'FIX-P0-27/28: unlocked Math reinforcement completes cleanly without 2-RPC self-lockout'
  );

  -- Trying to double-dip the same lesson via reinf_lesson_lesson_math_starter is rejected!
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_addition',
    'reinf_lesson_lesson_math_starter', 'q_lesson_math_starter_practice', 0, '4', 'w0b1-math-reinf-alias-2'
  );
  BEGIN
    PERFORM public.complete_reinforcement(
      'reinf_lesson_lesson_math_starter', 'course_math_01', 'skill_math_addition', 'q_lesson_math_starter_practice', 30
    );
    RAISE EXCEPTION 'ASSERT [W0-B1]: second alias reinf_lesson_lesson_math_starter double-dipped XP/score';
  EXCEPTION WHEN invalid_parameter_value OR insufficient_privilege THEN NULL;
  END;
END;
$$;
RESET ROLE;

-- ============================================================================
-- 3. FIX-P0-28: Dual-prefix farming, starter-quiz rejection, & non-eternal floor
-- ============================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000702', true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_reinf JSONB;
  v_after_miss JSONB;
BEGIN
  -- Establish a < 70% weak score on skill_it_python (0% from 1 wrong lesson quiz).
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_it', 'skill_it_python',
    'lesson_it_python_01', 'q_live_it_python_01_quiz', 0, '123', 'w0b1-it-miss-1'
  );

  -- 3a. Legacy reinf_<course>_<skill> prefix is rejected.
  BEGIN
    PERFORM public.submit_answer_attempt(
      auth.uid(), 'course_it', 'skill_it_python',
      'reinf_course_it_skill_it_python', 'q_live_it_python_01_practice', 2, '"62"', 'w0b1-legacy-prefix'
    );
    RAISE EXCEPTION 'ASSERT [W0-B1]: legacy reinf_<course>_<skill> prefix accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;

  -- 3b. Starter/step quiz cannot be submitted as a reinforcement exercise.
  BEGIN
    PERFORM public.submit_answer_attempt(
      auth.uid(), 'course_it', 'skill_it_python',
      'reinf_node_it_python', 'q_live_it_python_01_quiz', 1, '15', 'w0b1-step-quiz-as-reinf'
    );
    RAISE EXCEPTION 'ASSERT [W0-B1]: step quiz accepted under reinf_node_it_python';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;

  -- 3c. Valid canonical reinforcement succeeds once (+30 XP, 0 -> 22; or max(50, 22) = 50).
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_it', 'skill_it_python',
    'reinf_node_it_python', 'q_live_it_python_01_practice', 2, '"62"', 'w0b1-valid-it-reinf'
  );
  v_reinf := public.complete_reinforcement(
    'reinf_node_it_python', 'course_it', 'skill_it_python', 'q_live_it_python_01_practice', 30
  );
  PERFORM pg_temp.assert_w0b1(
    (v_reinf->>'xp_awarded')::INT = 30 AND (v_reinf->>'old_score')::INT = 0,
    'FIX-P0-28: pre-attempt v_before is 0 and canonical reinforcement awards +30 XP once'
  );
END;
$$;
RESET ROLE;

SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_reinf_score INT;
  v_after_miss JSONB;
  v_high_reinf JSONB;
BEGIN
  SELECT score INTO v_reinf_score
  FROM public.learner_skill_scores
  WHERE user_id = auth.uid() AND course_id = 'course_it' AND skill_id = 'skill_it_python';

  -- Failing a subsequent newer lesson question must NOT stay frozen at after_score forever
  -- (verified within the exact same SQL transaction via monotonic clock_timestamp(), zero backdating!).
  v_after_miss := public.submit_answer_attempt(
    auth.uid(), 'course_it', 'skill_it_python',
    'lesson_it_starter', 'q_lesson_it_starter_quiz', 0, 'print', 'w0b1-newer-wrong-attempt'
  );
  PERFORM pg_temp.assert_w0b1(
    (v_after_miss->>'new_skill_score')::INT < v_reinf_score
      AND (public.recalculate_skill_scores('course_it')->'skill_it_python'->>'score')::INT = (v_after_miss->>'new_skill_score')::INT,
    'FIX-P0-28: subsequent wrong attempt supersedes stale reinforcement floor consistently'
  );

  -- Multi-skill step attribution & cross-skill reinforcement guard:
  -- q_w0b1_ms_gram_step has skillId=skill_eng_grammar on a skill_eng_vocab parent lesson.
  -- Trying to credit skill_eng_vocab must be rejected with 22023, while skill_eng_grammar succeeds.
  BEGIN
    PERFORM public.submit_answer_attempt(
      auth.uid(), 'course_eng_01', 'skill_eng_vocab',
      'lesson_w0b1_multiskill', 'q_w0b1_ms_gram_step', 0, 'is', 'w0b1-ms-wrong-skill'
    );
    RAISE EXCEPTION 'ASSERT [W0-B1]: multi-skill step credited parent lesson skill instead of item skillId';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_grammar',
    'lesson_w0b1_multiskill', 'q_w0b1_ms_gram_step', 0, 'is', 'w0b1-ms-gram-pass'
  );

  -- v_before >= required_score (70) must block reinforcement completion with 42501.
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_grammar',
    'reinf_lesson_lesson_w0b1_multiskill', 'q_w0b1_ms_reinf', 1, 'are', 'w0b1-high-score-reinf-sub'
  );
  BEGIN
    v_high_reinf := public.complete_reinforcement(
      'reinf_lesson_lesson_w0b1_multiskill', 'course_eng_01', 'skill_eng_grammar', 'q_w0b1_ms_reinf', 30
    );
    RAISE EXCEPTION 'ASSERT [W0-B1]: complete_reinforcement allowed already-mastered skill (>= required_score)';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- Non-math generated_lessons AI lesson supports reinf_lesson_<id> reinforcement cleanly.
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_it', 'skill_it_python',
    'reinf_lesson_gl_w0b1_it_reinf', 'q_gl_w0b1_1', 1, '5', 'w0b1-gl-reinf-sub'
  );
  PERFORM pg_temp.assert_w0b1(
    (public.complete_reinforcement(
      'reinf_lesson_gl_w0b1_it_reinf', 'course_it', 'skill_it_python', 'q_gl_w0b1_1', 30
    )->>'xp_awarded')::INT = 30,
    'FIX-P0-27: non-math generated_lessons supports reinf_lesson_<id> reinforcement'
  );
END;
$$;
RESET ROLE;

-- ============================================================================
-- 3b. Reverse-order reinf_lesson_* persists canonical reinf_node_* & blocks alias
-- ============================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000704', true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_first JSONB;
  v_retry JSONB;
BEGIN
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_it', 'skill_it_python',
    'lesson_it_python_01', 'q_live_it_python_01_quiz', 0, '123', 'w0b1-rev-miss'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_it', 'skill_it_python',
    'reinf_lesson_lesson_it_python_01', 'q_live_it_python_01_practice', 2, '"62"', 'w0b1-rev-lesson-reinf'
  );
  v_first := public.complete_reinforcement(
    'reinf_lesson_lesson_it_python_01', 'course_it', 'skill_it_python', 'q_live_it_python_01_practice', 30
  );
  PERFORM pg_temp.assert_w0b1(
    (v_first->>'xp_awarded')::INT = 30
      AND EXISTS (
        SELECT 1 FROM public.reinforcement_attempts ra
        WHERE ra.user_id = auth.uid() AND ra.reinforcement_node_id = 'reinf_node_it_python'
      ),
    'FIX-P0-28: reinf_lesson_* persists canonical reinf_node_* in reinforcement_attempts'
  );

  -- Exact same alias retry stays idempotent (xp_awarded = 0).
  v_retry := public.complete_reinforcement(
    'reinf_lesson_lesson_it_python_01', 'course_it', 'skill_it_python', 'q_live_it_python_01_practice', 30
  );
  PERFORM pg_temp.assert_w0b1(
    (v_retry->>'already_processed')::BOOLEAN = true AND (v_retry->>'xp_awarded')::INT = 0,
    'FIX-P0-28: retrying same reinf_lesson_* alias stays idempotent'
  );

  -- Trying to double-dip via canonical reinf_node_it_python is rejected with 42501.
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_it', 'skill_it_python',
    'reinf_node_it_python', 'q_live_it_python_01_practice', 2, '"62"', 'w0b1-rev-canon-dup'
  );
  BEGIN
    PERFORM public.complete_reinforcement(
      'reinf_node_it_python', 'course_it', 'skill_it_python', 'q_live_it_python_01_practice', 30
    );
    RAISE EXCEPTION 'ASSERT [W0-B1]: canonical alias double-dipped after reinf_lesson_*';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$$;
RESET ROLE;

-- ============================================================================
-- 4. FIX-P0-28: Unknown p_question_id rejected with 22023 and zero free streak
-- ============================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000703', true);
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  BEGIN
    PERFORM public.submit_answer_attempt(
      auth.uid(), 'course_it', 'skill_it_python',
      'lesson_it_starter', 'q_totally_nonexistent_id_999', 0, 'hacked', 'w0b1-unknown-qid'
    );
    RAISE EXCEPTION 'ASSERT [W0-B1]: unknown question_id was accepted instead of raising 22023';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;

  PERFORM pg_temp.assert_w0b1(
    NOT EXISTS (SELECT 1 FROM public.answer_attempts WHERE user_id = auth.uid())
      AND COALESCE((SELECT streak_days FROM public.gamification_profiles WHERE user_id = auth.uid()), 0) = 0,
    'FIX-P0-28: unknown question_id writes zero answer_attempts and grants zero streak_days'
  );
END;
$$;

RESET ROLE;
ROLLBACK;
