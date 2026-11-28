-- Disposable PostgreSQL 17.11 regression suite for Wave 1 · Batch W1-B4:
--   * FIX-P1-08: Math Pilot placement >= 80% unlocks foundation arithmetic (addition, multiplication -> expressions) without fabricating completed status
--   * FIX-P1-17: Day-8 review slip on Node 1 marks ONLY Node 1 'reinforcement' ('needs_review') while keeping mastered Nodes 2-3 'completed' (can_open_math_lesson = true), and consecutive multi-day retrieval passes expand review_interval (7d -> 14d -> 30d)
--   * FIX-P1-19: English placement ('placement_test') remains isolated from public.learner_skill_scores while persisting placement_*_by_course on public.learner_profiles
BEGIN;

CREATE FUNCTION pg_temp.assert_w1_b4(condition BOOLEAN, label TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'W1-B4 ASSERT FAILED: %', label;
  END IF;
  RAISE NOTICE '[PASS] %', label;
END;
$$;

INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('00000000-0000-0000-0000-00000000b401', 'w1b4-math-placed@example.invalid', '{}'),
  ('00000000-0000-0000-0000-00000000b402', 'w1b4-math-srs@example.invalid', '{}'),
  ('00000000-0000-0000-0000-00000000b403', 'w1b4-eng-isolation@example.invalid', '{}'),
  ('00000000-0000-0000-0000-00000000b404', 'w1b4-math-false-unlock@example.invalid', '{}');

-- ============================================================================
-- 1. FIX-P1-08: 4/4 (100%) Math Pilot placement unlocks foundation arithmetic
--    so strong learners can open lesson_math_expressions_intro directly,
--    while keeping completedCount = 0 and advanced chapters locked.
-- ============================================================================
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_state JSONB;
  v_nodes JSONB;
  v_qid TEXT;
  v_idx INT;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b401', true);

  v_state := public.advance_placement('course_math_01');
  FOR i IN 1..4 LOOP
    v_qid := v_state->'question'->>'id';
    v_idx := CASE v_qid
      WHEN 'q_math_pilot_place_add_01' THEN 1
      WHEN 'q_math_pilot_place_add_02' THEN 0
      WHEN 'q_math_pilot_place_mul_01' THEN 2
      WHEN 'q_math_pilot_place_mul_02' THEN 0
    END;
    v_state := public.advance_placement('course_math_01', (v_state->>'session_id')::UUID, v_qid, v_idx);
  END LOOP;

  v_nodes := public.get_math_progression();
  PERFORM pg_temp.assert_w1_b4(
    v_state->'result'->>'score' = '100'
    AND (SELECT count(*) FROM jsonb_array_elements(v_nodes) n WHERE n->>'status' = 'completed') = 0
    AND v_nodes->0->>'status' = 'available'
    AND v_nodes->1->>'status' = 'available'
    AND v_nodes->2->>'status' = 'available'
    AND v_nodes->3->>'status' = 'locked'
    AND public.can_open_math_lesson('lesson_math_expressions_intro') = true
    AND public.can_open_math_lesson('lesson_math_functions_03') = false
    AND (SELECT NOT is_locked AND jsonb_array_length(steps) > 2 FROM public.learner_lessons WHERE id = 'lesson_math_expressions_intro'),
    'FIX-P1-08: 4/4 Math placement unlocks addition, multiplication, and expressions_intro with 0 fabricated completions'
  );
END;
$$;
RESET ROLE;

-- ============================================================================
-- 2. FIX-P1-17 (Part A): Mastering Nodes 1-3 at Day 0, advancing +8d, and
--    slipping on 2 items on Node 1 marks ONLY Node 1 'reinforcement' while
--    keeping Nodes 2-3 'completed' (can_open_math_lesson = true) and Node 4 'available'.
-- ============================================================================
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_obj RECORD;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b402', true);

  FOR v_obj IN SELECT * FROM (VALUES
    ('lesson_math_starter', 'skill_math_addition', ARRAY[0,2,1,2,0]),
    ('lesson_math_foundation_02', 'skill_math_multiplication', ARRAY[1,0,1,2,1]),
    ('lesson_math_expressions_intro', 'skill_math_algebra', ARRAY[1,2,0,1,2])
  ) t(lesson_id, skill_id, correct_indices)
  LOOP
    FOR i IN 1..5 LOOP
      PERFORM public.submit_answer_attempt(
        auth.uid(),
        'course_math_01',
        v_obj.skill_id,
        v_obj.lesson_id,
        'q_pilot_' || v_obj.lesson_id || '_' || i,
        v_obj.correct_indices[i],
        '',
        'w1b4-pass1:' || v_obj.lesson_id || ':' || i
      );
    END LOOP;
    PERFORM public.complete_lesson(v_obj.lesson_id, 'course_math_01');
  END LOOP;
END;
$$;
RESET ROLE;

-- Advance all Day-0 attempts back by 8 days
UPDATE public.answer_attempts
SET created_at = now() - interval '8 days'
WHERE user_id = '00000000-0000-0000-0000-00000000b402';

SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_nodes JSONB;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b402', true);

  v_nodes := public.get_math_progression();
  PERFORM pg_temp.assert_w1_b4(
    v_nodes->0->>'review_due' = 'true'
    AND v_nodes->1->>'review_due' = 'true'
    AND v_nodes->2->>'review_due' = 'true',
    'FIX-P1-17: 1st retrieval pass becomes review_due after 8 days (> 7d initial interval)'
  );

  -- Learner slips on 2 items during Day-8 review of Node 1 (lesson_math_starter):
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter',
    'q_pilot_lesson_math_starter_4', 0, '', 'w1b4-slip-4'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter',
    'q_pilot_lesson_math_starter_5', 1, '', 'w1b4-slip-5'
  );

  v_nodes := public.get_math_progression();
  PERFORM pg_temp.assert_w1_b4(
    v_nodes->0->>'status' = 'reinforcement'
    AND v_nodes->0->>'mastery_state' = 'needs_review'
    AND v_nodes->1->>'status' = 'completed'
    AND v_nodes->1->>'mastery_state' = 'mastered'
    AND v_nodes->2->>'status' = 'completed'
    AND v_nodes->2->>'mastery_state' = 'mastered'
    AND v_nodes->3->>'status' = 'available'
    AND public.can_open_math_lesson('lesson_math_foundation_02') = true
    AND public.can_open_math_lesson('lesson_math_expressions_intro') = true
    AND public.can_open_math_lesson('lesson_math_equations_01') = true,
    'FIX-P1-17: Day-8 slip on Node 1 marks ONLY Node 1 reinforcement while Nodes 2-3 remain completed and openable'
  );

  -- Refresh Node 2 (lesson_math_foundation_02) retrieval items (_4 and _5) correctly on Day 8 -> 2nd pass expands interval to 14d!
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_multiplication', 'lesson_math_foundation_02',
    'q_pilot_lesson_math_foundation_02_4', 2, '', 'w1b4-mul-pass2-4'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_multiplication', 'lesson_math_foundation_02',
    'q_pilot_lesson_math_foundation_02_5', 1, '', 'w1b4-mul-pass2-5'
  );

  v_nodes := public.get_math_progression();
  PERFORM pg_temp.assert_w1_b4(
    v_nodes->1->>'review_due' = 'false',
    'FIX-P1-17: refreshing both retrieval items clears review_due immediately'
  );
END;
$$;
RESET ROLE;

-- Advance Node 2 attempts by +10 days (so Pass 1 is -18d and Pass 2 is -10d: > 7d, < 14d!)
UPDATE public.answer_attempts
SET created_at = created_at - interval '10 days'
WHERE user_id = '00000000-0000-0000-0000-00000000b402'
  AND lesson_id = 'lesson_math_foundation_02';

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b402', true);
SELECT pg_temp.assert_w1_b4(
  public.get_math_progression()->1->>'review_due' = 'false',
  'FIX-P1-17: 2nd consecutive retrieval pass expands interval to 14d (not due at +10d)'
);
RESET ROLE;

-- Advance Node 2 attempts by another +5 days (Pass 2 now at -15d >= 14d -> due!)
UPDATE public.answer_attempts
SET created_at = created_at - interval '5 days'
WHERE user_id = '00000000-0000-0000-0000-00000000b402'
  AND lesson_id = 'lesson_math_foundation_02';

SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b402', true);
  PERFORM pg_temp.assert_w1_b4(
    public.get_math_progression()->1->>'review_due' = 'true',
    'FIX-P1-17: 2nd retrieval pass becomes review_due after 15d (>= 14d)'
  );

  -- Complete 3rd retrieval pass -> expands interval to 30d!
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_multiplication', 'lesson_math_foundation_02',
    'q_pilot_lesson_math_foundation_02_4', 2, '', 'w1b4-mul-pass3-4'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_multiplication', 'lesson_math_foundation_02',
    'q_pilot_lesson_math_foundation_02_5', 1, '', 'w1b4-mul-pass3-5'
  );
END;
$$;
RESET ROLE;

-- Advance Node 2 attempts by +20 days (> 14d, < 30d -> still NOT due!)
UPDATE public.answer_attempts
SET created_at = created_at - interval '20 days'
WHERE user_id = '00000000-0000-0000-0000-00000000b402'
  AND lesson_id = 'lesson_math_foundation_02';

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b402', true);
SELECT pg_temp.assert_w1_b4(
  public.get_math_progression()->1->>'review_due' = 'false',
  'FIX-P1-17: 3rd consecutive retrieval pass expands interval to 30d (not due at +20d)'
);
RESET ROLE;

-- ============================================================================
-- 3. FIX-P1-19 (SQL): 0/8 English placement writes 0 lesson rows into
--    public.learner_skill_scores while persisting Pre-A1 on learner_profiles.
-- ============================================================================
DO $$
DECLARE
  v_state JSONB;
  v_session_id UUID;
  v_qid TEXT;
  v_wrong_idx INT;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b403', true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_state := public.advance_placement('course_eng_01');
  EXECUTE 'RESET ROLE';
  v_session_id := (v_state->>'session_id')::UUID;

  FOR i IN 1..8 LOOP
    v_qid := v_state->'question'->>'id';
    SELECT (correct_index + 1) % 4 INTO v_wrong_idx FROM public.questions WHERE id = v_qid;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_state := public.advance_placement('course_eng_01', v_session_id, v_qid, v_wrong_idx);
    EXECUTE 'RESET ROLE';
  END LOOP;

  PERFORM pg_temp.assert_w1_b4(
    (v_state->'result'->>'score')::INT = 0
    AND v_state->'result'->>'assessed_cefr' = 'Pre-A1'
    AND (SELECT count(*) FROM public.learner_skill_scores WHERE user_id = '00000000-0000-0000-0000-00000000b403' AND course_id = 'course_eng_01') = 0
    AND (SELECT placement_cefr_by_course->>'course_eng_01' FROM public.learner_profiles WHERE user_id = '00000000-0000-0000-0000-00000000b403') = 'Pre-A1',
    'FIX-P1-19: 0/8 English placement produces 0 polluted learner_skill_scores rows while persisting Pre-A1'
  );
END;
$$;

-- ============================================================================
-- 4. FIX-P1-17 (Edge Cases): Same-UTC-day repeated retrieval passes do NOT
--    inflate streak to 30d; a wrong retrieval answer resets interval back to 7d
--    without unlocking unmastered node_math_functions or re-locking mastered
--    node_math_multiplication; and disjoint < 4/5 guesses NEVER falsely unlock
--    downstream chapters via ever_mastered.
-- ============================================================================
-- Advance b402 Node 2 attempts by another +12d (total -32d >= 30d -> due)
UPDATE public.answer_attempts
SET created_at = created_at - interval '12 days'
WHERE user_id = '00000000-0000-0000-0000-00000000b402'
  AND lesson_id = 'lesson_math_foundation_02';

SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b402', true);
  PERFORM pg_temp.assert_w1_b4(
    public.get_math_progression()->1->>'review_due' = 'true',
    'FIX-P1-17: 30d interval becomes review_due after 32d'
  );

  -- Learner answers _4 WRONG first, then recovers _4 and _5 CORRECT twice on the SAME UTC day!
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_multiplication', 'lesson_math_foundation_02',
    'q_pilot_lesson_math_foundation_02_4', 0, '', 'w1b4-mul-wrong-reset'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_multiplication', 'lesson_math_foundation_02',
    'q_pilot_lesson_math_foundation_02_4', 2, '', 'w1b4-mul-recover-4a'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_multiplication', 'lesson_math_foundation_02',
    'q_pilot_lesson_math_foundation_02_4', 2, '', 'w1b4-mul-recover-4b'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_multiplication', 'lesson_math_foundation_02',
    'q_pilot_lesson_math_foundation_02_5', 1, '', 'w1b4-mul-recover-5a'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_math_01', 'skill_math_multiplication', 'lesson_math_foundation_02',
    'q_pilot_lesson_math_foundation_02_5', 1, '', 'w1b4-mul-recover-5b'
  );

  PERFORM pg_temp.assert_w1_b4(
    public.get_math_progression()->1->>'status' = 'completed'
    AND public.get_math_progression()->1->>'review_due' = 'false'
    AND public.get_math_progression()->4->>'status' = 'locked',
    'FIX-P1-17: recovery keeps Node 2 completed without unlocking unmastered Node 5 (functions)'
  );
END;
$$;
RESET ROLE;

-- Advance Node 2 attempts by +8 days (> 7d, < 14d): because _4 had a wrong attempt followed
-- by only 1 distinct UTC day of correct attempts, interval MUST have reset to 7d (due = true)!
UPDATE public.answer_attempts
SET created_at = created_at - interval '8 days'
WHERE user_id = '00000000-0000-0000-0000-00000000b402'
  AND lesson_id = 'lesson_math_foundation_02';

SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b402', true);
  PERFORM pg_temp.assert_w1_b4(
    public.get_math_progression()->1->>'review_due' = 'true'
    AND public.get_math_progression()->1->>'status' = 'completed',
    'FIX-P1-17: wrong retrieval attempt + same-UTC-day retries resets review interval to 7d (due at +8d)'
  );

  -- Disjoint wrong/right retries on b404 (Round 1: 1/5, Round 2: 2/5, Round 3: 1/5 — never >= 4/5 simultaneously)
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b404', true);
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter', 'q_pilot_lesson_math_starter_1', 0, '', 'w1b4-fu-r1-1');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter', 'q_pilot_lesson_math_starter_2', 0, '', 'w1b4-fu-r1-2');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter', 'q_pilot_lesson_math_starter_3', 0, '', 'w1b4-fu-r1-3');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter', 'q_pilot_lesson_math_starter_4', 0, '', 'w1b4-fu-r1-4');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter', 'q_pilot_lesson_math_starter_5', 1, '', 'w1b4-fu-r1-5');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter', 'q_pilot_lesson_math_starter_1', 1, '', 'w1b4-fu-r2-1');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter', 'q_pilot_lesson_math_starter_2', 2, '', 'w1b4-fu-r2-2');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter', 'q_pilot_lesson_math_starter_3', 1, '', 'w1b4-fu-r2-3');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter', 'q_pilot_lesson_math_starter_2', 0, '', 'w1b4-fu-r3-2');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter', 'q_pilot_lesson_math_starter_3', 0, '', 'w1b4-fu-r3-3');
  PERFORM public.submit_answer_attempt(auth.uid(), 'course_math_01', 'skill_math_addition', 'lesson_math_starter', 'q_pilot_lesson_math_starter_4', 2, '', 'w1b4-fu-r3-4');

  PERFORM pg_temp.assert_w1_b4(
    public.get_math_progression()->0->>'status' = 'reinforcement'
    AND public.get_math_progression()->0->>'correct' = '1'
    AND public.get_math_progression()->1->>'status' = 'locked'
    AND public.can_open_math_lesson('lesson_math_foundation_02') = false,
    'FIX-P1-17: disjoint retries never reaching >=4/5 simultaneously do NOT falsely unlock downstream chapters'
  );
END;
$$;
RESET ROLE;

ROLLBACK;
