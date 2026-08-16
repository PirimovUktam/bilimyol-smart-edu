-- BilimYo‘l Smart Edu - Seed Data
-- Seed: courses, skills, questions, roadmap_nodes

-- 1. COURSES
INSERT INTO public.courses (id, title, subject, description, icon_name, primary_color_hex, secondary_color_hex, total_students_estimate, is_active)
VALUES
  ('course_math_01', 'Matematika', 'mathematics', 'Mantiqiy fikrlash, masalalar va funksiyalarni chuqur mustahkamlash kursi.', 'calculator', '#2563EB', '#3B82F6', 1420, true),
  ('course_eng_01', 'Ingliz tili', 'english', 'Lug‘at, grammatika, tinglab tushunish va o‘qish ko‘nikmalarini rivojlantirish.', 'headphones', '#14B8A6', '#0D9488', 1890, true)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description;

-- 2. SKILLS
INSERT INTO public.skills (id, course_id, name, code, description, order_index, icon_name)
VALUES
  ('skill_math_algebra', 'course_math_01', 'Algebra asoslari', 'MATH-ALG', 'Qisqa ko‘paytirish formulalari, ko‘phadlar va amallar tartibi.', 1, 'percent'),
  ('skill_math_equations', 'course_math_01', 'Tenglamalar', 'MATH-EQ', 'Chiziqli va kvadrat tenglamalarni yechish usullari.', 2, 'equal'),
  ('skill_math_functions', 'course_math_01', 'Funksiyalar', 'MATH-FUNC', 'Funksiya tushunchasi, argument va funksiya qiymatini hisoblash.', 3, 'activity'),
  ('skill_math_graphs', 'course_math_01', 'Grafiklar', 'MATH-GRAPH', 'Koordinatalar tekisligida chiziqli va kvadratik funksiyalar grafigi.', 4, 'show_chart'),

  ('skill_eng_vocab', 'course_eng_01', 'Vocabulary', 'ENG-VOCAB', 'Akademik va kundalik so‘z boyligi, kontekstual iboralar.', 1, 'menu_book'),
  ('skill_eng_grammar', 'course_eng_01', 'Grammar', 'ENG-GRAM', 'Zamonlar, modal fe’llar va gap tuzilishi qoidalari.', 2, 'description'),
  ('skill_eng_listening', 'course_eng_01', 'Listening', 'ENG-LIST', 'Audio va suhbatlardagi asosiy ma’no va kalit so‘zlarni ilg‘ash.', 3, 'headphones'),
  ('skill_eng_reading', 'course_eng_01', 'Reading', 'ENG-READ', 'Matnni tahlil qilish, asosiy g‘oyani va detallarni topish.', 4, 'chrome_reader_mode')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;

-- 3. QUESTIONS (Placement questions)
INSERT INTO public.questions (id, course_id, skill_id, text, context_snippet, options, correct_index, difficulty, explanation, formula_latex, is_placement)
VALUES
  ('q_math_p1', 'course_math_01', 'skill_math_algebra', 'Hisoblang: (a + 3)² ifodani soddalashtirganda qaysi natija to‘g‘ri?', NULL, '["a² + 6a + 9", "a² + 9", "a² + 3a + 9", "2a + 6"]'::jsonb, 0, 'medium', 'Qisqa ko‘paytirish formulasiga ko‘ra: (a + b)² = a² + 2ab + b² = a² + 6a + 9.', '(a + 3)^2', true),
  ('q_math_p2', 'course_math_01', 'skill_math_equations', 'Tenglamani yeching: 3x - 5 = 16. x ning qiymati nechaga teng?', NULL, '["x = 7", "x = 5", "x = 8", "x = 6"]'::jsonb, 0, 'easy', '3x = 16 + 5 => 3x = 21 => x = 7.', '3x - 5 = 16', true),
  ('q_math_p3', 'course_math_01', 'skill_math_functions', 'Agar f(x) = x² - 4x + 1 bo‘lsa, f(3) ning qiymatini toping.', NULL, '["-2", "4", "1", "-1"]'::jsonb, 0, 'hard', 'f(3) = 3² - 4(3) + 1 = 9 - 12 + 1 = -2.', 'f(3) = 3^2 - 4(3) + 1', true),
  ('q_math_p4', 'course_math_01', 'skill_math_graphs', 'y = 2x - 4 to‘g‘ri chizig‘i Oy o‘qini qaysi nuqtada kesib o‘tadi?', NULL, '["(0, -4)", "(2, 0)", "(0, 4)", "(-4, 0)"]'::jsonb, 0, 'medium', 'Oy o‘qi bilan kesishishda x = 0 bo‘ladi: y = 2(0) - 4 = -4. Nuqta: (0, -4).', 'y = 2x - 4', true),
  ('q_math_p5', 'course_math_01', 'skill_math_functions', 'Agar f(x) = 5 - 2x funksiya berilgan bo‘lsa, qaysi x da f(x) = 1 bo‘ladi?', NULL, '["x = 2", "x = -2", "x = 3", "x = 1"]'::jsonb, 0, 'hard', '5 - 2x = 1 => 2x = 4 => x = 2.', '5 - 2x = 1', true),

  ('q_eng_p1', 'course_eng_01', 'skill_eng_vocab', 'Choose the best synonym for the word "Essential":', NULL, '["Crucial / Muhim", "Optional", "Dangerous", "Rare"]'::jsonb, 0, 'easy', '"Essential" means absolutely necessary or crucial.', NULL, true),
  ('q_eng_p2', 'course_eng_01', 'skill_eng_grammar', 'Complete the sentence: "If she ____ harder, she would pass the exam."', NULL, '["studied", "studies", "has studied", "will study"]'::jsonb, 0, 'medium', 'Second Conditional structure: If + Past Simple, would + Verb.', NULL, true),
  ('q_eng_p3', 'course_eng_01', 'skill_eng_listening', 'Audio context: "We decided to postpone the conference from Tuesday to Friday."', 'Speaker: "Due to schedule conflicts, the conference is postponed to Friday."', '["The conference is on Friday", "The conference is on Tuesday", "The conference is canceled", "The conference is next month"]'::jsonb, 0, 'hard', 'The speaker explicitly states the conference was moved to Friday.', NULL, true),
  ('q_eng_p4', 'course_eng_01', 'skill_eng_reading', 'Read the sentence: "Renewable energy sources are becoming more cost-effective each year."', 'What is the main idea?', '["Clean energy is getting cheaper to produce", "Fossil fuels are disappearing", "Renewable energy is too expensive", "Solar panels are rare"]'::jsonb, 0, 'medium', '"Cost-effective" directly relates to getting cheaper and more affordable.', NULL, true),
  ('q_eng_p5', 'course_eng_01', 'skill_eng_listening', 'Audio context: "Please submit your homework before midnight, not tomorrow morning."', 'Speaker: "Remember, the deadline is tonight before 12:00 AM."', '["Before 12:00 AM tonight", "Tomorrow morning", "Next week", "Any time tomorrow"]'::jsonb, 0, 'hard', 'The speaker emphasizes the deadline is tonight before midnight.', NULL, true)
ON CONFLICT (id) DO UPDATE SET
  text = EXCLUDED.text,
  options = EXCLUDED.options;

-- 4. ROADMAP NODES
INSERT INTO public.roadmap_nodes (id, course_id, skill_id, title, description, prerequisites, required_score, is_reinforcement, target_lesson_id, estimated_minutes, order_index, is_active)
VALUES
  ('node_math_alg', 'course_math_01', 'skill_math_algebra', 'Algebra asoslari', 'Qisqa ko‘paytirish formulalari va ko‘phadlar ustida amallar.', '[]'::jsonb, 50, false, NULL, 15, 1.0, true),
  ('node_math_eq', 'course_math_01', 'skill_math_equations', 'Tenglamalar', 'Chiziqli tenglamalarni yechish qoidalari.', '["node_math_alg"]'::jsonb, 50, false, NULL, 20, 2.0, true),
  ('node_math_func', 'course_math_01', 'skill_math_functions', 'Funksiyalar', 'Funksiya tushunchasi, argument va natijani topish.', '["node_math_eq"]'::jsonb, 50, false, 'lesson_math_functions_01', 10, 3.0, true),
  ('node_math_graphs', 'course_math_01', 'skill_math_graphs', 'Grafiklar', 'Koordinata o‘qlarida funksiya grafiklarini chizish.', '["node_math_func"]'::jsonb, 70, false, NULL, 25, 4.0, true),

  ('node_eng_vocab', 'course_eng_01', 'skill_eng_vocab', 'Vocabulary', 'Akademik so‘z boyligi va asosiy iboralar.', '[]'::jsonb, 50, false, NULL, 15, 1.0, true),
  ('node_eng_gram', 'course_eng_01', 'skill_eng_grammar', 'Grammar', 'Shart ergash gaplar va murakkab tuzilmalar.', '["node_eng_vocab"]'::jsonb, 50, false, NULL, 20, 2.0, true),
  ('node_eng_list', 'course_eng_01', 'skill_eng_listening', 'Listening', 'Audio xabarlar va vaqt ko‘rsatkichlarini farqlash.', '["node_eng_gram"]'::jsonb, 50, false, 'lesson_eng_listening_01', 12, 3.0, true),
  ('node_eng_read', 'course_eng_01', 'skill_eng_reading', 'Reading', 'Matnni tahlil qilish va xulosa chiqarish.', '["node_eng_list"]'::jsonb, 70, false, NULL, 25, 4.0, true)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description;
