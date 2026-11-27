-- ============================================================================
-- BILIMYO'L SMART EDU - WAVE 1 · BATCH W1-B2 REGRESSION SUITE
-- File: supabase/tests/w1_b2_cefr_sql_and_grading_parity_regression.sql
-- Run ONLY on disposable local PostgreSQL after all migrations:
--   psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/w1_b2_cefr_sql_and_grading_parity_regression.sql
-- Plain PostgreSQL assertions; rolls back all fixtures.
-- ============================================================================
BEGIN;

CREATE FUNCTION pg_temp.assert_w1b2(value BOOLEAN, label TEXT)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF value IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'ASSERT [W1-B2]: %', label;
  END IF;
END;
$$;

INSERT INTO auth.users (id, email, email_confirmed_at, raw_user_meta_data) VALUES
  ('00000000-0000-0000-0000-000000001201', 'w1b2-learner@example.invalid', now(), '{"first_name":"Dilnoza","last_name":"Tursunova"}'),
  ('00000000-0000-0000-0000-000000001202', 'w1b2-reinf@example.invalid', now(), '{"first_name":"Bekzod","last_name":"Ergashev"}');

-- ============================================================================
-- 1. FIX-P0-01: Canonical 33 CEFR English lessons & 31 roadmap_nodes seeded
-- ============================================================================
SELECT pg_temp.assert_w1b2(
  (SELECT count(*) = 33 FROM public.lessons WHERE course_id = 'course_eng_01' AND is_published AND NOT is_archived)
  AND (SELECT count(*) = 17 FROM public.lessons WHERE course_id = 'course_eng_01' AND cefr_level = 'A1')
  AND (SELECT count(*) = 8 FROM public.lessons WHERE course_id = 'course_eng_01' AND cefr_level = 'A2')
  AND (SELECT count(*) = 8 FROM public.lessons WHERE course_id = 'course_eng_01' AND cefr_level = 'B1')
  AND (SELECT count(*) = 33 FROM public.lessons WHERE course_id = 'course_eng_01' AND NULLIF(btrim(COALESCE(title_ru, '')), '') IS NOT NULL)
  AND (SELECT count(*) = 33 FROM public.lessons WHERE course_id = 'course_eng_01' AND jsonb_typeof(pedagogy17) = 'object'),
  'FIX-P0-01: all 33 canonical CEFR A1-B1 English lessons (17 A1, 8 A2, 8 B1) seeded with RU & pedagogy17 columns'
);

SELECT pg_temp.assert_w1b2(
  (SELECT count(*) = 31 FROM public.roadmap_nodes WHERE course_id = 'course_eng_01' AND is_active AND NOT is_reinforcement)
  AND (SELECT count(*) = 15 FROM public.roadmap_nodes WHERE course_id = 'course_eng_01' AND cefr_level = 'A1' AND is_active)
  AND (SELECT count(*) = 8 FROM public.roadmap_nodes WHERE course_id = 'course_eng_01' AND cefr_level = 'A2' AND is_active)
  AND (SELECT count(*) = 8 FROM public.roadmap_nodes WHERE course_id = 'course_eng_01' AND cefr_level = 'B1' AND is_active)
  AND (SELECT count(*) = 31 FROM public.roadmap_nodes WHERE course_id = 'course_eng_01' AND NULLIF(btrim(COALESCE(title_ru, '')), '') IS NOT NULL)
  AND (SELECT count(*) > 0 FROM public.roadmap_nodes WHERE course_id = 'course_eng_01' AND is_checkpoint = true)
  AND (SELECT count(*) > 0 FROM public.roadmap_nodes WHERE course_id = 'course_eng_01' AND has_rich_exercise = true),
  'FIX-P0-01: all 31 canonical CEFR A1-B1 roadmap_nodes (15 A1, 8 A2, 8 B1) seeded with full 14 CEFR/RU columns'
);

-- ============================================================================
-- 2. Coupling #2 & FIX-P0-01: learner_lessons CTE rewrite & rich key sanitization
-- ============================================================================
SELECT pg_temp.assert_w1b2(
  pg_get_viewdef('public.learner_lessons'::regclass, true) !~* 'can_open_math_lesson|OFFSET\s+0'
  AND pg_get_viewdef('public.learner_lessons'::regclass, true) ~* 'unlocked_math_lesson_ids',
  'Coupling #2: public.learner_lessons uses single math_progression CTE with zero OFFSET 0 or per-row can_open_math_lesson'
);

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000001201', true);
SET LOCAL ROLE authenticated;

SELECT pg_temp.assert_w1b2(
  (
    SELECT count(*) = 0
    FROM public.learner_lessons ll
    WHERE ll.course_id = 'course_eng_01'
      AND (
        ll.steps::TEXT ~ 'acceptedAnswers|accepted_answers|correctIndex|correct_index|explanationRu|explanation_ru|mistakeFeedbackByOption|mistake_feedback_by_option'
        OR COALESCE(ll.reinforcement_exercise::TEXT, '') ~ 'acceptedAnswers|accepted_answers|correctIndex|correct_index|explanationRu|explanation_ru|mistakeFeedbackByOption|mistake_feedback_by_option'
        OR COALESCE(ll.alternate_exercise::TEXT, '') ~ 'acceptedAnswers|accepted_answers|correctIndex|correct_index|explanationRu|explanation_ru|mistakeFeedbackByOption|mistake_feedback_by_option'
      )
  ),
  'FIX-P0-01: learner_lessons strips acceptedAnswers, correctIndex, explanationRu, and mistakeFeedbackByOption across steps, reinforcement_exercise, and alternate_exercise'
);

SELECT pg_temp.assert_w1b2(
  (
    SELECT ll.cefr_level = 'A1'
      AND NULLIF(btrim(COALESCE(ll.title_ru, '')), '') IS NOT NULL
      AND jsonb_typeof(ll.pedagogy17) = 'object'
      AND NULLIF(btrim(COALESCE(ll.official_cefr_disclaimer_uz, '')), '') IS NOT NULL
    FROM public.learner_lessons ll
    WHERE ll.id = 'lesson_eng_starter'
  ),
  'FIX-P0-01: learner_lessons exposes cefr_level, title_ru, pedagogy17, and official_cefr_disclaimer_uz'
);

RESET ROLE;

-- Verify orderedTokens are deterministically scrambled out of exact solution order AND Web UI shift order,
-- and matchPairs right-hand translations have 0 fixed points relative to raw public.lessons!
SELECT pg_temp.assert_w1b2(
  NOT EXISTS (
    SELECT 1
    FROM public.lessons raw_l
    JOIN public.learner_lessons safe_l ON safe_l.id = raw_l.id
    CROSS JOIN LATERAL jsonb_array_elements(raw_l.steps) WITH ORDINALITY AS rs(step, idx)
    CROSS JOIN LATERAL jsonb_array_elements(safe_l.steps) WITH ORDINALITY AS ss(step, idx)
    WHERE raw_l.course_id = 'course_eng_01'
      AND rs.idx = ss.idx
      AND jsonb_typeof(rs.step->'interactiveQuestion'->'orderedTokens') = 'array'
      AND (
        ss.step->'interactiveQuestion'->'orderedTokens' = rs.step->'interactiveQuestion'->'orderedTokens'
        OR jsonb_array_length(ss.step->'interactiveQuestion'->'orderedTokens') <> jsonb_array_length(rs.step->'interactiveQuestion'->'orderedTokens')
      )
  ),
  'FIX-P0-01: sanitize_learner_content scrambles orderedTokens out of exact solution order while preserving token count'
);

SELECT pg_temp.assert_w1b2(
  NOT EXISTS (
    SELECT 1
    FROM public.lessons raw_l
    JOIN public.learner_lessons safe_l ON safe_l.id = raw_l.id
    CROSS JOIN LATERAL jsonb_array_elements(raw_l.steps) WITH ORDINALITY AS rs(step, idx)
    CROSS JOIN LATERAL jsonb_array_elements(safe_l.steps) WITH ORDINALITY AS ss(step, idx)
    CROSS JOIN LATERAL jsonb_array_elements(rs.step->'interactiveQuestion'->'matchPairs') WITH ORDINALITY AS rp(pair, p_idx)
    CROSS JOIN LATERAL jsonb_array_elements(ss.step->'interactiveQuestion'->'matchPairs') WITH ORDINALITY AS sp(pair, p_idx)
    WHERE raw_l.course_id = 'course_eng_01'
      AND rs.idx = ss.idx
      AND rp.p_idx = sp.p_idx
      AND jsonb_typeof(rs.step->'interactiveQuestion'->'matchPairs') = 'array'
      AND rp.pair->>'right' = sp.pair->>'right'
  ),
  'FIX-P0-01: sanitize_learner_content deranges matchPairs right-hand values with zero fixed-point leaks'
);

-- ============================================================================
-- 3. FIX-P0-01 & FIX-P1-40: Server grading of all 9 question modes + wire safety
-- ============================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000001201', true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_res JSONB;
  v_fb JSONB;
BEGIN
  -- Mode 1: text_input (normalized punctuation/apostrophe/case + non-spoiler wrongFeedback)
  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_starter', 'q_lesson_eng_starter_quiz', 0,
    'Wrong answer', '12011111-1111-4111-8111-111111111201'
  );
  PERFORM pg_temp.assert_w1b2(
    (v_res->>'is_correct')::BOOLEAN = false
    AND (v_res->>'explanation') NOT LIKE 'Ajoyib!%'
    AND (v_res->>'explanation') LIKE '%I''m ...%',
    'Mode 1 (text_input): rejects wrong text with wrongFeedback instead of praise/spoiler explanation'
  );

  v_fb := public.get_mistake_feedback('course_eng_01', 'skill_eng_vocab', 'q_lesson_eng_starter_quiz');
  PERFORM pg_temp.assert_w1b2(
    v_fb IS NOT NULL
    AND (v_fb->>'correctOption') IS NULL
    AND NULLIF(btrim(COALESCE(v_fb->>'explanation', '')), '') IS NOT NULL
    AND (v_fb->>'explanation') NOT LIKE 'Ajoyib!%',
    'FIX-P1-40: get_mistake_feedback withholds literal correctOption on text_input while returning targeted wrongFeedback'
  );

  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_starter', 'q_lesson_eng_starter_quiz', 0,
    '  hello,  i’m sam! ', '12011111-1111-4111-8111-111111111202'
  );
  PERFORM pg_temp.assert_w1b2(
    (v_res->>'is_correct')::BOOLEAN = true AND (v_res->>'xp_awarded')::INT = 2,
    'Mode 1 (text_input): accepts normalized curly-apostrophe + comma + case-insensitive answer'
  );

  -- Mode 2: fill_blank
  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_grammar',
    'lesson_eng_a1_m2_daily_life', 'q_eng_a1_m2_daily_fill', 0,
    'studies.', '12011111-1111-4111-8111-111111111203'
  );
  PERFORM pg_temp.assert_w1b2((v_res->>'is_correct')::BOOLEAN = true, 'Mode 2 (fill_blank): grades acceptedAnswers');

  -- Mode 3: word_match (must reject pair-ID cheat {"pair_gm":"pair_gm"} and accept {"leftId":"rightText"})
  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_a1_m1_greetings', 'q_eng_a1_m1_greet_match', 0,
    '{"pair_ge":"pair_ge","pair_gm":"pair_gm","pair_hay":"pair_hay","pair_ift":"pair_ift"}',
    '12011111-1111-4111-8111-111111111204'
  );
  PERFORM pg_temp.assert_w1b2(
    (v_res->>'is_correct')::BOOLEAN = false
    AND (v_res->>'explanation') NOT LIKE 'Barakalla!%',
    'Mode 3 (word_match): rejects pair-ID cheat payload {"pair_gm":"pair_gm"} with wrongFeedback'
  );

  v_fb := public.get_mistake_feedback('course_eng_01', 'skill_eng_vocab', 'q_eng_a1_m1_greet_match');
  PERFORM pg_temp.assert_w1b2(
    v_fb IS NOT NULL
    AND (v_fb->>'correctOption') IS NULL
    AND (v_fb->>'selectedOption') LIKE 'Good morning -> %'
    AND (v_fb->>'explanation') NOT LIKE 'Barakalla!%',
    'FIX-P1-40: get_mistake_feedback formats word_match selectedOption cleanly and withholds answer-key spoiler'
  );

  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_a1_m1_greetings', 'q_eng_a1_m1_greet_match', 0,
    '{"pair_ge":"Xayrli kech","pair_gm":"Xayrli tong","pair_hay":"Ahvolingiz qanday?","pair_ift":"Yaxshiman, rahmat."}',
    '12011111-1111-4111-8111-111111111205'
  );
  PERFORM pg_temp.assert_w1b2(
    (v_res->>'is_correct')::BOOLEAN = true,
    'Mode 3 (word_match): accepts canonical key-sorted {"leftId":"selectedRightText"} JSON'
  );

  -- Mode 4: sentence_order (canonical JSON token array)
  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_grammar',
    'lesson_eng_a1_m2_sentence_builder', 'q_eng_a1_m2_order_1', 0,
    '["books","They","read"]',
    '12011111-1111-4111-8111-111111111206'
  );
  PERFORM pg_temp.assert_w1b2((v_res->>'is_correct')::BOOLEAN = false, 'Mode 4 (sentence_order): rejects wrong token order');

  v_fb := public.get_mistake_feedback('course_eng_01', 'skill_eng_grammar', 'q_eng_a1_m2_order_1');
  PERFORM pg_temp.assert_w1b2(
    v_fb IS NOT NULL
    AND (v_fb->>'correctOption') IS NULL
    AND (v_fb->>'selectedOption') = 'books They read',
    'FIX-P1-40: get_mistake_feedback formats sentence_order selectedOption and withholds unscrambled spoiler from authenticated caller'
  );

  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_grammar',
    'lesson_eng_a1_m2_sentence_builder', 'q_eng_a1_m2_order_1', 0,
    '["They","read","books","in","the","library."]',
    '12011111-1111-4111-8111-111111111207'
  );
  PERFORM pg_temp.assert_w1b2(
    (v_res->>'is_correct')::BOOLEAN = true,
    'Mode 4 (sentence_order): accepts canonical JSON token array'
  );

  -- Mode 5: multiple_choice
  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_a1_u1_checkpoint', 'q_eng_a1_u1_cp_main', 0,
    'Good afternoon, Miss Nilufar. My name is Anvar.',
    '12011111-1111-4111-8111-111111111208'
  );
  PERFORM pg_temp.assert_w1b2((v_res->>'is_correct')::BOOLEAN = true, 'Mode 5 (multiple_choice): grades MCQ');

  -- Mode 6: error_correction
  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_a1_u3_checkpoint', 'q_eng_a1_u3_cp_main', 0,
    'The study desk is beside the window.',
    '12011111-1111-4111-8111-111111111209'
  );
  PERFORM pg_temp.assert_w1b2((v_res->>'is_correct')::BOOLEAN = true, 'Mode 6 (error_correction): grades error_correction');

  -- Mode 7: conversation_completion
  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_listening',
    'lesson_eng_a2_u1_checkpoint', 'q_eng_a2_u1_cp_conv', 3,
    'Get off at the second stop across from the history museum and take bus 28.',
    '12011111-1111-4111-8111-111111111210'
  );
  PERFORM pg_temp.assert_w1b2((v_res->>'is_correct')::BOOLEAN = true, 'Mode 7 (conversation_completion): grades conversation_completion');

  -- Mode 8: speaking_prompt (self_assessed JSON {"response","criteria"})
  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_a1_m1_speaking', 'q_eng_a1_m1_speaking_prompt', 0,
    '{"response":"   ","criteria":[]}',
    '12011111-1111-4111-8111-111111111211'
  );
  PERFORM pg_temp.assert_w1b2((v_res->>'is_correct')::BOOLEAN = false, 'Mode 8 (speaking_prompt): rejects blank response');

  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_a1_m1_speaking', 'q_eng_a1_m1_speaking_prompt', 0,
    '{"response":"Good morning! My name is Dilnoza. Nice to meet you.","criteria":["crit_greet","crit_name"]}',
    '12011111-1111-4111-8111-111111111212'
  );
  PERFORM pg_temp.assert_w1b2((v_res->>'is_correct')::BOOLEAN = true, 'Mode 8 (speaking_prompt): accepts non-empty self_assessed JSON');

  -- Mode 9: writing_prompt (self_assessed JSON {"response","criteria"})
  v_res := public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_reading',
    'lesson_eng_a1_m4_writing', 'q_eng_a1_m4_writing_prompt', 0,
    '{"response":"I wake up at 7:00, study English at 9:00, and read in the evening.","criteria":["crit_time"]}',
    '12011111-1111-4111-8111-111111111213'
  );
  PERFORM pg_temp.assert_w1b2((v_res->>'is_correct')::BOOLEAN = true, 'Mode 9 (writing_prompt): accepts non-empty self_assessed JSON');
END;
$$;

-- ============================================================================
-- 4. FIX-P1-40: Multi-skill step lesson completion & alternate_exercise swap
-- ============================================================================
DO $$
DECLARE
  v_comp JSONB;
BEGIN
  -- lesson_eng_a1_exit has lesson.skill_id = skill_eng_reading, while its 4 steps span:
  --   q_eng_a1_exit_listen (skill_eng_listening, ci=3)
  --   q_eng_a1_exit_fill   (skill_eng_grammar, fill_blank 'opens')
  --   q_eng_a1_exit_order  (skill_eng_grammar, sentence_order)
  --   q_eng_a1_exit_read   (skill_eng_reading, ci=0)
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_listening',
    'lesson_eng_a1_exit', 'q_eng_a1_exit_listen', 3, '20:30',
    '12011111-1111-4111-8111-111111111214'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_grammar',
    'lesson_eng_a1_exit', 'q_eng_a1_exit_fill', 0, 'opens',
    '12011111-1111-4111-8111-111111111215'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_grammar',
    'lesson_eng_a1_exit', 'q_eng_a1_exit_order', 0,
    '["I","drink","my","tea","beside","the","window."]',
    '12011111-1111-4111-8111-111111111216'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_reading',
    'lesson_eng_a1_exit', 'q_eng_a1_exit_read', 0,
    'Yakshanba kuni soat 16:00–17:00 orasida suhbat davrasi bor va talabalarga choy bepul',
    '12011111-1111-4111-8111-111111111217'
  );

  v_comp := public.complete_lesson('lesson_eng_a1_exit', 'course_eng_01');
  PERFORM pg_temp.assert_w1b2(
    (v_comp->>'completed')::BOOLEAN = true AND (v_comp->>'xp_awarded')::INT = 20,
    'FIX-P1-40: complete_lesson succeeds on multi-skill English exit assessment across 3 skills'
  );

  -- Alternate exercise swap on lesson_eng_b1_u1_checkpoint:
  -- Learner misses primary step q_eng_b1_u1_cp_conv (or switches to alternate q_eng_b1_u1_cp_alt_fill)
  -- Wait: check how many steps lesson_eng_a1_u2_checkpoint has (1 step + alternate_exercise q_eng_a1_u2_cp_alt)!
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_grammar',
    'lesson_eng_a1_u2_checkpoint', 'q_eng_a1_u2_cp_main', 0,
    'wrong attempt',
    '12011111-1111-4111-8111-111111111218'
  );
  -- Passing alternate_exercise q_eng_a1_u2_cp_alt satisfies the swapped step!
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_grammar',
    'lesson_eng_a1_u2_checkpoint', 'q_eng_a1_u2_cp_alt', 2,
    'They are in the library on Monday.',
    '12011111-1111-4111-8111-111111111219'
  );
  v_comp := public.complete_lesson('lesson_eng_a1_u2_checkpoint', 'course_eng_01');
  PERFORM pg_temp.assert_w1b2(
    (v_comp->>'completed')::BOOLEAN = true,
    'FIX-P1-40: complete_lesson accepts passed alternate_exercise when swapped for a failed step question'
  );
END;
$$;

RESET ROLE;

-- ============================================================================
-- 5. FIX-P1-40: <28% stuck reinforcement clearance (0/3 -> >=50%) + rich alternate reinf
-- ============================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000001202', true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_reinf JSONB;
BEGIN
  -- Fail 3 distinct vocab questions so pre-reinforcement score is 0% (0/3)
  -- and even after 1 correct reinforcement attempt raw ratio is 1/4 = 25% (< 50%)!
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_starter', 'q_lesson_eng_starter_quiz', 0, 'wrong 1',
    '12021111-1111-4111-8111-111111111201'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_a1_m1_greetings', 'q_eng_a1_m1_greet_match', 0, '{"pair_gm":"wrong"}',
    '12021111-1111-4111-8111-111111111202'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'lesson_eng_a1_u1_checkpoint', 'q_eng_a1_u1_cp_main', 1, 'Good night, Miss Nilufar. Goodbye.',
    '12021111-1111-4111-8111-111111111203'
  );

  -- Complete reinforcement on reinf_node_eng_a1_u1_checkpoint using alternate_exercise q_eng_a1_u1_cp_alt!
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'reinf_node_eng_a1_u1_checkpoint', 'q_eng_a1_u1_cp_alt', 1, 'Nice to meet you, Laylo!',
    '12021111-1111-4111-8111-111111111204'
  );
  v_reinf := public.complete_reinforcement(
    'reinf_node_eng_a1_u1_checkpoint', 'course_eng_01', 'skill_eng_vocab', 'q_eng_a1_u1_cp_alt', 30
  );

  PERFORM pg_temp.assert_w1b2(
    (v_reinf->>'old_score')::INT = 0
    AND (v_reinf->>'new_score')::INT >= 50
    AND (SELECT score >= 50 FROM public.learner_skill_scores WHERE user_id = auth.uid() AND course_id = 'course_eng_01' AND skill_id = 'skill_eng_vocab'),
    'FIX-P1-40: complete_reinforcement lifts 0% (0/3, raw 25%) skill to >= 50% and accepts alternate_exercise'
  );
END;
$$;

RESET ROLE;

-- ============================================================================
-- 6. Adversarial edge cases: service_role tutor_mistake_context, multi-skill
--    complete_reinforcement (parent <50% vs exercise >=70%), cross-skill
--    alternate_exercise 42501 guard, admin_save_lesson rich column preservation,
--    and 2-token / palindrome orderedTokens scrambling
-- ============================================================================
INSERT INTO auth.users (id, email, email_confirmed_at, raw_user_meta_data) VALUES
  ('00000000-0000-0000-0000-000000001203', 'w1b2-multireinf@example.invalid', now(), '{"first_name":"Malika","last_name":"Saidova"}'),
  ('00000000-0000-0000-0000-000000001204', 'w1b2-altdup@example.invalid', now(), '{"first_name":"Otabek","last_name":"Nazarov"}'),
  ('00000000-0000-0000-0000-000000001205', 'w1b2-admin@example.invalid', now(), '{"first_name":"Admin","last_name":"CMS"}');

SELECT set_config('bilimyol.authorized_role_change', 'true', true);
UPDATE public.profiles SET role = 'admin' WHERE id = '00000000-0000-0000-0000-000000001205';
SELECT set_config('bilimyol.authorized_role_change', '', true);

-- 6a. service_role tutor_mistake_context receives full correctOption & formatted selectedOption
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000001203', true);
SET LOCAL ROLE authenticated;
SELECT public.submit_answer_attempt(
  auth.uid(), 'course_eng_01', 'skill_eng_vocab',
  'lesson_eng_starter', 'q_lesson_eng_starter_quiz', 0, 'wrong',
  '12031111-1111-4111-8111-111111111201'
);
RESET ROLE;

SET LOCAL ROLE service_role;
SELECT pg_temp.assert_w1b2(
  (public.tutor_mistake_context('00000000-0000-0000-0000-000000001203', 'course_eng_01', 'skill_eng_vocab', 'q_lesson_eng_starter_quiz')->>'correctOption') = 'I''m Sam'
  AND (public.tutor_mistake_context('00000000-0000-0000-0000-000000001203', 'course_eng_01', 'skill_eng_vocab', 'q_lesson_eng_starter_quiz')->>'explanation') NOT LIKE 'Ajoyib!%',
  'FIX-P1-40: service_role tutor_mistake_context returns full correctOption and non-praise wrongFeedback for yolchi-tutor'
);
RESET ROLE;

-- 6b. Multi-skill complete_reinforcement succeeds when parent node skill <50% while exercise skill >=70%
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000001203', true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_reinf JSONB;
BEGIN
  -- Learner has 0% on skill_eng_vocab (parent skill of node_eng_b1_m4_decisions) and 100% on skill_eng_grammar
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_grammar',
    'lesson_eng_a1_m2_daily_life', 'q_eng_a1_m2_daily_fill', 0, 'studies',
    '12031111-1111-4111-8111-111111111202'
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_grammar',
    'reinf_node_eng_b1_m4_decisions', 'q_eng_b1_m4_rep_text', 0,
    'Ali told us that he could send the agenda that day',
    '12031111-1111-4111-8111-111111111203'
  );
  v_reinf := public.complete_reinforcement(
    'reinf_node_eng_b1_m4_decisions', 'course_eng_01', 'skill_eng_grammar', 'q_eng_b1_m4_rep_text', 30
  );
  PERFORM pg_temp.assert_w1b2(
    (v_reinf->>'already_processed')::BOOLEAN = false
    AND (v_reinf->>'xp_awarded')::INT = 30
    AND EXISTS (
      SELECT 1 FROM public.reinforcement_attempts
      WHERE user_id = auth.uid() AND reinforcement_node_id = 'reinf_node_eng_b1_m4_decisions'
    ),
    'FIX-P1-40: multi-skill complete_reinforcement succeeds when parent node skill <50% even if exercise skill >=70%'
  );
END;
$$;
RESET ROLE;

-- 6c. Cross-skill alternate_exercise duplicate reinforcement raises controlled 42501 instead of raw 23505
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000001204', true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_sqlstate TEXT := '';
BEGIN
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_grammar',
    'reinf_node_eng_b1_u2_checkpoint', 'q_eng_b1_u2_cp_reinf_order', 0,
    '["If","the bus","arrives late,","we","will take","a taxi."]',
    '12041111-1111-4111-8111-111111111201'
  );
  PERFORM public.complete_reinforcement(
    'reinf_node_eng_b1_u2_checkpoint', 'course_eng_01', 'skill_eng_grammar', 'q_eng_b1_u2_cp_reinf_order', 30
  );
  PERFORM public.submit_answer_attempt(
    auth.uid(), 'course_eng_01', 'skill_eng_vocab',
    'reinf_node_eng_b1_u2_checkpoint', 'q_eng_b1_u2_cp_alt_text', 0,
    'Unless you save a backup, you will lose the file',
    '12041111-1111-4111-8111-111111111202'
  );
  BEGIN
    PERFORM public.complete_reinforcement(
      'reinf_node_eng_b1_u2_checkpoint', 'course_eng_01', 'skill_eng_vocab', 'q_eng_b1_u2_cp_alt_text', 30
    );
  EXCEPTION WHEN OTHERS THEN
    v_sqlstate := SQLSTATE;
  END;
  PERFORM pg_temp.assert_w1b2(
    v_sqlstate = '42501',
    'FIX-P1-40: cross-skill alternate_exercise duplicate reinforcement raises controlled 42501 instead of 23505'
  );
END;
$$;
RESET ROLE;

-- 6d. admin_save_lesson preserves requires_mastery, cefr_level, pedagogy17, reinforcement_exercise, and alternate_exercise on minimal/null CMS payloads
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000001205', true);
SET LOCAL ROLE authenticated;
SELECT public.admin_save_lesson(jsonb_build_object(
  'id', 'lesson_eng_b1_u3_checkpoint',
  'course_id', 'course_eng_01',
  'skill_id', 'skill_eng_grammar',
  'title', 'Updated Checkpoint Title',
  'steps', (SELECT steps FROM public.admin_lessons WHERE id = 'lesson_eng_b1_u3_checkpoint'),
  'pedagogy17', NULL
));
RESET ROLE;

SELECT pg_temp.assert_w1b2(
  (
    SELECT l.requires_mastery = true
      AND l.cefr_level = 'B1'
      AND jsonb_typeof(l.pedagogy17) = 'object'
      AND jsonb_typeof(l.reinforcement_exercise) = 'object'
      AND jsonb_typeof(l.alternate_exercise) = 'object'
    FROM public.lessons l
    WHERE l.id = 'lesson_eng_b1_u3_checkpoint'
  ),
  'FIX-P0-01: admin_save_lesson preserves requires_mastery, cefr_level, pedagogy17, reinforcement_exercise, and alternate_exercise'
);

-- 6e. sanitize_learner_content scrambles 2-token and palindrome orderedTokens arrays
SELECT pg_temp.assert_w1b2(
  (public.sanitize_learner_content('{"id":"q_2tok","orderedTokens":["Hello","world"]}'::jsonb)->'orderedTokens')
    = '["world","Hello"]'::jsonb
  AND (public.sanitize_learner_content('{"id":"q_pal","orderedTokens":["a","b","a"]}'::jsonb)->'orderedTokens')
    IS DISTINCT FROM '["a","b","a"]'::jsonb,
  'FIX-P0-01: sanitize_learner_content scrambles 2-token and palindrome orderedTokens arrays'
);

ROLLBACK;
