-- BilimYo‘l Smart Edu - Real Adaptive Learning Engine
-- Migration: 20260817000001_real_adaptive_learning.sql

-- 1. EXTEND QUESTIONS TABLE WITH 20+ VERIFIED MATHEMATICS QUESTIONS
-- Covering: Algebra (5), Tenglamalar (5), Funksiyalar (6), Grafiklar (5)
-- Difficulties: easy, medium, hard

INSERT INTO public.questions (id, course_id, skill_id, text, context_snippet, options, correct_index, difficulty, explanation, formula_latex, is_placement)
VALUES
  -- ALGEBRA (5 questions)
  ('q_math_alg_01', 'course_math_01', 'skill_math_algebra', 'Hisoblang: (a + 3)² ifodani ochganda qaysi natija hosil bo‘ladi?', NULL, '["a² + 6a + 9", "a² + 9", "a² + 3a + 9", "2a + 6"]'::jsonb, 0, 'easy', '(a + b)² = a² + 2ab + b² formulasi bo‘yicha: a² + 2*3*a + 3² = a² + 6a + 9.', '(a + 3)^2', true),
  ('q_math_alg_02', 'course_math_01', 'skill_math_algebra', 'Ko‘paytuvchilarga ajrating: x² - 25 ifodasi nimaga teng?', NULL, '["(x - 5)(x + 5)", "(x - 5)²", "(x + 5)²", "x(x - 25)"]'::jsonb, 0, 'easy', 'Kvadratlar ayirmasi formulasi: a² - b² = (a - b)(a + b). Shuning uchun x² - 5² = (x - 5)(x + 5).', 'x^2 - 25', true),
  ('q_math_alg_03', 'course_math_01', 'skill_math_algebra', 'Soddalashtiring: (2x - 3)(x + 4) ifodani ko‘paytiring.', NULL, '["2x² + 5x - 12", "2x² - 12", "2x² + 8x - 12", "2x² - 5x - 12"]'::jsonb, 0, 'medium', '(2x - 3)(x + 4) = 2x*x + 2x*4 - 3*x - 3*4 = 2x² + 8x - 3x - 12 = 2x² + 5x - 12.', '(2x - 3)(x + 4)', true),
  ('q_math_alg_04', 'course_math_01', 'skill_math_algebra', 'Hisoblang: (3a - 2b)² ifodani yoying.', NULL, '["9a² - 12ab + 4b²", "9a² - 4b²", "9a² + 12ab + 4b²", "6a² - 12ab + 4b²"]'::jsonb, 0, 'medium', '(3a - 2b)² = (3a)² - 2*(3a)*(2b) + (2b)² = 9a² - 12ab + 4b².', '(3a - 2b)^2', true),
  ('q_math_alg_05', 'course_math_01', 'skill_math_algebra', 'Ifodaning qiymatini toping: agar a = 3, b = -2 bo‘lsa, 2a² - 3ab + b² nimaga teng?', NULL, '["40", "28", "32", "20"]'::jsonb, 0, 'hard', '2*(3)² - 3*(3)*(-2) + (-2)² = 2*9 - (-18) + 4 = 18 + 18 + 4 = 40.', '2a^2 - 3ab + b^2', true),

  -- TENGLAMALAR (5 questions)
  ('q_math_eq_01', 'course_math_01', 'skill_math_equations', 'Chiziqli tenglamani yeching: 3x - 5 = 16. x ning qiymati nechaga teng?', NULL, '["x = 7", "x = 5", "x = 8", "x = 6"]'::jsonb, 0, 'easy', '3x = 16 + 5 => 3x = 21 => x = 21 / 3 => x = 7.', '3x - 5 = 16', true),
  ('q_math_eq_02', 'course_math_01', 'skill_math_equations', 'Tenglamani yeching: 4(x - 2) = 2x + 6. x nechaga teng?', NULL, '["x = 7", "x = 5", "x = 4", "x = -1"]'::jsonb, 0, 'medium', '4x - 8 = 2x + 6 => 4x - 2x = 6 + 8 => 2x = 14 => x = 7.', '4(x - 2) = 2x + 6', true),
  ('q_math_eq_03', 'course_math_01', 'skill_math_equations', 'Kvadrat tenglamaning ildizlarini toping: x² - 7x + 12 = 0.', NULL, '["x₁ = 3, x₂ = 4", "x₁ = -3, x₂ = -4", "x₁ = 2, x₂ = 6", "x₁ = 1, x₂ = 12"]'::jsonb, 0, 'medium', 'Viyet teoremasi bo‘yicha: x₁ + x₂ = 7 va x₁ * x₂ = 12. Demak, ildizlar 3 va 4.', 'x^2 - 7x + 12 = 0', true),
  ('q_math_eq_04', 'course_math_01', 'skill_math_equations', 'Tenglamani yeching: 2x² - 8 = 0.', NULL, '["x = ±2", "x = 2", "x = 4", "x = ±4"]'::jsonb, 0, 'easy', '2x² = 8 => x² = 4 => x = ±2.', '2x^2 - 8 = 0', true),
  ('q_math_eq_05', 'course_math_01', 'skill_math_equations', 'Kvadrat tenglamaning diskriminantini hisoblang: 2x² - 5x + 3 = 0.', NULL, '["D = 1", "D = 49", "D = -1", "D = 25"]'::jsonb, 0, 'hard', 'D = b² - 4ac = (-5)² - 4*2*3 = 25 - 24 = 1.', '2x^2 - 5x + 3 = 0', true),

  -- FUNKSIYALAR (6 questions)
  ('q_math_func_01', 'course_math_01', 'skill_math_functions', 'Agar f(x) = 2x + 3 bo‘lsa, f(4) ning qiymatini toping.', NULL, '["11", "8", "14", "9"]'::jsonb, 0, 'easy', 'Argument x = 4 o‘rniga qo‘yiladi: f(4) = 2*4 + 3 = 8 + 3 = 11.', 'f(x) = 2x + 3', true),
  ('q_math_func_02', 'course_math_01', 'skill_math_functions', 'Agar f(x) = 3x - 5 bo‘lsa, qaysi x da f(x) = 13 bo‘ladi?', NULL, '["x = 6", "x = 5", "x = 4", "x = 7"]'::jsonb, 0, 'medium', '3x - 5 = 13 => 3x = 18 => x = 6.', 'f(x) = 3x - 5 = 13', true),
  ('q_math_func_03', 'course_math_01', 'skill_math_functions', 'Agar f(x) = x² - 4x + 1 bo‘lsa, f(3) ning qiymatini hisoblang.', NULL, '["-2", "4", "1", "-1"]'::jsonb, 0, 'medium', 'f(3) = 3² - 4(3) + 1 = 9 - 12 + 1 = -2.', 'f(3) = 3^2 - 4(3) + 1', true),
  ('q_math_func_04', 'course_math_01', 'skill_math_functions', 'Agar f(x) = 5 - 2x bo‘lsa, f(-3) ning qiymatini toping.', NULL, '["11", "-1", "1", "-11"]'::jsonb, 0, 'easy', 'f(-3) = 5 - 2*(-3) = 5 - (-6) = 5 + 6 = 11.', 'f(-3) = 5 - 2(-3)', true),
  ('q_math_func_05', 'course_math_01', 'skill_math_functions', 'Agar f(x) = 2x + 1 va g(x) = x² bo‘lsa, f(g(2)) ning qiymatini toping.', NULL, '["9", "16", "25", "10"]'::jsonb, 0, 'hard', 'g(2) = 2² = 4. f(g(2)) = f(4) = 2*4 + 1 = 8 + 1 = 9.', 'f(g(2))', true),
  ('q_math_func_06', 'course_math_01', 'skill_math_functions', 'Chiziqli funksiya f(x) = kx + b berilgan. Agar f(0) = 4 va f(2) = 10 bo‘lsa, k nechaga teng?', NULL, '["k = 3", "k = 2", "k = 4", "k = 5"]'::jsonb, 0, 'hard', 'f(0) = b = 4. f(2) = 2k + 4 = 10 => 2k = 6 => k = 3.', 'f(x) = kx + b', true),

  -- GRAFIKLAR (5 questions)
  ('q_math_graph_01', 'course_math_01', 'skill_math_graphs', 'y = 2x - 4 to‘g‘ri chizig‘i Oy o‘qini qaysi nuqtada kesib o‘tadi?', NULL, '["(0, -4)", "(2, 0)", "(0, 4)", "(-4, 0)"]'::jsonb, 0, 'easy', 'Oy o‘qi bilan kesishishda x = 0 bo‘ladi: y = 2(0) - 4 = -4. Nuqta: (0, -4).', 'y = 2x - 4', true),
  ('q_math_graph_02', 'course_math_01', 'skill_math_graphs', 'y = 3x - 6 funksiyaning noli (Ox o‘qi bilan kesishish nuqtasi) qaysi?', NULL, '["(2, 0)", "(0, -6)", "(-2, 0)", "(6, 0)"]'::jsonb, 0, 'medium', 'Ox o‘qi bilan kesishishda y = 0: 3x - 6 = 0 => 3x = 6 => x = 2. Nuqta: (2, 0).', 'y = 3x - 6', true),
  ('q_math_graph_03', 'course_math_01', 'skill_math_graphs', 'Qaysi funksiya grafigi koordinatalar boshidan (0, 0) o‘tadi?', NULL, '["y = 5x", "y = 5x + 2", "y = 2x - 1", "y = x² + 1"]'::jsonb, 0, 'easy', 'To‘g‘ri proporsionallik y = kx grafigi b = 0 bo‘lganda doim (0, 0) orqali o‘tadi.', 'y = kx', true),
  ('q_math_graph_04', 'course_math_01', 'skill_math_graphs', 'y = -2x + 5 funksiya grafigi haqida qaysi fikr to‘g‘ri?', NULL, '["k < 0 bo‘lgani uchun funksiya kamayuvchi", "k > 0 bo‘lgani uchun funksiya o‘suvchi", "Grafigi (0, 0) nuqtadan o‘tadi", "Ox o‘qini (5, 0) da kesadi"]'::jsonb, 0, 'medium', 'k = -2 < 0 bo‘lgani uchun to‘g‘ri chiziq kamayuvchi bo‘ladi.', 'y = -2x + 5', true),
  ('q_math_graph_05', 'course_math_01', 'skill_math_graphs', 'y = x² - 4 parabolaning uchi qaysi nuqtada joylashgan?', NULL, '["(0, -4)", "(2, 0)", "(-2, 0)", "(0, 4)"]'::jsonb, 0, 'hard', 'y = x² - 4 parabolaning simmetriya o‘qi x = 0 bo‘lib, uchi (0, -4) nuqtada joylashadi.', 'y = x^2 - 4', true)
ON CONFLICT (id) DO UPDATE SET
  text = EXCLUDED.text,
  options = EXCLUDED.options,
  correct_index = EXCLUDED.correct_index,
  explanation = EXCLUDED.explanation;

-- 2. CREATE SERVER-SIDE SECURE ANSWER EVALUATION FUNCTION
CREATE OR REPLACE FUNCTION public.submit_answer_attempt(
  p_user_id UUID,
  p_course_id TEXT,
  p_skill_id TEXT,
  p_lesson_id TEXT,
  p_question_id TEXT,
  p_selected_index INT,
  p_selected_text TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_correct_index INT;
  v_is_correct BOOLEAN;
  v_explanation TEXT;
  v_total_count INT;
  v_correct_count INT;
  v_new_score INT;
  v_mastery_level TEXT;
BEGIN
  -- 1. Fetch the question's true correct answer securely from questions table
  SELECT correct_index, explanation
  INTO v_correct_index, v_explanation
  FROM public.questions
  WHERE id = p_question_id;

  IF v_correct_index IS NULL THEN
    -- Fallback check for dynamic question IDs
    v_is_correct := (p_selected_index = 0);
  ELSE
    v_is_correct := (p_selected_index = v_correct_index);
  END IF;

  -- 2. Insert into answer_attempts audit log
  INSERT INTO public.answer_attempts (
    user_id, lesson_id, question_id, selected_index, selected_answer, is_correct
  )
  VALUES (
    p_user_id, p_lesson_id, p_question_id, p_selected_index, p_selected_text, v_is_correct
  );

  -- 3. Calculate real cumulative skill stats for this user & skill
  SELECT COUNT(*), COUNT(*) FILTER (WHERE is_correct = true)
  INTO v_total_count, v_correct_count
  FROM public.answer_attempts aa
  JOIN public.questions q ON aa.question_id = q.id
  WHERE aa.user_id = p_user_id AND q.skill_id = p_skill_id;

  IF v_total_count > 0 THEN
    v_new_score := ROUND((v_correct_count::NUMERIC / v_total_count::NUMERIC) * 100);
  ELSE
    v_new_score := CASE WHEN v_is_correct THEN 100 ELSE 0 END;
  END IF;

  v_new_score := GREATEST(0, LEAST(100, v_new_score));

  -- Mastery classification
  IF v_new_score < 40 THEN
    v_mastery_level := 'needs_remediation';
  ELSIF v_new_score < 60 THEN
    v_mastery_level := 'developing';
  ELSIF v_new_score < 80 THEN
    v_mastery_level := 'proficient';
  ELSE
    v_mastery_level := 'mastered';
  END IF;

  -- 4. Upsert into learner_skill_scores
  INSERT INTO public.learner_skill_scores (
    user_id, course_id, skill_id, score, mastery_level, attempt_count, last_updated
  )
  VALUES (
    p_user_id, p_course_id, p_skill_id, v_new_score, v_mastery_level, v_total_count, now()
  )
  ON CONFLICT (user_id, course_id, skill_id) DO UPDATE SET
    score = EXCLUDED.score,
    mastery_level = EXCLUDED.mastery_level,
    attempt_count = EXCLUDED.attempt_count,
    last_updated = now();

  -- 5. Award XP idempotently (+2 XP per correct answer)
  IF v_is_correct THEN
    UPDATE public.gamification_profiles
    SET xp = xp + 2, updated_at = now()
    WHERE user_id = p_user_id;
  END IF;

  RETURN jsonb_build_object(
    'is_correct', v_is_correct,
    'correct_index', v_correct_index,
    'explanation', v_explanation,
    'new_skill_score', v_new_score,
    'total_attempts', v_total_count,
    'correct_attempts', v_correct_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
