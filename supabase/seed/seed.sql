-- BilimYöl Smart Edu - Seed Data
-- Seed: courses, skills, questions, roadmap_nodes

-- 1. COURSES
INSERT INTO public.courses (id, title, subject, description, icon_name, primary_color_hex, secondary_color_hex, total_students_estimate, is_active)
VALUES
  ('course_math_01', 'Matematika', 'mathematics', 'Mantiqiy fikrlaş, masalalar va funksiyalarni çuqur mustahkamlaş kursi.', 'calculator', '#2563EB', '#3B82F6', 1420, true),
  ('course_eng_01', 'Ingliz tili', 'english', 'Luğat, grammatika, tinglab tuşuniş va öqiş könikmalarini rivojlantiriş.', 'headphones', '#14B8A6', '#0D9488', 1890, true),
  ('course_it', 'IT & Kodlaş', 'it', 'Dasturlaş asoslari, algoritmlar va axborot texnologiyalari kursi.', 'code', '#06B6D4', '#0891B2', 980, true),
  ('course_logic', 'Mantiq', 'logic', 'Mantiqiy fikrlaş, deduksiya va intellektual boşqotirmalar.', 'brain', '#10B981', '#059669', 850, true)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description;

-- 2. SKILLS
INSERT INTO public.skills (id, course_id, name, code, description, order_index, icon_name)
VALUES
  ('skill_math_algebra', 'course_math_01', 'Algebra asoslari', 'MATH-ALG', 'Qisqa köpaytiriş formulalari, köphadlar va amallar tartibi.', 1, 'percent'),
  ('skill_math_equations', 'course_math_01', 'Tenglamalar', 'MATH-EQ', 'Çiziqli va kvadrat tenglamalarni yeçiş usullari.', 2, 'equal'),
  ('skill_math_functions', 'course_math_01', 'Funksiyalar', 'MATH-FUNC', 'Funksiya tuşunçasi, argument va funksiya qiymatini hisoblaş.', 3, 'activity'),
  ('skill_math_graphs', 'course_math_01', 'Grafiklar', 'MATH-GRAPH', 'Koordinatalar tekisligida çiziqli va kvadratik funksiyalar grafigi.', 4, 'show_chart'),

  ('skill_eng_vocab', 'course_eng_01', 'Vocabulary', 'ENG-VOCAB', 'Akademik va kundalik söz boyligi, kontekstual iboralar.', 1, 'menu_book'),
  ('skill_eng_grammar', 'course_eng_01', 'Grammar', 'ENG-GRAM', 'Zamonlar, modal fe’llar va gap tuzilişi qoidalari.', 2, 'description'),
  ('skill_eng_listening', 'course_eng_01', 'Listening', 'ENG-LIST', 'Audio va suhbatlardagi asosiy ma’no va kalit sözlarni ilğaş.', 3, 'headphones'),
  ('skill_eng_reading', 'course_eng_01', 'Reading', 'ENG-READ', 'Matnni tahlil qiliş, asosiy ğoyani va detallarni topiş.', 4, 'chrome_reader_mode'),

  ('skill_it_python', 'course_it', 'Python asoslari', 'IT-PY', 'Özgaruvçilar, ma’lumot turlari, şart operatorlari va sikllar.', 1, 'code'),
  ('skill_it_web', 'course_it', 'Veb dasturlaş', 'IT-WEB', 'HTML struktura, CSS uslublar va sahifa elementlari bilan işlaş.', 2, 'public'),

  ('skill_logic_puzzles', 'course_logic', 'Mantiqiy boşqotirmalar', 'LOG-PUZ', 'Deduktiv xulosalar, şartli mulohazalar va mantiqiy jadvallar.', 1, 'psychology'),
  ('skill_logic_patterns', 'course_logic', 'Qonuniyatlar va ketma-ketliklar', 'LOG-PAT', 'Sonli va şakl qonuniyatlarini topiş, keyingi elementni aniqlaş.', 2, 'trending_up')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;

-- 3. QUESTIONS (Placement questions)
INSERT INTO public.questions (id, course_id, skill_id, text, context_snippet, options, correct_index, difficulty, explanation, formula_latex, is_placement)
VALUES
  ('q_math_p1', 'course_math_01', 'skill_math_algebra', 'Hisoblang: (a + 3)² ifodani soddalaştirganda qaysi natija töğri?', NULL, '["a² + 6a + 9", "a² + 9", "a² + 3a + 9", "2a + 6"]'::jsonb, 0, 'medium', 'Qisqa köpaytiriş formulasiga köra: (a + b)² = a² + 2ab + b² = a² + 6a + 9.', '(a + 3)^2', true),
  ('q_math_p2', 'course_math_01', 'skill_math_equations', 'Tenglamani yeçing: 3x - 5 = 16. x ning qiymati neçaga teng?', NULL, '["x = 7", "x = 5", "x = 8", "x = 6"]'::jsonb, 0, 'easy', '3x = 16 + 5 => 3x = 21 => x = 7.', '3x - 5 = 16', true),
  ('q_math_p3', 'course_math_01', 'skill_math_functions', 'Agar f(x) = x² - 4x + 1 bölsa, f(3) ning qiymatini toping.', NULL, '["-2", "4", "1", "-1"]'::jsonb, 0, 'hard', 'f(3) = 3² - 4(3) + 1 = 9 - 12 + 1 = -2.', 'f(3) = 3^2 - 4(3) + 1', true),
  ('q_math_p4', 'course_math_01', 'skill_math_graphs', 'y = 2x - 4 töğri çiziği Oy öqini qaysi nuqtada kesib ötadi?', NULL, '["(0, -4)", "(2, 0)", "(0, 4)", "(-4, 0)"]'::jsonb, 0, 'medium', 'Oy öqi bilan kesişişda x = 0 böladi: y = 2(0) - 4 = -4. Nuqta: (0, -4).', 'y = 2x - 4', true),
  ('q_math_p5', 'course_math_01', 'skill_math_functions', 'Agar f(x) = 5 - 2x funksiya berilgan bölsa, qaysi x da f(x) = 1 böladi?', NULL, '["x = 2", "x = -2", "x = 3", "x = 1"]'::jsonb, 0, 'hard', '5 - 2x = 1 => 2x = 4 => x = 2.', '5 - 2x = 1', true),

  ('q_eng_p1', 'course_eng_01', 'skill_eng_vocab', 'Choose the best synonym for the word "Essential":', NULL, '["Crucial", "Optional", "Dangerous", "Rare"]'::jsonb, 0, 'easy', '"Essential" means absolutely necessary or crucial.', NULL, true),
  ('q_eng_p2', 'course_eng_01', 'skill_eng_grammar', 'Complete the sentence: "If she ____ harder, she would pass the exam."', NULL, '["studied", "studies", "has studied", "will study"]'::jsonb, 0, 'medium', 'Second Conditional structure: If + Past Simple, would + Verb.', NULL, true),
  ('q_eng_p3', 'course_eng_01', 'skill_eng_listening', 'Audio context: "We decided to postpone the conference from Tuesday to Friday."', 'Speaker: "Due to schedule conflicts, the conference is postponed to Friday."', '["The conference is on Friday", "The conference is on Tuesday", "The conference is canceled", "The conference is next month"]'::jsonb, 0, 'hard', 'The speaker explicitly states the conference was moved to Friday.', NULL, true),
  ('q_eng_p4', 'course_eng_01', 'skill_eng_reading', 'Read the sentence: "Renewable energy sources are becoming more cost-effective each year."', 'What is the main idea?', '["Clean energy is getting cheaper to produce", "Fossil fuels are disappearing", "Renewable energy is too expensive", "Solar panels are rare"]'::jsonb, 0, 'medium', '"Cost-effective" directly relates to getting cheaper and more affordable.', NULL, true),
  ('q_eng_p5', 'course_eng_01', 'skill_eng_listening', 'Audio context: "Please submit your homework before midnight, not tomorrow morning."', 'Speaker: "Remember, the deadline is tonight before 12:00 AM."', '["Before 12:00 AM tonight", "Tomorrow morning", "Next week", "Any time tomorrow"]'::jsonb, 0, 'hard', 'The speaker emphasizes the deadline is tonight before midnight.', NULL, true),

  -- IT & CODING placement bank (2+ per skill)
  ('q_it_py_01', 'course_it', 'skill_it_python', 'Python’da özgaruvçi e’lon qilişning töğri usuli qaysi?', NULL, '["x = 10", "int x = 10", "var x = 10", "let x = 10"]'::jsonb, 0, 'easy', 'Python’da özgaruvçi turini oldindan yoziş şart emas — `x = 10` deb yoziladi.', NULL, true),
  ('q_it_py_02', 'course_it', 'skill_it_python', 'Quyidagi kodning natijasi nima? `print(3 * "ab")`', NULL, '["ababab", "ab3", "3ab", "33ab"]'::jsonb, 0, 'easy', 'Python’da satrni songa köpaytiriş uni takrorlaydi: 3 * "ab" = "ababab".', NULL, true),
  ('q_it_py_03', 'course_it', 'skill_it_python', '`range(5)` qanday qiymatlar ketma-ketligini hosil qiladi?', NULL, '["0,1,2,3,4", "1,2,3,4,5", "0,1,2,3,4,5", "5,4,3,2,1"]'::jsonb, 0, 'medium', '`range(5)` 0 dan 4 gaça (5 kirmaydi) sonlar ketma-ketligini beradi.', NULL, true),
  ('q_it_py_04', 'course_it', 'skill_it_python', 'Quyidagi `for` sikli neça marta işlaydi? `for i in range(3):`', NULL, '["3 marta", "2 marta", "4 marta", "Çeksiz"]'::jsonb, 0, 'medium', '`range(3)` → 0,1,2 — ya’ni 3 marta takrorlanadi.', NULL, true),

  ('q_it_web_01', 'course_it', 'skill_it_web', 'HTML’da eng katta sarlavha teği qaysi?', NULL, '["<h1>", "<h6>", "<head>", "<title>"]'::jsonb, 0, 'easy', '`<h1>` — eng yuqori darajadagi (eng katta) sarlavha teği.', NULL, true),
  ('q_it_web_02', 'course_it', 'skill_it_web', 'Matn rangini özgartiruvçi CSS xossasi qaysi?', NULL, '["color", "font-color", "text-color", "background"]'::jsonb, 0, 'easy', 'CSS’da matn rangi `color` xossasi bilan belgilanadi.', NULL, true),
  ('q_it_web_03', 'course_it', 'skill_it_web', 'Giperhavola (link) yaratiş uçun qaysi HTML teği işlatiladi?', NULL, '["<a>", "<link>", "<href>", "<url>"]'::jsonb, 0, 'medium', '`<a href="...">` teği giperhavola yaratadi.', NULL, true),
  ('q_it_web_04', 'course_it', 'skill_it_web', 'Elementga öng tomondan 20px masofa beruvçi CSS xossasi qaysi?', NULL, '["margin-right: 20px", "padding-right: 20px", "right: 20px", "spacing-right: 20px"]'::jsonb, 0, 'medium', 'Taşqi masofa `margin` bilan beriladi: `margin-right`.', NULL, true),

  -- LOGIC placement bank
  ('q_logic_puz_01', 'course_logic', 'skill_logic_puzzles', 'Barça quşlar uçadi. Çumçu quş. Xulosa nima?', NULL, '["Çumçu uçadi", "Çumçu uça olmaydi", "Xulosa çiqarib bölmaydi", "Barça quşlar çumçu"]'::jsonb, 0, 'easy', 'Deduktiv xulosa: barça quşlar uçsa va çumçu quş bölsa, çumçu ham uçadi.', NULL, true),
  ('q_logic_puz_02', 'course_logic', 'skill_logic_puzzles', 'Ali Vali’dan katta. Vali Olim’dan katta. Kim eng kiçik?', NULL, '["Olim", "Vali", "Ali", "Aniqlab bölmaydi"]'::jsonb, 0, 'easy', 'Zanjir: Ali > Vali > Olim — eng kiçigi Olim.', NULL, true),
  ('q_logic_puz_03', 'course_logic', 'skill_logic_puzzles', 'Agar yomğir yoğsa, köça höl böladi. Köça höl emas. Nima deyiş mumkin?', NULL, '["Yomğir yoğmadi", "Yomğir yoğdi", "Köça quruq edi", "Xulosa yöq"]'::jsonb, 0, 'medium', 'Modus tollens: P→Q, ¬Q ⇒ ¬P. Yomğir yoğmagan.', NULL, true),
  ('q_logic_puz_04', 'course_logic', 'skill_logic_puzzles', 'Uç döst — Ali, Vali, Olim — navbatda turişdi. Ali eng oldinda emas. Vali eng oxirida ham emas. Olim Vali’dan keyin. Tartib qanday?', NULL, '["Vali – Ali – Olim", "Ali – Vali – Olim", "Olim – Vali – Ali", "Vali – Olim – Ali"]'::jsonb, 0, 'hard', 'Olim oxirida (Vali’dan keyin). Ali oldinda emas → 2-örinda. Vali esa oxirida emas va Olim’dan oldin → 1-örinda. Javob: Vali – Ali – Olim.', NULL, true),

  ('q_logic_pat_01', 'course_logic', 'skill_logic_patterns', 'Ketma-ketlikdagi keyingi son: 3, 6, 12, 24, ...', NULL, '["48", "36", "30", "42"]'::jsonb, 0, 'easy', 'Har bir son oldingisidan 2 baravar: 24 × 2 = 48.', NULL, true),
  ('q_logic_pat_02', 'course_logic', 'skill_logic_patterns', 'Ketma-ketlikdagi keyingi son: 5, 9, 17, 33, ...', NULL, '["65", "49", "60", "66"]'::jsonb, 0, 'medium', 'Qonuniyat: har son oldingisidan 2×−1 → 33×2−1=65.', NULL, true),
  ('q_logic_pat_03', 'course_logic', 'skill_logic_patterns', 'Kvadratlar ketma-ketligi: 1, 4, 9, 16, 25, ... keyingi son?', NULL, '["36", "30", "35", "49"]'::jsonb, 0, 'medium', 'n² ketma-ketligi: 1²,2²,3²,4²,5²,6²=36.', NULL, true),
  ('q_logic_pat_04', 'course_logic', 'skill_logic_patterns', 'Ketma-ketlik: 2, 3, 5, 9, 17, ... keyingi son?', NULL, '["33", "26", "31", "25"]'::jsonb, 0, 'hard', 'Har son = oldingisi×2−1: 2→3, 3→5, 5→9, 9→17, 17→33.', NULL, true)
ON CONFLICT (id) DO UPDATE SET
  text = EXCLUDED.text,
  options = EXCLUDED.options;

-- 4. ROADMAP NODES
INSERT INTO public.roadmap_nodes (id, course_id, skill_id, title, description, prerequisites, required_score, is_reinforcement, target_lesson_id, estimated_minutes, order_index, is_active)
VALUES
  ('node_math_alg', 'course_math_01', 'skill_math_algebra', 'Algebra asoslari', 'Qisqa köpaytiriş formulalari va köphadlar ustida amallar.', '[]'::jsonb, 50, false, NULL, 15, 1.0, true),
  ('node_math_eq', 'course_math_01', 'skill_math_equations', 'Tenglamalar', 'Çiziqli tenglamalarni yeçiş qoidalari.', '["node_math_alg"]'::jsonb, 50, false, NULL, 20, 2.0, true),
  ('node_math_func', 'course_math_01', 'skill_math_functions', 'Funksiyalar', 'Funksiya tuşunçasi, argument va natijani topiş.', '["node_math_eq"]'::jsonb, 50, false, 'lesson_math_functions_01', 10, 3.0, true),
  ('node_math_graphs', 'course_math_01', 'skill_math_graphs', 'Grafiklar', 'Koordinata öqlarida funksiya grafiklarini çiziş.', '["node_math_func"]'::jsonb, 70, false, NULL, 25, 4.0, true),

  ('node_eng_vocab', 'course_eng_01', 'skill_eng_vocab', 'Vocabulary', 'Akademik söz boyligi va asosiy iboralar.', '[]'::jsonb, 50, false, NULL, 15, 1.0, true),
  ('node_eng_gram', 'course_eng_01', 'skill_eng_grammar', 'Grammar', 'Şart ergaş gaplar va murakkab tuzilmalar.', '["node_eng_vocab"]'::jsonb, 50, false, NULL, 20, 2.0, true),
  ('node_eng_list', 'course_eng_01', 'skill_eng_listening', 'Listening', 'Audio xabarlar va vaqt körsatkiçlarini farqlaş.', '["node_eng_gram"]'::jsonb, 50, false, 'lesson_eng_listening_01', 12, 3.0, true),
  ('node_eng_read', 'course_eng_01', 'skill_eng_reading', 'Reading', 'Matnni tahlil qiliş va xulosa çiqariş.', '["node_eng_list"]'::jsonb, 70, false, NULL, 25, 4.0, true),

  -- IT & CODING path
  ('node_it_python', 'course_it', 'skill_it_python', 'Python asoslari', 'Özgaruvçilar, ma’lumot turlari va oddiy algoritmlar.', '[]'::jsonb, 50, false, 'lesson_it_python_01', 15, 1.0, true),
  ('node_it_web', 'course_it', 'skill_it_web', 'Veb sahifa tuzilişi', 'HTML teglar, CSS uslublar va sahifa elementlarini joylaştiriş.', '["node_it_python"]'::jsonb, 50, false, 'lesson_it_web_01', 20, 2.0, true),

  -- LOGIC path
  ('node_logic_puzzles', 'course_logic', 'skill_logic_puzzles', 'Mantiqiy boşqotirmalar', 'Deduktiv xulosalar va şartli mulohazalarni yeçiş.', '[]'::jsonb, 50, false, 'lesson_logic_puzzles_01', 15, 1.0, true),
  ('node_logic_patterns', 'course_logic', 'skill_logic_patterns', 'Qonuniyatlar', 'Sonli va şakl qonuniyatlarini topiş va davom ettiriş.', '["node_logic_puzzles"]'::jsonb, 50, false, 'lesson_logic_patterns_01', 18, 2.0, true)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description
WHERE roadmap_nodes.course_id <> 'course_math_01';
