BEGIN;

INSERT INTO public.skills (id, course_id, name, code, description, order_index, icon_name)
VALUES
  ('skill_math_addition', 'course_math_01', 'Qo‘shish va ayirish', 'MATH_ADD', 'Miqdorlarni birlashtirish va farqni topish.', -2, 'calculator'),
  ('skill_math_multiplication', 'course_math_01', 'Teng guruhlar', 'MATH_MUL', 'Teng miqdorlarni takror qo‘shish va ko‘paytirish.', -1, 'calculator');

-- Old attempts retain their original context. New assessments use the
-- individual foundation skills instead of aggregating them under algebra.
UPDATE public.lessons SET skill_id = 'skill_math_addition'
WHERE id = 'lesson_math_starter' AND course_id = 'course_math_01';
UPDATE public.lessons SET skill_id = 'skill_math_multiplication'
WHERE id = 'lesson_math_foundation_02' AND course_id = 'course_math_01';

INSERT INTO public.questions (id, course_id, skill_id, text, options, correct_index, difficulty, explanation, is_placement)
VALUES
  ('q_math_pilot_place_add_01', 'course_math_01', 'skill_math_addition',
    '2 ta daftar yoniga yana 3 ta daftar qo‘yildi. Jami nechta?', '["4","5","6"]', 1, 'easy', '2 + 3 = 5.', true),
  ('q_math_pilot_place_add_02', 'course_math_01', 'skill_math_addition',
    '8 ta qalamdan 3 tasi olindi. Nechta qoldi?', '["5","6","11"]', 0, 'easy', '8 − 3 = 5.', true),
  ('q_math_pilot_place_mul_01', 'course_math_01', 'skill_math_multiplication',
    'Ikkita qutining har birida 3 tadan kubik bor. Jami nechta?', '["5","9","6"]', 2, 'easy', '3 + 3 = 6.', true),
  ('q_math_pilot_place_mul_02', 'course_math_01', 'skill_math_multiplication',
    '4 + 4 + 4 yig‘indisi qaysi ifodaga teng?', '["3 × 4","3 + 4","4 × 4"]', 0, 'easy', '4 soni 3 marta qo‘shilgan.', true);

-- Use the same bank for both question selection and session length. The revision
-- hash in advance_placement restarts an unfinished session with a changed bank.
CREATE OR REPLACE VIEW bilimyol_private.placement_question_bank AS
SELECT q.* FROM public.questions q
WHERE q.is_placement AND NOT EXISTS (
  SELECT 1 FROM bilimyol_private.demo_placement_question_ids demo WHERE demo.question_id = q.id
) AND (q.course_id <> 'course_math_01' OR q.id IN (
  'q_math_pilot_place_add_01', 'q_math_pilot_place_add_02',
  'q_math_pilot_place_mul_01', 'q_math_pilot_place_mul_02'
));

INSERT INTO public.lessons (id, course_id, skill_id, title, summary, estimated_minutes, steps, is_published, is_archived)
VALUES ('lesson_math_expressions_intro', 'course_math_01', 'skill_math_algebra', 'Harfli ifodalar va qavslar',
  'Harf o‘rniga son qo‘ying va qavs oldidagi ko‘paytuvchini har bir hadga qo‘llang.', 9,
  '[
    {"id":"math_expr_recap","stepNumber":1,"type":"concept","title":"Maqsad va tayanch","content":"Harf son o‘rnini bildirishi mumkin. Masalan, x = 3 bo‘lsa, 2x ikki guruhda uchtadan degani: 2 × 3 = 6."},
    {"id":"math_expr_example","stepNumber":2,"type":"visual_example","title":"Ishlangan misol","content":"2(x + 1) ikki marta (x + 1) olishdir. Yozib ochamiz: (x + 1) + (x + 1) = 2x + 2. x = 3 bo‘lganda ikkala ko‘rinish ham 8 beradi."}
  ]', true, false);

INSERT INTO public.roadmap_nodes
  (id, course_id, skill_id, title, description, prerequisites, required_score, target_lesson_id, estimated_minutes, order_index)
VALUES
  ('node_math_addition', 'course_math_01', 'skill_math_addition', 'Qo‘shish va ayirish',
    'Birlashtirish va ayrim qismini olib tashlashni sonlar bilan ifodalang.', '[]', 80, 'lesson_math_starter', 8, 10),
  ('node_math_multiplication', 'course_math_01', 'skill_math_multiplication', 'Teng guruhlar va ko‘paytirish',
    'Teng guruhlarni takroriy qo‘shish va ko‘paytirish bilan ifodalang.', '["node_math_addition"]', 80, 'lesson_math_foundation_02', 8, 20),
  ('node_math_expressions', 'course_math_01', 'skill_math_algebra', 'Harfli ifodalar va qavslar',
    'Harf o‘rniga son qo‘ying va qavsni taqsimot qonuni bilan oching.', '["node_math_multiplication"]', 80, 'lesson_math_expressions_intro', 9, 30);

UPDATE public.roadmap_nodes AS n
SET prerequisites = change.prerequisites, order_index = change.position, required_score = 80,
    description = change.objective,
    title = CASE WHEN n.id = 'node_math_alg' THEN 'Qavs kvadrati' ELSE n.title END
FROM (VALUES
  ('node_math_eq', '["node_math_expressions"]'::jsonb, 40, 'Tenglikni saqlab, bitta noma’lumli chiziqli tenglamani yeching.'),
  ('node_math_func', '["node_math_eq"]'::jsonb, 50, 'Berilgan kirish qiymatiga funksiya qoidasini qo‘llang.'),
  ('node_math_graphs', '["node_math_func"]'::jsonb, 60, 'Chiziqli grafikning koordinata o‘qlari bilan kesishish nuqtalarini toping.'),
  ('node_math_alg', '["node_math_expressions"]'::jsonb, 70, 'Qavs kvadratini yoying va aralash hadning ishorasini aniqlang.')
) AS change(id, prerequisites, position, objective)
WHERE n.id = change.id AND n.course_id = 'course_math_01';

-- Each row is a reviewed, original assessment item. The first three positions
-- apply the concept. The two following the recap require recalling the rule.
WITH authored(lesson_id, items) AS (VALUES
  ('lesson_math_starter', '[
    ["4 ta ko‘k va 3 ta oq tugma bor. Jami nechta tugma?","7|1|12",0,"Ikki guruhni birlashtiring: 4 + 3 = 7."],
    ["9 ta chiptadan 4 tasi ishlatildi. Nechta chipta qoldi?","13|4|5",2,"Qolganini topish uchun 9 dan 4 ni ayiring: 9 − 4 = 5."],
    ["6 + 2 bilan qaysi vaziyatni ifodalaysiz?","6 tadan 2 tasi olindi|6 toshga 2 tosh qo‘shildi|2 guruhda 6 tadan tosh bor",1,"Qo‘shish ikkita miqdorni birlashtiradi."],
    ["Qaysi amal 11 tadan 3 tasi ketganini bildiradi?","11 + 3|3 − 11|11 − 3",2,"Boshlang‘ich 11 tadan olib tashlangan 3 tani ayiramiz."],
    ["Bir qutida 5 ta, ikkinchisida 4 ta bo‘lak bo‘r bor. Jami nechta?","9|1|10",0,"Jami 5 + 4 = 9 ta bo‘lak."]
  ]'::jsonb),
  ('lesson_math_foundation_02', '[
    ["Uchta tokchaning har birida 4 tadan kitob bor. Jami nechta?","7|12|16",1,"To‘rttani uch marta qo‘shing: 4 + 4 + 4 = 12."],
    ["2 + 2 + 2 + 2 + 2 ni ko‘paytirish shaklida yozing.","5 × 2|5 + 2|2 × 2",0,"2 soni 5 marta uchraydi, ya’ni 5 × 2."],
    ["3 × 5 qaysi vaziyatga mos?","3 va 5 ta buyumni ajratish|5 tadan buyumli 3 ta guruh|3 ta buyumga 5 ta qo‘shish",1,"Bu yozuv 5 + 5 + 5 ni ifodalaydi."],
    ["4 ta konvertning har birida 3 tadan belgi bor. Jami nechta?","7|9|12",2,"3 + 3 + 3 + 3 = 12."],
    ["Nega 3 + 4 + 4 ni 3 × 4 shaklida yozib bo‘lmaydi?","Guruhlar soni noma’lum|Guruhlarning miqdori teng emas|4 soni juda katta",1,"Birinchi guruhda 3 ta, keyingilarida 4 tadan. Takroriy qo‘shishda guruhlar teng bo‘ladi."]
  ]'::jsonb),
  ('lesson_math_expressions_intro', '[
    ["x = 4 bo‘lsa, 3x nechaga teng?","7|12|34",1,"3x = 3 × 4 = 12."],
    ["2(x + 4) ni qavssiz yozing.","2x + 4|x + 8|2x + 8",2,"2 ni x ga ham, 4 ga ham ko‘paytiring."],
    ["x = 5 bo‘lsa, x + 6 qiymati nechaga teng?","11|30|56",0,"x o‘rniga 5 qo‘ying: 5 + 6 = 11."],
    ["3(x − 2) ni qavssiz yozing.","3x − 2|3x − 6|x − 6",1,"Ikkala had 3 ga ko‘payadi. Ikkinchi had −6 bo‘ladi."],
    ["x = 2 bo‘lsa, 4(x + 1) qancha?","8|9|12",2,"Avval 2 + 1 = 3, so‘ng 4 × 3 = 12."]
  ]'::jsonb),
  ('lesson_math_equations_01', '[
    ["x + 6 = 14 bo‘lsa, x qancha?","8|20|6",0,"Ikki tomondan 6 ni ayiring: x = 8."],
    ["3x = 18 bo‘lsa, x qancha?","15|6|54",1,"Ikki tomonni 3 ga bo‘ling: x = 6."],
    ["2x + 5 = 17 tenglamasida avval nima qilasiz?","Faqat o‘ngdan 5 ni ayiraman|Ikkala tomonga 5 qo‘shaman|Ikkala tomondan 5 ni ayiraman",2,"Bir xil amal tenglikni saqlaydi va chapda 2x qoladi."],
    ["4x − 3 = 13 tenglamasini yeching.","4|2|16",0,"Ikkala tomonga 3 qo‘shsak 4x = 16. 4 ga bo‘lsak x = 4."],
    ["Qaysi qiymat 5x + 1 = 16 ni qanoatlantiradi?","5|3|4",1,"x = 3 ni tekshiring: 5 × 3 + 1 = 16."]
  ]'::jsonb),
  ('lesson_math_functions_01', '[
    ["f(x) = x + 4 bo‘lsa, f(3) qancha?","12|7|1",1,"x o‘rniga 3 qo‘ying: 3 + 4 = 7."],
    ["g(x) = 2x − 1 bo‘lsa, g(4) qancha?","6|8|7",2,"2 × 4 − 1 = 7."],
    ["Funksiya bitta kirishga nechta chiqish moslaydi?","Aynan bitta|Kamida ikkita|Istalgancha",0,"Har bir kirishga yagona chiqish mos keladi."],
    ["h(x) = 5 − x bo‘lsa, h(2) qancha?","7|3|10",1,"5 − 2 = 3."],
    ["f(x) = 3x + 2 uchun x = 2 bo‘lganda (x, f(x)) qaysi?","(2, 7)|(8, 2)|(2, 8)",2,"f(2) = 6 + 2 = 8. Avval kirish, keyin chiqish yoziladi."]
  ]'::jsonb),
  ('lesson_math_functions_03', '[
    ["y = x + 4 grafigi y o‘qini qayerda kesadi?","(4, 0)|(0, 4)|(0, −4)",1,"y o‘qida x = 0, shuning uchun y = 4."],
    ["y = x − 3 grafigi x o‘qini qayerda kesadi?","(0, −3)|(−3, 0)|(3, 0)",2,"x o‘qida y = 0. x − 3 = 0 dan x = 3."],
    ["x o‘qidagi nuqtada qaysi koordinata nol?","y|x|Har doim ikkalasi",0,"x o‘qi bo‘ylab vertikal siljish yo‘q, ya’ni y = 0."],
    ["y = 2x + 6 grafigi x o‘qini qayerda kesadi?","(−3, 0)|(3, 0)|(0, 6)",0,"0 = 2x + 6 dan 2x = −6 va x = −3."],
    ["y = −x − 2 grafigi y o‘qini qayerda kesadi?","(−2, 0)|(0, −2)|(0, 2)",1,"x = 0 ni qo‘ying: y = −2."]
  ]'::jsonb),
  ('lesson_math_algebra_01', '[
    ["(x + 2)² yoyilmasi qaysi?","x² + 4|x² + 4x + 4|x² + 2x + 4",1,"(x + 2)(x + 2) da ikkita 2x hadi bor."],
    ["(x − 3)² yoyilmasida x oldidagi koeffitsiyent nechaga teng?","−3|6|−6",2,"Aralash hadlar −3x va −3x, yig‘indisi −6x."],
    ["(a + b)² formuladagi 2ab qayerdan keladi?","ab + ba yig‘indisidan|a² + b² yig‘indisidan|Faqat b ni kvadratlashdan",0,"Qavslarni ko‘paytirish ikkita bir xil aralash had beradi."],
    ["(y + 5)² yoyilmasining o‘zgarmas hadi nechaga teng?","10|25|5",1,"O‘zgarmas had 5 × 5 = 25."],
    ["(2x + 1)² yoyilmasi qaysi?","4x² + 2x + 1|2x² + 4x + 1|4x² + 4x + 1",2,"(2x)² = 4x², aralash had 2 × 2x × 1 = 4x, oxirgi had 1."]
  ]'::jsonb)
), retained_steps AS (
  SELECT l.id, step.value, step.ordinality * 10 AS position
  FROM public.lessons l JOIN authored a ON a.lesson_id = l.id
  CROSS JOIN LATERAL jsonb_array_elements(l.steps) WITH ORDINALITY AS step(value, ordinality)
  WHERE step.value->>'type' IS DISTINCT FROM 'interactive_question'
), new_steps AS (
  SELECT a.lesson_id AS id, 100 + q.ordinality * 10 AS position, jsonb_build_object(
    'id', a.lesson_id || '_pilot_' || q.ordinality,
    'type', 'interactive_question',
    'title', CASE WHEN q.ordinality <= 3 THEN 'Mustaqil mashq' ELSE 'Eslab qo‘llang' END,
    'content', CASE WHEN q.ordinality <= 3 THEN 'Qoidadan foydalanib javobni tanlang.' ELSE 'Qoidani xotiradan eslab, yangi misolda qo‘llang.' END,
    'masteryCheckpoint', CASE WHEN q.ordinality <= 3 THEN 'application' ELSE 'retrieval' END,
    'interactiveQuestion', jsonb_build_object(
      'id', 'q_pilot_' || a.lesson_id || '_' || q.ordinality,
      'text', q.value->>0, 'options', to_jsonb(string_to_array(q.value->>1, '|')),
      'correctIndex', (q.value->>2)::int, 'explanation', q.value->>3,
      'difficulty', CASE
        WHEN l.id IN ('lesson_math_starter', 'lesson_math_foundation_02', 'lesson_math_expressions_intro') THEN 'easy'
        WHEN l.id = 'lesson_math_algebra_01' THEN 'hard'
        ELSE 'medium'
      END
    )
  ) AS value
  FROM authored a JOIN public.lessons l ON l.id = a.lesson_id
  CROSS JOIN LATERAL jsonb_array_elements(a.items) WITH ORDINALITY AS q(value, ordinality)
  UNION ALL
  SELECT guide.lesson_id, 90, jsonb_build_object(
    'id', guide.lesson_id || '_pilot_guided', 'type', 'visual_example', 'title', 'Birga mashq qilamiz', 'content', guide.content
  )
  FROM (VALUES
    ('lesson_math_starter', '7 ta katakdan 2 tasini o‘chiring. Qolganini sanash uchun 7 dan orqaga ikki qadam yuring: 6, 5. Endi 5 + 2 ni hisoblab, tekshiring.'),
    ('lesson_math_foundation_02', 'Ikki qator chizing va har biriga 4 ta nuqta qo‘ying. Avval 4 + 4 deb sanang, keyin shu jami miqdorni 2 × 4 shaklida yozing.'),
    ('lesson_math_expressions_intro', '3(x + 2) ni ochish uchun avval x ni, keyin 2 ni uch marta oling. Natijani 3x + 6 deb yozing va x = 1 bilan tekshiring.')
  ) guide(lesson_id, content)
  UNION ALL
  SELECT a.lesson_id, 135, jsonb_build_object(
    'id', a.lesson_id || '_pilot_recall', 'type', 'concept', 'title', 'Qoidani eslang',
    'content', 'Misolni yopib, hozir qo‘llagan qoidangizni o‘z so‘zingiz bilan ayting. Keyingi ikki savolda uni yangi vaziyatda qo‘llaysiz.'
  )
  FROM authored a
  UNION ALL
  SELECT a.lesson_id, 160, jsonb_build_object(
    'id', a.lesson_id || '_pilot_finish', 'type', 'concept', 'title', 'Darsni yakunlash',
    'content', 'Ikki tekshiruvdagi javoblaringiz asosida mavzu holati yangilanadi. Qiyin joy qolgan bo‘lsa, ishlangan misolga qaytib, keyin yana sinab ko‘ring.'
  )
  FROM authored a
), numbered AS (
  SELECT id, value, row_number() OVER (PARTITION BY id ORDER BY position) AS number
  FROM (
    SELECT id, value, position FROM retained_steps
    UNION ALL SELECT id, value, position FROM new_steps
  ) AS all_steps
), packed AS (
  SELECT id, jsonb_agg(value || jsonb_build_object('stepNumber', number) ORDER BY number) AS steps
  FROM numbered GROUP BY id
)
UPDATE public.lessons l
SET steps = packed.steps, updated_at = now()
FROM packed
WHERE l.id = packed.id AND l.course_id = 'course_math_01';

CREATE VIEW bilimyol_private.math_pilot_policy AS
SELECT 80 AS min_accuracy, 5 AS min_items, 2 AS min_checkpoints, interval '7 days' AS review_interval;

CREATE VIEW bilimyol_private.math_pilot_objectives AS
SELECT n.*, n.id = 'node_math_alg' AS is_optional
FROM public.roadmap_nodes n
JOIN public.lessons l ON l.id = n.target_lesson_id AND l.course_id = n.course_id
WHERE n.course_id = 'course_math_01' AND n.is_active AND NOT n.is_reinforcement
  AND l.is_published AND NOT l.is_archived
  AND n.id IN ('node_math_addition', 'node_math_multiplication', 'node_math_expressions',
    'node_math_eq', 'node_math_func', 'node_math_graphs', 'node_math_alg');

CREATE VIEW bilimyol_private.math_pilot_items AS
SELECT l.id AS lesson_id, l.skill_id, step->>'masteryCheckpoint' AS checkpoint,
  step->'interactiveQuestion'->>'id' AS question_id
FROM bilimyol_private.math_pilot_objectives n
JOIN public.lessons l ON l.id = n.target_lesson_id
CROSS JOIN LATERAL jsonb_array_elements(l.steps) AS step
WHERE step->>'masteryCheckpoint' IN ('application', 'retrieval')
  AND starts_with(step->'interactiveQuestion'->>'id', 'q_pilot_' || l.id || '_');

DO $$
BEGIN
  IF (SELECT count(*) FROM bilimyol_private.math_pilot_objectives) <> 7 OR EXISTS (
    SELECT 1 FROM bilimyol_private.math_pilot_objectives n
    JOIN public.lessons l ON l.id = n.target_lesson_id
    JOIN public.skills s ON s.id = n.skill_id
    CROSS JOIN bilimyol_private.math_pilot_policy p
    WHERE s.course_id <> n.course_id
      OR n.skill_id <> l.skill_id
      OR (n.id <> 'node_math_addition' AND jsonb_array_length(n.prerequisites) = 0)
      OR EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(n.prerequisites) AS dep(id)
        LEFT JOIN bilimyol_private.math_pilot_objectives parent ON parent.id = dep.id
        WHERE parent.id IS NULL OR parent.order_index >= n.order_index OR parent.is_optional
      )
      OR (
        SELECT count(DISTINCT item.question_id) < p.min_items OR count(DISTINCT item.checkpoint) < p.min_checkpoints
        FROM bilimyol_private.math_pilot_items item WHERE item.lesson_id = l.id
      )
  ) OR EXISTS (
    SELECT question_id FROM bilimyol_private.math_pilot_items GROUP BY question_id HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Matematika pilotining dars, bog‘liqlik yoki savol xaritasi noto‘g‘ri.';
  END IF;
END;
$$;

CREATE FUNCTION bilimyol_private.math_progression(p_uid UUID)
RETURNS TABLE (
  id TEXT, course_id TEXT, skill_id TEXT, title TEXT, description TEXT, prerequisites JSONB,
  target_lesson_id TEXT, estimated_minutes INT, order_index NUMERIC, status TEXT, mastery_state TEXT,
  answered INT, correct INT, required_items INT, required_score INT, passed_checkpoints INT,
  required_checkpoints INT, review_due BOOLEAN, is_optional BOOLEAN
)
LANGUAGE sql STABLE SET search_path = ''
AS $$
  WITH RECURSIVE objectives AS MATERIALIZED (
    SELECT * FROM bilimyol_private.math_pilot_objectives
  ), dependencies AS (
    SELECT n.id AS target_id, parent.id AS ancestor_id
    FROM objectives n
    CROSS JOIN LATERAL jsonb_array_elements_text(n.prerequisites) AS parent(id)
    UNION
    SELECT d.target_id, parent.id
    FROM dependencies d JOIN objectives n ON n.id = d.ancestor_id
    CROSS JOIN LATERAL jsonb_array_elements_text(n.prerequisites) AS parent(id)
  ), evidence AS (
    SELECT item.lesson_id,
      count(a.id)::INT AS answered,
      count(a.id) FILTER (WHERE a.is_correct)::INT AS correct,
      count(DISTINCT item.checkpoint) FILTER (WHERE a.is_correct)::INT AS checkpoints,
      min(a.created_at) FILTER (WHERE item.checkpoint = 'retrieval') AS last_retrieval
    FROM bilimyol_private.math_pilot_items item
    LEFT JOIN LATERAL (
      SELECT attempt.id, attempt.is_correct, attempt.created_at
      FROM public.answer_attempts attempt
      WHERE attempt.user_id = p_uid AND attempt.course_id = 'course_math_01'
        AND attempt.skill_id = item.skill_id AND attempt.lesson_id = item.lesson_id
        AND attempt.question_id = item.question_id
      ORDER BY attempt.created_at DESC, attempt.id DESC LIMIT 1
    ) a ON true
    GROUP BY item.lesson_id
  ), evaluated AS MATERIALIZED (
    SELECT n.*, COALESCE(e.answered, 0) AS answered, COALESCE(e.correct, 0) AS correct,
      COALESCE(e.checkpoints, 0) AS checkpoints, e.last_retrieval,
      p.min_items, p.min_accuracy, p.min_checkpoints, p.review_interval,
      COALESCE(e.answered >= p.min_items AND 100 * e.correct >= p.min_accuracy * e.answered
        AND e.checkpoints >= p.min_checkpoints, false) AS mastered,
      EXISTS (
        SELECT 1 FROM public.lesson_progress lp
        WHERE lp.user_id = p_uid AND lp.course_id = n.course_id AND lp.lesson_id = n.target_lesson_id
          AND lp.status = 'completed'
      ) AS previously_completed
    FROM objectives n CROSS JOIN bilimyol_private.math_pilot_policy p
    LEFT JOIN evidence e ON e.lesson_id = n.target_lesson_id
  ), resolved AS (
    SELECT n.*, NOT EXISTS (
      SELECT 1
      FROM dependencies d LEFT JOIN evaluated parent ON parent.id = d.ancestor_id
      WHERE d.target_id = n.id AND (parent.mastered IS DISTINCT FROM true OR parent.order_index >= n.order_index)
    ) AS eligible,
    NOT n.mastered AND (n.answered - n.correct >= 2 OR n.previously_completed) AS needs_review
    FROM evaluated n
  )
  SELECT n.id, n.course_id, n.skill_id, n.title, n.description, n.prerequisites,
    n.target_lesson_id, n.estimated_minutes, n.order_index,
    CASE WHEN NOT n.eligible THEN 'locked' WHEN n.mastered THEN 'completed'
      WHEN n.needs_review THEN 'reinforcement' WHEN n.answered > 0 THEN 'in_progress' ELSE 'available' END,
    CASE WHEN n.mastered THEN 'mastered' WHEN n.needs_review THEN 'needs_review'
      WHEN n.answered > 0 THEN 'practicing' ELSE 'not_started' END,
    n.answered, n.correct, n.min_items, n.min_accuracy, n.checkpoints, n.min_checkpoints,
    COALESCE(n.eligible AND n.mastered AND n.last_retrieval <= now() - n.review_interval, false), n.is_optional
  FROM resolved n ORDER BY n.order_index;
$$;

REVOKE ALL ON bilimyol_private.math_pilot_policy, bilimyol_private.math_pilot_objectives,
  bilimyol_private.math_pilot_items FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION bilimyol_private.math_progression(UUID) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.get_math_progression() RETURNS JSONB
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT COALESCE(jsonb_agg(to_jsonb(n) ORDER BY n.order_index), '[]'::jsonb)
  FROM bilimyol_private.math_progression(auth.uid()) n
  WHERE auth.uid() IS NOT NULL;
$$;
REVOKE ALL ON FUNCTION public.get_math_progression() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_math_progression() TO authenticated;

CREATE FUNCTION public.can_open_math_lesson(p_lesson_id TEXT) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM bilimyol_private.math_progression(auth.uid()) n
    WHERE n.target_lesson_id = p_lesson_id AND n.status <> 'locked'
  );
$$;
REVOKE ALL ON FUNCTION public.can_open_math_lesson(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.can_open_math_lesson(TEXT) TO authenticated, service_role;

CREATE OR REPLACE VIEW public.learner_lessons AS
SELECT l.id, l.course_id, l.skill_id, l.title, l.summary, l.estimated_minutes,
  CASE WHEN gate.is_locked THEN '[]'::jsonb ELSE public.sanitize_learner_content(l.steps) END AS steps,
  CASE WHEN NOT gate.is_locked THEN public.sanitize_learner_content(l.reinforcement_exercise) END AS reinforcement_exercise,
  l.is_published, l.is_archived, l.created_at, l.updated_at, gate.is_locked
FROM public.lessons l
CROSS JOIN LATERAL (
  SELECT l.course_id = 'course_math_01' AND NOT public.can_open_math_lesson(l.id) AS is_locked OFFSET 0
) gate
WHERE l.is_published AND NOT l.is_archived;

-- Existing drafts stay in storage for admin/history purposes.
CREATE OR REPLACE VIEW public.learner_generated_lessons AS
SELECT gl.id, gl.course_id, gl.skill_id, gl.topic, gl.level, gl.difficulty, gl.title,
  gl.summary, gl.objective, gl.estimated_minutes, public.sanitize_learner_content(gl.steps) AS steps,
  public.sanitize_learner_content(gl.questions) AS questions, gl.generation_model, gl.created_at
FROM public.generated_lessons gl
WHERE gl.course_id <> 'course_math_01';

CREATE OR REPLACE FUNCTION public.submit_answer_attempt(
  p_user_id UUID, p_course_id TEXT, p_skill_id TEXT, p_lesson_id TEXT, p_question_id TEXT,
  p_selected_index INT, p_selected_text TEXT, p_idempotency_key TEXT DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_user_id OR p_lesson_id = 'placement_test'
    OR EXISTS (SELECT 1 FROM public.questions WHERE id = p_question_id AND is_placement) THEN
    RAISE EXCEPTION 'Ushbu javobni bu yo‘l orqali topshirib bo‘lmaydi.' USING ERRCODE = '42501';
  END IF;
  IF p_course_id = 'course_math_01' THEN
    PERFORM pg_advisory_xact_lock(hashtextextended('learning:' || p_user_id::TEXT, 0));
    IF NOT public.can_open_math_lesson(p_lesson_id) THEN
      RAISE EXCEPTION 'Avval tayanch mavzularni o‘zlashtiring.' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN bilimyol_private.submit_answer_attempt(p_user_id, p_course_id, p_skill_id,
    p_lesson_id, p_question_id, p_selected_index, p_selected_text, p_idempotency_key);
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_lesson(p_lesson_id TEXT, p_course_id TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_course TEXT;
  v_skill TEXT;
  v_questions TEXT[];
  v_question TEXT;
  v_award JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('learning:' || v_uid::TEXT, 0));

  IF p_course_id = 'course_math_01' THEN
    SELECT n.course_id INTO v_course
    FROM bilimyol_private.math_progression(v_uid) n
    WHERE n.target_lesson_id = p_lesson_id AND n.status = 'completed';
    IF v_course IS NULL THEN
      IF public.can_open_math_lesson(p_lesson_id) THEN
        RAISE EXCEPTION 'Darsni yakunlash uchun ikkala tekshiruvdagi mashqlarni bajaring va ishlangan misolni qayta ko‘ring.' USING ERRCODE = '42501';
      END IF;
      RAISE EXCEPTION 'Avval tayanch mavzularni o‘zlashtiring.' USING ERRCODE = '42501';
    END IF;
  ELSE
    SELECT l.course_id, l.skill_id, ARRAY(
      SELECT COALESCE(step->'interactiveQuestion', step->'interactive_question')->>'id'
      FROM jsonb_array_elements(l.steps) AS step
      WHERE NULLIF(COALESCE(step->'interactiveQuestion', step->'interactive_question')->>'id', '') IS NOT NULL
    ) INTO v_course, v_skill, v_questions
    FROM public.lessons l WHERE l.id = p_lesson_id AND l.is_published AND NOT l.is_archived;

    IF v_course IS NOT NULL AND COALESCE(cardinality(v_questions), 0) = 0 THEN
      SELECT ARRAY[l.reinforcement_exercise->>'id'] INTO v_questions
      FROM public.lessons l
      WHERE l.id = p_lesson_id AND NULLIF(l.reinforcement_exercise->>'id', '') IS NOT NULL;
    END IF;
    IF v_course IS NULL THEN
      SELECT course_id, skill_id, ARRAY[questions->0->>'id'] INTO v_course, v_skill, v_questions
      FROM public.generated_lessons WHERE id = p_lesson_id;
    END IF;
    IF v_course IS NULL OR v_course IS DISTINCT FROM p_course_id THEN
      RAISE EXCEPTION 'Dars kursda topilmadi.' USING ERRCODE = '22023';
    END IF;
    IF COALESCE(cardinality(v_questions), 0) = 0 THEN
      RAISE EXCEPTION 'Darsning baholanadigan savollari topilmadi.' USING ERRCODE = '22023';
    END IF;
    FOREACH v_question IN ARRAY v_questions LOOP
      IF v_question IS NULL OR NOT COALESCE((
        SELECT is_correct FROM public.answer_attempts
        WHERE user_id = v_uid AND course_id = v_course AND skill_id = v_skill
          AND lesson_id = p_lesson_id AND question_id = v_question
        ORDER BY created_at DESC, id DESC LIMIT 1
      ), false) THEN
        RAISE EXCEPTION 'Dars javoblari serverda tasdiqlanmagan.' USING ERRCODE = '42501';
      END IF;
    END LOOP;
  END IF;

  INSERT INTO public.lesson_progress (
    user_id, lesson_id, course_id, status, progress_percent, completed_at, updated_at
  ) VALUES (v_uid, p_lesson_id, v_course, 'completed', 100, now(), now())
  ON CONFLICT (user_id, lesson_id) DO UPDATE SET
    status = 'completed', progress_percent = 100,
    completed_at = COALESCE(public.lesson_progress.completed_at, now()), updated_at = now();
  v_award := public.award_xp(20, 'lesson_completed_' || p_lesson_id);
  PERFORM public.record_learning_activity();
  RETURN jsonb_build_object('completed', true, 'xp_awarded',
    CASE WHEN (v_award->>'awarded')::BOOLEAN THEN 20 ELSE 0 END);
END;
$$;
REVOKE ALL ON FUNCTION public.complete_lesson(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_lesson(TEXT, TEXT) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
