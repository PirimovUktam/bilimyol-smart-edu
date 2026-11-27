-- ============================================================================
-- BILIMYO'L SMART EDU - WAVE 1 · BATCH W1-B3
-- Migration: 20261128000100_w1_b3_placement_cefr_priors_and_prereqs.sql
-- Scope:
--   * FIX-P0-02: Seed 12 canonical q_eng_place_* items (with cefr_level, text_ru,
--                explanation_ru, media, and deterministic option permutation)
--                into public.questions; retire 12 legacy q_live_eng_* IDs into
--                bilimyol_private.demo_placement_question_ids; add & persist
--                placement_score_by_course, placement_cefr_by_course, and
--                placement_skill_scores_by_course on public.learner_profiles
--                (guarded against direct client tampering); and isolate
--                'placement_test' from course_eng_01 learner_skill_scores.
--   * FIX-P0-11: Start adaptive placement at 'medium' (A2) and require
--                b1_total >= 2 && b1_acc >= 0.5 before awarding 'B1'.
--   * FIX-P1-07: Chain all 15 A1 English nodes sequentially (1..15) into
--                node_eng_a1_exit and unlock orthogonal node_it_web &
--                node_logic_patterns (prerequisites = '[]').
--   * FIX-P1-09: Port Bayesian skill calibration (priorWeight = 4,
--                starterOnlyMaxScore = 55, starter weight 0.5, attemptCount >= 4
--                for 'mastered', spoiled choice-retry discount 0.75) to SQL.
--   * FIX-P1-14: Maintain 1-step Markov difficulty transition in
--                bilimyol_private.next_placement_question.
--   * FIX-P1-16: Difficulty-weight placement credit (easy: 0.75, medium: 1.0,
--                hard: 1.25) and gate weakest_skill_id / is_weakest_focus on
--                lowest_score < 80.
--   * FIX-P1-46: Supersede prior placement_test sessions on Day-2 retake so
--                8/8 retake yields 100% without Day-1 placement_test drag.
--   * FIX-P2-09: Separate assessed_cefr from unlocked_cefr_floor in
--                evaluate_english_placement_cefr and expose confidence metadata.
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS bilimyol_private;
REVOKE ALL ON SCHEMA bilimyol_private FROM PUBLIC, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 1. Extend public.questions with CEFR, RU & media columns + recreate safe views
-- ----------------------------------------------------------------------------
ALTER TABLE public.questions
  ADD COLUMN IF NOT EXISTS skill_domain TEXT,
  ADD COLUMN IF NOT EXISTS cefr_level TEXT,
  ADD COLUMN IF NOT EXISTS topic TEXT,
  ADD COLUMN IF NOT EXISTS question_type TEXT NOT NULL DEFAULT 'multiple_choice',
  ADD COLUMN IF NOT EXISTS text_ru TEXT,
  ADD COLUMN IF NOT EXISTS explanation_ru TEXT,
  ADD COLUMN IF NOT EXISTS wrong_feedback TEXT,
  ADD COLUMN IF NOT EXISTS wrong_feedback_ru TEXT,
  ADD COLUMN IF NOT EXISTS mistake_feedback_by_option JSONB,
  ADD COLUMN IF NOT EXISTS media JSONB;

ALTER TABLE public.questions DROP CONSTRAINT IF EXISTS questions_domain_bounds_check;
ALTER TABLE public.questions
  ADD CONSTRAINT questions_domain_bounds_check CHECK (
    pg_catalog.btrim(id) <> ''
    AND pg_catalog.char_length(id) <= 160
    AND pg_catalog.btrim(text) <> ''
    AND pg_catalog.char_length(text) <= 4000
    AND (text_ru IS NULL OR pg_catalog.char_length(text_ru) <= 4000)
    AND (context_snippet IS NULL OR pg_catalog.char_length(context_snippet) <= 8000)
    AND pg_catalog.char_length(explanation) <= 8000
    AND (explanation_ru IS NULL OR pg_catalog.char_length(explanation_ru) <= 8000)
    AND (wrong_feedback IS NULL OR pg_catalog.char_length(wrong_feedback) <= 4000)
    AND (wrong_feedback_ru IS NULL OR pg_catalog.char_length(wrong_feedback_ru) <= 4000)
    AND (formula_latex IS NULL OR pg_catalog.char_length(formula_latex) <= 2000)
    AND difficulty IN ('easy', 'medium', 'hard')
    AND (cefr_level IS NULL OR cefr_level IN ('Pre-A1', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'))
    AND pg_catalog.jsonb_typeof(options) = 'array'
    AND (media IS NULL OR pg_catalog.jsonb_typeof(media) = 'object')
    AND (mistake_feedback_by_option IS NULL OR pg_catalog.jsonb_typeof(mistake_feedback_by_option) = 'object')
    AND correct_index >= 0
    AND (
      pg_catalog.jsonb_array_length(options) = 0
      OR correct_index < pg_catalog.jsonb_array_length(options)
    )
  );

DROP VIEW IF EXISTS bilimyol_private.placement_question_bank;
CREATE VIEW bilimyol_private.placement_question_bank AS
SELECT q.*
FROM public.questions q
WHERE q.is_placement
  AND NOT EXISTS (
    SELECT 1
    FROM bilimyol_private.demo_placement_question_ids demo
    WHERE demo.question_id = q.id
  )
  AND (
    q.course_id <> 'course_math_01'
    OR q.id IN (
      'q_math_pilot_place_add_01',
      'q_math_pilot_place_add_02',
      'q_math_pilot_place_mul_01',
      'q_math_pilot_place_mul_02'
    )
  );
REVOKE ALL ON bilimyol_private.placement_question_bank FROM PUBLIC, anon, authenticated;

DROP VIEW IF EXISTS public.learner_questions;
CREATE VIEW public.learner_questions
  WITH (security_invoker = true)
AS
SELECT
  id,
  course_id,
  skill_id,
  skill_domain,
  cefr_level,
  topic,
  question_type,
  text,
  text_ru,
  context_snippet,
  options,
  media,
  difficulty,
  formula_latex,
  audio_sim_text,
  audio_sim_speaker,
  is_placement,
  created_at
FROM public.questions;

DROP VIEW IF EXISTS public.admin_questions;
CREATE VIEW public.admin_questions AS
SELECT
  q.id,
  q.course_id,
  q.skill_id,
  q.skill_domain,
  q.cefr_level,
  q.topic,
  q.question_type,
  q.text,
  q.text_ru,
  q.context_snippet,
  q.options,
  q.media,
  q.correct_index,
  q.difficulty,
  q.explanation,
  q.explanation_ru,
  q.wrong_feedback,
  q.wrong_feedback_ru,
  q.mistake_feedback_by_option,
  q.formula_latex,
  q.audio_sim_text,
  q.audio_sim_speaker,
  q.is_placement,
  q.created_at
FROM public.questions q
WHERE public.is_admin();

REVOKE ALL ON TABLE public.questions FROM PUBLIC, anon, authenticated;
GRANT SELECT (
  id,
  course_id,
  skill_id,
  skill_domain,
  cefr_level,
  topic,
  question_type,
  text,
  text_ru,
  context_snippet,
  options,
  media,
  difficulty,
  formula_latex,
  audio_sim_text,
  audio_sim_speaker,
  is_placement,
  created_at
) ON public.questions TO authenticated;
GRANT DELETE ON TABLE public.questions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.questions TO service_role;

REVOKE ALL ON TABLE public.learner_questions, public.admin_questions
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.learner_questions, public.admin_questions
  TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. Seed 12 canonical q_eng_place_* items & retire 12 legacy q_live_eng_* IDs
-- ----------------------------------------------------------------------------
INSERT INTO public.questions (
  id,
  course_id,
  skill_id,
  skill_domain,
  cefr_level,
  topic,
  question_type,
  text,
  text_ru,
  context_snippet,
  options,
  correct_index,
  difficulty,
  explanation,
  explanation_ru,
  wrong_feedback,
  wrong_feedback_ru,
  mistake_feedback_by_option,
  media,
  is_placement
)
VALUES
  ('q_eng_place_vocab_a1', 'course_eng_01', 'skill_eng_vocab', 'vocabulary', 'A1', 'Placement A1: Everyday weather and clothing vocabulary', 'multiple_choice', 'Choose the best word to complete the sentence: "It is raining outside, so please take your ____ before you leave."', 'Выберите подходящее слово, чтобы дополнить предложение: «It is raining outside, so please take your ____ before you leave.»', NULL, '["pillow","sunglasses","umbrella","spoon"]'::pg_catalog.jsonb, 2, 'easy', '"It is raining" (yomg‘ir yog‘yapti) kontekstida yomg‘irdan saqlanish uchun "umbrella" (soyabon) olinadi.', 'В контексте «It is raining» (идёт дождь) для защиты от дождя берут «umbrella» (зонт).', 'Gapning boshidagi ob-havo holatiga qarab tashqarida kerak bo‘ladigan buyumni tanlang.', 'Посмотрите на описание погоды в начале предложения и выберите предмет, нужный на улице.', '{"pillow":{"uz":"«Pillow» — yostiq, u yotoqxona buyumi bo‘lib, yomg‘irda ishlatilmaydi.","ru":"«Pillow» — это подушка, предмет для сна, а не для дождя."},"sunglasses":{"uz":"«Sunglasses» (quyosh ko‘zoynagi) quyoshli kunda taqiladi, yomg‘irda emas.","ru":"«Sunglasses» (солнечные очки) носят в солнечную погоду, а не под дождём."},"umbrella":{"uz":"To‘g‘ri! Yomg‘irli ob-havoda soyabon («umbrella») olinadi.","ru":"Верно! В дождливую погоду берут зонт («umbrella»)."},"spoon":{"uz":"«Spoon» — qoshiq, u oshxona anjomi.","ru":"«Spoon» — это ложка, столовый прибор."}}'::pg_catalog.jsonb, NULL, true),
  ('q_eng_place_vocab_a2', 'course_eng_01', 'skill_eng_vocab', 'vocabulary', 'A2', 'Placement A2: Money verbs lend vs borrow', 'multiple_choice', 'Complete the sentence with the most natural word: "Timur forgot his wallet at home, so he asked his friend to ____ him some money for lunch."', 'Дополните предложение наиболее подходящим словом: «Timur forgot his wallet at home, so he asked his friend to ____ him some money for lunch.»', NULL, '["borrow","spend","earn","lend"]'::pg_catalog.jsonb, 3, 'medium', '"Lend someone money" — birovga vaqtincha pul berib turmoq. "Borrow" esa birovdan olmoq ("borrow from someone") ma’nosida ishlatiladi.', '«Lend someone money» означает временно дать кому-то деньги взаймы. «Borrow» означает взять в долг у кого-то («borrow from someone»).', 'Do‘sti Timurga vaqtincha pul berib turishini so‘raganiga va fe’ldan keyin «him» kelganiga qarang.', 'Обратите внимание, что друг должен временно дать деньги Тимуру, а после глагола стоит местоимение «him».', '{"borrow":{"uz":"«Borrow» — birovdan olish; «borrow him money» deyilmaydi, «borrow money from him» deyiladi.","ru":"«Borrow» — брать взаймы у кого-то; нельзя сказать «borrow him money» (нужно «borrow from»)."},"spend":{"uz":"«Spend» — pul sarflamoq; do‘stidan o‘ziga berib turishni so‘rash ma’nosini bermaydi.","ru":"«Spend» — тратить деньги; не подходит по смыслу с «him»."},"earn":{"uz":"«Earn» — mehnat qilib pul topmoq, qarz berish emas.","ru":"«Earn» — зарабатывать деньги, а не одалживать."},"lend":{"uz":"To‘g‘ri! «Lend someone something» — kimgadir vaqtincha berib turmoq.","ru":"Верно! «Lend someone something» — одолжить что-то кому-то."}}'::pg_catalog.jsonb, NULL, true),
  ('q_eng_place_vocab_b1', 'course_eng_01', 'skill_eng_vocab', 'vocabulary', 'B1', 'Placement B1: Workplace and commuting collocations', 'multiple_choice', 'Choose the word that best fits the context: "To ____ traffic jams during the morning rush, many office workers take the metro instead of driving."', 'Выберите слово, наиболее подходящее по смыслу: «To ____ traffic jams during the morning rush, many office workers take the metro instead of driving.»', NULL, '["create","avoid","attend","expect"]'::pg_catalog.jsonb, 1, 'hard', '"Avoid traffic jams" — tirbandliklarga tushib qolmaslik / ularni chetlab o‘tish uchun metroga tushish mantiqan to‘g‘ri.', '«Avoid traffic jams» (избегать пробок) точно объясняет выбор метро вместо машины в утренний час пик.', 'Odamlar mashina o‘rniga metroga tushish orqali tirbandlik bilan nima qilishni xohlashini o‘ylang.', 'Подумайте, зачем люди выбирают метро вместо автомобиля в утренний час пик.', '{"create":{"uz":"«Create» — yaratmoq; xodimlar tirbandlik yaratish uchun metroga tushmaydi.","ru":"«Create» — создавать; работники не едут на метро, чтобы создавать пробки."},"avoid":{"uz":"To‘g‘ri! «Avoid» — chetlab o‘tmoq, oldini olmoq.","ru":"Верно! «Avoid» — избегать, объезжать."},"attend":{"uz":"«Attend» — tadbir yoki darsga qatnashmoq, tirbandlik bilan ishlatilmaydi.","ru":"«Attend» — посещать (мероприятие/урок), с «traffic jams» не сочетается."},"expect":{"uz":"«Expect» — kutmoq; «tirbandlik kutish uchun metroga tushadi» mazmunga zid.","ru":"«Expect» — ожидать; не объясняет отказ от машины."}}'::pg_catalog.jsonb, NULL, true),
  ('q_eng_place_grammar_a1', 'course_eng_01', 'skill_eng_grammar', 'grammar', 'A1', 'Placement A1: There is vs There are agreement', 'multiple_choice', 'Choose the correct option to complete the sentence: "There ____ three books on the teacher’s desk."', 'Выберите правильный вариант для дополнения предложения: «There ____ three books on the teacher’s desk.»', NULL, '["are","is","am","be"]'::pg_catalog.jsonb, 0, 'easy', '"Three books" ko‘plik ot bo‘lgani uchun "There are" ishlatiladi.', 'Так как «three books» — множественное число, используется форма «There are».', '"Three books" birlikmi yoki ko‘plikmi? Otning soniga qarab fe’l tanlang.', 'Определите число существительного «three books» и выберите согласованную форму глагола «to be».', '{"are":{"uz":"To‘g‘ri! Ko‘plik otlar («three books») bilan «There are» ishlatiladi.","ru":"Верно! С множественным числом («three books») используется «There are»."},"is":{"uz":"«There is» faqat birlik (masalan, «one book») bilan ishlatiladi.","ru":"«There is» используется только с единственным числом (например, «one book»)."},"am":{"uz":"«Am» faqat «I» olmoshi bilan keladi, «There» bilan ishlatilmaydi.","ru":"«Am» употребляется только с местоимением «I», но не с «There»."},"be":{"uz":"«Be» — asosiy shakl; bu o‘rinda «There» dan keyin tuslangan «are» kerak.","ru":"«Be» — начальная форма; после «There» нужна личная форма «are»."}}'::pg_catalog.jsonb, NULL, true),
  ('q_eng_place_grammar_a2', 'course_eng_01', 'skill_eng_grammar', 'grammar', 'A2', 'Placement A2: Past Simple irregular verb with past time marker', 'multiple_choice', 'Choose the correct verb form: "Yesterday evening, Madina ____ fresh fruit at the market on her way home."', 'Выберите правильную форму глагола: «Yesterday evening, Madina ____ fresh fruit at the market on her way home.»', NULL, '["buys","bought","buy","is buying"]'::pg_catalog.jsonb, 1, 'medium', '"Yesterday evening" (kecha kechqurun) tugallangan o‘tgan vaqt bo‘lgani uchun "buy" fe’lining Past Simple shakli — "bought" ishlatiladi.', 'Указатель «Yesterday evening» (вчера вечером) обозначает завершённое действие в прошлом, поэтому нужна форма Past Simple от «buy» — «bought».', 'Gap boshidagi «Yesterday evening» vaqt ko‘rsatkichiga qarang — harakat o‘tgan zamonda sodir bo‘lgan.', 'Обратите внимание на маркер времени «Yesterday evening» — действие произошло в прошлом.', '{"buys":{"uz":"«Buys» — hozirgi zamon (Present Simple), «yesterday evening» bilan mos kelmaydi.","ru":"«Buys» — настоящее время (Present Simple), оно не сочетается с «yesterday evening»."},"bought":{"uz":"To‘g‘ri! «Buy» fe’lining o‘tgan zamon (Past Simple) shakli — «bought».","ru":"Верно! Форма Past Simple от глагола «buy» — «bought»."},"buy":{"uz":"«Buy» — asosiy shakl; o‘tgan zamondagi tasdiq gapda noto‘g‘ri fe’lning 2-shakli kerak.","ru":"«Buy» — начальная форма; в утверждении в Past Simple нужна вторая форма неправильного глагола."},"is buying":{"uz":"«Is buying» hozir davom etayotgan harakatni bildiradi, kechagi voqeani emas.","ru":"«Is buying» описывает действие прямо сейчас, а не вчера вечером."}}'::pg_catalog.jsonb, NULL, true),
  ('q_eng_place_grammar_b1', 'course_eng_01', 'skill_eng_grammar', 'grammar', 'B1', 'Placement B1: Present Perfect since vs for', 'multiple_choice', 'Choose the grammatically correct option: "Dilshod has lived in Samarkand ____ 2019, so he knows the old city very well."', 'Выберите грамматически правильный вариант: «Dilshod has lived in Samarkand ____ 2019, so he knows the old city very well.»', NULL, '["for","during","from","since"]'::pg_catalog.jsonb, 3, 'hard', 'Present Perfect ("has lived") bilan aniq boshlanish nuqtasi ("2019") berilganda "since" qo‘llanadi.', 'В Present Perfect («has lived») с точной точкой начала («2019») используется предлог «since».', '"Has lived" (Present Perfect) va "2019" (boshlanish yili) birga kelganda qaysi predlog ishlatilishini eslang.', 'Вспомните, какой предлог соединяет Present Perfect («has lived») с точкой отсчёта в прошлом («2019»).', '{"for":{"uz":"«For» davomiylik miqdori bilan keladi (masalan, «for five years»), aniq yil bilan emas.","ru":"«For» употребляется с длительностью периода (например, «for five years»), а не с конкретным годом."},"during":{"uz":"«During» ot bilan keladi (masalan, «during the summer») va Present Perfect boshlanish nuqtasini bildirmaydi.","ru":"«During» ставится перед существительными («during the summer») и не обозначает точку начала в Present Perfect."},"from":{"uz":"«From» odatda «from ... to ...» juftligida ishlatiladi; Present Perfect bilan aniq boshlanish nuqtasi uchun mos kelmaydi.","ru":"«From» обычно используется в паре «from ... to ...», а не для точки начала в Present Perfect."},"since":{"uz":"To‘g‘ri! «Since 2019» — 2019-yildan beri (boshlanish nuqtasidan hozirgacha).","ru":"Верно! «Since 2019» — с 2019 года (от точки начала до настоящего времени)."}}'::pg_catalog.jsonb, NULL, true),
  ('q_eng_place_listening_a1', 'course_eng_01', 'skill_eng_listening', 'listening', 'A1', 'Placement A1: Listening for morning club time', 'multiple_choice', 'Listen to the conversation. What time does the music club start?', 'Прослушайте диалог. Во сколько начинается музыкальный кружок?', NULL, '["09:00 in the morning","09:00 in the evening","10:00 in the morning","07:00 in the morning"]'::pg_catalog.jsonb, 0, 'easy', 'Timur audioda to‘garak shanba kuni "nine o''clock in the morning" (ertalab 09:00) da boshlanishini aytdi.', 'В аудио Тимур ясно говорит, что кружок начинается в субботу в «nine o''clock in the morning» (09:00 утра).', 'Audiodagi soat raqamiga va kunning qaysi qismi ekaniga diqqat bilan quloq soling.', 'Внимательно послушайте названный час и время суток в ответе Тимура.', '{"09:00 in the morning":{"uz":"To‘g‘ri! Suhbatda «nine o''clock in the morning» (ertalab soat 9) deyildi.","ru":"Верно! В диалоге прозвучало «nine o''clock in the morning» (9 часов утра)."},"09:00 in the evening":{"uz":"Soat 9 to‘g‘ri, ammo audioda «in the evening» emas, «in the morning» deyilgan.","ru":"Час указан верно, но в аудио сказано «in the morning», а не «in the evening»."},"10:00 in the morning":{"uz":"Audioda 10 emas, «nine o''clock» (soat 9) aytildi.","ru":"В записи звучит «nine o''clock» (9 часов), а не 10."},"07:00 in the morning":{"uz":"Audioda soat 7 tilga olinmagan; «nine o''clock» eshitildi.","ru":"7 часов в аудио не упоминаются; там сказано «nine o''clock»."}}'::pg_catalog.jsonb, '{"id":"media_eng_place_listening_a1","kind":"audio","language":"en","source":"/lesson-media/english/placement/q_eng_place_listening_a1.wav","title":"Maktab musiqa to‘garagi vaqti","titleUz":"Maktab musiqa to‘garagi vaqti","titleRu":"Время школьного музыкального кружка","transcript":"Lola: Hi, Timur! When is our school music club?\nTimur: It starts at nine o''clock in the morning on Saturday.","durationSeconds":6.919,"reviewStatus":"approved","provenance":"local-system-speech"}'::pg_catalog.jsonb, true),
  ('q_eng_place_listening_a2', 'course_eng_01', 'skill_eng_listening', 'listening', 'A2', 'Placement A2: Listening to a rescheduled class day and afternoon time', 'multiple_choice', 'Listen to the phone call. When is the beginner swimming class this week?', 'Прослушайте телефонный разговор. Когда пройдёт занятие по плаванию для начинающих на этой неделе?', NULL, '["Wednesday at 16:00","Thursday at 16:00","Thursday at 04:00 in the morning","Friday at 16:00"]'::pg_catalog.jsonb, 1, 'medium', 'Qabulxona xodimi dars chorshanbadan "Thursday at four o''clock in the afternoon" (payshanba 16:00) ga ko‘chirilganini aytdi.', 'Администратор уточняет, что занятие перенесли со среды на «Thursday at four o''clock in the afternoon» (четверг в 16:00).', 'Eski kun («Wednesday») bilan yangi ko‘chirilgan kun va «in the afternoon» belgisini solishtiring.', 'Сравните прежний день («Wednesday») с новым днём и уточнением «in the afternoon».', '{"Wednesday at 16:00":{"uz":"Chorshanba — eski jadval; xodim «No, we moved it... not Wednesday» dedi.","ru":"Среда — это старое расписание; сотрудник сказал «No, we moved it... not Wednesday»."},"Thursday at 16:00":{"uz":"To‘g‘ri! Payshanba kuni kunduzgi soat 4 («four o''clock in the afternoon» = 16:00).","ru":"Верно! Четверг в 4 часа дня («four o''clock in the afternoon» = 16:00)."},"Thursday at 04:00 in the morning":{"uz":"Audioda «in the afternoon» (kunduzi 16:00) deyildi, tungi 04:00 emas.","ru":"В аудио сказано «in the afternoon» (16:00 дня), а не 04:00 утра."},"Friday at 16:00":{"uz":"Juma kuni tilga olinmadi; dars payshanbaga ko‘chirildi.","ru":"Пятница в диалоге не звучит; занятие перенесли на четверг."}}'::pg_catalog.jsonb, '{"id":"media_eng_place_listening_a2","kind":"audio","language":"en","source":"/lesson-media/english/placement/q_eng_place_listening_a2.wav","title":"Suzish mashg‘uloti jadvali o‘zgarishi","titleUz":"Suzish mashg‘uloti jadvali o‘zgarishi","titleRu":"Изменение расписания занятий по плаванию","transcript":"Receptionist: Hello, City Sports Center. How can I help you?\nCaller: Hi! Is the beginner swimming class still on Wednesday afternoon?\nReceptionist: No, we moved it this week. It is now on Thursday at four o''clock in the afternoon, not Wednesday.","durationSeconds":16.048,"reviewStatus":"approved","provenance":"local-system-speech"}'::pg_catalog.jsonb, true),
  ('q_eng_place_listening_b1', 'course_eng_01', 'skill_eng_listening', 'listening', 'B1', 'Placement B1: Listening to workplace problem-solving and next action', 'multiple_choice', 'Listen to the conversation. What will the speakers do for the morning session?', 'Прослушайте разговор. Что собеседники сделают для утренней сессии?', NULL, '["Cancel the morning session and wait until two o’clock","Pick up the printed booklets at ten o’clock in the morning","Ask participants to print the booklets at home","Send the PDF link in the group chat first and give out booklets after lunch"]'::pg_catalog.jsonb, 3, 'hard', 'Bekzod ertalabki guruhga PDF havolasini guruh chatida yuborishni, bosma bukletlarni esa tushlikdan keyin tarqatishni taklif qildi.', 'Бекзод предлагает сначала отправить ссылку на PDF в групповой чат для утренней группы, а печатные буклеты раздать после обеда.', 'Bekzod soat 10:00 dagi guruh uchun qanday tezkor yechim taklif qilganiga quloq soling.', 'Прислушайтесь к решению, которое предлагает Бекзод для утренней группы в 10:00.', '{"Cancel the morning session and wait until two o’clock":{"uz":"Ular darsni bekor qilmadi; ertalabki guruh uchun raqamli PDF yechimini tanladi.","ru":"Они не отменяли сессию, а выбрали цифровой PDF для утренней группы."},"Pick up the printed booklets at ten o’clock in the morning":{"uz":"Soat 10:00 da seminar boshlanadi; bosma bukletlar esa soat 14:00 gacha yetib kelmaydi.","ru":"В 10:00 начинается сессия, а печатные буклеты привезут только к 14:00."},"Ask participants to print the booklets at home":{"uz":"Ishtirokchilarga uydan chop etish haqida hech narsa deyilmagan.","ru":"Участников не просили распечатывать буклеты дома."},"Send the PDF link in the group chat first and give out booklets after lunch":{"uz":"To‘g‘ri! Suhbatda PDF havolani chatda yuborish va bukletlarni tushlikdan keyin berishga kelishildi.","ru":"Верно! Собеседники договорились отправить PDF в чат сначала, а буклеты раздать после обеда."}}'::pg_catalog.jsonb, '{"id":"media_eng_place_listening_b1","kind":"audio","language":"en","source":"/lesson-media/english/placement/q_eng_place_listening_b1.wav","title":"Seminar materiallari bo‘yicha qaror","titleUz":"Seminar materiallari bo‘yicha qaror","titleRu":"Решение по материалам семинара","transcript":"Malika: Bekzod, the print shop just called. The boxes of workshop booklets won''t arrive until two o''clock in the afternoon, and our morning session starts at ten.\nBekzod: Thanks for telling me. Since the morning group needs the tasks right away, let''s share the PDF link in the group chat first and hand out the printed booklets after lunch.","durationSeconds":20.064,"reviewStatus":"approved","provenance":"local-system-speech"}'::pg_catalog.jsonb, true),
  ('q_eng_place_reading_a1', 'course_eng_01', 'skill_eng_reading', 'reading', 'A1', 'Placement A1: Reading a public shop hours sign', 'multiple_choice', 'Read the sign: "Green Park Bookshop. Open Monday to Saturday from 9:00 AM to 6:00 PM. Closed on Sunday." When can a customer visit the bookshop?', 'Прочитайте вывеску: «Green Park Bookshop. Open Monday to Saturday from 9:00 AM to 6:00 PM. Closed on Sunday.» Когда покупатель может посетить книжный магазин?', NULL, '["On Sunday at 11:00 AM","On Monday at 8:00 PM","On Saturday at 7:00 AM","On Wednesday at 11:00 AM"]'::pg_catalog.jsonb, 3, 'easy', 'Do‘kon dushanbadan shanbagacha ("Monday to Saturday") soat 9:00 dan 18:00 gacha ochiq, shuning uchun chorshanba soat 11:00 da tashrif buyurish mumkin.', 'Магазин открыт с понедельника по субботу («Monday to Saturday») с 9:00 до 18:00, поэтому в среду в 11:00 его можно посетить.', 'E’londagi ish kunlari («Monday to Saturday») va soat oralig‘iga («9:00 AM to 6:00 PM») qarang.', 'Сверьте дни работы («Monday to Saturday») и часы («9:00 AM to 6:00 PM») на вывеске.', '{"On Sunday at 11:00 AM":{"uz":"E’londa «Closed on Sunday» (yakshanba kuni yopiq) deb yozilgan.","ru":"На вывеске написано «Closed on Sunday» (закрыто в воскресенье)."},"On Monday at 8:00 PM":{"uz":"Do‘kon 6:00 PM (18:00) da yopiladi, kechki 20:00 da yopiq bo‘ladi.","ru":"Магазин закрывается в 6:00 PM (18:00), поэтому в 20:00 он уже закрыт."},"On Wednesday at 11:00 AM":{"uz":"To‘g‘ri! Chorshanba ish kuni (dushanba–shanba oralig‘ida) va 11:00 AM ish vaqtiga kiradi.","ru":"Верно! Среда входит в интервал понедельник–суббота, а 11:00 AM — рабочее время."},"On Saturday at 7:00 AM":{"uz":"Do‘kon ertalab soat 9:00 da ochiladi, 7:00 AM da hali yopiq.","ru":"Магазин открывается в 9:00 утра, в 7:00 AM он ещё закрыт."}}'::pg_catalog.jsonb, NULL, true),
  ('q_eng_place_reading_a2', 'course_eng_01', 'skill_eng_reading', 'reading', 'A2', 'Placement A2: Reading a short message about changed plans', 'multiple_choice', 'Read the message from Anvar: "Hi Jasur, the weather forecast says heavy rain tomorrow, so we are going to play chess at my house instead of football in the park. See you at 3:00 PM!" Why did Anvar change the plan?', 'Прочитайте сообщение от Анвара: «Hi Jasur, the weather forecast says heavy rain tomorrow, so we are going to play chess at my house instead of football in the park. See you at 3:00 PM!» Почему Анвар изменил план?', NULL, '["The park is closed at 3:00 PM","Jasur does not like football","Bad weather is expected tomorrow","Anvar lost his chess set"]'::pg_catalog.jsonb, 2, 'medium', 'Xabarda "the weather forecast says heavy rain tomorrow, so..." deb ertaga kuchli yomg‘ir (yomon ob-havo) kutilayotgani sabab qilib ko‘rsatilgan.', 'В сообщении указана причина: «the weather forecast says heavy rain tomorrow, so...» (завтра ожидается сильный дождь).', 'Xabardagi «so» bog‘lovchisidan oldingi sabab qismiga e’tibor bering.', 'Обратите внимание на причину перед союзом «so» в тексте сообщения.', '{"The park is closed at 3:00 PM":{"uz":"Matnda bog‘ yopiq ekani aytilmagan.","ru":"В тексте не говорится, что парк закрыт."},"Jasur does not like football":{"uz":"Jasur futbolni yoqtirmasligi haqida gap yo‘q; sabab ob-havo.","ru":"В сообщении нет речи о том, что Жасур не любит футбол; причина — погода."},"Bad weather is expected tomorrow":{"uz":"To‘g‘ri! Kuchli yomg‘ir (yomon ob-havo) kutilayotgani uchun ular uy ichida shaxmat o‘ynashga qaror qilishdi.","ru":"Верно! Из-за прогноза сильного дождя они решили сыграть в шахматы дома."},"Anvar lost his chess set":{"uz":"Aksincha, ular Anvarning uyida shaxmat o‘ynashmoqchi.","ru":"Наоборот, они собираются играть в шахматы у Анвара дома."}}'::pg_catalog.jsonb, NULL, true),
  ('q_eng_place_reading_b1', 'course_eng_01', 'skill_eng_reading', 'reading', 'B1', 'Placement B1: Reading a city bike pass policy notice', 'multiple_choice', 'Read the notice: "City Bike Pass members can ride for up to 45 minutes per trip at no extra cost. However, if a ride lasts longer than 45 minutes and the rider does not report a dock problem, an hourly fee is charged." How can a member avoid paying the extra fee?', 'Прочитайте объявление: «City Bike Pass members can ride for up to 45 minutes per trip at no extra cost. However, if a ride lasts longer than 45 minutes and the rider does not report a dock problem, an hourly fee is charged.» Как участник может избежать дополнительной платы?', NULL, '["Return the bike within 45 minutes","Use the bike only once a week","Pay an hourly fee before every trip","Keep the bike overnight without reporting"]'::pg_catalog.jsonb, 0, 'hard', 'Qoidaga ko‘ra, bir safar 45 daqiqagacha ("up to 45 minutes") qo‘shimcha to‘lovsiz hisoblanadi.', 'По правилам поездка длительностью до 45 минут («up to 45 minutes») не требует дополнительной оплаты.', 'Matnning birinchi gapidagi safar vaqti chegarasiga e’tibor bering.', 'Обратите внимание на ограничение времени одной поездки в первом предложении объявления.', '{"Return the bike within 45 minutes":{"uz":"To‘g‘ri! Safarni 45 daqiqa ichida yakunlash qo‘shimcha to‘lovdan saqlaydi.","ru":"Верно! Возврат велосипеда в пределах 45 минут освобождает от доплаты."},"Use the bike only once a week":{"uz":"Haftalik cheklov haqida yozilmagan; cheklov har bir safar davomiyligiga («per trip») tegishli.","ru":"Ограничение относится к длительности каждой поездки («per trip»), а не к числу поездок в неделю."},"Pay an hourly fee before every trip":{"uz":"45 daqiqagacha safar qo‘shimcha to‘lovsiz («at no extra cost»).","ru":"Поездки до 45 минут бесплатны сверх абонемента («at no extra cost»)."},"Keep the bike overnight without reporting":{"uz":"45 daqiqadan uzoq va xabar bermasdan saqlash aynan qo‘shimcha haqqa sabab bo‘ladi.","ru":"Удержание велосипеда дольше 45 минут без сообщения о поломке как раз ведёт к доплате."}}'::pg_catalog.jsonb, NULL, true)
ON CONFLICT (id) DO UPDATE SET
  course_id = EXCLUDED.course_id,
  skill_id = EXCLUDED.skill_id,
  skill_domain = EXCLUDED.skill_domain,
  cefr_level = EXCLUDED.cefr_level,
  topic = EXCLUDED.topic,
  question_type = EXCLUDED.question_type,
  text = EXCLUDED.text,
  text_ru = EXCLUDED.text_ru,
  context_snippet = EXCLUDED.context_snippet,
  options = EXCLUDED.options,
  correct_index = EXCLUDED.correct_index,
  difficulty = EXCLUDED.difficulty,
  explanation = EXCLUDED.explanation,
  explanation_ru = EXCLUDED.explanation_ru,
  wrong_feedback = EXCLUDED.wrong_feedback,
  wrong_feedback_ru = EXCLUDED.wrong_feedback_ru,
  mistake_feedback_by_option = EXCLUDED.mistake_feedback_by_option,
  media = EXCLUDED.media,
  is_placement = EXCLUDED.is_placement;

INSERT INTO bilimyol_private.demo_placement_question_ids (question_id)
SELECT pg_catalog.unnest(ARRAY[
  'q_live_eng_vocab_context',
  'q_live_eng_grammar_daily',
  'q_live_eng_reading_evidence',
  'q_live_eng_vocab_borrow',
  'q_live_eng_vocab_scarce',
  'q_live_eng_grammar_plural',
  'q_live_eng_grammar_past_condition',
  'q_live_eng_reading_notice',
  'q_live_eng_reading_inference',
  'q_live_eng_listening_time',
  'q_live_eng_listening_place',
  'q_live_eng_listening_change'
])
ON CONFLICT (question_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. Extend public.learner_profiles with server-authoritative placement JSONB
-- ----------------------------------------------------------------------------
ALTER TABLE public.learner_profiles
  ADD COLUMN IF NOT EXISTS placement_score_by_course JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS placement_cefr_by_course JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS placement_skill_scores_by_course JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.learner_profiles DROP CONSTRAINT IF EXISTS learner_profiles_domain_bounds_check;
ALTER TABLE public.learner_profiles
  ADD CONSTRAINT learner_profiles_domain_bounds_check CHECK (
    goal IN ('mastery', 'exam_prep', 'skills_boost')
    AND daily_minutes IN (15, 30, 60)
    AND initial_level IN ('beginner', 'intermediate', 'advanced')
    AND pg_catalog.jsonb_typeof(course_levels) = 'object'
    AND pg_catalog.octet_length(course_levels::text) <= 4096
    AND NOT pg_catalog.jsonb_path_exists(
      course_levels,
      '$.* ? (@.type() != "string" || (@ != "beginner" && @ != "intermediate" && @ != "advanced"))'
    )
    AND pg_catalog.jsonb_typeof(placement_score_by_course) = 'object'
    AND pg_catalog.octet_length(placement_score_by_course::text) <= 4096
    AND NOT pg_catalog.jsonb_path_exists(
      placement_score_by_course,
      '$.* ? (@.type() != "number" || @ < 0 || @ > 100)'
    )
    AND pg_catalog.jsonb_typeof(placement_cefr_by_course) = 'object'
    AND pg_catalog.octet_length(placement_cefr_by_course::text) <= 4096
    AND NOT pg_catalog.jsonb_path_exists(
      placement_cefr_by_course,
      '$.* ? (@.type() != "string" || (@ != "Pre-A1" && @ != "A1" && @ != "A2" && @ != "B1" && @ != "B2" && @ != "C1" && @ != "C2"))'
    )
    AND pg_catalog.jsonb_typeof(placement_skill_scores_by_course) = 'object'
    AND pg_catalog.octet_length(placement_skill_scores_by_course::text) <= 32768
  );

CREATE OR REPLACE FUNCTION bilimyol_private.guard_learner_profile_derived_placement()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF CURRENT_USER IN ('authenticated', 'anon') THEN
    IF TG_OP = 'INSERT' THEN
      IF NEW.placement_score_by_course IS DISTINCT FROM '{}'::pg_catalog.jsonb
         OR NEW.placement_cefr_by_course IS DISTINCT FROM '{}'::pg_catalog.jsonb
         OR NEW.placement_skill_scores_by_course IS DISTINCT FROM '{}'::pg_catalog.jsonb THEN
        RAISE EXCEPTION 'Placement natijalarini bevosita o‘zgartirish taqiqlanadi.'
          USING ERRCODE = '42501';
      END IF;
    ELSIF TG_OP = 'UPDATE' THEN
      IF NEW.placement_score_by_course IS DISTINCT FROM OLD.placement_score_by_course
         OR NEW.placement_cefr_by_course IS DISTINCT FROM OLD.placement_cefr_by_course
         OR NEW.placement_skill_scores_by_course IS DISTINCT FROM OLD.placement_skill_scores_by_course THEN
        RAISE EXCEPTION 'Placement natijalarini bevosita o‘zgartirish taqiqlanadi.'
          USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION bilimyol_private.guard_learner_profile_derived_placement()
  FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_guard_learner_profile_derived_placement ON public.learner_profiles;
CREATE TRIGGER trg_guard_learner_profile_derived_placement
  BEFORE INSERT OR UPDATE ON public.learner_profiles
  FOR EACH ROW
  EXECUTE FUNCTION bilimyol_private.guard_learner_profile_derived_placement();

-- Backfill placement_score_by_course from existing placement_attempts
WITH latest_plc AS (
  SELECT DISTINCT ON (pa.user_id, pa.course_id)
    pa.user_id,
    pa.course_id,
    GREATEST(0, LEAST(100, pa.score)) AS score
  FROM public.placement_attempts pa
  ORDER BY pa.user_id, pa.course_id, pa.completed_at DESC, pa.id DESC
),
agg_plc AS (
  SELECT
    lp.user_id,
    pg_catalog.jsonb_object_agg(lp.course_id, lp.score) AS score_map
  FROM latest_plc lp
  GROUP BY lp.user_id
)
UPDATE public.learner_profiles prof
SET placement_score_by_course = COALESCE(prof.placement_score_by_course, '{}'::pg_catalog.jsonb) || agg_plc.score_map
FROM agg_plc
WHERE prof.user_id = agg_plc.user_id
  AND (prof.placement_score_by_course || agg_plc.score_map) IS DISTINCT FROM prof.placement_score_by_course;

-- Remove legacy placement-only rows from learner_skill_scores for course_eng_01
DELETE FROM public.learner_skill_scores lss
WHERE lss.course_id = 'course_eng_01'
  AND NOT EXISTS (
    SELECT 1
    FROM public.answer_attempts aa
    WHERE aa.user_id = lss.user_id
      AND aa.course_id = 'course_eng_01'
      AND aa.skill_id = lss.skill_id
      AND aa.lesson_id <> 'placement_test'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.reinforcement_attempts ra
    WHERE ra.user_id = lss.user_id
      AND ra.course_id = 'course_eng_01'
      AND ra.skill_id = lss.skill_id
      AND ra.is_correct = true
  );

-- ----------------------------------------------------------------------------
-- 4. Sequential 15-node A1 English graph & orthogonal IT/Logic unlocks (FIX-P1-07)
-- ----------------------------------------------------------------------------
UPDATE public.roadmap_nodes
SET order_index = 1,
    prerequisites = '[]'::pg_catalog.jsonb
WHERE id = 'node_eng_a1_m1_greetings' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 2,
    prerequisites = '["node_eng_a1_m1_greetings"]'::pg_catalog.jsonb
WHERE id = 'node_eng_a1_m1_speaking' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 3,
    prerequisites = '["node_eng_a1_m1_speaking"]'::pg_catalog.jsonb
WHERE id = 'node_eng_a1_u1_checkpoint' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 4,
    prerequisites = '["node_eng_a1_u1_checkpoint"]'::pg_catalog.jsonb
WHERE id = 'node_eng_a1_m2_sentence_builder' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 5,
    prerequisites = '["node_eng_a1_m2_sentence_builder"]'::pg_catalog.jsonb
WHERE id = 'node_eng_gram' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 6,
    prerequisites = '["node_eng_gram"]'::pg_catalog.jsonb
WHERE id = 'node_eng_a1_m2_daily_life' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 7,
    prerequisites = '["node_eng_a1_m2_daily_life"]'::pg_catalog.jsonb
WHERE id = 'node_eng_a1_u2_checkpoint' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 8,
    prerequisites = '["node_eng_a1_u2_checkpoint"]'::pg_catalog.jsonb
WHERE id = 'node_eng_vocab' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 9,
    prerequisites = '["node_eng_vocab"]'::pg_catalog.jsonb
WHERE id = 'node_eng_list' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 10,
    prerequisites = '["node_eng_list"]'::pg_catalog.jsonb
WHERE id = 'node_eng_a1_m3_time_schedule' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 11,
    prerequisites = '["node_eng_a1_m3_time_schedule"]'::pg_catalog.jsonb
WHERE id = 'node_eng_a1_u3_checkpoint' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 12,
    prerequisites = '["node_eng_a1_u3_checkpoint"]'::pg_catalog.jsonb
WHERE id = 'node_eng_read' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 13,
    prerequisites = '["node_eng_read"]'::pg_catalog.jsonb
WHERE id = 'node_eng_a1_m4_writing' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 14,
    prerequisites = '["node_eng_a1_m4_writing"]'::pg_catalog.jsonb
WHERE id = 'node_eng_a1_u4_checkpoint' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET order_index = 15,
    prerequisites = '["node_eng_a1_u4_checkpoint"]'::pg_catalog.jsonb
WHERE id = 'node_eng_a1_exit' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '[]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_starter' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '[]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_a1_m1_greetings' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_a1_m1_greetings"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_a1_m1_speaking' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_a1_m1_speaking"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_a1_u1_checkpoint' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["lesson_eng_starter"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_foundation_02' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_a1_u1_checkpoint"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_a1_m2_sentence_builder' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_gram"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_a1_m2_daily_life' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_a1_m2_sentence_builder"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_grammar_01' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_a1_m2_daily_life"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_a1_u2_checkpoint' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_a1_u2_checkpoint"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_vocab_01' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_vocab"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_listening_01' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_list"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_a1_m3_time_schedule' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_a1_m3_time_schedule"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_a1_u3_checkpoint' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_a1_u3_checkpoint"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_reading_01' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_read"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_a1_m4_writing' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_a1_m4_writing"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_a1_u4_checkpoint' AND course_id = 'course_eng_01';

UPDATE public.lessons
SET prerequisites = '["node_eng_a1_u4_checkpoint"]'::pg_catalog.jsonb,
    updated_at = pg_catalog.now()
WHERE id = 'lesson_eng_a1_exit' AND course_id = 'course_eng_01';

UPDATE public.roadmap_nodes
SET prerequisites = '[]'::pg_catalog.jsonb
WHERE id IN ('node_it_web', 'node_logic_patterns')
  AND course_id IN ('course_it', 'course_logic');

-- ----------------------------------------------------------------------------
-- 5. Calibrated Skill Scoring, Placement Weighting & CEFR Evaluation Helpers
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION bilimyol_private.get_mastery_level(
  p_score INT,
  p_attempt_count INT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT CASE
    WHEN COALESCE(p_score, 0) < 40 THEN 'needs_remediation'
    WHEN COALESCE(p_score, 0) < 60 THEN 'developing'
    WHEN COALESCE(p_score, 0) < 80 THEN 'proficient'
    WHEN p_attempt_count IS NOT NULL AND p_attempt_count < 4 THEN 'proficient'
    ELSE 'mastered'
  END;
$$;

REVOKE ALL ON FUNCTION bilimyol_private.get_mastery_level(INT, INT)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION bilimyol_private.compute_confidence_label(p_attempt_count INT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT CASE
    WHEN COALESCE(p_attempt_count, 0) < 2 THEN 'low'
    WHEN COALESCE(p_attempt_count, 0) < 4 THEN 'medium'
    ELSE 'high'
  END;
$$;

REVOKE ALL ON FUNCTION bilimyol_private.compute_confidence_label(INT)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION bilimyol_private.compute_confidence_numeric(p_attempt_count INT)
RETURNS NUMERIC(3,2)
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT CASE
    WHEN COALESCE(p_attempt_count, 0) < 2 THEN 0.35::NUMERIC(3,2)
    WHEN COALESCE(p_attempt_count, 0) < 4 THEN 0.65::NUMERIC(3,2)
    ELSE 0.90::NUMERIC(3,2)
  END;
$$;

REVOKE ALL ON FUNCTION bilimyol_private.compute_confidence_numeric(INT)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION bilimyol_private.compute_calibrated_skill_score(
  p_weighted_correct NUMERIC,
  p_weighted_total NUMERIC,
  p_prior_score INT DEFAULT NULL,
  p_starter_only BOOLEAN DEFAULT false,
  p_has_non_starter BOOLEAN DEFAULT true
)
RETURNS INT
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  v_prior_weight CONSTANT NUMERIC := 4.0;
  v_starter_max CONSTANT INT := 55;
  v_base NUMERIC;
  v_raw INT;
  v_clamped INT;
BEGIN
  IF p_weighted_total IS NULL OR p_weighted_total <= 0 THEN
    RETURN GREATEST(0, LEAST(100, COALESCE(p_prior_score, 0)));
  END IF;

  v_base := CASE
    WHEN p_prior_score IS NOT NULL THEN GREATEST(0, LEAST(100, p_prior_score))::NUMERIC
    ELSE 50.0
  END;

  IF p_prior_score IS NOT NULL
     AND p_prior_score >= v_starter_max
     AND NOT COALESCE(p_has_non_starter, false)
     AND p_weighted_correct >= p_weighted_total THEN
    RETURN GREATEST(0, LEAST(100, p_prior_score));
  END IF;

  v_raw := pg_catalog.round(
    ((v_base * v_prior_weight) + (p_weighted_correct * 100.0))
    / (v_prior_weight + p_weighted_total)
  )::INT;
  v_clamped := GREATEST(0, LEAST(100, v_raw));

  IF COALESCE(p_starter_only, false)
     OR (p_prior_score IS NOT NULL AND p_prior_score < v_starter_max AND NOT COALESCE(p_has_non_starter, false)) THEN
    RETURN LEAST(v_starter_max, v_clamped);
  END IF;

  RETURN v_clamped;
END;
$$;

REVOKE ALL ON FUNCTION bilimyol_private.compute_calibrated_skill_score(NUMERIC, NUMERIC, INT, BOOLEAN, BOOLEAN)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION bilimyol_private.compute_placement_skill_scores(
  p_course_id TEXT,
  p_submissions JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  v_rec RECORD;
  v_min_score INT := 101;
  v_weakest_skill_id TEXT := NULL;
  v_skill_map JSONB := '{}'::pg_catalog.jsonb;
  v_sum_scores INT := 0;
  v_skill_count INT := 0;
  v_overall_score INT := 0;
  v_now_ms BIGINT := (EXTRACT(EPOCH FROM pg_catalog.now()) * 1000)::BIGINT;
BEGIN
  FOR v_rec IN
    WITH dedup AS (
      SELECT DISTINCT ON (item->>'question_id')
        item->>'question_id' AS question_id,
        (item->>'selected_index')::INT AS selected_index,
        ord
      FROM pg_catalog.jsonb_array_elements(COALESCE(p_submissions, '[]'::pg_catalog.jsonb)) WITH ORDINALITY AS s(item, ord)
      ORDER BY item->>'question_id', ord DESC
    ),
    weighted AS (
      SELECT
        q.skill_id,
        (d.selected_index = q.correct_index) AS is_correct,
        CASE q.difficulty
          WHEN 'easy' THEN 0.75
          WHEN 'hard' THEN 1.25
          ELSE 1.00
        END AS item_weight
      FROM dedup d
      JOIN public.questions q ON q.id = d.question_id AND q.course_id = p_course_id
    ),
    by_skill AS (
      SELECT
        w.skill_id,
        pg_catalog.count(*)::INT AS attempt_count,
        pg_catalog.sum(CASE WHEN w.is_correct THEN w.item_weight ELSE 0 END) AS earned,
        pg_catalog.sum(CASE WHEN w.is_correct THEN w.item_weight ELSE LEAST(w.item_weight, 1.00) END) AS possible
      FROM weighted w
      GROUP BY w.skill_id
    )
    SELECT
      bs.skill_id,
      bs.attempt_count,
      GREATEST(
        0,
        LEAST(
          100,
          CASE
            WHEN bs.possible > 0 THEN pg_catalog.round((bs.earned / bs.possible) * 100.0)::INT
            ELSE 0
          END
        )
      ) AS skill_score
    FROM by_skill bs
    ORDER BY bs.skill_id ASC
  LOOP
    IF v_rec.skill_score < v_min_score THEN
      v_min_score := v_rec.skill_score;
      v_weakest_skill_id := v_rec.skill_id;
    END IF;
    v_sum_scores := v_sum_scores + v_rec.skill_score;
    v_skill_count := v_skill_count + 1;
  END LOOP;

  IF v_min_score >= 80 THEN
    v_weakest_skill_id := NULL;
  END IF;

  IF v_skill_count > 0 THEN
    v_overall_score := pg_catalog.round(v_sum_scores::NUMERIC / v_skill_count::NUMERIC)::INT;
  END IF;

  FOR v_rec IN
    WITH dedup AS (
      SELECT DISTINCT ON (item->>'question_id')
        item->>'question_id' AS question_id,
        (item->>'selected_index')::INT AS selected_index,
        ord
      FROM pg_catalog.jsonb_array_elements(COALESCE(p_submissions, '[]'::pg_catalog.jsonb)) WITH ORDINALITY AS s(item, ord)
      ORDER BY item->>'question_id', ord DESC
    ),
    weighted AS (
      SELECT
        q.skill_id,
        (d.selected_index = q.correct_index) AS is_correct,
        CASE q.difficulty
          WHEN 'easy' THEN 0.75
          WHEN 'hard' THEN 1.25
          ELSE 1.00
        END AS item_weight
      FROM dedup d
      JOIN public.questions q ON q.id = d.question_id AND q.course_id = p_course_id
    ),
    by_skill AS (
      SELECT
        w.skill_id,
        pg_catalog.count(*)::INT AS attempt_count,
        pg_catalog.sum(CASE WHEN w.is_correct THEN w.item_weight ELSE 0 END) AS earned,
        pg_catalog.sum(CASE WHEN w.is_correct THEN w.item_weight ELSE LEAST(w.item_weight, 1.00) END) AS possible
      FROM weighted w
      GROUP BY w.skill_id
    )
    SELECT
      bs.skill_id,
      bs.attempt_count,
      GREATEST(
        0,
        LEAST(
          100,
          CASE
            WHEN bs.possible > 0 THEN pg_catalog.round((bs.earned / bs.possible) * 100.0)::INT
            ELSE 0
          END
        )
      ) AS skill_score
    FROM by_skill bs
    ORDER BY bs.skill_id ASC
  LOOP
    v_skill_map := v_skill_map || pg_catalog.jsonb_build_object(
      v_rec.skill_id,
      pg_catalog.jsonb_build_object(
        'skillId', v_rec.skill_id,
        'courseId', p_course_id,
        'score', v_rec.skill_score,
        'lastUpdated', v_now_ms,
        'masteryLevel', bilimyol_private.get_mastery_level(v_rec.skill_score, v_rec.attempt_count),
        'isWeakestFocus', (v_weakest_skill_id IS NOT NULL AND v_rec.skill_id = v_weakest_skill_id),
        'attemptCount', v_rec.attempt_count,
        'confidence', bilimyol_private.compute_confidence_label(v_rec.attempt_count)
      )
    );
  END LOOP;

  RETURN pg_catalog.jsonb_build_object(
    'overall_score', v_overall_score,
    'weakest_skill_id', v_weakest_skill_id,
    'skill_scores', v_skill_map
  );
END;
$$;

REVOKE ALL ON FUNCTION bilimyol_private.compute_placement_skill_scores(TEXT, JSONB)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION bilimyol_private.evaluate_english_placement_cefr(
  p_user_id UUID,
  p_submissions JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  v_a1_total INT := 0;
  v_a1_correct INT := 0;
  v_a2_total INT := 0;
  v_a2_correct INT := 0;
  v_b1_total INT := 0;
  v_b1_correct INT := 0;
  v_total INT := 0;
  v_correct INT := 0;
  v_a1_acc NUMERIC := 0;
  v_a2_acc NUMERIC := 0;
  v_b1_acc NUMERIC := 0;
  v_overall_acc NUMERIC := 0;
  v_assessed TEXT := 'A1';
  v_floor TEXT := NULL;
  v_effective TEXT := 'A1';
  v_assessed_rank INT := 1;
  v_floor_rank INT := 0;
BEGIN
  IF p_user_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM public.lesson_progress lp
      LEFT JOIN public.roadmap_nodes rn
        ON rn.target_lesson_id = lp.lesson_id AND rn.course_id = 'course_eng_01'
      WHERE lp.user_id = p_user_id
        AND lp.course_id = 'course_eng_01'
        AND lp.status = 'completed'
        AND (
          rn.id IN ('node_eng_b1_exit', 'node_eng_a2_exit')
          OR lp.lesson_id IN ('lesson_eng_b1_exit_assessment', 'lesson_eng_a2_exit_assessment')
        )
    ) THEN
      v_floor := 'B1';
    ELSIF EXISTS (
      SELECT 1
      FROM public.lesson_progress lp
      LEFT JOIN public.roadmap_nodes rn
        ON rn.target_lesson_id = lp.lesson_id AND rn.course_id = 'course_eng_01'
      WHERE lp.user_id = p_user_id
        AND lp.course_id = 'course_eng_01'
        AND lp.status = 'completed'
        AND (
          rn.id = 'node_eng_a1_exit'
          OR lp.lesson_id = 'lesson_eng_a1_exit_assessment'
        )
    ) THEN
      v_floor := 'A2';
    END IF;
  END IF;

  WITH dedup AS (
    SELECT DISTINCT ON (item->>'question_id')
      item->>'question_id' AS question_id,
      (item->>'selected_index')::INT AS selected_index,
      ord
    FROM pg_catalog.jsonb_array_elements(COALESCE(p_submissions, '[]'::pg_catalog.jsonb)) WITH ORDINALITY AS s(item, ord)
    ORDER BY item->>'question_id', ord DESC
  ),
  banded AS (
    SELECT
      CASE
        WHEN q.cefr_level IN ('A1', 'A2', 'B1') THEN q.cefr_level
        WHEN q.difficulty = 'easy' THEN 'A1'
        WHEN q.difficulty = 'hard' THEN 'B1'
        ELSE 'A2'
      END AS band,
      (d.selected_index = q.correct_index) AS is_correct
    FROM dedup d
    JOIN public.questions q ON q.id = d.question_id AND q.course_id = 'course_eng_01'
  )
  SELECT
    pg_catalog.count(*)::INT,
    pg_catalog.count(*) FILTER (WHERE is_correct)::INT,
    pg_catalog.count(*) FILTER (WHERE band = 'A1')::INT,
    pg_catalog.count(*) FILTER (WHERE band = 'A1' AND is_correct)::INT,
    pg_catalog.count(*) FILTER (WHERE band = 'A2')::INT,
    pg_catalog.count(*) FILTER (WHERE band = 'A2' AND is_correct)::INT,
    pg_catalog.count(*) FILTER (WHERE band = 'B1')::INT,
    pg_catalog.count(*) FILTER (WHERE band = 'B1' AND is_correct)::INT
  INTO
    v_total, v_correct,
    v_a1_total, v_a1_correct,
    v_a2_total, v_a2_correct,
    v_b1_total, v_b1_correct
  FROM banded;

  IF v_total = 0 THEN
    v_assessed := 'A1';
  ELSE
    v_a1_acc := CASE WHEN v_a1_total > 0 THEN v_a1_correct::NUMERIC / v_a1_total::NUMERIC ELSE 0 END;
    v_a2_acc := CASE WHEN v_a2_total > 0 THEN v_a2_correct::NUMERIC / v_a2_total::NUMERIC ELSE 0 END;
    v_b1_acc := CASE WHEN v_b1_total > 0 THEN v_b1_correct::NUMERIC / v_b1_total::NUMERIC ELSE 0 END;
    v_overall_acc := v_correct::NUMERIC / v_total::NUMERIC;

    IF v_b1_total >= 2
       AND v_b1_acc >= 0.5
       AND (v_a2_total = 0 OR v_a2_acc >= 0.5)
       AND v_overall_acc >= 0.625 THEN
      v_assessed := 'B1';
    ELSIF v_a2_total > 0
          AND v_a2_acc >= 0.5
          AND (v_b1_total > 0 OR v_a1_total = 0 OR v_a1_acc >= 0.5)
          AND v_overall_acc >= 0.375 THEN
      v_assessed := 'A2';
    ELSIF v_b1_total = 0 AND v_a2_total = 0 AND v_overall_acc >= 0.75 THEN
      v_assessed := 'A2';
    ELSIF (v_a1_total > 0 AND v_a1_acc >= 0.5) OR v_overall_acc >= 0.25 THEN
      v_assessed := 'A1';
    ELSE
      v_assessed := 'Pre-A1';
    END IF;
  END IF;

  v_assessed_rank := CASE v_assessed
    WHEN 'Pre-A1' THEN 0
    WHEN 'A1' THEN 1
    WHEN 'A2' THEN 2
    WHEN 'B1' THEN 3
    ELSE 1
  END;

  v_floor_rank := CASE v_floor
    WHEN 'A1' THEN 1
    WHEN 'A2' THEN 2
    WHEN 'B1' THEN 3
    ELSE -1
  END;

  v_effective := CASE
    WHEN v_floor IS NOT NULL AND v_floor_rank > v_assessed_rank THEN v_floor
    ELSE v_assessed
  END;

  RETURN pg_catalog.jsonb_build_object(
    'assessed_cefr', v_assessed,
    'unlocked_cefr_floor', v_floor,
    'effective_cefr', v_effective
  );
END;
$$;

REVOKE ALL ON FUNCTION bilimyol_private.evaluate_english_placement_cefr(UUID, JSONB)
  FROM PUBLIC, anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 6. Unified Course Skill Score Recalculation (FIX-P0-02, FIX-P1-09, FIX-P1-46)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION bilimyol_private.recalculate_course_skill_scores_for_user(
  p_user_id UUID,
  p_course_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_latest_plc_id UUID := NULL;
  v_latest_plc_at TIMESTAMPTZ := NULL;
  v_plc_skills JSONB := '{}'::pg_catalog.jsonb;
  v_starter_lesson_id TEXT := NULL;
  v_skill RECORD;
  v_prior_score INT;
  v_unique_total INT;
  v_unique_correct INT;
  v_weighted_correct NUMERIC;
  v_weighted_total NUMERIC;
  v_unadjusted_earned NUMERIC;
  v_has_non_starter BOOLEAN;
  v_post_count INT;
  v_score INT;
  v_reinf_floor INT;
  v_effective_count INT;
  v_mastery_count INT;
  v_mastery TEXT;
  v_min_score INT := 101;
  v_weakest_skill_id TEXT := NULL;
  v_result JSONB := '{}'::pg_catalog.jsonb;
BEGIN
  IF p_user_id IS NULL OR NULLIF(pg_catalog.btrim(p_course_id), '') IS NULL THEN
    RETURN '{}'::pg_catalog.jsonb;
  END IF;

  SELECT c.starter_lesson_id
  INTO v_starter_lesson_id
  FROM public.courses c
  WHERE c.id = p_course_id;

  SELECT pa.id, pa.completed_at
  INTO v_latest_plc_id, v_latest_plc_at
  FROM public.placement_attempts pa
  WHERE pa.user_id = p_user_id
    AND pa.course_id = p_course_id
  ORDER BY pa.completed_at DESC, pa.id DESC
  LIMIT 1;

  SELECT COALESCE(lp.placement_skill_scores_by_course->p_course_id, '{}'::pg_catalog.jsonb)
  INTO v_plc_skills
  FROM public.learner_profiles lp
  WHERE lp.user_id = p_user_id;

  IF v_plc_skills IS NULL THEN
    v_plc_skills := '{}'::pg_catalog.jsonb;
  END IF;

  IF v_latest_plc_id IS NOT NULL AND v_plc_skills = '{}'::pg_catalog.jsonb THEN
    SELECT COALESCE(
      (bilimyol_private.compute_placement_skill_scores(
        p_course_id,
        COALESCE(
          (SELECT pg_catalog.jsonb_agg(
             pg_catalog.jsonb_build_object('question_id', ans.question_id, 'selected_index', ans.selected_index)
             ORDER BY ans.created_at ASC, ans.id ASC
           )
           FROM public.placement_answers ans
           WHERE ans.attempt_id = v_latest_plc_id),
          '[]'::pg_catalog.jsonb
        )
      ))->'skill_scores',
      '{}'::pg_catalog.jsonb
    )
    INTO v_plc_skills;
  END IF;

  IF p_course_id = 'course_eng_01' THEN
    DELETE FROM public.learner_skill_scores lss
    WHERE lss.user_id = p_user_id
      AND lss.course_id = 'course_eng_01'
      AND NOT EXISTS (
        SELECT 1
        FROM public.answer_attempts aa
        WHERE aa.user_id = p_user_id
          AND aa.course_id = 'course_eng_01'
          AND aa.skill_id = lss.skill_id
          AND aa.lesson_id <> 'placement_test'
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.reinforcement_attempts ra
        WHERE ra.user_id = p_user_id
          AND ra.course_id = 'course_eng_01'
          AND ra.skill_id = lss.skill_id
          AND ra.is_correct = true
      );
  END IF;

  FOR v_skill IN
    SELECT DISTINCT s_union.skill_id
    FROM (
      SELECT aa.skill_id
      FROM public.answer_attempts aa
      WHERE aa.user_id = p_user_id
        AND aa.course_id = p_course_id
        AND aa.lesson_id <> 'placement_test'
      UNION
      SELECT ra.skill_id
      FROM public.reinforcement_attempts ra
      WHERE ra.user_id = p_user_id
        AND ra.course_id = p_course_id
        AND ra.is_correct = true
      UNION
      SELECT k.skill_id
      FROM pg_catalog.jsonb_object_keys(
        CASE
          WHEN p_course_id <> 'course_eng_01' THEN v_plc_skills
          ELSE '{}'::pg_catalog.jsonb
        END
      ) AS k(skill_id)
    ) s_union
    JOIN public.skills sk ON sk.id = s_union.skill_id AND sk.course_id = p_course_id
    ORDER BY s_union.skill_id ASC
  LOOP
    v_prior_score := NULL;
    IF v_plc_skills ? v_skill.skill_id AND pg_catalog.jsonb_typeof(v_plc_skills->v_skill.skill_id->'score') = 'number' THEN
      v_prior_score := (v_plc_skills->v_skill.skill_id->>'score')::INT;
    END IF;

    IF p_course_id = 'course_eng_01' THEN
      WITH post_attempts AS (
        SELECT
          aa.id,
          aa.question_id,
          aa.lesson_id,
          aa.is_correct,
          aa.created_at,
          (
            aa.lesson_id IN ('lesson_math_starter', 'lesson_eng_starter', 'lesson_it_starter', 'lesson_logic_starter')
            OR (v_starter_lesson_id IS NOT NULL AND aa.lesson_id = v_starter_lesson_id)
          ) AS is_starter
        FROM public.answer_attempts aa
        WHERE aa.user_id = p_user_id
          AND aa.course_id = p_course_id
          AND aa.skill_id = v_skill.skill_id
          AND aa.lesson_id <> 'placement_test'
          AND (v_latest_plc_at IS NULL OR aa.created_at > v_latest_plc_at)
      ),
      per_question AS (
        SELECT DISTINCT ON (pa.question_id)
          pa.question_id,
          pa.is_correct AS latest_is_correct,
          pa.is_starter,
          (SELECT p_first.is_correct
           FROM post_attempts p_first
           WHERE p_first.question_id = pa.question_id
           ORDER BY p_first.created_at ASC, p_first.id ASC
           LIMIT 1) AS first_is_correct
        FROM post_attempts pa
        ORDER BY pa.question_id, pa.created_at DESC, pa.id DESC
      )
      SELECT
        (SELECT pg_catalog.count(*)::INT FROM post_attempts),
        pg_catalog.count(*)::INT,
        pg_catalog.count(*) FILTER (WHERE pq.latest_is_correct)::INT,
        COALESCE(pg_catalog.bool_or(NOT pq.is_starter), false),
        COALESCE(pg_catalog.sum(CASE WHEN pq.is_starter THEN 0.5 ELSE 1.0 END), 0),
        COALESCE(pg_catalog.sum(
          CASE
            WHEN NOT pq.latest_is_correct THEN 0
            WHEN NOT pq.first_is_correct AND NOT pq.is_starter THEN (CASE WHEN pq.is_starter THEN 0.5 ELSE 1.0 END) * 0.75
            ELSE (CASE WHEN pq.is_starter THEN 0.5 ELSE 1.0 END)
          END
        ), 0),
        COALESCE(pg_catalog.sum(
          CASE
            WHEN NOT pq.latest_is_correct THEN 0
            WHEN NOT pq.first_is_correct AND NOT pq.is_starter THEN 0.75
            ELSE 1.0
          END
        ), 0)
      INTO
        v_post_count,
        v_unique_total,
        v_unique_correct,
        v_has_non_starter,
        v_weighted_total,
        v_weighted_correct,
        v_unadjusted_earned
      FROM per_question pq;

      -- Isolate English placement prior from non-starter curriculum mastery,
      -- while keeping starter-only attempts calibrated against placement prior (FIX-P1-09).
      IF v_has_non_starter THEN
        v_prior_score := NULL;
      END IF;

      IF v_post_count = 0 THEN
        SELECT pg_catalog.count(*)::INT,
               pg_catalog.count(*) FILTER (WHERE latest_all.is_correct)::INT
        INTO v_unique_total, v_unique_correct
        FROM (
          SELECT DISTINCT ON (aa.question_id) aa.is_correct
          FROM public.answer_attempts aa
          WHERE aa.user_id = p_user_id
            AND aa.course_id = p_course_id
            AND aa.skill_id = v_skill.skill_id
            AND aa.lesson_id <> 'placement_test'
          ORDER BY aa.question_id, aa.created_at DESC, aa.id DESC
        ) latest_all;

        v_score := CASE
          WHEN v_unique_total > 0 THEN pg_catalog.round((v_unique_correct::NUMERIC / v_unique_total::NUMERIC) * 100.0)::INT
          ELSE COALESCE(v_prior_score, 0)
        END;
      ELSIF v_prior_score IS NULL AND v_has_non_starter THEN
        v_score := pg_catalog.round((v_unadjusted_earned / GREATEST(1, v_unique_total)::NUMERIC) * 100.0)::INT;
      ELSE
        v_score := bilimyol_private.compute_calibrated_skill_score(
          v_weighted_correct,
          v_weighted_total,
          v_prior_score,
          (v_prior_score IS NULL AND NOT v_has_non_starter),
          v_has_non_starter
        );
      END IF;
    ELSE
      WITH post_attempts AS (
        SELECT
          aa.id,
          aa.question_id,
          aa.lesson_id,
          aa.is_correct,
          aa.created_at,
          (
            aa.lesson_id IN ('lesson_math_starter', 'lesson_eng_starter', 'lesson_it_starter', 'lesson_logic_starter')
            OR (v_starter_lesson_id IS NOT NULL AND aa.lesson_id = v_starter_lesson_id)
          ) AS is_starter
        FROM public.answer_attempts aa
        WHERE aa.user_id = p_user_id
          AND aa.course_id = p_course_id
          AND aa.skill_id = v_skill.skill_id
          AND aa.lesson_id <> 'placement_test'
          AND (v_latest_plc_at IS NULL OR aa.created_at > v_latest_plc_at)
      ),
      per_question AS (
        SELECT DISTINCT ON (pa.question_id)
          pa.question_id,
          pa.is_correct AS latest_is_correct
        FROM post_attempts pa
        ORDER BY pa.question_id, pa.created_at DESC, pa.id DESC
      )
      SELECT
        pg_catalog.count(*)::INT,
        COALESCE((SELECT pg_catalog.count(*)::INT FROM per_question), 0),
        COALESCE((SELECT pg_catalog.count(*) FILTER (WHERE latest_is_correct)::INT FROM per_question), 0),
        COALESCE(pg_catalog.bool_or(NOT pa.is_starter), false),
        COALESCE(pg_catalog.sum(CASE WHEN pa.is_starter THEN 0.5 ELSE 1.0 END), 0),
        COALESCE(pg_catalog.sum(
          CASE
            WHEN pa.is_correct THEN (CASE WHEN pa.is_starter THEN 0.5 ELSE 1.0 END)
            ELSE 0
          END
        ), 0)
      INTO
        v_post_count,
        v_unique_total,
        v_unique_correct,
        v_has_non_starter,
        v_weighted_total,
        v_weighted_correct
      FROM post_attempts pa;

      IF v_post_count = 0 THEN
        v_score := COALESCE(v_prior_score, 0);
      ELSE
        v_score := bilimyol_private.compute_calibrated_skill_score(
          v_weighted_correct,
          v_weighted_total,
          v_prior_score,
          (v_prior_score IS NULL AND NOT v_has_non_starter),
          v_has_non_starter
        );
      END IF;
    END IF;

    v_score := GREATEST(0, LEAST(100, COALESCE(v_score, 0)));

    SELECT COALESCE(pg_catalog.max(ra.after_score), 0)
    INTO v_reinf_floor
    FROM public.reinforcement_attempts ra
    WHERE ra.user_id = p_user_id
      AND ra.course_id = p_course_id
      AND ra.skill_id = v_skill.skill_id
      AND ra.is_correct = true
      AND (v_latest_plc_at IS NULL OR p_course_id = 'course_eng_01' OR ra.created_at > v_latest_plc_at)
      AND NOT EXISTS (
        SELECT 1
        FROM public.answer_attempts newer_wrong
        WHERE newer_wrong.user_id = p_user_id
          AND newer_wrong.course_id = p_course_id
          AND newer_wrong.skill_id = v_skill.skill_id
          AND newer_wrong.lesson_id <> 'placement_test'
          AND newer_wrong.is_correct = false
          AND newer_wrong.created_at > ra.created_at
      );

    IF v_reinf_floor > v_score THEN
      v_score := v_reinf_floor;
    END IF;

    v_effective_count := GREATEST(
      COALESCE(v_unique_total, 0),
      CASE WHEN v_prior_score IS NOT NULL THEN 2 ELSE 0 END,
      CASE WHEN v_reinf_floor > 0 THEN 1 ELSE 0 END
    );
    v_mastery_count := CASE
      WHEN COALESCE(v_unique_total, 0) > 0 THEN v_unique_total
      WHEN v_prior_score IS NOT NULL THEN 4
      ELSE 1
    END;
    v_mastery := bilimyol_private.get_mastery_level(v_score, v_mastery_count);

    INSERT INTO public.learner_skill_scores (
      user_id, course_id, skill_id, score, mastery_level, is_weakest_focus, confidence, attempt_count, last_updated
    )
    VALUES (
      p_user_id,
      p_course_id,
      v_skill.skill_id,
      v_score,
      v_mastery,
      false,
      bilimyol_private.compute_confidence_numeric(v_effective_count),
      GREATEST(1, v_effective_count),
      pg_catalog.now()
    )
    ON CONFLICT (user_id, course_id, skill_id) DO UPDATE SET
      score = EXCLUDED.score,
      mastery_level = EXCLUDED.mastery_level,
      confidence = EXCLUDED.confidence,
      attempt_count = EXCLUDED.attempt_count,
      last_updated = pg_catalog.now();

    IF v_score < v_min_score THEN
      v_min_score := v_score;
      v_weakest_skill_id := v_skill.skill_id;
    END IF;

    v_result := v_result || pg_catalog.jsonb_build_object(
      v_skill.skill_id,
      pg_catalog.jsonb_build_object(
        'score', v_score,
        'attempt_count', GREATEST(1, v_effective_count),
        'unique_total', COALESCE(v_unique_total, 0),
        'unique_correct', COALESCE(v_unique_correct, 0),
        'mastery_level', v_mastery,
        'confidence', bilimyol_private.compute_confidence_label(v_effective_count)
      )
    );
  END LOOP;

  UPDATE public.learner_skill_scores lss
  SET is_weakest_focus = (v_min_score < 80 AND lss.skill_id = v_weakest_skill_id)
  WHERE lss.user_id = p_user_id
    AND lss.course_id = p_course_id
    AND lss.is_weakest_focus IS DISTINCT FROM (v_min_score < 80 AND lss.skill_id = v_weakest_skill_id);

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION bilimyol_private.recalculate_course_skill_scores_for_user(UUID, TEXT)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.recalculate_skill_scores(p_course_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('learning:' || v_uid::TEXT, 0)
  );

  RETURN bilimyol_private.recalculate_course_skill_scores_for_user(v_uid, p_course_id);
END;
$$;

REVOKE ALL ON FUNCTION public.recalculate_skill_scores(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recalculate_skill_scores(TEXT) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 7. Updated public.save_placement_attempt & public.advance_placement
--    (FIX-P0-02, FIX-P0-11, FIX-P1-16, FIX-P1-46, FIX-P2-09)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.save_placement_attempt(
  p_course_id TEXT,
  p_submissions JSONB,
  p_idempotency_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_attempt_id UUID;
  v_existing_score INT;
  v_existing_weakest TEXT;
  v_submission JSONB;
  v_question RECORD;
  v_selected INT;
  v_is_correct BOOLEAN;
  v_score INT;
  v_weakest_skill_id TEXT;
  v_plc_calc JSONB;
  v_skill_scores_json JSONB;
  v_cefr_eval JSONB := NULL;
  v_effective_cefr TEXT := NULL;
  v_assessed_cefr TEXT := NULL;
  v_unlocked_floor TEXT := NULL;
  v_existing_payload JSONB;
  v_request_payload JSONB;
  v_award JSONB;
  v_answer_xp INT := 0;
  v_correct_qids TEXT[] := '{}';
  v_qid TEXT;
  v_today DATE := (pg_catalog.now() AT TIME ZONE 'Asia/Tashkent')::date;
  v_daily_total INT := 0;
  v_daily_correct INT := 0;
  v_daily_accuracy INT := 0;
  v_answer_idem_key TEXT;
  v_attempt_ts TIMESTAMPTZ;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  IF p_course_id IS NULL OR NULLIF(pg_catalog.btrim(p_course_id), '') IS NULL THEN
    RAISE EXCEPTION 'Placement kursi noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;
  IF pg_catalog.char_length(p_course_id) > 64 THEN
    RAISE EXCEPTION 'Placement kursi identifikatori haddan tashqari uzun.' USING ERRCODE = '23514';
  END IF;
  IF p_submissions IS NULL OR pg_catalog.jsonb_typeof(p_submissions) <> 'array'
     OR pg_catalog.jsonb_array_length(p_submissions) = 0 THEN
    RAISE EXCEPTION 'Placement javoblari bo‘sh bo‘lishi mumkin emas.' USING ERRCODE = '22023';
  END IF;
  IF NULLIF(pg_catalog.btrim(p_idempotency_key), '') IS NULL THEN
    RAISE EXCEPTION 'Placement idempotency kaliti talab qilinadi.' USING ERRCODE = '22023';
  END IF;
  IF pg_catalog.char_length(p_idempotency_key) > 128 THEN
    RAISE EXCEPTION 'Idempotency kaliti uzunligi 128 belgidan oshmasligi shart.' USING ERRCODE = '23514';
  END IF;
  IF pg_catalog.jsonb_array_length(p_submissions) > 100 OR EXISTS (
    SELECT 1 FROM pg_catalog.jsonb_array_elements(p_submissions) AS item
    GROUP BY item->>'question_id' HAVING pg_catalog.count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Placement savollari takrorlangan yoki soni ortiqcha.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('learning:' || v_uid::TEXT, 0)
  );
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_uid::TEXT || ':' || p_course_id || ':' || p_idempotency_key, 0)
  );

  SELECT pa.id, pa.score, pa.weakest_skill_id
  INTO v_attempt_id, v_existing_score, v_existing_weakest
  FROM public.placement_attempts pa
  WHERE pa.user_id = v_uid
    AND pa.course_id = p_course_id
    AND pa.idempotency_key = p_idempotency_key
  LIMIT 1;

  IF v_attempt_id IS NOT NULL THEN
    SELECT pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object('question_id', pa.question_id, 'selected_index', pa.selected_index)
      ORDER BY pa.question_id
    )
    INTO v_existing_payload
    FROM public.placement_answers pa
    WHERE pa.attempt_id = v_attempt_id;

    SELECT pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object('question_id', item->>'question_id', 'selected_index', item->'selected_index')
      ORDER BY item->>'question_id'
    )
    INTO v_request_payload
    FROM pg_catalog.jsonb_array_elements(p_submissions) AS item;

    IF v_request_payload IS DISTINCT FROM v_existing_payload THEN
      RAISE EXCEPTION 'Idempotency kaliti boshqa placement javoblari uchun ishlatilgan.' USING ERRCODE = '22023';
    END IF;

    v_plc_calc := bilimyol_private.compute_placement_skill_scores(p_course_id, p_submissions);
    IF p_course_id = 'course_eng_01' THEN
      v_cefr_eval := bilimyol_private.evaluate_english_placement_cefr(v_uid, p_submissions);
      v_effective_cefr := v_cefr_eval->>'effective_cefr';
      v_assessed_cefr := v_cefr_eval->>'assessed_cefr';
      v_unlocked_floor := v_cefr_eval->>'unlocked_cefr_floor';
    END IF;

    RETURN pg_catalog.jsonb_build_object(
      'attempt_id', v_attempt_id,
      'score', v_existing_score,
      'weakest_skill_id', COALESCE(v_existing_weakest, ''),
      'skill_scores', COALESCE(v_plc_calc->'skill_scores', '{}'::pg_catalog.jsonb),
      'placement_cefr', v_effective_cefr,
      'assessed_cefr', v_assessed_cefr,
      'unlocked_cefr_floor', v_unlocked_floor,
      'already_processed', true
    );
  END IF;

  FOR v_submission IN SELECT * FROM pg_catalog.jsonb_array_elements(p_submissions) LOOP
    SELECT q.id, q.skill_id, q.correct_index, q.options
    INTO v_question
    FROM public.questions q
    WHERE q.id = v_submission->>'question_id'
      AND q.course_id = p_course_id
      AND q.is_placement = true;

    IF v_question.id IS NULL THEN
      RAISE EXCEPTION 'Placement savoli kurs bilan mos emas.' USING ERRCODE = '22023';
    END IF;
    IF NOT COALESCE((v_submission->>'selected_index') ~ '^[0-9]+$', false) THEN
      RAISE EXCEPTION 'Tanlangan javob indeksi noto‘g‘ri.' USING ERRCODE = '22023';
    END IF;
    v_selected := (v_submission->>'selected_index')::INT;
    IF v_selected IS NULL OR v_selected < 0
       OR v_selected >= pg_catalog.jsonb_array_length(v_question.options) THEN
      RAISE EXCEPTION 'Tanlangan javob indeksi noto‘g‘ri.' USING ERRCODE = '22023';
    END IF;
  END LOOP;

  v_plc_calc := bilimyol_private.compute_placement_skill_scores(p_course_id, p_submissions);
  v_score := COALESCE((v_plc_calc->>'overall_score')::INT, 0);
  v_weakest_skill_id := NULLIF(COALESCE(v_plc_calc->>'weakest_skill_id', ''), '');
  v_skill_scores_json := COALESCE(v_plc_calc->'skill_scores', '{}'::pg_catalog.jsonb);

  IF p_course_id = 'course_eng_01' THEN
    v_cefr_eval := bilimyol_private.evaluate_english_placement_cefr(v_uid, p_submissions);
    v_effective_cefr := v_cefr_eval->>'effective_cefr';
    v_assessed_cefr := v_cefr_eval->>'assessed_cefr';
    v_unlocked_floor := v_cefr_eval->>'unlocked_cefr_floor';
  END IF;

  v_attempt_ts := GREATEST(
    pg_catalog.clock_timestamp(),
    COALESCE(
      (SELECT pg_catalog.max(aa_prev.created_at) + interval '1 microsecond'
       FROM public.answer_attempts aa_prev
       WHERE aa_prev.user_id = v_uid),
      pg_catalog.clock_timestamp()
    ),
    COALESCE(
      (SELECT pg_catalog.max(pa_prev.completed_at) + interval '1 microsecond'
       FROM public.placement_attempts pa_prev
       WHERE pa_prev.user_id = v_uid),
      pg_catalog.clock_timestamp()
    )
  );

  INSERT INTO public.placement_attempts (
    user_id, course_id, score, weakest_skill_id, idempotency_key, started_at, completed_at
  )
  VALUES (
    v_uid, p_course_id, v_score, v_weakest_skill_id, p_idempotency_key, v_attempt_ts, v_attempt_ts
  )
  RETURNING id INTO v_attempt_id;

  FOR v_submission IN SELECT * FROM pg_catalog.jsonb_array_elements(p_submissions) LOOP
    SELECT q.skill_id, q.correct_index, q.options
    INTO v_question
    FROM public.questions q
    WHERE q.id = v_submission->>'question_id'
      AND q.course_id = p_course_id
      AND q.is_placement = true;

    v_selected := (v_submission->>'selected_index')::INT;
    v_is_correct := (v_selected = v_question.correct_index);
    v_answer_idem_key := pg_catalog.left(
      'plc:' || v_attempt_id::TEXT || ':' || (v_submission->>'question_id'),
      128
    );

    INSERT INTO public.placement_answers (
      attempt_id, user_id, question_id, selected_index, is_correct, created_at
    )
    VALUES (
      v_attempt_id, v_uid, v_submission->>'question_id', v_selected, v_is_correct, v_attempt_ts
    );

    INSERT INTO public.answer_attempts (
      user_id, course_id, skill_id, lesson_id, question_id,
      selected_index, selected_answer, is_correct, idempotency_key, created_at
    )
    VALUES (
      v_uid,
      p_course_id,
      v_question.skill_id,
      'placement_test',
      v_submission->>'question_id',
      v_selected,
      pg_catalog.left(COALESCE(v_question.options->>v_selected, ''), 4000),
      v_is_correct,
      v_answer_idem_key,
      v_attempt_ts
    )
    ON CONFLICT (user_id, idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

    INSERT INTO bilimyol_private.daily_question_outcomes (
      user_id, activity_date, question_id, is_correct, updated_at
    )
    VALUES (
      v_uid, v_today, v_submission->>'question_id', v_is_correct, v_attempt_ts
    )
    ON CONFLICT (user_id, activity_date, question_id) DO UPDATE SET
      is_correct = EXCLUDED.is_correct,
      updated_at = EXCLUDED.updated_at;

    IF v_is_correct THEN
      v_correct_qids := pg_catalog.array_append(v_correct_qids, v_submission->>'question_id');
    END IF;
  END LOOP;

  INSERT INTO public.learner_profiles (
    user_id,
    selected_course_id,
    placement_score_by_course,
    placement_cefr_by_course,
    placement_skill_scores_by_course,
    updated_at
  )
  VALUES (
    v_uid,
    p_course_id,
    pg_catalog.jsonb_build_object(p_course_id, v_score),
    CASE
      WHEN v_effective_cefr IS NOT NULL THEN pg_catalog.jsonb_build_object(p_course_id, v_effective_cefr)
      ELSE '{}'::pg_catalog.jsonb
    END,
    pg_catalog.jsonb_build_object(p_course_id, v_skill_scores_json),
    pg_catalog.now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    placement_score_by_course = pg_catalog.jsonb_set(
      COALESCE(public.learner_profiles.placement_score_by_course, '{}'::pg_catalog.jsonb),
      ARRAY[p_course_id],
      pg_catalog.to_jsonb(v_score),
      true
    ),
    placement_cefr_by_course = CASE
      WHEN v_effective_cefr IS NOT NULL THEN pg_catalog.jsonb_set(
        COALESCE(public.learner_profiles.placement_cefr_by_course, '{}'::pg_catalog.jsonb),
        ARRAY[p_course_id],
        pg_catalog.to_jsonb(v_effective_cefr),
        true
      )
      ELSE COALESCE(public.learner_profiles.placement_cefr_by_course, '{}'::pg_catalog.jsonb)
    END,
    placement_skill_scores_by_course = pg_catalog.jsonb_set(
      COALESCE(public.learner_profiles.placement_skill_scores_by_course, '{}'::pg_catalog.jsonb),
      ARRAY[p_course_id],
      v_skill_scores_json,
      true
    ),
    updated_at = pg_catalog.now();

  PERFORM bilimyol_private.recalculate_course_skill_scores_for_user(v_uid, p_course_id);

  SELECT pg_catalog.count(*)::INT,
         pg_catalog.count(*) FILTER (WHERE dqo.is_correct)::INT
  INTO v_daily_total, v_daily_correct
  FROM bilimyol_private.daily_question_outcomes dqo
  WHERE dqo.user_id = v_uid AND dqo.activity_date = v_today;

  v_daily_accuracy := CASE
    WHEN v_daily_total > 0
    THEN pg_catalog.round((v_daily_correct::NUMERIC * 100) / v_daily_total::NUMERIC)::INT
    ELSE 0
  END;

  INSERT INTO public.daily_learning_stats (
    user_id, activity_date, questions_answered, correct_answers, accuracy_percent, xp_earned, updated_at
  )
  VALUES (v_uid, v_today, v_daily_total, v_daily_correct, v_daily_accuracy, 0, pg_catalog.now())
  ON CONFLICT (user_id, activity_date) DO UPDATE SET
    questions_answered = EXCLUDED.questions_answered,
    correct_answers = EXCLUDED.correct_answers,
    accuracy_percent = EXCLUDED.accuracy_percent,
    updated_at = pg_catalog.now();

  FOREACH v_qid IN ARRAY v_correct_qids LOOP
    v_award := bilimyol_private.award_xp(v_uid, 2, 'answer_correct_' || v_qid);
    IF (v_award->>'awarded')::BOOLEAN THEN
      v_answer_xp := v_answer_xp + 2;
    END IF;
  END LOOP;

  IF v_answer_xp > 0 THEN
    UPDATE public.daily_learning_stats
    SET xp_earned = public.daily_learning_stats.xp_earned + v_answer_xp,
        updated_at = pg_catalog.now()
    WHERE user_id = v_uid AND activity_date = v_today;
  END IF;

  PERFORM public.record_learning_activity(v_today);
  PERFORM bilimyol_private.award_xp(v_uid, 20, 'placement_completed_' || p_course_id);

  RETURN pg_catalog.jsonb_build_object(
    'attempt_id', v_attempt_id,
    'score', v_score,
    'weakest_skill_id', COALESCE(v_weakest_skill_id, ''),
    'skill_scores', v_skill_scores_json,
    'placement_cefr', v_effective_cefr,
    'assessed_cefr', v_assessed_cefr,
    'unlocked_cefr_floor', v_unlocked_floor,
    'already_processed', false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.save_placement_attempt(TEXT, JSONB, TEXT)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.advance_placement(
  p_course_id TEXT,
  p_session_id UUID DEFAULT NULL,
  p_question_id TEXT DEFAULT NULL,
  p_selected_index INT DEFAULT NULL,
  p_restart BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_now TIMESTAMPTZ;
  v_today DATE;
  v_session bilimyol_private.placement_sessions;
  v_question public.questions;
  v_revision TEXT;
  v_total INT;
  v_attempt JSONB;
  v_last JSONB;
  v_answers JSONB;
  v_next TEXT;
  v_reset BOOLEAN := false;
  v_new_session BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.courses WHERE id = p_course_id AND is_active)
    OR (p_session_id IS NULL AND (p_question_id IS NOT NULL OR p_selected_index IS NOT NULL))
    OR (p_session_id IS NOT NULL AND (p_question_id IS NULL OR p_selected_index IS NULL OR p_restart)) THEN
    RAISE EXCEPTION 'Diagnostika so‘rovi noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('learning:' || v_uid::TEXT, 0));
  v_now := pg_catalog.clock_timestamp();
  v_today := (v_now AT TIME ZONE 'Asia/Tashkent')::date;
  SELECT * INTO v_session FROM bilimyol_private.placement_sessions
  WHERE user_id = v_uid AND course_id = p_course_id;

  IF p_session_id IS NOT NULL AND p_session_id IS DISTINCT FROM v_session.id THEN
    RAISE EXCEPTION 'Diagnostika sessiyasini qayta yuklang.' USING ERRCODE = '42501';
  END IF;
  v_new_session := p_restart AND v_session.completed_at IS NOT NULL
    AND (v_session.completed_at AT TIME ZONE 'Asia/Tashkent')::date < v_today;

  IF v_session.completed_at IS NULL OR v_new_session THEN
    PERFORM 1 FROM bilimyol_private.placement_question_bank WHERE course_id = p_course_id FOR SHARE;
    SELECT COALESCE(pg_catalog.sum(LEAST(question_count, 2)), 0), pg_catalog.md5(pg_catalog.string_agg(revision, '|' ORDER BY skill_id))
    INTO v_total, v_revision
    FROM (
      SELECT q.skill_id, pg_catalog.count(*) AS question_count, pg_catalog.md5(pg_catalog.string_agg(pg_catalog.md5(pg_catalog.to_jsonb(q)::TEXT), '|' ORDER BY q.id)) AS revision
      FROM bilimyol_private.placement_question_bank q
      JOIN public.skills s ON s.id = q.skill_id AND s.course_id = p_course_id
      WHERE q.course_id = p_course_id
      GROUP BY q.skill_id
    ) bank;
    IF v_total NOT BETWEEN 1 AND 100 THEN
      RAISE EXCEPTION 'Bu fan uchun diagnostika savollari tayyor emas.' USING ERRCODE = '22023';
    END IF;

    v_reset := v_session.id IS NOT NULL AND v_session.completed_at IS NULL
      AND (v_session.bank_revision IS DISTINCT FROM v_revision
        OR v_session.question_started_at < v_now - interval '48 hours');
    IF v_session.id IS NULL OR v_new_session OR v_reset THEN
      INSERT INTO bilimyol_private.placement_sessions AS session (
        user_id, course_id, bank_revision, total_questions, question_id, question_started_at
      ) VALUES (
        v_uid, p_course_id, v_revision, v_total,
        bilimyol_private.next_placement_question(p_course_id, '[]'::pg_catalog.jsonb), v_now
      )
      ON CONFLICT (user_id, course_id) DO UPDATE SET
        id = EXCLUDED.id, bank_revision = EXCLUDED.bank_revision, total_questions = EXCLUDED.total_questions,
        question_id = EXCLUDED.question_id, question_started_at = EXCLUDED.question_started_at,
        answers = '[]'::pg_catalog.jsonb, result = NULL, completed_at = NULL
      RETURNING session.* INTO v_session;
    ELSIF p_session_id IS NOT NULL THEN
      v_last := v_session.answers->-1;
      IF p_question_id = v_session.question_id THEN
        SELECT * INTO STRICT v_question FROM public.questions WHERE id = p_question_id;
        IF p_selected_index < 0 OR p_selected_index >= pg_catalog.jsonb_array_length(v_question.options) THEN
          RAISE EXCEPTION 'Tanlangan javob indeksi noto‘g‘ri.' USING ERRCODE = '22023';
        END IF;
        v_answers := v_session.answers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'question_id', v_question.id, 'selected_index', p_selected_index,
          'is_correct', p_selected_index = v_question.correct_index,
          'time_spent_seconds', LEAST(600, GREATEST(1, pg_catalog.floor(EXTRACT(EPOCH FROM v_now - v_session.question_started_at))))
        ));

        IF pg_catalog.jsonb_array_length(v_answers) = v_session.total_questions THEN
          v_attempt := public.save_placement_attempt(p_course_id, v_answers, 'placement-session:' || v_session.id::TEXT);
          SELECT v_attempt || pg_catalog.jsonb_build_object('completed_at', v_now, 'answers', pg_catalog.jsonb_agg(
            a.item || pg_catalog.jsonb_build_object(
              'question_text', q.text,
              'question_text_ru', q.text_ru,
              'selected_option', q.options->>((a.item->>'selected_index')::INT),
              'correct_option', q.options->>q.correct_index,
              'explanation', q.explanation,
              'explanation_ru', q.explanation_ru,
              'cefr_level', q.cefr_level
            ) ORDER BY a.position
          )) INTO v_attempt
          FROM pg_catalog.jsonb_array_elements(v_answers) WITH ORDINALITY AS a(item, position)
          JOIN public.questions q ON q.id = a.item->>'question_id';
        ELSE
          v_next := bilimyol_private.next_placement_question(p_course_id, v_answers);
          IF v_next IS NULL THEN
            RAISE EXCEPTION 'Diagnostika savollarini qayta yuklang.' USING ERRCODE = '22023';
          END IF;
        END IF;

        UPDATE bilimyol_private.placement_sessions SET
          answers = v_answers, question_id = v_next, question_started_at = v_now,
          result = v_attempt, completed_at = CASE WHEN v_attempt IS NOT NULL THEN v_now END
        WHERE user_id = v_uid AND course_id = p_course_id
        RETURNING * INTO v_session;
      ELSIF p_question_id IS DISTINCT FROM v_last->>'question_id'
        OR p_selected_index IS DISTINCT FROM (v_last->>'selected_index')::INT THEN
        RAISE EXCEPTION 'Savol o‘zgardi. Diagnostikani qayta yuklang.' USING ERRCODE = '22023';
      END IF;
    END IF;
  END IF;

  SELECT * INTO v_question FROM public.questions WHERE id = v_session.question_id;
  RETURN pg_catalog.jsonb_build_object(
    'session_id', v_session.id,
    'total_questions', v_session.total_questions,
    'question_number', LEAST(pg_catalog.jsonb_array_length(v_session.answers) + 1, v_session.total_questions),
    'question', CASE WHEN v_question.id IS NOT NULL THEN pg_catalog.jsonb_build_object(
      'id', v_question.id,
      'course_id', v_question.course_id,
      'skill_id', v_question.skill_id,
      'text', v_question.text,
      'text_ru', v_question.text_ru,
      'options', v_question.options,
      'media', v_question.media,
      'context_snippet', v_question.context_snippet,
      'formula_latex', v_question.formula_latex,
      'audio_sim_text', v_question.audio_sim_text,
      'audio_sim_speaker', v_question.audio_sim_speaker
    ) END,
    'result', v_session.result,
    'reset', v_reset,
    'can_retake', COALESCE((v_session.completed_at AT TIME ZONE 'Asia/Tashkent')::date < v_today, false)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.advance_placement(TEXT, UUID, TEXT, INT, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.advance_placement(TEXT, UUID, TEXT, INT, BOOLEAN) TO authenticated;

-- ----------------------------------------------------------------------------
-- 8. Update bilimyol_private.submit_answer_attempt & public.complete_reinforcement
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION bilimyol_private.submit_answer_attempt(
  p_user_id UUID,
  p_course_id TEXT,
  p_skill_id TEXT,
  p_lesson_id TEXT,
  p_question_id TEXT,
  p_selected_index INT,
  p_selected_text TEXT,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_uid UUID;
  v_existing_id UUID;
  v_existing_is_correct BOOLEAN;
  v_question_course TEXT;
  v_question_skill TEXT;
  v_q_body JSONB;
  v_explanation TEXT;
  v_is_correct BOOLEAN := false;
  v_recalc JSONB;
  v_unique_total INT := 0;
  v_unique_correct INT := 0;
  v_new_skill_score INT := 0;
  v_overall_score INT := 0;
  v_xp_delta INT := 0;
  v_pending_answer_xp INT := 0;
  v_total_xp INT := 0;
  v_award JSONB;
  v_eff_idempotency TEXT;
  v_clean_text TEXT;
  v_today DATE;
  v_daily_total INT := 0;
  v_daily_correct INT := 0;
  v_daily_accuracy INT := 0;
  v_reinf_target RECORD;
  v_wrong_count INT := 0;
  v_hide_mistake_spoiler BOOLEAN := false;
  v_q_row RECORD;
BEGIN
  v_caller_uid := auth.uid();
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'Xavfsizlik qoidasi: javob topshirish uchun autentifikatsiya talab qilinadi.'
      USING ERRCODE = '42501';
  END IF;
  IF p_user_id IS DISTINCT FROM v_caller_uid THEN
    RAISE EXCEPTION 'Xavfsizlik qoidasi: boshqa foydalanuvchi nomidan javob topshirish taqiqlanadi.'
      USING ERRCODE = '42501';
  END IF;

  v_today := (pg_catalog.now() AT TIME ZONE 'Asia/Tashkent')::date;
  IF NULLIF(pg_catalog.btrim(p_course_id), '') IS NULL
     OR NULLIF(pg_catalog.btrim(p_skill_id), '') IS NULL
     OR NULLIF(pg_catalog.btrim(p_lesson_id), '') IS NULL
     OR NULLIF(pg_catalog.btrim(p_question_id), '') IS NULL
     OR p_selected_index IS NULL
     OR p_selected_index < 0
     OR p_selected_index > 100 THEN
    RAISE EXCEPTION 'Javob konteksti yoki indeksi noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;

  IF pg_catalog.char_length(p_course_id) > 64
     OR pg_catalog.char_length(p_skill_id) > 64
     OR pg_catalog.char_length(p_lesson_id) > 160
     OR pg_catalog.char_length(p_question_id) > 160 THEN
    RAISE EXCEPTION 'Javob identifikatorlari ruxsat etilgan hajmdan oshib ketdi.' USING ERRCODE = '23514';
  END IF;

  v_clean_text := COALESCE(p_selected_text, '');
  IF pg_catalog.char_length(v_clean_text) > 4000 THEN
    RAISE EXCEPTION 'Javob matni 4000 belgidan oshmasligi shart.' USING ERRCODE = '23514';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    IF pg_catalog.btrim(p_idempotency_key) = '' THEN
      RAISE EXCEPTION 'Idempotency kaliti bo‘sh satr bo‘lishi mumkin emas.' USING ERRCODE = '22023';
    END IF;
    IF pg_catalog.char_length(p_idempotency_key) > 128 THEN
      RAISE EXCEPTION 'Idempotency kaliti uzunligi 128 belgidan oshmasligi shart.' USING ERRCODE = '23514';
    END IF;
    v_eff_idempotency := p_idempotency_key;
  ELSE
    v_eff_idempotency := NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.skills s
    WHERE s.id = p_skill_id AND s.course_id = p_course_id
  ) THEN
    RAISE EXCEPTION 'Ko‘nikma kurs bilan mos emas.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('learning:' || p_user_id::TEXT, 0)
  );

  IF v_eff_idempotency IS NOT NULL THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_user_id::TEXT || ':' || v_eff_idempotency, 0)
    );

    SELECT aa.id, aa.is_correct
    INTO v_existing_id, v_existing_is_correct
    FROM public.answer_attempts aa
    WHERE aa.user_id = p_user_id AND aa.idempotency_key = v_eff_idempotency
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
      IF EXISTS (
        SELECT 1 FROM public.answer_attempts aa
        WHERE aa.id = v_existing_id
          AND (
            aa.course_id IS DISTINCT FROM p_course_id
            OR aa.skill_id IS DISTINCT FROM p_skill_id
            OR aa.lesson_id IS DISTINCT FROM p_lesson_id
            OR aa.question_id IS DISTINCT FROM p_question_id
            OR aa.selected_index IS DISTINCT FROM p_selected_index
            OR aa.selected_answer IS DISTINCT FROM v_clean_text
          )
      ) THEN
        RAISE EXCEPTION 'Idempotency kaliti boshqa javob uchun ishlatilgan.' USING ERRCODE = '22023';
      END IF;

      SELECT COALESCE(lss.score, 50)
      INTO v_new_skill_score
      FROM public.learner_skill_scores lss
      WHERE lss.user_id = p_user_id AND lss.course_id = p_course_id AND lss.skill_id = p_skill_id;

      SELECT COALESCE(pg_catalog.round(pg_catalog.avg(lss.score))::INT, 50)
      INTO v_overall_score
      FROM public.learner_skill_scores lss
      WHERE lss.user_id = p_user_id AND lss.course_id = p_course_id;

      SELECT COALESCE(gp.xp, 0)
      INTO v_total_xp
      FROM public.gamification_profiles gp
      WHERE gp.user_id = p_user_id;

      IF v_existing_is_correct = true THEN
        SELECT exp_cand.explanation
        INTO v_explanation
        FROM (
          SELECT q.explanation AS explanation
          FROM public.questions q
          WHERE q.id = p_question_id AND NOT q.is_placement
          UNION ALL
          SELECT items.elem->>'explanation' AS explanation
          FROM public.lessons l
          CROSS JOIN LATERAL (
            SELECT COALESCE(step_elem->'interactiveQuestion', step_elem->'interactive_question') AS elem
            FROM pg_catalog.jsonb_array_elements(
              CASE WHEN pg_catalog.jsonb_typeof(l.steps) = 'array' THEN l.steps ELSE '[]'::pg_catalog.jsonb END
            ) AS step_elem
            UNION ALL
            SELECT l.reinforcement_exercise AS elem
            WHERE pg_catalog.jsonb_typeof(l.reinforcement_exercise) = 'object'
            UNION ALL
            SELECT l.alternate_exercise AS elem
            WHERE pg_catalog.jsonb_typeof(l.alternate_exercise) = 'object'
          ) items
          WHERE l.course_id = p_course_id
            AND l.is_published
            AND NOT l.is_archived
            AND pg_catalog.jsonb_typeof(items.elem) = 'object'
            AND items.elem->>'id' = p_question_id
          UNION ALL
          SELECT g_items.elem->>'explanation' AS explanation
          FROM public.generated_lessons gl
          CROSS JOIN LATERAL (
            SELECT elem
            FROM pg_catalog.jsonb_array_elements(
              CASE WHEN pg_catalog.jsonb_typeof(gl.questions) = 'array' THEN gl.questions ELSE '[]'::pg_catalog.jsonb END
            ) AS elem
            UNION ALL
            SELECT COALESCE(step_elem->'interactiveQuestion', step_elem->'interactive_question') AS elem
            FROM pg_catalog.jsonb_array_elements(
              CASE WHEN pg_catalog.jsonb_typeof(gl.steps) = 'array' THEN gl.steps ELSE '[]'::pg_catalog.jsonb END
            ) AS step_elem
          ) g_items
          WHERE gl.course_id = p_course_id
            AND gl.course_id <> 'course_math_01'
            AND pg_catalog.jsonb_typeof(g_items.elem) = 'object'
            AND g_items.elem->>'id' = p_question_id
        ) exp_cand
        WHERE NULLIF(pg_catalog.btrim(COALESCE(exp_cand.explanation, '')), '') IS NOT NULL
        LIMIT 1;
      ELSE
        v_explanation := 'Javob avval qayd etilgan.';
      END IF;

      RETURN pg_catalog.jsonb_build_object(
        'is_correct', v_existing_is_correct,
        'explanation', COALESCE(v_explanation, 'Javob avval qayd etilgan.'),
        'new_skill_score', COALESCE(v_new_skill_score, 50),
        'overall_score', COALESCE(v_overall_score, 50),
        'xp_awarded', 0,
        'total_xp', COALESCE(v_total_xp, 0),
        'already_processed', true
      );
    END IF;
  END IF;

  IF pg_catalog.starts_with(p_lesson_id, 'reinf_') THEN
    SELECT rt.canonical_reinf_id, rt.target_lesson_id, rt.required_score
    INTO v_reinf_target
    FROM bilimyol_private.resolve_reinforcement_target(p_course_id, p_skill_id, p_lesson_id) rt
    LIMIT 1;

    IF v_reinf_target.target_lesson_id IS NULL THEN
      RAISE EXCEPTION 'Mustahkamlash tuguni kurs va ko‘nikmaga mos emas.' USING ERRCODE = '22023';
    END IF;

    SELECT l.course_id,
           COALESCE(NULLIF(COALESCE(cand.elem->>'skillId', cand.elem->>'skill_id'), ''), l.skill_id) AS resolved_skill,
           cand.elem AS resolved_body,
           cand.elem->>'explanation' AS resolved_exp
    INTO v_question_course, v_question_skill, v_q_body, v_explanation
    FROM public.lessons l
    CROSS JOIN LATERAL (
      SELECT l.reinforcement_exercise AS elem
      WHERE pg_catalog.jsonb_typeof(l.reinforcement_exercise) = 'object'
      UNION ALL
      SELECT l.alternate_exercise AS elem
      WHERE pg_catalog.jsonb_typeof(l.alternate_exercise) = 'object'
    ) cand
    WHERE l.id = v_reinf_target.target_lesson_id
      AND l.course_id = p_course_id
      AND l.is_published
      AND NOT l.is_archived
      AND cand.elem->>'id' = p_question_id
    LIMIT 1;

    IF v_question_course IS NULL AND NOT EXISTS (
      SELECT 1 FROM public.lessons existing_l WHERE existing_l.id = v_reinf_target.target_lesson_id
    ) THEN
      SELECT gl.course_id,
             COALESCE(NULLIF(COALESCE(cand.elem->>'skillId', cand.elem->>'skill_id'), ''), gl.skill_id),
             cand.elem,
             cand.elem->>'explanation'
      INTO v_question_course, v_question_skill, v_q_body, v_explanation
      FROM public.generated_lessons gl
      CROSS JOIN LATERAL (
        SELECT elem
        FROM pg_catalog.jsonb_array_elements(
          CASE WHEN pg_catalog.jsonb_typeof(gl.questions) = 'array' THEN gl.questions ELSE '[]'::pg_catalog.jsonb END
        ) AS elem
        UNION ALL
        SELECT COALESCE(step_elem->'interactiveQuestion', step_elem->'interactive_question') AS elem
        FROM pg_catalog.jsonb_array_elements(
          CASE WHEN pg_catalog.jsonb_typeof(gl.steps) = 'array' THEN gl.steps ELSE '[]'::pg_catalog.jsonb END
        ) AS step_elem
      ) cand
      WHERE gl.id = v_reinf_target.target_lesson_id
        AND gl.course_id = p_course_id
        AND gl.course_id <> 'course_math_01'
        AND (
          gl.skill_id = p_skill_id
          OR COALESCE(cand.elem->>'skillId', cand.elem->>'skill_id') = p_skill_id
        )
        AND pg_catalog.jsonb_typeof(cand.elem) = 'object'
        AND cand.elem->>'id' = p_question_id
      LIMIT 1;
    END IF;

    IF v_question_course IS NULL THEN
      RAISE EXCEPTION 'Savol ushbu mustahkamlash mashqiga tegishli emas.' USING ERRCODE = '22023';
    END IF;
  ELSE
    SELECT l.course_id,
           COALESCE(NULLIF(COALESCE(cand.elem->>'skillId', cand.elem->>'skill_id'), ''), l.skill_id) AS resolved_skill,
           cand.elem AS resolved_body,
           cand.elem->>'explanation' AS resolved_exp
    INTO v_question_course, v_question_skill, v_q_body, v_explanation
    FROM public.lessons l
    CROSS JOIN LATERAL (
      SELECT COALESCE(step_elem->'interactiveQuestion', step_elem->'interactive_question') AS elem
      FROM pg_catalog.jsonb_array_elements(
        CASE WHEN pg_catalog.jsonb_typeof(l.steps) = 'array' THEN l.steps ELSE '[]'::pg_catalog.jsonb END
      ) AS step_elem
      UNION ALL
      SELECT l.alternate_exercise AS elem
      WHERE pg_catalog.jsonb_typeof(l.alternate_exercise) = 'object'
      UNION ALL
      SELECT l.reinforcement_exercise AS elem
      WHERE pg_catalog.jsonb_typeof(l.reinforcement_exercise) = 'object'
        AND NOT EXISTS (
          SELECT 1
          FROM pg_catalog.jsonb_array_elements(
            CASE WHEN pg_catalog.jsonb_typeof(l.steps) = 'array' THEN l.steps ELSE '[]'::pg_catalog.jsonb END
          ) AS s_chk
          WHERE NULLIF(COALESCE(s_chk->'interactiveQuestion', s_chk->'interactive_question')->>'id', '') IS NOT NULL
        )
    ) cand
    WHERE l.id = p_lesson_id
      AND l.is_published
      AND NOT l.is_archived
      AND pg_catalog.jsonb_typeof(cand.elem) = 'object'
      AND cand.elem->>'id' = p_question_id
    LIMIT 1;

    IF v_question_course IS NULL AND NOT EXISTS (
      SELECT 1 FROM public.lessons existing_l WHERE existing_l.id = p_lesson_id
    ) THEN
      SELECT gl.course_id,
             COALESCE(NULLIF(COALESCE(cand.elem->>'skillId', cand.elem->>'skill_id'), ''), gl.skill_id),
             cand.elem,
             cand.elem->>'explanation'
      INTO v_question_course, v_question_skill, v_q_body, v_explanation
      FROM public.generated_lessons gl
      CROSS JOIN LATERAL (
        SELECT elem
        FROM pg_catalog.jsonb_array_elements(
          CASE WHEN pg_catalog.jsonb_typeof(gl.questions) = 'array' THEN gl.questions ELSE '[]'::pg_catalog.jsonb END
        ) AS elem
        UNION ALL
        SELECT COALESCE(step_elem->'interactiveQuestion', step_elem->'interactive_question') AS elem
        FROM pg_catalog.jsonb_array_elements(
          CASE WHEN pg_catalog.jsonb_typeof(gl.steps) = 'array' THEN gl.steps ELSE '[]'::pg_catalog.jsonb END
        ) AS step_elem
      ) cand
      WHERE gl.id = p_lesson_id
        AND gl.course_id <> 'course_math_01'
        AND pg_catalog.jsonb_typeof(cand.elem) = 'object'
        AND cand.elem->>'id' = p_question_id
      LIMIT 1;
    END IF;
  END IF;

  IF v_question_course IS NULL THEN
    RAISE EXCEPTION 'Savol dars tarkibida yoki chop etilgan bazada topilmadi.' USING ERRCODE = '22023';
  END IF;
  IF v_question_course <> p_course_id OR v_question_skill <> p_skill_id THEN
    RAISE EXCEPTION 'Savol kurs yoki ko‘nikma kontekstiga mos emas.' USING ERRCODE = '22023';
  END IF;

  IF COALESCE(v_q_body->>'correct_index', v_q_body->>'correctIndex') IS NULL
     AND COALESCE(NULLIF(COALESCE(v_q_body->>'questionType', v_q_body->>'question_type', v_q_body->>'mode', ''), ''), 'multiple_choice')
         IN ('multiple_choice', 'error_correction', 'conversation_completion') THEN
    SELECT q.correct_index, q.explanation, q.options
    INTO v_q_row
    FROM public.questions q
    WHERE q.id = p_question_id
      AND NOT q.is_placement
      AND q.course_id = v_question_course
      AND q.skill_id = v_question_skill;

    IF FOUND THEN
      v_q_body := COALESCE(v_q_body, '{}'::pg_catalog.jsonb)
        || pg_catalog.jsonb_build_object(
             'correct_index', v_q_row.correct_index,
             'options', COALESCE(v_q_body->'options', v_q_row.options)
           );
      v_explanation := COALESCE(NULLIF(v_explanation, ''), v_q_row.explanation);
    END IF;
  END IF;

  v_is_correct := bilimyol_private.grade_question_attempt(v_q_body, p_selected_index, v_clean_text);
  IF NOT v_is_correct THEN
    v_explanation := COALESCE(
      NULLIF(pg_catalog.btrim(COALESCE(v_q_body->>'wrongFeedback', v_q_body->>'wrong_feedback', '')), ''),
      NULLIF(pg_catalog.btrim(COALESCE(v_explanation, '')), '')
    );
  END IF;

  INSERT INTO public.answer_attempts (
    user_id, course_id, skill_id, lesson_id, question_id,
    selected_index, selected_answer, is_correct, idempotency_key, created_at
  )
  VALUES (
    p_user_id, p_course_id, p_skill_id, p_lesson_id, p_question_id,
    p_selected_index, v_clean_text, v_is_correct, v_eff_idempotency,
    GREATEST(
      pg_catalog.clock_timestamp(),
      COALESCE(
        (SELECT pg_catalog.max(aa_prev.created_at) + interval '1 microsecond'
         FROM public.answer_attempts aa_prev
         WHERE aa_prev.user_id = p_user_id),
        pg_catalog.clock_timestamp()
      ),
      COALESCE(
        (SELECT pg_catalog.max(ra_prev.created_at) + interval '1 microsecond'
         FROM public.reinforcement_attempts ra_prev
         WHERE ra_prev.user_id = p_user_id),
        pg_catalog.clock_timestamp()
      ),
      COALESCE(
        (SELECT pg_catalog.max(pa_prev.completed_at) + interval '1 microsecond'
         FROM public.placement_attempts pa_prev
         WHERE pa_prev.user_id = p_user_id),
        pg_catalog.clock_timestamp()
      )
    )
  )
  ON CONFLICT (user_id, idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

  IF NOT FOUND AND v_eff_idempotency IS NOT NULL THEN
    RETURN bilimyol_private.submit_answer_attempt(
      p_user_id, p_course_id, p_skill_id, p_lesson_id, p_question_id,
      p_selected_index, p_selected_text, p_idempotency_key
    );
  END IF;

  v_recalc := bilimyol_private.recalculate_course_skill_scores_for_user(p_user_id, p_course_id);
  v_new_skill_score := COALESCE(
    (v_recalc->p_skill_id->>'score')::INT,
    CASE WHEN v_is_correct THEN 55 ELSE 0 END
  );
  v_unique_total := COALESCE((v_recalc->p_skill_id->>'unique_total')::INT, 1);
  v_unique_correct := COALESCE((v_recalc->p_skill_id->>'unique_correct')::INT, CASE WHEN v_is_correct THEN 1 ELSE 0 END);

  SELECT COALESCE(pg_catalog.round(pg_catalog.avg(lss.score))::INT, v_new_skill_score)
  INTO v_overall_score
  FROM public.learner_skill_scores lss
  WHERE lss.user_id = p_user_id AND lss.course_id = p_course_id;

  IF v_is_correct AND NOT EXISTS (
    SELECT 1 FROM public.gamification_events ge
    WHERE ge.user_id = p_user_id AND ge.action_key = 'answer_correct_' || p_question_id
  ) THEN
    v_pending_answer_xp := 2;
  END IF;

  INSERT INTO bilimyol_private.daily_question_outcomes (
    user_id, activity_date, question_id, is_correct, updated_at
  )
  VALUES (
    p_user_id, v_today, p_question_id, v_is_correct, pg_catalog.now()
  )
  ON CONFLICT (user_id, activity_date, question_id) DO UPDATE SET
    is_correct = EXCLUDED.is_correct,
    updated_at = EXCLUDED.updated_at;

  SELECT pg_catalog.count(*)::INT,
         pg_catalog.count(*) FILTER (WHERE dqo.is_correct)::INT
  INTO v_daily_total, v_daily_correct
  FROM bilimyol_private.daily_question_outcomes dqo
  WHERE dqo.user_id = p_user_id AND dqo.activity_date = v_today;

  v_daily_accuracy := CASE
    WHEN v_daily_total > 0
    THEN pg_catalog.round((v_daily_correct::NUMERIC * 100) / v_daily_total::NUMERIC)::INT
    ELSE 0
  END;

  INSERT INTO public.daily_learning_stats (
    user_id, activity_date, questions_answered, correct_answers,
    accuracy_percent, xp_earned, overall_score, updated_at
  )
  VALUES (
    p_user_id, v_today, v_daily_total, v_daily_correct,
    v_daily_accuracy, v_pending_answer_xp, v_overall_score, pg_catalog.now()
  )
  ON CONFLICT (user_id, activity_date) DO UPDATE SET
    questions_answered = EXCLUDED.questions_answered,
    correct_answers = EXCLUDED.correct_answers,
    accuracy_percent = EXCLUDED.accuracy_percent,
    xp_earned = public.daily_learning_stats.xp_earned + EXCLUDED.xp_earned,
    overall_score = v_overall_score,
    updated_at = pg_catalog.now();

  IF v_is_correct THEN
    v_award := bilimyol_private.award_xp(p_user_id, 2, 'answer_correct_' || p_question_id);
    v_xp_delta := CASE WHEN (v_award->>'awarded')::BOOLEAN THEN 2 ELSE 0 END;
  ELSE
    v_xp_delta := 0;
  END IF;

  PERFORM public.record_learning_activity(v_today);

  SELECT COALESCE(gp.xp, 0)
  INTO v_total_xp
  FROM public.gamification_profiles gp
  WHERE gp.user_id = p_user_id;

  IF NOT v_is_correct AND p_course_id = 'course_math_01' AND EXISTS (
    SELECT 1 FROM bilimyol_private.math_pilot_items mpi
    WHERE mpi.lesson_id = p_lesson_id AND mpi.question_id = p_question_id
  ) THEN
    SELECT pg_catalog.count(*)::INT
    INTO v_wrong_count
    FROM public.answer_attempts aa
    WHERE aa.user_id = p_user_id
      AND aa.course_id = p_course_id
      AND aa.skill_id = p_skill_id
      AND aa.lesson_id = p_lesson_id
      AND aa.question_id = p_question_id
      AND aa.is_correct = false;

    IF v_wrong_count < 2 AND NOT EXISTS (
      SELECT 1 FROM bilimyol_private.math_progression(p_user_id) mp
      WHERE mp.target_lesson_id = p_lesson_id
        AND mp.mastery_state IN ('needs_review', 'mastered')
    ) THEN
      v_hide_mistake_spoiler := true;
    END IF;
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'is_correct', v_is_correct,
    'explanation', CASE
      WHEN v_hide_mistake_spoiler THEN 'Ishlangan misolni ko‘rib chiqing va qayta urinib ko‘ring.'
      ELSE COALESCE(v_explanation, 'To‘g‘ri yechim.')
    END,
    'new_skill_score', v_new_skill_score,
    'overall_score', v_overall_score,
    'xp_awarded', v_xp_delta,
    'total_xp', COALESCE(v_total_xp, 0),
    'total_attempts', v_unique_total,
    'correct_attempts', v_unique_correct,
    'already_processed', false
  );
END;
$$;

REVOKE ALL ON FUNCTION bilimyol_private.submit_answer_attempt(
  UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT
) FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.complete_reinforcement(
  p_reinforcement_node_id TEXT,
  p_course_id TEXT,
  p_skill_id TEXT,
  p_question_id TEXT,
  p_xp_awarded INT DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_target RECORD;
  v_existing RECORD;
  v_origin_alias TEXT;
  v_latest_plc_at TIMESTAMPTZ := NULL;
  v_plc_skill_score INT := NULL;
  v_parent_plc_score INT := NULL;
  v_unique_total INT := 0;
  v_unique_correct INT := 0;
  v_before INT := 0;
  v_parent_skill_id TEXT;
  v_parent_total INT := 0;
  v_parent_correct INT := 0;
  v_parent_lss_score INT;
  v_parent_before INT := 0;
  v_parent_needs_remediation BOOLEAN := false;
  v_current_raw INT := 0;
  v_after INT := 50;
  v_server_xp_awarded CONSTANT INT := 30;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;

  IF NULLIF(pg_catalog.btrim(p_reinforcement_node_id), '') IS NULL
     OR NULLIF(pg_catalog.btrim(p_course_id), '') IS NULL
     OR NULLIF(pg_catalog.btrim(p_skill_id), '') IS NULL
     OR NULLIF(pg_catalog.btrim(p_question_id), '') IS NULL THEN
    RAISE EXCEPTION 'Mustahkamlash ma’lumotlari noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('learning:' || v_uid::TEXT, 0)
  );

  SELECT rt.canonical_reinf_id, rt.target_lesson_id, rt.required_score
  INTO v_target
  FROM bilimyol_private.resolve_reinforcement_target(p_course_id, p_skill_id, p_reinforcement_node_id) rt
  LIMIT 1;

  IF v_target.target_lesson_id IS NULL THEN
    RAISE EXCEPTION 'Mustahkamlash mashqi kurs va ko‘nikmaga mos emas.' USING ERRCODE = '22023';
  END IF;

  IF p_course_id = 'course_math_01' AND NOT public.can_open_math_lesson(v_target.target_lesson_id) THEN
    RAISE EXCEPTION 'Avval tayanch mavzularni o‘zlashtiring.' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.lessons l
    CROSS JOIN LATERAL (
      SELECT l.reinforcement_exercise AS elem
      WHERE pg_catalog.jsonb_typeof(l.reinforcement_exercise) = 'object'
      UNION ALL
      SELECT l.alternate_exercise AS elem
      WHERE pg_catalog.jsonb_typeof(l.alternate_exercise) = 'object'
    ) cand
    WHERE l.id = v_target.target_lesson_id
      AND l.course_id = p_course_id
      AND l.is_published
      AND NOT l.is_archived
      AND cand.elem->>'id' = p_question_id
      AND COALESCE(NULLIF(COALESCE(cand.elem->>'skillId', cand.elem->>'skill_id'), ''), l.skill_id) = p_skill_id
    UNION ALL
    SELECT 1
    FROM public.generated_lessons gl
    CROSS JOIN LATERAL (
      SELECT elem
      FROM pg_catalog.jsonb_array_elements(
        CASE WHEN pg_catalog.jsonb_typeof(gl.questions) = 'array' THEN gl.questions ELSE '[]'::pg_catalog.jsonb END
      ) AS elem
      UNION ALL
      SELECT COALESCE(step_elem->'interactiveQuestion', step_elem->'interactive_question') AS elem
      FROM pg_catalog.jsonb_array_elements(
        CASE WHEN pg_catalog.jsonb_typeof(gl.steps) = 'array' THEN gl.steps ELSE '[]'::pg_catalog.jsonb END
      ) AS step_elem
    ) cand
    WHERE gl.id = v_target.target_lesson_id
      AND gl.course_id = p_course_id
      AND gl.course_id <> 'course_math_01'
      AND (
        gl.skill_id = p_skill_id
        OR COALESCE(cand.elem->>'skillId', cand.elem->>'skill_id') = p_skill_id
      )
      AND NOT EXISTS (SELECT 1 FROM public.lessons existing_l WHERE existing_l.id = v_target.target_lesson_id)
      AND pg_catalog.jsonb_typeof(cand.elem) = 'object'
      AND cand.elem->>'id' = p_question_id
  ) THEN
    RAISE EXCEPTION 'Mustahkamlash savoli darsning ruxsat etilgan mashqiga mos emas.' USING ERRCODE = '22023';
  END IF;

  SELECT *
  INTO v_existing
  FROM public.reinforcement_attempts ra
  WHERE ra.user_id = v_uid
    AND ra.course_id = p_course_id
    AND (
      ra.reinforcement_node_id = v_target.canonical_reinf_id
      OR (
        ra.skill_id = p_skill_id
        AND (
          ra.reinforcement_node_id = p_reinforcement_node_id
          OR ra.reinforcement_node_id = 'reinf_lesson_' || v_target.target_lesson_id
          OR ra.reinforcement_node_id = 'reinf_' || p_course_id || '_' || p_skill_id
          OR EXISTS (
            SELECT 1
            FROM bilimyol_private.resolve_reinforcement_target(
              p_course_id, p_skill_id, ra.reinforcement_node_id
            ) existing_t
            WHERE existing_t.target_lesson_id = v_target.target_lesson_id
          )
        )
      )
    )
  ORDER BY ra.created_at ASC, ra.id ASC
  LIMIT 1;

  IF FOUND THEN
    SELECT aa.lesson_id
    INTO v_origin_alias
    FROM public.answer_attempts aa
    WHERE aa.user_id = v_uid
      AND aa.course_id = p_course_id
      AND aa.skill_id = v_existing.skill_id
      AND aa.is_correct = true
      AND aa.created_at <= v_existing.created_at
      AND aa.lesson_id IN (
        v_existing.reinforcement_node_id,
        v_target.canonical_reinf_id,
        'reinf_lesson_' || v_target.target_lesson_id,
        'reinf_' || p_course_id || '_' || v_existing.skill_id
      )
    ORDER BY aa.created_at DESC, aa.id DESC
    LIMIT 1;

    IF v_existing.skill_id = p_skill_id
       AND COALESCE(v_origin_alias, v_existing.reinforcement_node_id) = p_reinforcement_node_id THEN
      RETURN pg_catalog.jsonb_build_object(
        'already_processed', true,
        'old_score', v_existing.before_score,
        'new_score', v_existing.after_score,
        'xp_awarded', 0
      );
    END IF;

    RAISE EXCEPTION 'Ushbu dars bo‘yicha mustahkamlash mashqi allaqachon yakunlangan.' USING ERRCODE = '42501';
  END IF;

  IF NOT COALESCE((
    SELECT aa.is_correct
    FROM public.answer_attempts aa
    WHERE aa.user_id = v_uid
      AND aa.course_id = p_course_id
      AND aa.skill_id = p_skill_id
      AND aa.lesson_id = p_reinforcement_node_id
      AND aa.question_id = p_question_id
    ORDER BY aa.created_at DESC, aa.id DESC
    LIMIT 1
  ), false) THEN
    RAISE EXCEPTION 'Mustahkamlash javobi serverda to‘g‘ri deb tasdiqlanmagan.'
      USING ERRCODE = '42501';
  END IF;

  SELECT pa.completed_at
  INTO v_latest_plc_at
  FROM public.placement_attempts pa
  WHERE pa.user_id = v_uid AND pa.course_id = p_course_id
  ORDER BY pa.completed_at DESC, pa.id DESC
  LIMIT 1;

  SELECT (lp.placement_skill_scores_by_course->p_course_id->p_skill_id->>'score')::INT
  INTO v_plc_skill_score
  FROM public.learner_profiles lp
  WHERE lp.user_id = v_uid
    AND pg_catalog.jsonb_typeof(lp.placement_skill_scores_by_course->p_course_id->p_skill_id->'score') = 'number';

  SELECT pg_catalog.count(*)::INT,
         pg_catalog.count(*) FILTER (WHERE latest.is_correct)::INT
  INTO v_unique_total, v_unique_correct
  FROM (
    SELECT DISTINCT ON (aa.question_id) aa.is_correct
    FROM public.answer_attempts aa
    WHERE aa.user_id = v_uid
      AND aa.course_id = p_course_id
      AND aa.skill_id = p_skill_id
      AND aa.lesson_id <> 'placement_test'
      AND (v_latest_plc_at IS NULL OR aa.created_at > v_latest_plc_at)
      AND aa.lesson_id NOT IN (
        p_reinforcement_node_id,
        v_target.canonical_reinf_id,
        'reinf_lesson_' || v_target.target_lesson_id
      )
    ORDER BY aa.question_id, aa.created_at DESC, aa.id DESC
  ) latest;

  v_before := CASE
    WHEN v_unique_total > 0 THEN
      pg_catalog.round((v_unique_correct::NUMERIC / v_unique_total::NUMERIC) * 100)::INT
    ELSE
      COALESCE(v_plc_skill_score, 0)
  END;

  IF v_plc_skill_score IS NOT NULL AND v_plc_skill_score < v_target.required_score THEN
    v_before := LEAST(v_before, v_plc_skill_score);
  END IF;

  SELECT GREATEST(v_before, COALESCE(pg_catalog.max(ra.after_score), 0))
  INTO v_before
  FROM public.reinforcement_attempts ra
  WHERE ra.user_id = v_uid
    AND ra.course_id = p_course_id
    AND ra.skill_id = p_skill_id
    AND ra.is_correct = true
    AND (v_latest_plc_at IS NULL OR p_course_id = 'course_eng_01' OR ra.created_at > v_latest_plc_at)
    AND NOT EXISTS (
      SELECT 1 FROM public.answer_attempts newer_wrong
      WHERE newer_wrong.user_id = v_uid
        AND newer_wrong.course_id = p_course_id
        AND newer_wrong.skill_id = p_skill_id
        AND newer_wrong.lesson_id <> 'placement_test'
        AND newer_wrong.is_correct = false
        AND newer_wrong.created_at > ra.created_at
    );

  SELECT COALESCE(
    (SELECT rn.skill_id
     FROM public.roadmap_nodes rn
     WHERE rn.course_id = p_course_id
       AND rn.is_active
       AND (
         v_target.canonical_reinf_id = 'reinf_' || rn.id
         OR (rn.is_reinforcement AND v_target.canonical_reinf_id = rn.id)
       )
     ORDER BY rn.order_index ASC, rn.id ASC
     LIMIT 1),
    (SELECT l.skill_id FROM public.lessons l WHERE l.id = v_target.target_lesson_id LIMIT 1),
    p_skill_id
  )
  INTO v_parent_skill_id;

  IF v_parent_skill_id IS DISTINCT FROM p_skill_id THEN
    SELECT (lp.placement_skill_scores_by_course->p_course_id->v_parent_skill_id->>'score')::INT
    INTO v_parent_plc_score
    FROM public.learner_profiles lp
    WHERE lp.user_id = v_uid
      AND pg_catalog.jsonb_typeof(lp.placement_skill_scores_by_course->p_course_id->v_parent_skill_id->'score') = 'number';

    SELECT pg_catalog.count(*)::INT,
           pg_catalog.count(*) FILTER (WHERE latest.is_correct)::INT
    INTO v_parent_total, v_parent_correct
    FROM (
      SELECT DISTINCT ON (aa.question_id) aa.is_correct
      FROM public.answer_attempts aa
      WHERE aa.user_id = v_uid
        AND aa.course_id = p_course_id
        AND aa.skill_id = v_parent_skill_id
        AND aa.lesson_id <> 'placement_test'
        AND (v_latest_plc_at IS NULL OR aa.created_at > v_latest_plc_at)
        AND aa.lesson_id NOT IN (
          p_reinforcement_node_id,
          v_target.canonical_reinf_id,
          'reinf_lesson_' || v_target.target_lesson_id
        )
      ORDER BY aa.question_id, aa.created_at DESC, aa.id DESC
    ) latest;

    SELECT lss.score
    INTO v_parent_lss_score
    FROM public.learner_skill_scores lss
    WHERE lss.user_id = v_uid
      AND lss.course_id = p_course_id
      AND lss.skill_id = v_parent_skill_id;

    IF v_parent_total > 0 OR v_parent_lss_score IS NOT NULL OR v_parent_plc_score IS NOT NULL THEN
      v_parent_before := CASE
        WHEN v_parent_total > 0 THEN
          pg_catalog.round((v_parent_correct::NUMERIC / v_parent_total::NUMERIC) * 100)::INT
        ELSE
          COALESCE(v_parent_lss_score, v_parent_plc_score, 0)
      END;

      IF v_parent_plc_score IS NOT NULL AND v_parent_plc_score < v_target.required_score THEN
        v_parent_before := LEAST(v_parent_before, v_parent_plc_score);
      END IF;

      SELECT GREATEST(v_parent_before, COALESCE(pg_catalog.max(ra.after_score), 0))
      INTO v_parent_before
      FROM public.reinforcement_attempts ra
      WHERE ra.user_id = v_uid
        AND ra.course_id = p_course_id
        AND ra.skill_id = v_parent_skill_id
        AND ra.is_correct = true
        AND (v_latest_plc_at IS NULL OR p_course_id = 'course_eng_01' OR ra.created_at > v_latest_plc_at)
        AND NOT EXISTS (
          SELECT 1 FROM public.answer_attempts newer_wrong
          WHERE newer_wrong.user_id = v_uid
            AND newer_wrong.course_id = p_course_id
            AND newer_wrong.skill_id = v_parent_skill_id
            AND newer_wrong.lesson_id <> 'placement_test'
            AND newer_wrong.is_correct = false
            AND newer_wrong.created_at > ra.created_at
        );

      v_parent_needs_remediation := (v_parent_before < v_target.required_score);
    ELSE
      v_parent_needs_remediation := false;
    END IF;
  END IF;

  IF v_before >= v_target.required_score AND NOT v_parent_needs_remediation THEN
    RAISE EXCEPTION 'Ushbu ko‘nikma allaqachon yetarli darajada o‘zlashtirilgan.' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(lss.score, 0)
  INTO v_current_raw
  FROM public.learner_skill_scores lss
  WHERE lss.user_id = v_uid AND lss.course_id = p_course_id AND lss.skill_id = p_skill_id;

  v_after := LEAST(100, GREATEST(50, COALESCE(v_current_raw, 0), v_before + 22));

  INSERT INTO public.reinforcement_attempts (
    user_id, course_id, skill_id, reinforcement_node_id,
    before_score, after_score, is_correct, xp_awarded, created_at
  )
  VALUES (
    v_uid, p_course_id, p_skill_id, v_target.canonical_reinf_id,
    v_before, v_after, true, v_server_xp_awarded,
    GREATEST(
      pg_catalog.clock_timestamp(),
      COALESCE(
        (SELECT pg_catalog.max(aa_prev.created_at) + interval '1 microsecond'
         FROM public.answer_attempts aa_prev
         WHERE aa_prev.user_id = v_uid),
        pg_catalog.clock_timestamp()
      ),
      COALESCE(
        (SELECT pg_catalog.max(ra_prev.created_at) + interval '1 microsecond'
         FROM public.reinforcement_attempts ra_prev
         WHERE ra_prev.user_id = v_uid),
        pg_catalog.clock_timestamp()
      ),
      COALESCE(
        (SELECT pg_catalog.max(pa_prev.completed_at) + interval '1 microsecond'
         FROM public.placement_attempts pa_prev
         WHERE pa_prev.user_id = v_uid),
        pg_catalog.clock_timestamp()
      )
    )
  );

  PERFORM bilimyol_private.recalculate_course_skill_scores_for_user(v_uid, p_course_id);

  PERFORM bilimyol_private.award_xp(
    v_uid,
    v_server_xp_awarded,
    'reinforcement_completed_' || v_target.canonical_reinf_id
  );
  PERFORM public.record_learning_activity();

  RETURN pg_catalog.jsonb_build_object(
    'already_processed', false,
    'old_score', v_before,
    'new_score', v_after,
    'xp_awarded', v_server_xp_awarded
  );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_reinforcement(TEXT, TEXT, TEXT, TEXT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_reinforcement(TEXT, TEXT, TEXT, TEXT, INT)
  TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
