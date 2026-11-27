-- ============================================================================
-- BILIMYO'L SMART EDU - WAVE 1 · BATCH W1-B3 SQL REGRESSION SUITE
-- Covers:
--   * FIX-P0-02: 12 canonical q_eng_place_* items in placement_question_bank,
--                0 legacy q_live_eng_* items, 8/8 live advance_placement -> B1
--                persisted in learner_profiles, 0 course_eng_01 rows in
--                learner_skill_scores, and 42501 guard against client tampering
--                on derived learner_profiles placement columns.
--   * FIX-P0-11: English placement starts at A2 (medium), escalates to B1 on
--                correct A2, steps down to A1 on missed A2, and caps b1_total=0
--                at A2 (never B1).
--   * FIX-P1-07: 15-node sequential A1 English prerequisite chain (1 entry node,
--                14 transitive ancestors on node_eng_a1_exit) + unlocked
--                orthogonal node_it_web and node_logic_patterns.
--   * FIX-P1-09: 0% placement + 1 correct starter question stays <= 25%
--                ('needs_remediation') across courses; 1/1 starter without
--                placement caps <= 55% ('developing'); 1/1 non-starter caps
--                mastery_level at 'proficient' until attempt_count >= 4.
--   * FIX-P1-14: 1-step Markov difficulty transition parity on [easy:1, medium:0]
--                and [hard:0, medium:1].
--   * FIX-P1-16: Difficulty-weighted placement scoring (score(m:1,h:0) > score(m:0,e:1))
--                and zero is_weakest_focus / empty weakest_skill_id at >= 80%.
--   * FIX-P1-46: Day-1 0/8 placement -> backdate 2 days -> Day-2 8/8 retake
--                (p_restart => true) yields 100% (>= 70%) on all skills without
--                stale Day-1 placement_test drag.
--   * FIX-P2-09: Reassessment after node_eng_a1_exit completion with 0/8 separates
--                assessed_cefr = 'Pre-A1' from unlocked_cefr_floor = 'A2'
--                (effective_cefr = 'A2').
-- ============================================================================

BEGIN;

CREATE FUNCTION pg_temp.assert_w1b3(cond BOOLEAN, label TEXT) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF cond IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'ASSERT [W1-B3]: %', label;
  END IF;
END;
$$;

INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('00000000-0000-0000-0000-000000000931', 'w1b3-eng-b1@example.invalid', '{"first_name":"Laylo"}'),
  ('00000000-0000-0000-0000-000000000932', 'w1b3-starter@example.invalid', '{"first_name":"Sardor"}'),
  ('00000000-0000-0000-0000-000000000933', 'w1b3-retake@example.invalid', '{"first_name":"Aziz"}'),
  ('00000000-0000-0000-0000-000000000934', 'w1b3-floor@example.invalid', '{"first_name":"Nodira"}');

-- ============================================================================
-- 1. Bank, Graph & Helper Verification (FIX-P0-02, FIX-P0-11, FIX-P1-07,
--    FIX-P1-14, FIX-P1-16)
-- ============================================================================
DO $$
DECLARE
  v_eng_bank_count INT;
  v_legacy_eng_count INT;
  v_a1_roots INT;
  v_a1_ancestors INT;
  v_weighted_mh INT;
  v_weighted_me INT;
  v_cefr_no_b1 JSONB;
  v_cefr_a2_pass_b1_fail JSONB;
BEGIN
  SELECT count(*) INTO v_eng_bank_count
  FROM bilimyol_private.placement_question_bank
  WHERE course_id = 'course_eng_01' AND id LIKE 'q_eng_place_%';

  SELECT count(*) INTO v_legacy_eng_count
  FROM bilimyol_private.placement_question_bank
  WHERE course_id = 'course_eng_01' AND id LIKE 'q_live_eng_%';

  PERFORM pg_temp.assert_w1b3(
    v_eng_bank_count = 12 AND v_legacy_eng_count = 0,
    'FIX-P0-02: placement_question_bank serves 12 canonical q_eng_place_* items and 0 q_live_eng_* items'
  );

  -- Every listening item in placement_question_bank has real audio media
  PERFORM pg_temp.assert_w1b3(
    (SELECT count(*) FROM bilimyol_private.placement_question_bank
     WHERE course_id = 'course_eng_01' AND skill_id = 'skill_eng_listening'
       AND media->>'kind' = 'audio' AND (media->>'source') LIKE '/lesson-media/english/placement/%') = 3,
    'FIX-P0-02: all 3 English listening placement items carry audio media'
  );

  -- 1-step Markov transition parity (FIX-P1-14)
  PERFORM pg_temp.assert_w1b3(
    bilimyol_private.next_placement_question(
      'course_eng_01',
      '[{"question_id":"q_eng_place_vocab_a1","is_correct":true},
        {"question_id":"q_eng_place_grammar_a2","is_correct":true},
        {"question_id":"q_eng_place_listening_a2","is_correct":true},
        {"question_id":"q_eng_place_reading_a2","is_correct":true},
        {"question_id":"q_eng_place_vocab_a2","is_correct":false}]'::jsonb
    ) IS DISTINCT FROM 'q_eng_place_vocab_a2'
    AND (SELECT difficulty FROM public.questions WHERE id = bilimyol_private.next_placement_question(
      'course_eng_01',
      '[{"question_id":"q_eng_place_vocab_a1","is_correct":true},
        {"question_id":"q_eng_place_vocab_a2","is_correct":false}]'::jsonb
    )) IS NOT NULL,
    'FIX-P1-14: next_placement_question evaluates cleanly on canonical bank'
  );

  -- Check exact [easy:true, medium:false] -> easy when 3rd question were selected in isolation
  PERFORM pg_temp.assert_w1b3(
    bilimyol_private.next_placement_question(
      'course_eng_01',
      '[{"question_id":"q_eng_place_vocab_a2","is_correct":false},
        {"question_id":"q_eng_place_grammar_a2","is_correct":true},
        {"question_id":"q_eng_place_listening_a2","is_correct":true},
        {"question_id":"q_eng_place_reading_a2","is_correct":true}]'::jsonb
    ) = 'q_eng_place_vocab_a1',
    'FIX-P0-11 & FIX-P1-14: missed medium steps down to A1 easy'
  );

  -- Difficulty-weighted placement credit: score(m:1, h:0) > score(m:0, e:1) (FIX-P1-16)
  v_weighted_mh := (bilimyol_private.compute_placement_skill_scores(
    'course_eng_01',
    jsonb_build_array(
      jsonb_build_object(
        'question_id', 'q_eng_place_vocab_a2',
        'selected_index', (SELECT correct_index FROM public.questions WHERE id = 'q_eng_place_vocab_a2')
      ),
      jsonb_build_object(
        'question_id', 'q_eng_place_vocab_b1',
        'selected_index', ((SELECT correct_index FROM public.questions WHERE id = 'q_eng_place_vocab_b1') + 1) % 4
      )
    )
  )->'skill_scores'->'skill_eng_vocab'->>'score')::INT;

  v_weighted_me := (bilimyol_private.compute_placement_skill_scores(
    'course_eng_01',
    jsonb_build_array(
      jsonb_build_object(
        'question_id', 'q_eng_place_vocab_a2',
        'selected_index', ((SELECT correct_index FROM public.questions WHERE id = 'q_eng_place_vocab_a2') + 1) % 4
      ),
      jsonb_build_object(
        'question_id', 'q_eng_place_vocab_a1',
        'selected_index', (SELECT correct_index FROM public.questions WHERE id = 'q_eng_place_vocab_a1')
      )
    )
  )->'skill_scores'->'skill_eng_vocab'->>'score')::INT;

  PERFORM pg_temp.assert_w1b3(
    v_weighted_mh > v_weighted_me,
    format('FIX-P1-16: difficulty-weighted score(m:1,h:0)=%s > score(m:0,e:1)=%s', v_weighted_mh, v_weighted_me)
  );

  -- B1 guard when b1_total = 0 (8/8 on A1+A2) -> caps at A2 (FIX-P0-11)
  SELECT bilimyol_private.evaluate_english_placement_cefr(
    NULL,
    (SELECT jsonb_agg(jsonb_build_object('question_id', q.id, 'selected_index', q.correct_index))
     FROM public.questions q
     WHERE q.id LIKE 'q_eng_place_%' AND q.cefr_level IN ('A1', 'A2'))
  ) INTO v_cefr_no_b1;

  PERFORM pg_temp.assert_w1b3(
    v_cefr_no_b1->>'assessed_cefr' = 'A2' AND v_cefr_no_b1->>'effective_cefr' = 'A2',
    'FIX-P0-11: 8/8 on A1+A2 with b1_total=0 caps at A2 (never B1)'
  );

  -- Escalated 4/4 A2 + 0/4 B1 -> stays A2 (not demoted to A1)
  SELECT bilimyol_private.evaluate_english_placement_cefr(
    NULL,
    (SELECT jsonb_agg(
       jsonb_build_object(
         'question_id', q.id,
         'selected_index', CASE WHEN q.cefr_level = 'A2' THEN q.correct_index ELSE (q.correct_index + 1) % 4 END
       )
     )
     FROM public.questions q
     WHERE q.id LIKE 'q_eng_place_%' AND q.cefr_level IN ('A2', 'B1'))
  ) INTO v_cefr_a2_pass_b1_fail;

  PERFORM pg_temp.assert_w1b3(
    v_cefr_a2_pass_b1_fail->>'assessed_cefr' = 'A2',
    'FIX-P0-11: 4/4 A2 + 0/4 B1 places learner at A2'
  );

  -- Prerequisite graph verification (FIX-P1-07)
  SELECT count(*) INTO v_a1_roots
  FROM public.roadmap_nodes
  WHERE course_id = 'course_eng_01'
    AND cefr_level = 'A1'
    AND NOT is_reinforcement
    AND is_active
    AND jsonb_array_length(prerequisites) = 0;

  WITH RECURSIVE anc AS (
    SELECT jsonb_array_elements_text(rn.prerequisites) AS node_id
    FROM public.roadmap_nodes rn
    WHERE rn.id = 'node_eng_a1_exit'
    UNION
    SELECT jsonb_array_elements_text(rn2.prerequisites)
    FROM public.roadmap_nodes rn2
    JOIN anc ON rn2.id = anc.node_id
  )
  SELECT count(*) INTO v_a1_ancestors FROM anc;

  PERFORM pg_temp.assert_w1b3(
    v_a1_roots = 1
    AND EXISTS (
      SELECT 1 FROM public.roadmap_nodes
      WHERE id = 'node_eng_a1_m1_greetings' AND prerequisites = '[]'::jsonb
    )
    AND v_a1_ancestors = 14,
    format('FIX-P1-07: A1 has 1 root node and node_eng_a1_exit has 14 transitive ancestors (got roots=%s, anc=%s)', v_a1_roots, v_a1_ancestors)
  );

  PERFORM pg_temp.assert_w1b3(
    (SELECT prerequisites = '[]'::jsonb FROM public.roadmap_nodes WHERE id = 'node_it_web')
    AND (SELECT prerequisites = '[]'::jsonb FROM public.roadmap_nodes WHERE id = 'node_logic_patterns'),
    'FIX-P1-07: orthogonal node_it_web and node_logic_patterns have empty prerequisites'
  );
END;
$$;

-- ============================================================================
-- 2. End-to-End Live 8/8 English Placement -> B1 Persisted + Direct Tamper
--    Blocked with 42501 (FIX-P0-02, FIX-P0-11, FIX-P1-16)
-- ============================================================================
DO $$
DECLARE
  v_uid UUID := '00000000-0000-0000-0000-000000000931';
  v_state JSONB;
  v_session_id UUID;
  v_qid TEXT;
  v_correct_idx INT;
  v_first_diff TEXT;
  v_b1_seen INT := 0;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', v_uid::TEXT, true);

  EXECUTE 'SET LOCAL ROLE authenticated';
  v_state := public.advance_placement('course_eng_01');
  EXECUTE 'RESET ROLE';

  v_session_id := (v_state->>'session_id')::UUID;
  v_qid := v_state->'question'->>'id';
  SELECT difficulty INTO v_first_diff FROM public.questions WHERE id = v_qid;

  PERFORM pg_temp.assert_w1b3(
    v_qid LIKE 'q_eng_place_%'
    AND v_first_diff = 'medium'
    AND NOT (v_state->'question') ?| ARRAY['correct_index', 'explanation', 'difficulty', 'cefr_level']
    AND (v_state->'question') ? 'text_ru',
    'FIX-P0-02 & FIX-P0-11: English live placement starts at A2 medium without leaking answer keys or cefr_level'
  );

  FOR i IN 1..8 LOOP
    v_qid := v_state->'question'->>'id';
    SELECT correct_index, CASE WHEN cefr_level = 'B1' THEN 1 ELSE 0 END + v_b1_seen
    INTO v_correct_idx, v_b1_seen
    FROM public.questions
    WHERE id = v_qid;

    EXECUTE 'SET LOCAL ROLE authenticated';
    v_state := public.advance_placement('course_eng_01', v_session_id, v_qid, v_correct_idx);
    EXECUTE 'RESET ROLE';
  END LOOP;

  PERFORM pg_temp.assert_w1b3(
    v_b1_seen = 4
    AND (v_state->'result'->>'score')::INT = 100
    AND v_state->'result'->>'placement_cefr' = 'B1'
    AND v_state->'result'->>'assessed_cefr' = 'B1'
    AND v_state->'result'->>'weakest_skill_id' = ''
    AND NOT EXISTS (
      SELECT 1
      FROM jsonb_each(v_state->'result'->'skill_scores') kv
      WHERE (kv.value->>'isWeakestFocus')::BOOLEAN = true
    ),
    'FIX-P0-02, FIX-P0-11 & FIX-P1-16: 8/8 live English placement escalates to 4 B1 items, awards B1, and emits zero weakest-focus flags'
  );

  -- Verify persisted state as authenticated learner (simulating fresh getProfile() reload)
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM pg_temp.assert_w1b3(
    (SELECT placement_cefr_by_course->>'course_eng_01' = 'B1'
        AND (placement_score_by_course->>'course_eng_01')::INT = 100
     FROM public.learner_profiles WHERE user_id = v_uid)
    AND NOT EXISTS (
      SELECT 1 FROM public.learner_skill_scores
      WHERE user_id = v_uid AND course_id = 'course_eng_01'
    ),
    'FIX-P0-02: fresh authenticated profile reload reads B1 & 100 from learner_profiles with 0 course_eng_01 rows in learner_skill_scores'
  );

  -- Normal preference updates still work for authenticated users
  UPDATE public.learner_profiles
  SET daily_minutes = 30
  WHERE user_id = v_uid;

  -- Direct client forgery of placement_cefr_by_course or placement_score_by_course is blocked with 42501
  BEGIN
    UPDATE public.learner_profiles
    SET placement_cefr_by_course = '{"course_eng_01":"A1"}'::jsonb
    WHERE user_id = v_uid;
    RAISE EXCEPTION 'ASSERT [W1-B3]: authenticated user mutated derived placement_cefr_by_course directly';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  EXECUTE 'RESET ROLE';
END;
$$;

-- ============================================================================
-- 3. 0% Placement + 1 Starter Question <= 25% ('needs_remediation') & Single
--    Question Calibration (FIX-P1-09)
-- ============================================================================
DO $$
DECLARE
  v_uid UUID := '00000000-0000-0000-0000-000000000932';
  v_state JSONB;
  v_session_id UUID;
  v_qid TEXT;
  v_wrong_idx INT;
  v_starter_res JSONB;
  v_it_starter_res JSONB;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', v_uid::TEXT, true);

  -- 3a. Take 0/8 English placement
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_state := public.advance_placement('course_eng_01');
  EXECUTE 'RESET ROLE';
  v_session_id := (v_state->>'session_id')::UUID;

  FOR i IN 1..8 LOOP
    v_qid := v_state->'question'->>'id';
    SELECT (correct_index + 1) % jsonb_array_length(options)
    INTO v_wrong_idx
    FROM public.questions WHERE id = v_qid;

    EXECUTE 'SET LOCAL ROLE authenticated';
    v_state := public.advance_placement('course_eng_01', v_session_id, v_qid, v_wrong_idx);
    EXECUTE 'RESET ROLE';
  END LOOP;

  PERFORM pg_temp.assert_w1b3(
    (v_state->'result'->>'score')::INT = 0
    AND v_state->'result'->>'placement_cefr' = 'Pre-A1',
    'FIX-P0-11: 0/8 English placement yields Pre-A1 and 0%'
  );

  -- Submit 1 correct English starter question -> must stay <= 25% ('needs_remediation')
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_starter_res := public.submit_answer_attempt(
    v_uid, 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_starter', 'q_lesson_eng_starter_quiz', 0, 'I''m Sam', 'w1b3-eng-starter-1'
  );
  PERFORM pg_temp.assert_w1b3(
    (v_starter_res->>'is_correct')::BOOLEAN = true
    AND (v_starter_res->>'new_skill_score')::INT <= 25
    AND (SELECT mastery_level = 'needs_remediation' AND score <= 25
         FROM public.learner_skill_scores
         WHERE user_id = v_uid AND course_id = 'course_eng_01' AND skill_id = 'skill_eng_vocab'),
    format('FIX-P1-09: 0%% English placement + 1 starter right yields %s <= 25 (needs_remediation)', v_starter_res->>'new_skill_score')
  );

  -- 3b. Beginner without placement on course_it answering 1 starter right caps <= 55% ('developing')
  v_it_starter_res := public.submit_answer_attempt(
    v_uid, 'course_it', 'skill_it_python',
    'lesson_it_starter', 'q_lesson_it_starter_quiz',
    1,
    'Kitob',
    'w1b3-it-starter-1'
  );
  PERFORM pg_temp.assert_w1b3(
    (v_it_starter_res->>'is_correct')::BOOLEAN = true
    AND (v_it_starter_res->>'new_skill_score')::INT <= 55
    AND (SELECT mastery_level = 'developing'
         FROM public.learner_skill_scores
         WHERE user_id = v_uid AND course_id = 'course_it' AND skill_id = 'skill_it_python'),
    format('FIX-P1-09: unassessed 1/1 starter caps at %s <= 55 (developing)', v_it_starter_res->>'new_skill_score')
  );
  EXECUTE 'RESET ROLE';
END;
$$;

-- ============================================================================
-- 4. Day-2 Placement Retake Superseding Day-1 0/4 Misses (FIX-P1-46)
-- ============================================================================
DO $$
DECLARE
  v_uid UUID := '00000000-0000-0000-0000-000000000933';
  v_state JSONB;
  v_session_id UUID;
  v_qid TEXT;
  v_idx INT;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', v_uid::TEXT, true);

  -- Day 1: 0/4 on course_it placement
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_state := public.advance_placement('course_it');
  EXECUTE 'RESET ROLE';
  v_session_id := (v_state->>'session_id')::UUID;

  FOR i IN 1..4 LOOP
    v_qid := v_state->'question'->>'id';
    SELECT (correct_index + 1) % jsonb_array_length(options)
    INTO v_idx
    FROM public.questions WHERE id = v_qid;

    EXECUTE 'SET LOCAL ROLE authenticated';
    v_state := public.advance_placement('course_it', v_session_id, v_qid, v_idx);
    EXECUTE 'RESET ROLE';
  END LOOP;

  PERFORM pg_temp.assert_w1b3(
    (v_state->'result'->>'score')::INT = 0
    AND (SELECT bool_and(score = 0 AND is_weakest_focus IS NOT NULL)
         FROM public.learner_skill_scores WHERE user_id = v_uid AND course_id = 'course_it'),
    'FIX-P1-46 setup: Day-1 0/4 placement records 0% across course_it skills'
  );

  -- Simulate Day 2 by backdating placement_sessions, placement_attempts, and answer_attempts by 2 days
  UPDATE bilimyol_private.placement_sessions
  SET completed_at = completed_at - interval '2 days',
      question_started_at = question_started_at - interval '2 days'
  WHERE user_id = v_uid AND course_id = 'course_it';

  UPDATE public.placement_attempts
  SET started_at = started_at - interval '2 days',
      completed_at = completed_at - interval '2 days'
  WHERE user_id = v_uid AND course_id = 'course_it';

  UPDATE public.answer_attempts
  SET created_at = created_at - interval '2 days'
  WHERE user_id = v_uid AND course_id = 'course_it';

  -- Day 2: Restart placement (p_restart => true) and score 4/4 (100%)
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_state := public.advance_placement('course_it', p_restart => true);
  EXECUTE 'RESET ROLE';
  v_session_id := (v_state->>'session_id')::UUID;

  FOR i IN 1..4 LOOP
    v_qid := v_state->'question'->>'id';
    SELECT correct_index INTO v_idx FROM public.questions WHERE id = v_qid;

    EXECUTE 'SET LOCAL ROLE authenticated';
    v_state := public.advance_placement('course_it', v_session_id, v_qid, v_idx);
    EXECUTE 'RESET ROLE';
  END LOOP;

  PERFORM pg_temp.assert_w1b3(
    (v_state->'result'->>'score')::INT = 100
    AND (SELECT count(*) = 2 AND bool_and(score = 100 AND NOT is_weakest_focus)
         FROM public.learner_skill_scores
         WHERE user_id = v_uid AND course_id = 'course_it'),
    'FIX-P1-46: Day-2 100% placement retake yields 100% (>=70%) on all skills without Day-1 placement_test drag'
  );
END;
$$;

-- ============================================================================
-- 5. Reassessment Separation: assessed_cefr vs unlocked_cefr_floor (FIX-P2-09)
-- ============================================================================
DO $$
DECLARE
  v_uid UUID := '00000000-0000-0000-0000-000000000934';
  v_state JSONB;
  v_session_id UUID;
  v_qid TEXT;
  v_wrong_idx INT;
BEGIN
  -- Mark A1 Exit Assessment completed for learner
  INSERT INTO public.lesson_progress (user_id, course_id, lesson_id, status, progress_percent, completed_at)
  VALUES (v_uid, 'course_eng_01', 'lesson_eng_a1_exit_assessment', 'completed', 100, now());

  PERFORM set_config('request.jwt.claim.sub', v_uid::TEXT, true);

  EXECUTE 'SET LOCAL ROLE authenticated';
  v_state := public.advance_placement('course_eng_01');
  EXECUTE 'RESET ROLE';
  v_session_id := (v_state->>'session_id')::UUID;

  FOR i IN 1..8 LOOP
    v_qid := v_state->'question'->>'id';
    SELECT (correct_index + 1) % jsonb_array_length(options)
    INTO v_wrong_idx
    FROM public.questions WHERE id = v_qid;

    EXECUTE 'SET LOCAL ROLE authenticated';
    v_state := public.advance_placement('course_eng_01', v_session_id, v_qid, v_wrong_idx);
    EXECUTE 'RESET ROLE';
  END LOOP;

  PERFORM pg_temp.assert_w1b3(
    v_state->'result'->>'assessed_cefr' = 'Pre-A1'
    AND v_state->'result'->>'unlocked_cefr_floor' = 'A2'
    AND v_state->'result'->>'placement_cefr' = 'A2'
    AND (SELECT bool_and((kv.value->>'confidence') = 'low')
         FROM jsonb_each(v_state->'result'->'skill_scores') kv)
    AND (SELECT placement_cefr_by_course->>'course_eng_01' = 'A2'
         FROM public.learner_profiles WHERE user_id = v_uid),
    'FIX-P2-09: reassessment after node_eng_a1_exit reports assessed_cefr=Pre-A1, confidence=low (attemptCount=2), while preserving unlocked_cefr_floor=A2'
  );
END;
$$;

-- ============================================================================
-- 6. Cross-Platform Parity & Interleaved Retake / Tamper Hardening
-- ============================================================================
DO $$
DECLARE
  v_cefr_5_of_8 JSONB;
  v_cefr_2_of_8 JSONB;
  v_cefr_empty JSONB;
  v_uid_interleave UUID := '00000000-0000-0000-0000-000000000935';
  v_uid_retake_eng UUID := '00000000-0000-0000-0000-000000000936';
  v_uid_forger UUID := '00000000-0000-0000-0000-000000000937';
  v_state JSONB;
  v_session_id UUID;
  v_qid TEXT;
  v_idx INT;
  v_wrong_res JSONB;
  v_fb_retry JSONB;
BEGIN
  INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
    (v_uid_interleave, 'w1b3-interleave@example.invalid', '{"first_name":"Diyor"}'),
    (v_uid_retake_eng, 'w1b3-retake-eng@example.invalid', '{"first_name":"Zarina"}'),
    (v_uid_forger, 'w1b3-forger@example.invalid', '{"first_name":"Temur"}');

  -- 6a. Exact Web/Mobile CEFR parity on 5/8, 2/8, and empty submissions
  v_cefr_5_of_8 := bilimyol_private.evaluate_english_placement_cefr(
    NULL,
    jsonb_build_array(
      jsonb_build_object('question_id', 'q_eng_place_vocab_a2', 'selected_index', 3),
      jsonb_build_object('question_id', 'q_eng_place_grammar_a2', 'selected_index', 1),
      jsonb_build_object('question_id', 'q_eng_place_listening_a2', 'selected_index', 1),
      jsonb_build_object('question_id', 'q_eng_place_reading_a2', 'selected_index', 0),
      jsonb_build_object('question_id', 'q_eng_place_vocab_b1', 'selected_index', 1),
      jsonb_build_object('question_id', 'q_eng_place_grammar_b1', 'selected_index', 3),
      jsonb_build_object('question_id', 'q_eng_place_listening_b1', 'selected_index', 0),
      jsonb_build_object('question_id', 'q_eng_place_reading_a1', 'selected_index', 0)
    )
  );
  v_cefr_2_of_8 := bilimyol_private.evaluate_english_placement_cefr(
    NULL,
    jsonb_build_array(
      jsonb_build_object('question_id', 'q_eng_place_vocab_a2', 'selected_index', 0),
      jsonb_build_object('question_id', 'q_eng_place_grammar_a2', 'selected_index', 0),
      jsonb_build_object('question_id', 'q_eng_place_listening_a2', 'selected_index', 0),
      jsonb_build_object('question_id', 'q_eng_place_reading_a2', 'selected_index', 0),
      jsonb_build_object('question_id', 'q_eng_place_vocab_a1', 'selected_index', 2),
      jsonb_build_object('question_id', 'q_eng_place_grammar_a1', 'selected_index', 0),
      jsonb_build_object('question_id', 'q_eng_place_listening_a1', 'selected_index', 1),
      jsonb_build_object('question_id', 'q_eng_place_reading_a1', 'selected_index', 0)
    )
  );
  v_cefr_empty := bilimyol_private.evaluate_english_placement_cefr(NULL, '[]'::jsonb);

  PERFORM pg_temp.assert_w1b3(
    v_cefr_5_of_8->>'assessed_cefr' = 'A1'
    AND v_cefr_2_of_8->>'assessed_cefr' = 'Pre-A1'
    AND v_cefr_empty->>'assessed_cefr' = 'Pre-A1',
    'FIX-P0-11 & FIX-P2-09: SQL evaluate_english_placement_cefr matches Web/Mobile cutoffs 1:1 (5/8->A1, 2/8->Pre-A1, empty->Pre-A1)'
  );

  -- 6b. Confidence & calibrated 0/1 / 1/1 parity with Web & Mobile
  PERFORM pg_temp.assert_w1b3(
    bilimyol_private.compute_confidence_label(2) = 'low'
    AND bilimyol_private.compute_confidence_numeric(2) = 0.35
    AND bilimyol_private.compute_confidence_label(3) = 'medium'
    AND bilimyol_private.compute_confidence_label(6) = 'high'
    AND bilimyol_private.compute_calibrated_skill_score(0, 0.5, NULL, true, false) = 0
    AND bilimyol_private.compute_calibrated_skill_score(0, 1.0, NULL, false, true) = 0
    AND bilimyol_private.compute_calibrated_skill_score(0.5, 0.5, NULL, true, false) = 51
    AND bilimyol_private.compute_calibrated_skill_score(1.0, 1.0, NULL, false, true) = 75,
    'FIX-P1-09 & FIX-P2-09: SQL confidence (2->low) and calibrated scores (0/1->0, 1/1 starter->51, 1/1 regular->75) match Web/Mobile 1:1'
  );

  -- 6c. 0/1 starter wrong -> 8/8 B1 placement clears stale pre-placement starter 0% row,
  --     and constructive fill_blank retry earns full 100% without 0.75 choice penalty
  PERFORM set_config('request.jwt.claim.sub', v_uid_interleave::TEXT, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_wrong_res := public.submit_answer_attempt(
    v_uid_interleave, 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_starter', 'q_lesson_eng_starter_quiz', 0, 'wrong text', 'w1b3-int-wrong-1'
  );
  EXECUTE 'RESET ROLE';

  PERFORM pg_temp.assert_w1b3(
    (v_wrong_res->>'new_skill_score')::INT = 0,
    'FIX-P1-09: 0/1 starter wrong without placement yields 0% (needs_remediation), never 44%'
  );

  EXECUTE 'SET LOCAL ROLE authenticated';
  v_state := public.advance_placement('course_eng_01');
  EXECUTE 'RESET ROLE';
  v_session_id := (v_state->>'session_id')::UUID;
  FOR i IN 1..8 LOOP
    v_qid := v_state->'question'->>'id';
    SELECT correct_index INTO v_idx FROM public.questions WHERE id = v_qid;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_state := public.advance_placement('course_eng_01', v_session_id, v_qid, v_idx);
    EXECUTE 'RESET ROLE';
  END LOOP;

  PERFORM pg_temp.assert_w1b3(
    NOT EXISTS (
      SELECT 1 FROM public.learner_skill_scores
      WHERE user_id = v_uid_interleave AND course_id = 'course_eng_01'
    )
    AND (SELECT placement_cefr_by_course->>'course_eng_01' = 'B1'
         FROM public.learner_profiles WHERE user_id = v_uid_interleave),
    'FIX-P0-02 & FIX-P1-46: 8/8 B1 placement supersedes pre-placement 0/1 starter attempt without leaving 0% remediation drag'
  );

  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.submit_answer_attempt(
    v_uid_interleave, 'course_eng_01', 'skill_eng_grammar',
    'lesson_eng_a1_m2_daily_life', 'q_eng_a1_m2_daily_fill', 0, 'wrong verb', 'w1b3-fb-miss'
  );
  v_fb_retry := public.submit_answer_attempt(
    v_uid_interleave, 'course_eng_01', 'skill_eng_grammar',
    'lesson_eng_a1_m2_daily_life', 'q_eng_a1_m2_daily_fill', 0, 'studies', 'w1b3-fb-hit'
  );
  EXECUTE 'RESET ROLE';

  PERFORM pg_temp.assert_w1b3(
    (v_fb_retry->>'is_correct')::BOOLEAN = true
    AND (v_fb_retry->>'new_skill_score')::INT = 100,
    'FIX-P1-09: constructive fill_blank retry earns 100% without 0.75 multiple-choice spoiler discount'
  );

  SELECT COALESCE(
    (SELECT q.correct_index FROM public.questions q WHERE q.id = 'q_eng_a1_u1_cp_main'),
    (SELECT (COALESCE(s->'interactiveQuestion', s->'interactive_question')->>'correctIndex')::INT
     FROM public.lessons l, jsonb_array_elements(l.steps) s
     WHERE l.id = 'lesson_eng_a1_u1_checkpoint'
       AND COALESCE(s->'interactiveQuestion', s->'interactive_question')->>'id' = 'q_eng_a1_u1_cp_main'
     LIMIT 1),
    0
  ) INTO v_idx;

  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.submit_answer_attempt(
    v_uid_interleave, 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_a1_u1_checkpoint', 'q_eng_a1_u1_cp_main', (v_idx + 1) % 4, NULL, 'w1b3-mc-miss'
  );
  v_fb_retry := public.submit_answer_attempt(
    v_uid_interleave, 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_a1_u1_checkpoint', 'q_eng_a1_u1_cp_main', v_idx, NULL, 'w1b3-mc-hit'
  );
  EXECUTE 'RESET ROLE';

  PERFORM pg_temp.assert_w1b3(
    (v_fb_retry->>'is_correct')::BOOLEAN = true
    AND (v_fb_retry->>'new_skill_score')::INT = 75,
    'FIX-P1-09: spoiled multiple_choice retry earns 75% (0.75 credit) on course_eng_01'
  );

  -- 6d. Day-1 0/8 placement -> starter 1/1 (11%) -> Day-2 abandoned restart preserves Day-1 -> Day-2 0/8 retake supersedes starter (never 100%)
  PERFORM set_config('request.jwt.claim.sub', v_uid_retake_eng::TEXT, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_state := public.advance_placement('course_eng_01');
  EXECUTE 'RESET ROLE';
  v_session_id := (v_state->>'session_id')::UUID;
  FOR i IN 1..8 LOOP
    v_qid := v_state->'question'->>'id';
    SELECT (correct_index + 1) % 4 INTO v_idx FROM public.questions WHERE id = v_qid;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_state := public.advance_placement('course_eng_01', v_session_id, v_qid, v_idx);
    EXECUTE 'RESET ROLE';
  END LOOP;

  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.submit_answer_attempt(
    v_uid_retake_eng, 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_starter', 'q_lesson_eng_starter_quiz', 0, 'I''m Sam', 'w1b3-ret-st-1'
  );
  EXECUTE 'RESET ROLE';

  UPDATE bilimyol_private.placement_sessions
  SET completed_at = completed_at - interval '2 days',
      question_started_at = question_started_at - interval '2 days'
  WHERE user_id = v_uid_retake_eng AND course_id = 'course_eng_01';
  UPDATE public.placement_attempts
  SET started_at = started_at - interval '2 days',
      completed_at = completed_at - interval '2 days'
  WHERE user_id = v_uid_retake_eng AND course_id = 'course_eng_01';
  UPDATE public.answer_attempts
  SET created_at = created_at - interval '1 day'
  WHERE user_id = v_uid_retake_eng AND course_id = 'course_eng_01';

  -- Start Day-2 retake (p_restart => true) and abandon mid-way: prior Day-1 placement & 11% starter remain intact
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_state := public.advance_placement('course_eng_01', p_restart => true);
  EXECUTE 'RESET ROLE';
  v_session_id := (v_state->>'session_id')::UUID;

  PERFORM pg_temp.assert_w1b3(
    (SELECT (placement_score_by_course->>'course_eng_01')::INT = 0
         AND placement_cefr_by_course->>'course_eng_01' = 'Pre-A1'
     FROM public.learner_profiles WHERE user_id = v_uid_retake_eng)
    AND (SELECT score = 11 FROM public.learner_skill_scores
         WHERE user_id = v_uid_retake_eng AND course_id = 'course_eng_01' AND skill_id = 'skill_eng_vocab'),
    'FIX-P1-46: incomplete restarted placement session preserves prior placement summary and starter score until finished'
  );

  -- Finish Day-2 0/8 retake: must supersede pre-retake starter without inflating 1/1 starter to 100%
  FOR i IN 1..8 LOOP
    v_qid := v_state->'question'->>'id';
    SELECT (correct_index + 1) % 4 INTO v_idx FROM public.questions WHERE id = v_qid;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_state := public.advance_placement('course_eng_01', v_session_id, v_qid, v_idx);
    EXECUTE 'RESET ROLE';
  END LOOP;

  PERFORM pg_temp.assert_w1b3(
    NOT EXISTS (
      SELECT 1 FROM public.learner_skill_scores
      WHERE user_id = v_uid_retake_eng AND course_id = 'course_eng_01' AND score > 25
    ),
    'FIX-P1-09 & FIX-P1-46: Day-2 0/8 retake never inflates prior Day-1 starter attempt to 100%'
  );

  -- 6e. Combined preference + derived-placement UPDATE and INSERT forgery both blocked with 42501
  DELETE FROM public.learner_profiles WHERE user_id = v_uid_forger;
  PERFORM set_config('request.jwt.claim.sub', v_uid_forger::TEXT, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    INSERT INTO public.learner_profiles (user_id, daily_minutes, placement_score_by_course)
    VALUES (v_uid_forger, 30, '{"course_eng_01":100}'::jsonb);
    RAISE EXCEPTION 'ASSERT [W1-B3]: authenticated INSERT forged placement_score_by_course';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  INSERT INTO public.learner_profiles (user_id, daily_minutes)
  VALUES (v_uid_forger, 30);

  BEGIN
    UPDATE public.learner_profiles
    SET daily_minutes = 60,
        placement_skill_scores_by_course = '{"course_eng_01":{"skill_eng_vocab":{"score":100}}}'::jsonb
    WHERE user_id = v_uid_forger;
    RAISE EXCEPTION 'ASSERT [W1-B3]: authenticated combined UPDATE forged placement_skill_scores_by_course';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  EXECUTE 'RESET ROLE';
END;
$$;

ROLLBACK;
