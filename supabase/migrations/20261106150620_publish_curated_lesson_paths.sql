-- Curated introductory material for the existing four subjects.
-- Keep an administrator's existing content and already-linked nodes.
BEGIN;

INSERT INTO public.courses (id,title,subject,description,icon_name,primary_color_hex,secondary_color_hex)
VALUES
  ('course_it','IT & Kodlash','it','Dasturlash va veb asoslari.','Code2','#087653','#14B8A6'),
  ('course_logic','Mantiq','logic','Mulohaza, qonuniyat va boshqotirmalar.','Brain','#9A6100','#F59E0B')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.skills (id,course_id,name,code,description,order_index,icon_name)
VALUES
  ('skill_it_python','course_it','Python asoslari','IT-PY','O‘zgaruvchilar va ma’lumot turlari.',1,'Code2'),
  ('skill_it_web','course_it','Veb dasturlash','IT-WEB','HTML sahifa tuzilishi.',2,'Code2'),
  ('skill_logic_puzzles','course_logic','Mantiqiy boshqotirmalar','LOG-PUZ','Shartli mulohazalar.',1,'Brain'),
  ('skill_logic_patterns','course_logic','Qonuniyatlar va ketma-ketliklar','LOG-PAT','Hadlar orasidagi bog‘lanish.',2,'Brain')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.roadmap_nodes (id,course_id,skill_id,title,description,prerequisites,required_score,is_reinforcement,estimated_minutes,order_index,is_active)
SELECT n.id,n.course_id,n.skill_id,n.title,s.description,n.prerequisites,50,false,n.estimated_minutes,n.order_index,true
FROM (VALUES
  ('node_it_python','course_it','skill_it_python','Python asoslari','[]'::jsonb,9,1),
  ('node_it_web','course_it','skill_it_web','Veb sahifa tuzilishi','["node_it_python"]'::jsonb,8,2),
  ('node_logic_puzzles','course_logic','skill_logic_puzzles','Mantiqiy boshqotirmalar','[]'::jsonb,8,1),
  ('node_logic_patterns','course_logic','skill_logic_patterns','Qonuniyatlar','["node_logic_puzzles"]'::jsonb,8,2)
) AS n(id,course_id,skill_id,title,prerequisites,estimated_minutes,order_index)
JOIN public.skills s ON s.id=n.skill_id AND s.course_id=n.course_id
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.lessons (id,course_id,skill_id,title,summary,estimated_minutes,steps,reinforcement_exercise)
SELECT l.id,l.course_id,l.skill_id,l.title,l.summary,l.estimated_minutes,l.steps,l.reinforcement_exercise
FROM (VALUES
  ('lesson_math_algebra_01',
    'course_math_01',
    'skill_math_algebra',
    'Kvadratni ochish',
    '(a+b)² ni ochishda a² va b² orasidagi 2ab hadini yozing. Bu (a+b)(a+b) ni ko‘paytirishda hosil bo‘ladigan ikki bir xil ab hadining yig‘indisi.',
    8,
    '[{"id":"lesson_math_algebra_01_concept","stepNumber":1,"type":"concept","title":"Qoida","content":"(a+b)² ni ochishda a² va b² orasidagi 2ab hadini yozing. Bu (a+b)(a+b) ni ko‘paytirishda hosil bo‘ladigan ikki bir xil ab hadining yig‘indisi."},{"id":"lesson_math_algebra_01_example","stepNumber":2,"type":"visual_example","title":"Ishlangan misol","content":"Masalan, (x+3)² = x² + 6x + 9. Manfiy ishorali holatda (x−3)² = x² − 6x + 9."},{"id":"lesson_math_algebra_01_test","stepNumber":3,"type":"interactive_question","title":"Bilimingizni tekshiring","content":"Variantlardan birini tanlang va javobingizni tekshiring.","interactiveQuestion":{"id":"q_live_math_algebra_01_quiz","text":"(x + 4)² yoyilmasida x oldidagi koeffitsiyent nechaga teng?","options":["4","8","16","2"],"correctIndex":1,"explanation":"Aralash had 2 · x · 4 = 8x.","difficulty":"medium"}}]'::jsonb,
    '{"id":"q_live_math_algebra_01_practice","text":"(x − 5)² ni oching.","options":["x² − 5x + 25","x² + 10x + 25","x² − 25","x² − 10x + 25"],"correctIndex":3,"explanation":"O‘rtadagi had −2 · 5 · x = −10x, oxirgi had esa (−5)² = 25.","difficulty":"medium"}'::jsonb),
  ('lesson_math_equations_01',
    'course_math_01',
    'skill_math_equations',
    'Chiziqli tenglamani yechish',
    'Tenglikni saqlash uchun ikkala tomonga bir xil amal qo‘llanadi. Avval noma’lumli hadni ajrating, keyin uning koeffitsiyentiga bo‘ling.',
    9,
    '[{"id":"lesson_math_equations_01_concept","stepNumber":1,"type":"concept","title":"Qoida","content":"Tenglikni saqlash uchun ikkala tomonga bir xil amal qo‘llanadi. Avval noma’lumli hadni ajrating, keyin uning koeffitsiyentiga bo‘ling."},{"id":"lesson_math_equations_01_example","stepNumber":2,"type":"visual_example","title":"Ishlangan misol","content":"2x + 3 = 11 bo‘lsa, ikkala tomondan 3 ayirib 2x = 8 ni olamiz. Ikkala tomonni 2 ga bo‘lsak, x = 4."},{"id":"lesson_math_equations_01_test","stepNumber":3,"type":"interactive_question","title":"Bilimingizni tekshiring","content":"Variantlardan birini tanlang va javobingizni tekshiring.","interactiveQuestion":{"id":"q_live_math_equations_01_quiz","text":"4x − 7 = 13 tenglamasini yeching.","options":["5","4","3","−5"],"correctIndex":0,"explanation":"Ikkala tomonga 7 qo‘shing: 4x = 20. Keyin 4 ga bo‘ling.","difficulty":"medium"}}]'::jsonb,
    '{"id":"q_live_math_equations_01_practice","text":"3x + 8 = −4 tenglamasida x ni toping.","options":["4","−12","−4","−2"],"correctIndex":2,"explanation":"8 ni ayirsak, 3x = −12. Demak, x = −4.","difficulty":"medium"}'::jsonb),
  ('lesson_math_functions_01',
    'course_math_01',
    'skill_math_functions',
    'Funksiya nima? Asosiy tushunchalar',
    'Funksiya har bir ruxsat etilgan kirish qiymatiga bitta chiqish qiymatini mos qo‘yadi. f(3) yozuvi argument o‘rniga 3 qo‘yishni anglatadi.',
    10,
    '[{"id":"lesson_math_functions_01_concept","stepNumber":1,"type":"concept","title":"Qoida","content":"Funksiya har bir ruxsat etilgan kirish qiymatiga bitta chiqish qiymatini mos qo‘yadi. f(3) yozuvi argument o‘rniga 3 qo‘yishni anglatadi."},{"id":"lesson_math_functions_01_example","stepNumber":2,"type":"visual_example","title":"Ishlangan misol","content":"f(x) = 3x − 2 bo‘lsa, f(4) = 3 · 4 − 2 = 10. Avval ko‘paytiring, keyin 2 ni ayiring."},{"id":"lesson_math_functions_01_test","stepNumber":3,"type":"interactive_question","title":"Bilimingizni tekshiring","content":"Variantlardan birini tanlang va javobingizni tekshiring.","interactiveQuestion":{"id":"q_live_math_functions_01_quiz","text":"f(x) = 5x − 3 bo‘lsa, f(2) nechaga teng?","options":["2","10","13","7"],"correctIndex":3,"explanation":"x o‘rniga 2 qo‘yamiz: 5 · 2 − 3 = 7.","difficulty":"medium"}}]'::jsonb,
    '{"id":"q_live_math_functions_01_practice","text":"g(x) = 2x + 6 uchun g(−1) ni toping.","options":["−8","4","8","5"],"correctIndex":1,"explanation":"2 · (−1) + 6 = 4.","difficulty":"medium"}'::jsonb),
  ('lesson_math_functions_03',
    'course_math_01',
    'skill_math_graphs',
    'Grafikning o‘qlar bilan kesishishi',
    'Grafikning y o‘qi bilan kesishgan nuqtasida x = 0. Grafikning x o‘qi bilan kesishgan nuqtasida y = 0.',
    10,
    '[{"id":"lesson_math_functions_03_concept","stepNumber":1,"type":"concept","title":"Qoida","content":"Grafikning y o‘qi bilan kesishgan nuqtasida x = 0. Grafikning x o‘qi bilan kesishgan nuqtasida y = 0."},{"id":"lesson_math_functions_03_example","stepNumber":2,"type":"visual_example","title":"Ishlangan misol","content":"y = x + 2 chiziq y o‘qini (0, 2) da, x o‘qini (−2, 0) da kesadi. Har bir juftlikni tenglamaga qo‘yib tekshiring."},{"id":"lesson_math_functions_03_test","stepNumber":3,"type":"interactive_question","title":"Bilimingizni tekshiring","content":"Variantlardan birini tanlang va javobingizni tekshiring.","interactiveQuestion":{"id":"q_live_math_functions_03_quiz","text":"y = −2x + 6 grafigi y o‘qini qayerda kesadi?","options":["(6, 0)","(0, 6)","(3, 0)","(0, −2)"],"correctIndex":1,"explanation":"y o‘qida x = 0. Demak, y = 6.","difficulty":"medium"}}]'::jsonb,
    '{"id":"q_live_math_functions_03_practice","text":"Shu grafik x o‘qini qayerda kesadi?","options":["(0, 6)","(−3, 0)","(3, 0)","(6, 0)"],"correctIndex":2,"explanation":"y = 0 bo‘lganda −2x + 6 = 0, shundan x = 3.","difficulty":"medium"}'::jsonb),
  ('lesson_eng_vocab_01',
    'course_eng_01',
    'skill_eng_vocab',
    'So‘z ma’nosini kontekstdan topish',
    'Notanish so‘z atrofidagi harakat, vaqt va sababga qarang. Birinchi taxminni butun gapga qayta qo‘yib tekshiring.',
    8,
    '[{"id":"lesson_eng_vocab_01_concept","stepNumber":1,"type":"concept","title":"Qoida","content":"Notanish so‘z atrofidagi harakat, vaqt va sababga qarang. Birinchi taxminni butun gapga qayta qo‘yib tekshiring."},{"id":"lesson_eng_vocab_01_example","stepNumber":2,"type":"visual_example","title":"Ishlangan misol","content":"«We postponed the meeting because the road was closed. We will meet tomorrow.» Ikkinchi jumla uchrashuv bekor qilinmaganini, boshqa vaqtga ko‘chirilganini bildiradi."},{"id":"lesson_eng_vocab_01_test","stepNumber":3,"type":"interactive_question","title":"Bilimingizni tekshiring","content":"Variantlardan birini tanlang va javobingizni tekshiring.","interactiveQuestion":{"id":"q_live_eng_vocab_01_quiz","text":"«We allocated two hours for revision.» Bu yerda «allocated» nimani bildiradi?","options":["Qaytarib oldik","Ajratdik","Bekor qildik","O‘lchadik"],"correctIndex":1,"explanation":"Ikki soat takrorlash uchun ajratilgan, ya’ni reja ichida shu ishga berilgan.","difficulty":"medium"}}]'::jsonb,
    '{"id":"q_live_eng_vocab_01_practice","text":"«The train was delayed by thirty minutes.» «Delayed» so‘zining ma’nosi nima?","options":["Tezlashdi","To‘xtatildi","Kechikdi","Oldin jo‘nadi"],"correctIndex":2,"explanation":"Vaqt iborasi poezd 30 daqiqa kechikkanini ko‘rsatadi.","difficulty":"medium"}'::jsonb),
  ('lesson_eng_grammar_01',
    'course_eng_01',
    'skill_eng_grammar',
    'Birinchi shart gapi',
    'Birinchi shart gapida kelajakda bajarilishi mumkin bo‘lgan shart ifodalanadi. If qismida hozirgi oddiy zamon, natijada will va fe’lning asosiy shakli keladi.',
    9,
    '[{"id":"lesson_eng_grammar_01_concept","stepNumber":1,"type":"concept","title":"Qoida","content":"Birinchi shart gapida kelajakda bajarilishi mumkin bo‘lgan shart ifodalanadi. If qismida hozirgi oddiy zamon, natijada will va fe’lning asosiy shakli keladi."},{"id":"lesson_eng_grammar_01_example","stepNumber":2,"type":"visual_example","title":"Ishlangan misol","content":"«If it rains, we will study indoors.» If qismi «rains», natija qismi esa «will study»."},{"id":"lesson_eng_grammar_01_test","stepNumber":3,"type":"interactive_question","title":"Bilimingizni tekshiring","content":"Variantlardan birini tanlang va javobingizni tekshiring.","interactiveQuestion":{"id":"q_live_eng_grammar_01_quiz","text":"«If the library ___ early, we will study at home.» Bo‘sh joyni to‘ldiring.","options":["will close","closing","closes","close"],"correctIndex":2,"explanation":"The library birlikda. Shart qismida Present Simple bo‘yicha closes ishlatiladi.","difficulty":"medium"}}]'::jsonb,
    '{"id":"q_live_eng_grammar_01_practice","text":"«If she finishes early, she ___ us.» Natija qismini to‘ldiring.","options":["will call","call","called","calling"],"correctIndex":0,"explanation":"Ehtimoliy kelajak natijasi will call bilan ifodalanadi.","difficulty":"medium"}'::jsonb),
  ('lesson_eng_listening_01',
    'course_eng_01',
    'skill_eng_listening',
    'Xabardagi vaqt o‘zgarishini ajratish',
    'Xabar tinglayotganda avval aytilgan vaqt va yangilangan vaqtni ikki ustunga yozing. «Instead» yoki «has moved to» yangi ma’lumotni ajratishga yordam beradi.',
    10,
    '[{"id":"lesson_eng_listening_01_concept","stepNumber":1,"type":"concept","title":"Qoida","content":"Xabar tinglayotganda avval aytilgan vaqt va yangilangan vaqtni ikki ustunga yozing. «Instead» yoki «has moved to» yangi ma’lumotni ajratishga yordam beradi."},{"id":"lesson_eng_listening_01_example","stepNumber":2,"type":"visual_example","title":"Ishlangan misol","content":"«The club was due to meet at four, but it will now start at half past four.» Uchrashuvning amaldagi vaqti 16:30."},{"id":"lesson_eng_listening_01_test","stepNumber":3,"type":"interactive_question","title":"Bilimingizni tekshiring","content":"Variantlardan birini tanlang va javobingizni tekshiring.","interactiveQuestion":{"id":"q_live_eng_listening_01_quiz","text":"Audio xabarda to‘garakning yangilangan boshlanish vaqti qaysi?","options":["4:00","4:15","4:30","5:00"],"correctIndex":2,"explanation":"«Will now start at half past four» birikmasi yangilangan vaqt 4:30 ekanini bildiradi.","difficulty":"medium"},"visualModelData":{"type":"audio_wave","audioTranscript":"The club was due to meet at four, but it will now start at half past four.","speakerName":"To‘garak e’loni"}}]'::jsonb,
    '{"id":"q_live_eng_listening_01_practice","text":"«The talk will be in Room 12 instead of Room 9.» Qaysi xonaga borish kerak?","options":["9","12","21","19"],"correctIndex":1,"explanation":"«Room 12 instead of Room 9» yangi xona 12 ekanini bildiradi.","difficulty":"medium"}'::jsonb),
  ('lesson_eng_reading_01',
    'course_eng_01',
    'skill_eng_reading',
    'Asosiy g‘oya va dalil',
    'Asosiy g‘oya butun matn nima haqida ekanini qisqacha aytadi. Sana, miqdor yoki alohida misol g‘oyani tasdiqlovchi dalil bo‘lishi mumkin.',
    8,
    '[{"id":"lesson_eng_reading_01_concept","stepNumber":1,"type":"concept","title":"Qoida","content":"Asosiy g‘oya butun matn nima haqida ekanini qisqacha aytadi. Sana, miqdor yoki alohida misol g‘oyani tasdiqlovchi dalil bo‘lishi mumkin."},{"id":"lesson_eng_reading_01_example","stepNumber":2,"type":"visual_example","title":"Ishlangan misol","content":"«The school opened a repair club. On Fridays students fix broken lamps and learn to reuse old parts. The club helps reduce waste.» Matnning mavzusi ta’mirlash to‘garagi orqali chiqindini kamaytirish."},{"id":"lesson_eng_reading_01_test","stepNumber":3,"type":"interactive_question","title":"Bilimingizni tekshiring","content":"Variantlardan birini tanlang va javobingizni tekshiring.","interactiveQuestion":{"id":"q_live_eng_reading_01_quiz","text":"Matnning asosiy g‘oyasi qaysi?","options":["Chiroqlar qimmat turadi","Juma eng qisqa kun","To‘garak buyumlarni ta’mirlab, chiqindini kamaytiradi","Maktab eski buyumlarni sotadi"],"correctIndex":2,"explanation":"Uchala jumla ta’mirlash to‘garagining faoliyati va uning foydasini bog‘laydi.","difficulty":"medium"}}]'::jsonb,
    '{"id":"q_live_eng_reading_01_practice","text":"Qaysi jumla matndagi aniq dalilga mos?","options":["O‘quvchilar juma kuni chiroqlarni tuzatadi","To‘garak har kuni ochiq","Maktab faqat yangi qismlar sotib oladi","To‘garak may oyida ochilgan"],"correctIndex":0,"explanation":"Matnda juma kunlari chiroqlar tuzatilishi aytilgan.","difficulty":"medium"}'::jsonb),
  ('lesson_it_python_01',
    'course_it',
    'skill_it_python',
    'Python’da tur va qiymat',
    'O‘zgaruvchi qiymatga berilgan nom. Matn qo‘shtirnoq bilan yoziladi, butun son esa qo‘shtirnoqsiz yoziladi. Kerak bo‘lsa int() sonli matnni butun songa aylantiradi.',
    9,
    '[{"id":"lesson_it_python_01_concept","stepNumber":1,"type":"concept","title":"Qoida","content":"O‘zgaruvchi qiymatga berilgan nom. Matn qo‘shtirnoq bilan yoziladi, butun son esa qo‘shtirnoqsiz yoziladi. Kerak bo‘lsa int() sonli matnni butun songa aylantiradi."},{"id":"lesson_it_python_01_example","stepNumber":2,"type":"visual_example","title":"Ishlangan misol","content":"```python\nquantity = \"7\"\nprint(int(quantity) + 2)\n```\nint(quantity) natijasi 7 soni, shuning uchun ekranga 9 chiqadi."},{"id":"lesson_it_python_01_test","stepNumber":3,"type":"interactive_question","title":"Bilimingizni tekshiring","content":"Variantlardan birini tanlang va javobingizni tekshiring.","interactiveQuestion":{"id":"q_live_it_python_01_quiz","text":"Python’da print(int(\"12\") + 3) qanday natija chiqaradi?","options":["123","15","12","Xato"],"correctIndex":1,"explanation":"int(\"12\") 12 sonini qaytaradi. 12 + 3 = 15.","difficulty":"medium"}}]'::jsonb,
    '{"id":"q_live_it_python_01_practice","text":"Python’da \"6\" + \"2\" ifodasi qanday qiymat qaytaradi?","options":["8","12","\"62\"","\"8\""],"correctIndex":2,"explanation":"Ikkala operand matn. + matnlarni ketma-ket birlashtiradi.","difficulty":"medium"}'::jsonb),
  ('lesson_it_web_01',
    'course_it',
    'skill_it_web',
    'HTML sahifasining mazmuni va tuzilishi',
    'HTML teglar mazmunning vazifasini ko‘rsatadi. Asosiy mazmun main, navigatsiya nav, birinchi darajali sarlavha h1 bilan belgilanadi.',
    8,
    '[{"id":"lesson_it_web_01_concept","stepNumber":1,"type":"concept","title":"Qoida","content":"HTML teglar mazmunning vazifasini ko‘rsatadi. Asosiy mazmun main, navigatsiya nav, birinchi darajali sarlavha h1 bilan belgilanadi."},{"id":"lesson_it_web_01_example","stepNumber":2,"type":"visual_example","title":"Ishlangan misol","content":"```html\n<main>\n  <h1>Mening loyiham</h1>\n  <p>Bu sahifa loyihani tanishtiradi.</p>\n</main>\n```\nBrauzer va yordamchi texnologiyalar teglar orqali sahifa qismlarini ajratadi."},{"id":"lesson_it_web_01_test","stepNumber":3,"type":"interactive_question","title":"Bilimingizni tekshiring","content":"Variantlardan birini tanlang va javobingizni tekshiring.","interactiveQuestion":{"id":"q_live_it_web_01_quiz","text":"Sahifaning asosiy mazmuni uchun qaysi HTML tegi mos?","options":["<nav>","<aside>","<footer>","<main>"],"correctIndex":3,"explanation":"<main> sahifaning asosiy, mavzuga tegishli mazmunini bildiradi.","difficulty":"medium"}}]'::jsonb,
    '{"id":"q_live_it_web_01_practice","text":"Asosiy sarlavha uchun qaysi teg mos?","options":["<h1>","<p>","<span>","<li>"],"correctIndex":0,"explanation":"<h1> birinchi darajali sarlavha tegidir.","difficulty":"medium"}'::jsonb),
  ('lesson_logic_puzzles_01',
    'course_logic',
    'skill_logic_puzzles',
    'Shartdan to‘g‘ri xulosa chiqarish',
    '«A bo‘lsa, B» mulohazasi A dan B ga o‘tishga imkon beradi. B rostligidan A rostligi kelib chiqmaydi, chunki B ning boshqa sabablari ham bo‘lishi mumkin.',
    8,
    '[{"id":"lesson_logic_puzzles_01_concept","stepNumber":1,"type":"concept","title":"Qoida","content":"«A bo‘lsa, B» mulohazasi A dan B ga o‘tishga imkon beradi. B rostligidan A rostligi kelib chiqmaydi, chunki B ning boshqa sabablari ham bo‘lishi mumkin."},{"id":"lesson_logic_puzzles_01_example","stepNumber":2,"type":"visual_example","title":"Ishlangan misol","content":"«Kartasi bor odam zalga kirishi mumkin.» Samiraning kartasi bor, demak u zalga kirishi mumkin. Zalda bo‘lgan kishining kartasi borligini shu qoidaning o‘zidan bilmaymiz."},{"id":"lesson_logic_puzzles_01_test","stepNumber":3,"type":"interactive_question","title":"Bilimingizni tekshiring","content":"Variantlardan birini tanlang va javobingizni tekshiring.","interactiveQuestion":{"id":"q_live_logic_puzzles_01_quiz","text":"«Agar chiroq yoqilgan bo‘lsa, xona yorug‘». Xona yorug‘. Chiroq haqida qaysi xulosa aniq?","options":["U albatta yoqilgan","U albatta o‘chirilgan","U singan","Xulosa uchun ma’lumot yetarli emas"],"correctIndex":3,"explanation":"Xona boshqa sabab, masalan, quyosh nuri tufayli ham yorug‘ bo‘lishi mumkin.","difficulty":"medium"}}]'::jsonb,
    '{"id":"q_live_logic_puzzles_01_practice","text":"«A bo‘lsa B» rost va A rost. Qaysi xulosa aniq?","options":["B rost","B yolg‘on","A yolg‘on","Xulosa chiqarib bo‘lmaydi"],"correctIndex":0,"explanation":"Shart va uning old qismi rost bo‘lsa, natija B ham rost.","difficulty":"medium"}'::jsonb),
  ('lesson_logic_patterns_01',
    'course_logic',
    'skill_logic_patterns',
    'Ketma-ketlikda o‘zgarishni kuzatish',
    'Qo‘shni hadlar orasidagi farqlarni yozing. Farqlar bir xil bo‘lmasa, ularning o‘zi qanday o‘zgarayotganini tekshiring.',
    8,
    '[{"id":"lesson_logic_patterns_01_concept","stepNumber":1,"type":"concept","title":"Qoida","content":"Qo‘shni hadlar orasidagi farqlarni yozing. Farqlar bir xil bo‘lmasa, ularning o‘zi qanday o‘zgarayotganini tekshiring."},{"id":"lesson_logic_patterns_01_example","stepNumber":2,"type":"visual_example","title":"Ishlangan misol","content":"2, 5, 9, 14 ketma-ketligida farqlar 3, 4, 5. Farqlar har gal bittaga oshsa, keyingi farq 6 va navbatdagi had 20 bo‘ladi."},{"id":"lesson_logic_patterns_01_test","stepNumber":3,"type":"interactive_question","title":"Bilimingizni tekshiring","content":"Variantlardan birini tanlang va javobingizni tekshiring.","interactiveQuestion":{"id":"q_live_logic_patterns_01_quiz","text":"4, 7, 11, 16 ketma-ketligida farqlar har safar bittaga oshadi. Keyingi had nechaga teng?","options":["20","21","22","23"],"correctIndex":2,"explanation":"Farqlar 3, 4, 5. Keyingi farq 6, 16 + 6 = 22.","difficulty":"medium"}}]'::jsonb,
    '{"id":"q_live_logic_patterns_01_practice","text":"3, 6, 12, 24 ketma-ketligida har bir had ikki baravar oshadi. Keyingi had nechaga teng?","options":["30","36","42","48"],"correctIndex":3,"explanation":"24 ni 2 ga ko‘paytiramiz.","difficulty":"medium"}'::jsonb)
) AS l(id,course_id,skill_id,title,summary,estimated_minutes,steps,reinforcement_exercise)
JOIN public.skills s ON s.id=l.skill_id AND s.course_id=l.course_id
ON CONFLICT (id) DO NOTHING;

UPDATE public.roadmap_nodes n
SET target_lesson_id=l.id
FROM public.lessons l
WHERE n.target_lesson_id IS NULL AND NOT n.is_reinforcement AND n.is_active
  AND l.is_published AND NOT l.is_archived AND l.course_id=n.course_id AND l.skill_id=n.skill_id
  AND l.id IN ('lesson_math_algebra_01', 'lesson_math_equations_01', 'lesson_math_functions_01', 'lesson_math_functions_03', 'lesson_eng_vocab_01', 'lesson_eng_grammar_01', 'lesson_eng_listening_01', 'lesson_eng_reading_01', 'lesson_it_python_01', 'lesson_it_web_01', 'lesson_logic_puzzles_01', 'lesson_logic_patterns_01');


-- Distinct placement questions provide coverage on a migration-only project.
INSERT INTO public.questions (id,course_id,skill_id,text,options,correct_index,difficulty,explanation,is_placement)
SELECT q.id,q.course_id,q.skill_id,q.text,q.options,q.correct_index,'medium',q.explanation,true
FROM (VALUES
  ('q_live_eng_vocab_context', 'course_eng_01', 'skill_eng_vocab', '«The instructions were brief: only two lines.» Brief so‘zining ma’nosi nima?',
    '["Murakkab","Qisqa","Yashirin","Rangli"]'::jsonb, 1, 'Only two lines iborasi ko‘rsatma qisqaligini bildiradi.'),
  ('q_live_eng_grammar_daily', 'course_eng_01', 'skill_eng_grammar', '«My brother ___ to school every weekday.»',
    '["go","going","goes","gone"]'::jsonb, 2, 'Doimiy odat uchun Present Simple, uchinchi shaxs birlik uchun goes ishlatiladi.'),
  ('q_live_eng_reading_evidence', 'course_eng_01', 'skill_eng_reading', '«The library stays open until seven on Tuesdays because students attend a study group.» Kutubxona nega seshanba kuni kechroq yopiladi?',
    '["O‘quvchilar guruhda shug‘ullanishi uchun","Yangi kitoblar kelgani uchun","Darslar ertaroq tugagani uchun","Dam olish kuni bo‘lgani uchun"]'::jsonb, 0, 'Because bog‘lovchisidan keyin sabab aytilgan: students attend a study group.'),
  ('q_live_it_python_len', 'course_it', 'skill_it_python', 'Python’da len([2, 4, 6, 8]) natijasi nima?',
    '["8","3","20","4"]'::jsonb, 3, 'len ro‘yxatdagi elementlar sonini qaytaradi.'),
  ('q_live_it_python_compare', 'course_it', 'skill_it_python', 'Python’da 9 > 12 ifodasi qaysi qiymatga teng?',
    '["True","False","9","12"]'::jsonb, 1, '9 soni 12 dan katta emas, shuning uchun False.'),
  ('q_live_it_web_link', 'course_it', 'skill_it_web', 'HTML’da havolaning manzili qaysi atributda ko‘rsatiladi?',
    '["id","class","href","alt"]'::jsonb, 2, 'a tegidagi href atributi bog‘lanadigan manzilni bildiradi.'),
  ('q_live_it_web_image', 'course_it', 'skill_it_web', 'Rasm ochilmasa, uning tavsifini qaysi atribut beradi?',
    '["alt","src","href","lang"]'::jsonb, 0, 'alt atributi rasmning matnli muqobil tavsifidir.'),
  ('q_live_logic_all', 'course_logic', 'skill_logic_puzzles', 'Barcha kvadratlar to‘rtburchak. A shakli kvadrat. Nima aniq?',
    '["A uchburchak","A doira","A to‘rtburchak","A ning tomonlari soni noma’lum"]'::jsonb, 2, 'Umumiy qoida A kvadratiga ham tegishli.'),
  ('q_live_logic_converse', 'course_logic', 'skill_logic_puzzles', '«Yomg‘ir yog‘sa, yo‘l nam bo‘ladi.» Yo‘l nam. Nima aniq?',
    '["Yomg‘ir albatta yog‘di","Yomg‘ir hech qachon yog‘madi","Yo‘l nam","Yo‘l albatta sug‘orilgan"]'::jsonb, 2, 'Yo‘l namligi berilgan. Namlikning sababini faqat shu qoidadan aniqlab bo‘lmaydi.'),
  ('q_live_logic_pattern_three', 'course_logic', 'skill_logic_patterns', 'Har safar 3 qo‘shilsa, 5, 8, 11, 14 dan keyin qaysi son keladi?',
    '["15","18","16","17"]'::jsonb, 3, '14 + 3 = 17.'),
  ('q_live_logic_pattern_flip', 'course_logic', 'skill_logic_patterns', 'Qonuniyat ketma-ket +2, keyin −1: 6, 8, 7, 9, 8, ... Keyingi had qaysi?',
    '["10","9","7","11"]'::jsonb, 0, '8 dan keyingi amal +2, shuning uchun keyingi had 10.')
) AS q(id,course_id,skill_id,text,options,correct_index,explanation)
JOIN public.skills s ON s.id=q.skill_id AND s.course_id=q.course_id
ON CONFLICT (id) DO NOTHING;

-- Reinforcement rewards a verified practice answer. Only the lesson RPC can complete a lesson.
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
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_before INT := 0;
  v_after INT := 22;
  v_server_xp_awarded INT := 30;

  v_existing RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.skills
    WHERE id = p_skill_id AND course_id = p_course_id
  ) THEN
    RAISE EXCEPTION 'Ko‘nikma kurs bilan mos emas.' USING ERRCODE = '22023';
  END IF;

  IF p_reinforcement_node_id IS NULL OR NOT (
    p_reinforcement_node_id = 'reinf_' || p_course_id || '_' || p_skill_id
    OR EXISTS (SELECT 1 FROM public.roadmap_nodes
      WHERE course_id = p_course_id AND skill_id = p_skill_id AND is_active
        AND (p_reinforcement_node_id = 'reinf_' || id
          OR (is_reinforcement AND p_reinforcement_node_id = id)))
  ) THEN
    RAISE EXCEPTION 'Mustahkamlash tuguni kurs va ko‘nikmaga mos emas.' USING ERRCODE = '22023';
  END IF;

  -- Serialize completion for this learner/node so two concurrent retries
  -- cannot both create a reinforcement row or award XP.
  PERFORM pg_advisory_xact_lock(hashtextextended('learning:' || v_uid::TEXT, 0));
  PERFORM pg_advisory_xact_lock(
    hashtextextended(v_uid::TEXT || ':' || p_reinforcement_node_id, 0)
  );

  SELECT score INTO v_before
  FROM public.learner_skill_scores
  WHERE user_id = v_uid AND course_id = p_course_id AND skill_id = p_skill_id
  FOR UPDATE;

  SELECT * INTO v_existing FROM public.reinforcement_attempts
  WHERE user_id = v_uid AND reinforcement_node_id = p_reinforcement_node_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'already_processed', true,
      'old_score', v_existing.before_score,
      'new_score', v_existing.after_score,
      'xp_awarded', 0
    );
  END IF;

  -- A reinforcement completion is valid only after the same authenticated
  -- learner has a server-evaluated correct answer for this exact question.
  -- p_xp_awarded is accepted for backwards-compatible RPC clients but is not
  -- trusted for derived state.
  IF NOT COALESCE((
    SELECT is_correct
    FROM public.answer_attempts
    WHERE user_id = v_uid
      AND course_id = p_course_id
      AND skill_id = p_skill_id
      AND lesson_id = p_reinforcement_node_id
      AND question_id = p_question_id
    ORDER BY created_at DESC, id DESC LIMIT 1
  ), false) THEN
    RAISE EXCEPTION 'Mustahkamlash javobi serverda to‘g‘ri deb tasdiqlanmagan.'
      USING ERRCODE = '42501';
  END IF;

  v_before := COALESCE(v_before, 0);
  v_after := LEAST(100, v_before + 22);

  INSERT INTO public.reinforcement_attempts (
    user_id, course_id, skill_id, reinforcement_node_id,
    before_score, after_score, is_correct, xp_awarded, created_at
  )
  VALUES (
    v_uid, p_course_id, p_skill_id, p_reinforcement_node_id,
    v_before, v_after, true, v_server_xp_awarded, now()
  );

  INSERT INTO public.learner_skill_scores (
    user_id, course_id, skill_id, score, mastery_level, attempt_count, last_updated
  )
  VALUES (
    v_uid, p_course_id, p_skill_id, v_after,
    CASE WHEN v_after < 40 THEN 'needs_remediation'
         WHEN v_after < 60 THEN 'developing'
         WHEN v_after < 80 THEN 'proficient'
         ELSE 'mastered' END,
    1, now()
  )
  ON CONFLICT (user_id, course_id, skill_id) DO UPDATE SET
    score = EXCLUDED.score,
    mastery_level = EXCLUDED.mastery_level,
    last_updated = now();

  PERFORM public.award_xp(v_server_xp_awarded,
    'reinforcement_completed_' || p_reinforcement_node_id);
  PERFORM public.record_learning_activity();

  RETURN jsonb_build_object(
    'already_processed', false,
    'old_score', v_before,
    'new_score', v_after,
    'xp_awarded', v_server_xp_awarded
  );
END;
$$;

-- A streak begins with recorded learning activity rather than account creation.
CREATE OR REPLACE FUNCTION public.record_learning_activity(
  p_activity_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_today DATE := (now() AT TIME ZONE 'Asia/Tashkent')::date;
  v_streak INT := 1;
  v_last DATE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;

  IF p_activity_date IS NOT NULL AND p_activity_date <> v_today THEN
    RAISE EXCEPTION 'Faollik sanasi serverning joriy kuniga mos emas.' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('learning:' || v_uid::TEXT, 0));

  SELECT streak_days, last_activity_date
  INTO v_streak, v_last
  FROM public.gamification_profiles
  WHERE user_id = v_uid
  FOR UPDATE;

  v_streak := COALESCE(v_streak, 0);
  IF NOT EXISTS (
    SELECT 1 FROM public.daily_learning_stats
    WHERE user_id = v_uid AND activity_date = v_today
      AND (questions_answered > 0 OR xp_earned > 0 OR active_seconds >= 60)
  ) AND NOT EXISTS (
    SELECT 1 FROM public.placement_attempts WHERE user_id = v_uid
      AND completed_at >= (v_today::timestamp AT TIME ZONE 'Asia/Tashkent')
  ) THEN
    RETURN jsonb_build_object('streak_days', v_streak, 'activity_date', v_last);
  END IF;
  IF v_last = v_today THEN
    v_streak := GREATEST(v_streak, 1);
  ELSIF v_last = v_today - 1 THEN
    v_streak := v_streak + 1;
  ELSE
    v_streak := 1;
  END IF;

  INSERT INTO public.gamification_profiles (user_id, streak_days, last_activity_date, updated_at)
  VALUES (v_uid, v_streak, v_today, now())
  ON CONFLICT (user_id) DO UPDATE SET
    streak_days = EXCLUDED.streak_days,
    last_activity_date = EXCLUDED.last_activity_date,
    updated_at = now();

  RETURN jsonb_build_object('streak_days', v_streak, 'activity_date', v_today);
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_first_name TEXT;
  v_last_name TEXT;
  v_display_name TEXT;
  v_valid_course_id TEXT;
BEGIN
  v_first_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), ''), 'Foydalanuvchi');
  v_last_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), ''), '');
  v_display_name := CASE
    WHEN v_last_name <> '' THEN v_first_name || ' ' || v_last_name
    ELSE v_first_name
  END;

  INSERT INTO public.profiles (
    id, first_name, last_name, email, avatar_url, display_name, role, created_at, updated_at
  )
  VALUES (
    NEW.id,
    v_first_name,
    v_last_name,
    COALESCE(NEW.email, ''),
    NEW.raw_user_meta_data->>'avatar_url',
    v_display_name,
    'student',
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    first_name = CASE
      WHEN public.profiles.first_name = 'Foydalanuvchi'
        AND EXCLUDED.first_name <> 'Foydalanuvchi'
      THEN EXCLUDED.first_name
      ELSE public.profiles.first_name
    END,
    last_name = CASE
      WHEN public.profiles.last_name = '' AND EXCLUDED.last_name <> ''
      THEN EXCLUDED.last_name
      ELSE public.profiles.last_name
    END,
    display_name = CASE
      WHEN public.profiles.display_name = 'Foydalanuvchi'
        AND EXCLUDED.display_name <> 'Foydalanuvchi'
      THEN EXCLUDED.display_name
      ELSE public.profiles.display_name
    END,
    email = EXCLUDED.email,
    updated_at = now();

  BEGIN
    SELECT id INTO v_valid_course_id
    FROM public.courses
    WHERE id = 'course_math_01'
    LIMIT 1;

    INSERT INTO public.learner_profiles (
      user_id, selected_course_id, goal, daily_minutes, initial_level, created_at, updated_at
    )
    VALUES (
      NEW.id, v_valid_course_id, 'mastery', 15, 'intermediate', now(), now()
    )
    ON CONFLICT (user_id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: learner_profiles insert warning: %', SQLERRM;
  END;

  BEGIN
    INSERT INTO public.gamification_profiles (
      user_id, xp, streak_days, last_activity_date, updated_at
    )
    VALUES (
      NEW.id, 0, 0, NULL, now()
    )
    ON CONFLICT (user_id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: gamification_profiles insert warning: %', SQLERRM;
  END;

  BEGIN
    INSERT INTO public.user_preferences (
      user_id, dark_mode, notifications_enabled, language, updated_at
    )
    VALUES (NEW.id, false, true, 'uz', now())
    ON CONFLICT (user_id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: user_preferences insert warning: %', SQLERRM;
  END;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_new_user FATAL: %', SQLERRM;
  RETURN NEW;
END;
$$;

COMMIT;
