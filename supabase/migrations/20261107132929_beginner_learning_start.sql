BEGIN;

ALTER TABLE public.courses ADD COLUMN starter_lesson_id TEXT
  REFERENCES public.lessons (id) ON DELETE SET NULL;
ALTER TABLE public.learner_profiles ADD COLUMN course_levels JSONB NOT NULL DEFAULT '{}'::jsonb
  CHECK (jsonb_typeof(course_levels) = 'object');

CREATE FUNCTION public.save_course_learning_plan(
  p_course_id TEXT, p_goal TEXT, p_daily_minutes INT, p_level TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Avval hisobga kiring.' USING ERRCODE = '42501';
  END IF;
  IF p_level IS NULL OR p_level NOT IN ('beginner', 'intermediate', 'advanced')
    OR p_goal IS NULL OR p_goal NOT IN ('mastery', 'exam_prep', 'skills_boost')
    OR p_daily_minutes IS NULL OR p_daily_minutes NOT IN (15, 30, 60)
    OR NOT EXISTS (SELECT 1 FROM public.courses WHERE id = p_course_id AND is_active) THEN
    RAISE EXCEPTION 'Fan yoki o‘rganish sozlamalari noto‘g‘ri.' USING ERRCODE = '22023';
  END IF;

  UPDATE public.learner_profiles SET
    selected_course_id = p_course_id, goal = p_goal, daily_minutes = p_daily_minutes, initial_level = p_level,
    course_levels = jsonb_set(course_levels, ARRAY[p_course_id], to_jsonb(p_level), true),
    updated_at = now()
  WHERE user_id = auth.uid() AND (selected_course_id = p_course_id OR selected_course_id IS NULL);
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Joriy fan o‘zgargan. Fanni qayta tanlang.' USING ERRCODE = '22023';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.save_course_learning_plan(TEXT, TEXT, INT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_course_learning_plan(TEXT, TEXT, INT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- Introductory lessons are optional and leave existing roadmap prerequisites intact.
INSERT INTO public.lessons (
  id, course_id, skill_id, title, summary, estimated_minutes, steps, reinforcement_exercise, is_published, is_archived
)
SELECT lesson.id, lesson.course_id, lesson.skill_id, lesson.title, lesson.summary,
  5, lesson.steps, lesson.reinforcement, true, false
FROM (VALUES
  ('lesson_math_starter', 'course_math_01', 'skill_math_algebra', 'Qo‘shish va ayirishdan boshlaymiz', 'Qo‘shish ikki guruhni birlashtiradi. Ayirish guruhdan bir qismini olib tashlaydi.',
    '[{"id":"lesson_math_starter_read","stepNumber":1,"type":"concept","title":"Asosiy tushuncha","content":"Qo‘shish ikki guruhni birlashtiradi. Ayirish guruhdan bir qismini olib tashlaydi."},{"id":"lesson_math_starter_example","stepNumber":2,"type":"visual_example","title":"Birga misol ko‘ramiz","content":"Sizda 3 ta olma bor. Yana 2 ta olma olsangiz, jami 5 ta bo‘ladi. Yozilishi 3 + 2 = 5. Jami 5 tadan 2 tasini bersangiz, 5 − 2 = 3 ta qoladi."},{"id":"lesson_math_starter_try","stepNumber":3,"type":"interactive_question","title":"O‘rganganingizni sinab ko‘ring","content":"Misoldan foydalanib bitta javobni tanlang.","interactiveQuestion":{"id":"q_lesson_math_starter_quiz","courseId":"course_math_01","skillId":"skill_math_algebra","text":"4 ta qalamga yana 2 ta qalam qo‘shilsa, jami nechta bo‘ladi?","options":["2","4","6","8"],"correctIndex":2,"difficulty":"easy","explanation":"4 ta va 2 ta qalamni birlashtiramiz. 4 + 2 = 6."}}]'::jsonb,
    '{"id":"q_lesson_math_starter_practice","courseId":"course_math_01","skillId":"skill_math_algebra","text":"6 ta daftardan 2 tasi olinsa, nechta qoladi?","options":["4","2","6","8"],"correctIndex":0,"difficulty":"easy","explanation":"6 − 2 = 4."}'::jsonb),
  ('lesson_eng_starter', 'course_eng_01', 'skill_eng_vocab', 'Birinchi inglizcha so‘zlar', 'Ingliz tilida «Hello» — salom, «Thank you» — rahmat, «Goodbye» — xayr. O‘zingizni tanishtirish uchun «I am» dan keyin ismingizni ayting.',
    '[{"id":"lesson_eng_starter_read","stepNumber":1,"type":"concept","title":"Asosiy tushuncha","content":"Ingliz tilida «Hello» — salom, «Thank you» — rahmat, «Goodbye» — xayr. O‘zingizni tanishtirish uchun «I am» dan keyin ismingizni ayting."},{"id":"lesson_eng_starter_example","stepNumber":2,"type":"audio_simulation","title":"Birga misol ko‘ramiz","content":"Ikki kishining ilk suhbati.\n\nAziza — Hello! I am Aziza. (Salom! Men Azizaman.)\n\nSardor — Hello! I am Sardor. (Salom! Men Sardorman.)\n\nXayrlashayotganda «Goodbye!» deymiz.","visualModelData":{"type":"audio_wave","audioTranscript":"Hello! I am Aziza. Hello! I am Sardor. Goodbye!","speakerName":"Inglizcha salomlashish"}},{"id":"lesson_eng_starter_try","stepNumber":3,"type":"interactive_question","title":"O‘rganganingizni sinab ko‘ring","content":"Misoldan foydalanib bitta javobni tanlang.","interactiveQuestion":{"id":"q_lesson_eng_starter_quiz","courseId":"course_eng_01","skillId":"skill_eng_vocab","text":"Ingliz tilida salomlashish uchun qaysi so‘zni aytamiz?","options":["Goodbye","Hello","Thank you"],"correctIndex":1,"difficulty":"easy","explanation":"Hello — salom. Uni suhbatni boshlaganda aytamiz."}}]'::jsonb,
    '{"id":"q_lesson_eng_starter_practice","courseId":"course_eng_01","skillId":"skill_eng_vocab","text":"«Thank you» o‘zbekchada nima degani?","options":["Salom","Xayr","Rahmat"],"correctIndex":2,"difficulty":"easy","explanation":"Thank you — rahmat."}'::jsonb),
  ('lesson_it_starter', 'course_it', 'skill_it_python', 'Kompyuterga birinchi buyruq', 'Dastur kompyuter bajaradigan buyruqlardan iborat. Python tilida print buyrug‘i matnni ekranga chiqaradi.',
    '[{"id":"lesson_it_starter_read","stepNumber":1,"type":"concept","title":"Asosiy tushuncha","content":"Dastur kompyuter bajaradigan buyruqlardan iborat. Python tilida print buyrug‘i matnni ekranga chiqaradi."},{"id":"lesson_it_starter_example","stepNumber":2,"type":"visual_example","title":"Birga misol ko‘ramiz","content":"print(\"Salom!\") buyrug‘i ekranda Salom! yozuvini ko‘rsatadi. Qo‘shtirnoq qayerda matn boshlanib, qayerda tugashini bildiradi."},{"id":"lesson_it_starter_try","stepNumber":3,"type":"interactive_question","title":"O‘rganganingizni sinab ko‘ring","content":"Misoldan foydalanib bitta javobni tanlang.","interactiveQuestion":{"id":"q_lesson_it_starter_quiz","courseId":"course_it","skillId":"skill_it_python","text":"print(\"Kitob\") buyrug‘idan keyin ekranda nima ko‘rinadi?","options":["print","Kitob","Matn chiqmaydi"],"correctIndex":1,"difficulty":"easy","explanation":"print qo‘shtirnoq ichidagi Kitob so‘zini ekranga chiqaradi."}}]'::jsonb,
    '{"id":"q_lesson_it_starter_practice","courseId":"course_it","skillId":"skill_it_python","text":"Matnni ekranga chiqaradigan buyruq qaysi?","options":["print","Salom","Python"],"correctIndex":0,"difficulty":"easy","explanation":"print — ekranga chiqarish buyrug‘i."}'::jsonb),
  ('lesson_logic_starter', 'course_logic', 'skill_logic_puzzles', 'Rost va yolg‘on gaplar', 'Rost yoki yolg‘onligini tekshirish mumkin bo‘lgan gap mulohaza deyiladi. Savol esa javob so‘raydi.',
    '[{"id":"lesson_logic_starter_read","stepNumber":1,"type":"concept","title":"Asosiy tushuncha","content":"Rost yoki yolg‘onligini tekshirish mumkin bo‘lgan gap mulohaza deyiladi. Savol esa javob so‘raydi."},{"id":"lesson_logic_starter_example","stepNumber":2,"type":"visual_example","title":"Birga misol ko‘ramiz","content":"«2 + 3 = 5» rost mulohaza. «2 + 3 = 6» yolg‘on mulohaza. «Soat necha?» esa savol, uni rost yoki yolg‘on deb baholay olmaymiz."},{"id":"lesson_logic_starter_try","stepNumber":3,"type":"interactive_question","title":"O‘rganganingizni sinab ko‘ring","content":"Misoldan foydalanib bitta javobni tanlang.","interactiveQuestion":{"id":"q_lesson_logic_starter_quiz","courseId":"course_logic","skillId":"skill_logic_puzzles","text":"Qaysi gap rost mulohaza?","options":["4 + 1 = 7","Soat necha?","4 + 1 = 5"],"correctIndex":2,"difficulty":"easy","explanation":"4 ga 1 qo‘shilganda 5 bo‘ladi."}}]'::jsonb,
    '{"id":"q_lesson_logic_starter_practice","courseId":"course_logic","skillId":"skill_logic_puzzles","text":"Qaysi gap savol?","options":["Bir kunda 24 soat bor.","Bugun qaysi kun?","7 soni 5 dan katta."],"correctIndex":1,"difficulty":"easy","explanation":"«Bugun qaysi kun?» javob so‘raydi."}'::jsonb)
) AS lesson(id, course_id, skill_id, title, summary, steps, reinforcement)
JOIN public.skills ON skills.id = lesson.skill_id AND skills.course_id = lesson.course_id
ON CONFLICT (id) DO NOTHING;

UPDATE public.courses AS course SET starter_lesson_id = lesson.id
FROM public.lessons AS lesson
WHERE course.id = lesson.course_id AND course.starter_lesson_id IS NULL
  AND lesson.id IN ('lesson_math_starter', 'lesson_eng_starter', 'lesson_it_starter', 'lesson_logic_starter');

COMMIT;
