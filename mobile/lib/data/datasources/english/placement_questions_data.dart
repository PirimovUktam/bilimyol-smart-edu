// GENERATED FROM content/english/placement-questions.json - 1:1 canonical fidelity
import '../../../domain/entities/lesson_media.dart';
import '../../../domain/entities/question.dart';

const List<Question> englishPlacementQuestionsRaw = [
  Question(
    id: 'q_eng_place_vocab_a1',
    courseId: 'course_eng_01',
    skillId: 'skill_eng_vocab',
    skillDomain: 'vocabulary',
    difficulty: QuestionDifficulty.easy,
    cefrLevel: 'A1',
    topic: 'Placement A1: Everyday weather and clothing vocabulary',
    mode: QuestionMode.multipleChoice,
    isPlacement: true,
    text:
        'Choose the best word to complete the sentence: "It is raining outside, so please take your ____ before you leave."',
    textRu:
        'Выберите подходящее слово, чтобы дополнить предложение: «It is raining outside, so please take your ____ before you leave.»',
    options: ['pillow', 'sunglasses', 'umbrella', 'spoon'],
    correctIndex: 2,
    explanation:
        '"It is raining" (yomg‘ir yog‘yapti) kontekstida yomg‘irdan saqlanish uchun "umbrella" (soyabon) olinadi.',
    explanationRu:
        'В контексте «It is raining» (идёт дождь) для защиты от дождя берут «umbrella» (зонт).',
    wrongFeedback:
        'Gapning boshidagi ob-havo holatiga qarab tashqarida kerak bo‘ladigan buyumni tanlang.',
    wrongFeedbackRu:
        'Посмотрите на описание погоды в начале предложения и выберите предмет, нужный на улице.',
    mistakeFeedbackByOption: {
      'pillow': LocalizedFeedback(
        uz: '«Pillow» — yostiq, u yotoqxona buyumi bo‘lib, yomg‘irda ishlatilmaydi.',
        ru: '«Pillow» — это подушка, предмет для сна, а не для дождя.',
      ),
      'sunglasses': LocalizedFeedback(
        uz: '«Sunglasses» (quyosh ko‘zoynagi) quyoshli kunda taqiladi, yomg‘irda emas.',
        ru: '«Sunglasses» (солнечные очки) носят в солнечную погоду, а не под дождём.',
      ),
      'umbrella': LocalizedFeedback(
        uz: 'To‘g‘ri! Yomg‘irli ob-havoda soyabon («umbrella») olinadi.',
        ru: 'Верно! В дождливую погоду берут зонт («umbrella»).',
      ),
      'spoon': LocalizedFeedback(
        uz: '«Spoon» — qoshiq, u oshxona anjomi.',
        ru: '«Spoon» — это ложка, столовый прибор.',
      ),
    },
  ),
  Question(
    id: 'q_eng_place_vocab_a2',
    courseId: 'course_eng_01',
    skillId: 'skill_eng_vocab',
    skillDomain: 'vocabulary',
    difficulty: QuestionDifficulty.medium,
    cefrLevel: 'A2',
    topic: 'Placement A2: Money verbs lend vs borrow',
    mode: QuestionMode.multipleChoice,
    isPlacement: true,
    text:
        'Complete the sentence with the most natural word: "Timur forgot his wallet at home, so he asked his friend to ____ him some money for lunch."',
    textRu:
        'Дополните предложение наиболее подходящим словом: «Timur forgot his wallet at home, so he asked his friend to ____ him some money for lunch.»',
    options: ['borrow', 'spend', 'earn', 'lend'],
    correctIndex: 3,
    explanation:
        '"Lend someone money" — birovga vaqtincha pul berib turmoq. "Borrow" esa birovdan olmoq ("borrow from someone") ma’nosida ishlatiladi.',
    explanationRu:
        '«Lend someone money» означает временно дать кому-то деньги взаймы. «Borrow» означает взять в долг у кого-то («borrow from someone»).',
    wrongFeedback:
        'Do‘sti Timurga vaqtincha pul berib turishini so‘raganiga va fe’ldan keyin «him» kelganiga qarang.',
    wrongFeedbackRu:
        'Обратите внимание, что друг должен временно дать деньги Тимуру, а после глагола стоит местоимение «him».',
    mistakeFeedbackByOption: {
      'borrow': LocalizedFeedback(
        uz: '«Borrow» — birovdan olish; «borrow him money» deyilmaydi, «borrow money from him» deyiladi.',
        ru: '«Borrow» — брать взаймы у кого-то; нельзя сказать «borrow him money» (нужно «borrow from»).',
      ),
      'spend': LocalizedFeedback(
        uz: '«Spend» — pul sarflamoq; do‘stidan o‘ziga berib turishni so‘rash ma’nosini bermaydi.',
        ru: '«Spend» — тратить деньги; не подходит по смыслу с «him».',
      ),
      'earn': LocalizedFeedback(
        uz: '«Earn» — mehnat qilib pul topmoq, qarz berish emas.',
        ru: '«Earn» — зарабатывать деньги, а не одалживать.',
      ),
      'lend': LocalizedFeedback(
        uz: 'To‘g‘ri! «Lend someone something» — kimgadir vaqtincha berib turmoq.',
        ru: 'Верно! «Lend someone something» — одолжить что-то кому-то.',
      ),
    },
  ),
  Question(
    id: 'q_eng_place_vocab_b1',
    courseId: 'course_eng_01',
    skillId: 'skill_eng_vocab',
    skillDomain: 'vocabulary',
    difficulty: QuestionDifficulty.hard,
    cefrLevel: 'B1',
    topic: 'Placement B1: Workplace and commuting collocations',
    mode: QuestionMode.multipleChoice,
    isPlacement: true,
    text:
        'Choose the word that best fits the context: "To ____ traffic jams during the morning rush, many office workers take the metro instead of driving."',
    textRu:
        'Выберите слово, наиболее подходящее по смыслу: «To ____ traffic jams during the morning rush, many office workers take the metro instead of driving.»',
    options: ['create', 'avoid', 'attend', 'expect'],
    correctIndex: 1,
    explanation:
        '"Avoid traffic jams" — tirbandliklarga tushib qolmaslik / ularni chetlab o‘tish uchun metroga tushish mantiqan to‘g‘ri.',
    explanationRu:
        '«Avoid traffic jams» (избегать пробок) точно объясняет выбор метро вместо машины в утренний час пик.',
    wrongFeedback:
        'Odamlar mashina o‘rniga metroga tushish orqali tirbandlik bilan nima qilishni xohlashini o‘ylang.',
    wrongFeedbackRu:
        'Подумайте, зачем люди выбирают метро вместо автомобиля в утренний час пик.',
    mistakeFeedbackByOption: {
      'create': LocalizedFeedback(
        uz: '«Create» — yaratmoq; xodimlar tirbandlik yaratish uchun metroga tushmaydi.',
        ru: '«Create» — создавать; работники не едут на метро, чтобы создавать пробки.',
      ),
      'avoid': LocalizedFeedback(
        uz: 'To‘g‘ri! «Avoid» — chetlab o‘tmoq, oldini olmoq.',
        ru: 'Верно! «Avoid» — избегать, объезжать.',
      ),
      'attend': LocalizedFeedback(
        uz: '«Attend» — tadbir yoki darsga qatnashmoq, tirbandlik bilan ishlatilmaydi.',
        ru: '«Attend» — посещать (мероприятие/урок), с «traffic jams» не сочетается.',
      ),
      'expect': LocalizedFeedback(
        uz: '«Expect» — kutmoq; «tirbandlik kutish uchun metroga tushadi» mazmunga zid.',
        ru: '«Expect» — ожидать; не объясняет отказ от машины.',
      ),
    },
  ),
  Question(
    id: 'q_eng_place_grammar_a1',
    courseId: 'course_eng_01',
    skillId: 'skill_eng_grammar',
    skillDomain: 'grammar',
    difficulty: QuestionDifficulty.easy,
    cefrLevel: 'A1',
    topic: 'Placement A1: There is vs There are agreement',
    mode: QuestionMode.multipleChoice,
    isPlacement: true,
    text:
        'Choose the correct option to complete the sentence: "There ____ three books on the teacher’s desk."',
    textRu:
        'Выберите правильный вариант для дополнения предложения: «There ____ three books on the teacher’s desk.»',
    options: ['are', 'is', 'am', 'be'],
    correctIndex: 0,
    explanation:
        '"Three books" ko‘plik ot bo‘lgani uchun "There are" ishlatiladi.',
    explanationRu:
        'Так как «three books» — множественное число, используется форма «There are».',
    wrongFeedback:
        '"Three books" birlikmi yoki ko‘plikmi? Otning soniga qarab fe’l tanlang.',
    wrongFeedbackRu:
        'Определите число существительного «three books» и выберите согласованную форму глагола «to be».',
    mistakeFeedbackByOption: {
      'are': LocalizedFeedback(
        uz: 'To‘g‘ri! Ko‘plik otlar («three books») bilan «There are» ishlatiladi.',
        ru: 'Верно! С множественным числом («three books») используется «There are».',
      ),
      'is': LocalizedFeedback(
        uz: '«There is» faqat birlik (masalan, «one book») bilan ishlatiladi.',
        ru: '«There is» используется только с единственным числом (например, «one book»).',
      ),
      'am': LocalizedFeedback(
        uz: '«Am» faqat «I» olmoshi bilan keladi, «There» bilan ishlatilmaydi.',
        ru: '«Am» употребляется только с местоимением «I», но не с «There».',
      ),
      'be': LocalizedFeedback(
        uz: '«Be» — asosiy shakl; bu o‘rinda «There» dan keyin tuslangan «are» kerak.',
        ru: '«Be» — начальная форма; после «There» нужна личная форма «are».',
      ),
    },
  ),
  Question(
    id: 'q_eng_place_grammar_a2',
    courseId: 'course_eng_01',
    skillId: 'skill_eng_grammar',
    skillDomain: 'grammar',
    difficulty: QuestionDifficulty.medium,
    cefrLevel: 'A2',
    topic: 'Placement A2: Past Simple irregular verb with past time marker',
    mode: QuestionMode.multipleChoice,
    isPlacement: true,
    text:
        'Choose the correct verb form: "Yesterday evening, Madina ____ fresh fruit at the market on her way home."',
    textRu:
        'Выберите правильную форму глагола: «Yesterday evening, Madina ____ fresh fruit at the market on her way home.»',
    options: ['buys', 'bought', 'buy', 'is buying'],
    correctIndex: 1,
    explanation:
        '"Yesterday evening" (kecha kechqurun) tugallangan o‘tgan vaqt bo‘lgani uchun "buy" fe’lining Past Simple shakli — "bought" ishlatiladi.',
    explanationRu:
        'Указатель «Yesterday evening» (вчера вечером) обозначает завершённое действие в прошлом, поэтому нужна форма Past Simple от «buy» — «bought».',
    wrongFeedback:
        'Gap boshidagi «Yesterday evening» vaqt ko‘rsatkichiga qarang — harakat o‘tgan zamonda sodir bo‘lgan.',
    wrongFeedbackRu:
        'Обратите внимание на маркер времени «Yesterday evening» — действие произошло в прошлом.',
    mistakeFeedbackByOption: {
      'buys': LocalizedFeedback(
        uz: '«Buys» — hozirgi zamon (Present Simple), «yesterday evening» bilan mos kelmaydi.',
        ru: '«Buys» — настоящее время (Present Simple), оно не сочетается с «yesterday evening».',
      ),
      'bought': LocalizedFeedback(
        uz: 'To‘g‘ri! «Buy» fe’lining o‘tgan zamon (Past Simple) shakli — «bought».',
        ru: 'Верно! Форма Past Simple от глагола «buy» — «bought».',
      ),
      'buy': LocalizedFeedback(
        uz: '«Buy» — asosiy shakl; o‘tgan zamondagi tasdiq gapda noto‘g‘ri fe’lning 2-shakli kerak.',
        ru: '«Buy» — начальная форма; в утверждении в Past Simple нужна вторая форма неправильного глагола.',
      ),
      'is buying': LocalizedFeedback(
        uz: '«Is buying» hozir davom etayotgan harakatni bildiradi, kechagi voqeani emas.',
        ru: '«Is buying» описывает действие прямо сейчас, а не вчера вечером.',
      ),
    },
  ),
  Question(
    id: 'q_eng_place_grammar_b1',
    courseId: 'course_eng_01',
    skillId: 'skill_eng_grammar',
    skillDomain: 'grammar',
    difficulty: QuestionDifficulty.hard,
    cefrLevel: 'B1',
    topic: 'Placement B1: Present Perfect since vs for',
    mode: QuestionMode.multipleChoice,
    isPlacement: true,
    text:
        'Choose the grammatically correct option: "Dilshod has lived in Samarkand ____ 2019, so he knows the old city very well."',
    textRu:
        'Выберите грамматически правильный вариант: «Dilshod has lived in Samarkand ____ 2019, so he knows the old city very well.»',
    options: ['for', 'during', 'from', 'since'],
    correctIndex: 3,
    explanation:
        'Present Perfect ("has lived") bilan aniq boshlanish nuqtasi ("2019") berilganda "since" qo‘llanadi.',
    explanationRu:
        'В Present Perfect («has lived») с точной точкой начала («2019») используется предлог «since».',
    wrongFeedback:
        '"Has lived" (Present Perfect) va "2019" (boshlanish yili) birga kelganda qaysi predlog ishlatilishini eslang.',
    wrongFeedbackRu:
        'Вспомните, какой предлог соединяет Present Perfect («has lived») с точкой отсчёта в прошлом («2019»).',
    mistakeFeedbackByOption: {
      'for': LocalizedFeedback(
        uz: '«For» davomiylik miqdori bilan keladi (masalan, «for five years»), aniq yil bilan emas.',
        ru: '«For» употребляется с длительностью периода (например, «for five years»), а не с конкретным годом.',
      ),
      'during': LocalizedFeedback(
        uz: '«During» ot bilan keladi (masalan, «during the summer») va Present Perfect boshlanish nuqtasini bildirmaydi.',
        ru: '«During» ставится перед существительными («during the summer») и не обозначает точку начала в Present Perfect.',
      ),
      'from': LocalizedFeedback(
        uz: '«From» odatda «from ... to ...» juftligida ishlatiladi; Present Perfect bilan aniq boshlanish nuqtasi uchun mos kelmaydi.',
        ru: '«From» обычно используется в паре «from ... to ...», а не для точки начала в Present Perfect.',
      ),
      'since': LocalizedFeedback(
        uz: 'To‘g‘ri! «Since 2019» — 2019-yildan beri (boshlanish nuqtasidan hozirgacha).',
        ru: 'Верно! «Since 2019» — с 2019 года (от точки начала до настоящего времени).',
      ),
    },
  ),
  Question(
    id: 'q_eng_place_listening_a1',
    courseId: 'course_eng_01',
    skillId: 'skill_eng_listening',
    skillDomain: 'listening',
    difficulty: QuestionDifficulty.easy,
    cefrLevel: 'A1',
    topic: 'Placement A1: Listening for morning club time',
    mode: QuestionMode.multipleChoice,
    isPlacement: true,
    text: 'Listen to the conversation. What time does the music club start?',
    textRu: 'Прослушайте диалог. Во сколько начинается музыкальный кружок?',
    options: [
      '09:00 in the morning',
      '09:00 in the evening',
      '10:00 in the morning',
      '07:00 in the morning',
    ],
    correctIndex: 0,
    media: LessonMedia(
      id: 'media_eng_place_listening_a1',
      kind: LessonMediaKind.audio,
      language: LessonMediaLanguage.en,
      source: '/lesson-media/english/placement/q_eng_place_listening_a1.wav',
      title: 'Maktab musiqa to‘garagi vaqti',
      titleUz: 'Maktab musiqa to‘garagi vaqti',
      titleRu: 'Время школьного музыкального кружка',
      transcript:
          "Lola: Hi, Timur! When is our school music club?\nTimur: It starts at nine o'clock in the morning on Saturday.",
      durationSeconds: 6.919,
      reviewStatus: LessonMediaReviewStatus.approved,
      provenance: 'local-system-speech',
    ),
    explanation:
        'Timur audioda to‘garak shanba kuni "nine o\'clock in the morning" (ertalab 09:00) da boshlanishini aytdi.',
    explanationRu:
        'В аудио Тимур ясно говорит, что кружок начинается в субботу в «nine o\'clock in the morning» (09:00 утра).',
    wrongFeedback:
        'Audiodagi soat raqamiga va kunning qaysi qismi ekaniga diqqat bilan quloq soling.',
    wrongFeedbackRu:
        'Внимательно послушайте названный час и время суток в ответе Тимура.',
    mistakeFeedbackByOption: {
      '09:00 in the morning': LocalizedFeedback(
        uz: 'To‘g‘ri! Suhbatda «nine o\'clock in the morning» (ertalab soat 9) deyildi.',
        ru: 'Верно! В диалоге прозвучало «nine o\'clock in the morning» (9 часов утра).',
      ),
      '09:00 in the evening': LocalizedFeedback(
        uz: 'Soat 9 to‘g‘ri, ammo audioda «in the evening» emas, «in the morning» deyilgan.',
        ru: 'Час указан верно, но в аудио сказано «in the morning», а не «in the evening».',
      ),
      '10:00 in the morning': LocalizedFeedback(
        uz: 'Audioda 10 emas, «nine o\'clock» (soat 9) aytildi.',
        ru: 'В записи звучит «nine o\'clock» (9 часов), а не 10.',
      ),
      '07:00 in the morning': LocalizedFeedback(
        uz: 'Audioda soat 7 tilga olinmagan; «nine o\'clock» eshitildi.',
        ru: '7 часов в аудио не упоминаются; там сказано «nine o\'clock».',
      ),
    },
  ),
  Question(
    id: 'q_eng_place_listening_a2',
    courseId: 'course_eng_01',
    skillId: 'skill_eng_listening',
    skillDomain: 'listening',
    difficulty: QuestionDifficulty.medium,
    cefrLevel: 'A2',
    topic: 'Placement A2: Listening to a rescheduled class day and afternoon time',
    mode: QuestionMode.multipleChoice,
    isPlacement: true,
    text:
        'Listen to the phone call. When is the beginner swimming class this week?',
    textRu:
        'Прослушайте телефонный разговор. Когда пройдёт занятие по плаванию для начинающих на этой неделе?',
    options: [
      'Wednesday at 16:00',
      'Thursday at 16:00',
      'Thursday at 04:00 in the morning',
      'Friday at 16:00',
    ],
    correctIndex: 1,
    media: LessonMedia(
      id: 'media_eng_place_listening_a2',
      kind: LessonMediaKind.audio,
      language: LessonMediaLanguage.en,
      source: '/lesson-media/english/placement/q_eng_place_listening_a2.wav',
      title: 'Suzish mashg‘uloti jadvali o‘zgarishi',
      titleUz: 'Suzish mashg‘uloti jadvali o‘zgarishi',
      titleRu: 'Изменение расписания занятий по плаванию',
      transcript:
          "Receptionist: Hello, City Sports Center. How can I help you?\nCaller: Hi! Is the beginner swimming class still on Wednesday afternoon?\nReceptionist: No, we moved it this week. It is now on Thursday at four o'clock in the afternoon, not Wednesday.",
      durationSeconds: 16.048,
      reviewStatus: LessonMediaReviewStatus.approved,
      provenance: 'local-system-speech',
    ),
    explanation:
        'Qabulxona xodimi dars chorshanbadan "Thursday at four o\'clock in the afternoon" (payshanba 16:00) ga ko‘chirilganini aytdi.',
    explanationRu:
        'Администратор уточняет, что занятие перенесли со среды на «Thursday at four o\'clock in the afternoon» (четверг в 16:00).',
    wrongFeedback:
        'Eski kun («Wednesday») bilan yangi ko‘chirilgan kun va «in the afternoon» belgisini solishtiring.',
    wrongFeedbackRu:
        'Сравните прежний день («Wednesday») с новым днём и уточнением «in the afternoon».',
    mistakeFeedbackByOption: {
      'Wednesday at 16:00': LocalizedFeedback(
        uz: 'Chorshanba — eski jadval; xodim «No, we moved it... not Wednesday» dedi.',
        ru: 'Среда — это старое расписание; сотрудник сказал «No, we moved it... not Wednesday».',
      ),
      'Thursday at 16:00': LocalizedFeedback(
        uz: 'To‘g‘ri! Payshanba kuni kunduzgi soat 4 («four o\'clock in the afternoon» = 16:00).',
        ru: 'Верно! Четверг в 4 часа дня («four o\'clock in the afternoon» = 16:00).',
      ),
      'Thursday at 04:00 in the morning': LocalizedFeedback(
        uz: 'Audioda «in the afternoon» (kunduzi 16:00) deyildi, tungi 04:00 emas.',
        ru: 'В аудио сказано «in the afternoon» (16:00 дня), а не 04:00 утра.',
      ),
      'Friday at 16:00': LocalizedFeedback(
        uz: 'Juma kuni tilga olinmadi; dars payshanbaga ko‘chirildi.',
        ru: 'Пятница в диалоге не звучит; занятие перенесли на четверг.',
      ),
    },
  ),
  Question(
    id: 'q_eng_place_listening_b1',
    courseId: 'course_eng_01',
    skillId: 'skill_eng_listening',
    skillDomain: 'listening',
    difficulty: QuestionDifficulty.hard,
    cefrLevel: 'B1',
    topic:
        'Placement B1: Listening to workplace problem-solving and next action',
    mode: QuestionMode.multipleChoice,
    isPlacement: true,
    text:
        'Listen to the conversation. What will the speakers do for the morning session?',
    textRu:
        'Прослушайте разговор. Что собеседники сделают для утренней сессии?',
    options: [
      'Cancel the morning session and wait until two o’clock',
      'Pick up the printed booklets at ten o’clock in the morning',
      'Ask participants to print the booklets at home',
      'Send the PDF link in the group chat first and give out booklets after lunch',
    ],
    correctIndex: 3,
    media: LessonMedia(
      id: 'media_eng_place_listening_b1',
      kind: LessonMediaKind.audio,
      language: LessonMediaLanguage.en,
      source: '/lesson-media/english/placement/q_eng_place_listening_b1.wav',
      title: 'Seminar materiallari bo‘yicha qaror',
      titleUz: 'Seminar materiallari bo‘yicha qaror',
      titleRu: 'Решение по материалам семинара',
      transcript:
          "Malika: Bekzod, the print shop just called. The boxes of workshop booklets won't arrive until two o'clock in the afternoon, and our morning session starts at ten.\nBekzod: Thanks for telling me. Since the morning group needs the tasks right away, let's share the PDF link in the group chat first and hand out the printed booklets after lunch.",
      durationSeconds: 20.064,
      reviewStatus: LessonMediaReviewStatus.approved,
      provenance: 'local-system-speech',
    ),
    explanation:
        'Bekzod ertalabki guruhga PDF havolasini guruh chatida yuborishni, bosma bukletlarni esa tushlikdan keyin tarqatishni taklif qildi.',
    explanationRu:
        'Бекзод предлагает сначала отправить ссылку на PDF в групповой чат для утренней группы, а печатные буклеты раздать после обеда.',
    wrongFeedback:
        'Bekzod soat 10:00 dagi guruh uchun qanday tezkor yechim taklif qilganiga quloq soling.',
    wrongFeedbackRu:
        'Прислушайтесь к решению, которое предлагает Бекзод для утренней группы в 10:00.',
    mistakeFeedbackByOption: {
      'Cancel the morning session and wait until two o’clock': LocalizedFeedback(
        uz: 'Ular darsni bekor qilmadi; ertalabki guruh uchun raqamli PDF yechimini tanladi.',
        ru: 'Они не отменяли сессию, а выбрали цифровой PDF для утренней группы.',
      ),
      'Pick up the printed booklets at ten o’clock in the morning':
          LocalizedFeedback(
        uz: 'Soat 10:00 da seminar boshlanadi; bosma bukletlar esa soat 14:00 gacha yetib kelmaydi.',
        ru: 'В 10:00 начинается сессия, а печатные буклеты привезут только к 14:00.',
      ),
      'Ask participants to print the booklets at home': LocalizedFeedback(
        uz: 'Ishtirokchilarga uydan chop etish haqida hech narsa deyilmagan.',
        ru: 'Участников не просили распечатывать буклеты дома.',
      ),
      'Send the PDF link in the group chat first and give out booklets after lunch':
          LocalizedFeedback(
        uz: 'To‘g‘ri! Suhbatda PDF havolani chatda yuborish va bukletlarni tushlikdan keyin berishga kelishildi.',
        ru: 'Верно! Собеседники договорились отправить PDF в чат сначала, а буклеты раздать после обеда.',
      ),
    },
  ),
  Question(
    id: 'q_eng_place_reading_a1',
    courseId: 'course_eng_01',
    skillId: 'skill_eng_reading',
    skillDomain: 'reading',
    difficulty: QuestionDifficulty.easy,
    cefrLevel: 'A1',
    topic: 'Placement A1: Reading a public shop hours sign',
    mode: QuestionMode.multipleChoice,
    isPlacement: true,
    text:
        'Read the sign: "Green Park Bookshop. Open Monday to Saturday from 9:00 AM to 6:00 PM. Closed on Sunday." When can a customer visit the bookshop?',
    textRu:
        'Прочитайте вывеску: «Green Park Bookshop. Open Monday to Saturday from 9:00 AM to 6:00 PM. Closed on Sunday.» Когда покупатель может посетить книжный магазин?',
    options: [
      'On Sunday at 11:00 AM',
      'On Monday at 8:00 PM',
      'On Wednesday at 11:00 AM',
      'On Saturday at 7:00 AM',
    ],
    correctIndex: 2,
    explanation:
        'Do‘kon dushanbadan shanbagacha ("Monday to Saturday") soat 9:00 dan 18:00 gacha ochiq, shuning uchun chorshanba soat 11:00 da tashrif buyurish mumkin.',
    explanationRu:
        'Магазин открыт с понедельника по субботу («Monday to Saturday») с 9:00 до 18:00, поэтому в среду в 11:00 его можно посетить.',
    wrongFeedback:
        'E’londagi ish kunlari («Monday to Saturday») va soat oralig‘iga («9:00 AM to 6:00 PM») qarang.',
    wrongFeedbackRu:
        'Сверьте дни работы («Monday to Saturday») и часы («9:00 AM to 6:00 PM») на вывеске.',
    mistakeFeedbackByOption: {
      'On Sunday at 11:00 AM': LocalizedFeedback(
        uz: 'E’londa «Closed on Sunday» (yakshanba kuni yopiq) deb yozilgan.',
        ru: 'На вывеске написано «Closed on Sunday» (закрыто в воскресенье).',
      ),
      'On Monday at 8:00 PM': LocalizedFeedback(
        uz: 'Do‘kon 6:00 PM (18:00) da yopiladi, kechki 20:00 da yopiq bo‘ladi.',
        ru: 'Магазин закрывается в 6:00 PM (18:00), поэтому в 20:00 он уже закрыт.',
      ),
      'On Wednesday at 11:00 AM': LocalizedFeedback(
        uz: 'To‘g‘ri! Chorshanba ish kuni (dushanba–shanba oralig‘ida) va 11:00 AM ish vaqtiga kiradi.',
        ru: 'Верно! Среда входит в интервал понедельник–суббота, а 11:00 AM — рабочее время.',
      ),
      'On Saturday at 7:00 AM': LocalizedFeedback(
        uz: 'Do‘kon ertalab soat 9:00 da ochiladi, 7:00 AM da hali yopiq.',
        ru: 'Магазин открывается в 9:00 утра, в 7:00 AM он ещё закрыт.',
      ),
    },
  ),
  Question(
    id: 'q_eng_place_reading_a2',
    courseId: 'course_eng_01',
    skillId: 'skill_eng_reading',
    skillDomain: 'reading',
    difficulty: QuestionDifficulty.medium,
    cefrLevel: 'A2',
    topic: 'Placement A2: Reading a short message about changed plans',
    mode: QuestionMode.multipleChoice,
    isPlacement: true,
    text:
        'Read the message from Anvar: "Hi Jasur, the weather forecast says heavy rain tomorrow, so we are going to play chess at my house instead of football in the park. See you at 3:00 PM!" Why did Anvar change the plan?',
    textRu:
        'Прочитайте сообщение от Анвара: «Hi Jasur, the weather forecast says heavy rain tomorrow, so we are going to play chess at my house instead of football in the park. See you at 3:00 PM!» Почему Анвар изменил план?',
    options: [
      'The park is closed at 3:00 PM',
      'Jasur does not like football',
      'Bad weather is expected tomorrow',
      'Anvar lost his chess set',
    ],
    correctIndex: 2,
    explanation:
        'Xabarda "the weather forecast says heavy rain tomorrow, so..." deb ertaga kuchli yomg‘ir (yomon ob-havo) kutilayotgani sabab qilib ko‘rsatilgan.',
    explanationRu:
        'В сообщении указана причина: «the weather forecast says heavy rain tomorrow, so...» (завтра ожидается сильный дождь).',
    wrongFeedback:
        'Xabardagi «so» bog‘lovchisidan oldingi sabab qismiga e’tibor bering.',
    wrongFeedbackRu:
        'Обратите внимание на причину перед союзом «so» в тексте сообщения.',
    mistakeFeedbackByOption: {
      'The park is closed at 3:00 PM': LocalizedFeedback(
        uz: 'Matnda bog‘ yopiq ekani aytilmagan.',
        ru: 'В тексте не говорится, что парк закрыт.',
      ),
      'Jasur does not like football': LocalizedFeedback(
        uz: 'Jasur futbolni yoqtirmasligi haqida gap yo‘q; sabab ob-havo.',
        ru: 'В сообщении нет речи о том, что Жасур не любит футбол; причина — погода.',
      ),
      'Bad weather is expected tomorrow': LocalizedFeedback(
        uz: 'To‘g‘ri! Kuchli yomg‘ir (yomon ob-havo) kutilayotgani uchun ular uy ichida shaxmat o‘ynashga qaror qilishdi.',
        ru: 'Верно! Из-за прогноза сильного дождя они решили сыграть в шахматы дома.',
      ),
      'Anvar lost his chess set': LocalizedFeedback(
        uz: 'Aksincha, ular Anvarning uyida shaxmat o‘ynashmoqchi.',
        ru: 'Наоборот, они собираются играть в шахматы у Анвара дома.',
      ),
    },
  ),
  Question(
    id: 'q_eng_place_reading_b1',
    courseId: 'course_eng_01',
    skillId: 'skill_eng_reading',
    skillDomain: 'reading',
    difficulty: QuestionDifficulty.hard,
    cefrLevel: 'B1',
    topic: 'Placement B1: Reading a city bike pass policy notice',
    mode: QuestionMode.multipleChoice,
    isPlacement: true,
    text:
        'Read the notice: "City Bike Pass members can ride for up to 45 minutes per trip at no extra cost. However, if a ride lasts longer than 45 minutes and the rider does not report a dock problem, an hourly fee is charged." How can a member avoid paying the extra fee?',
    textRu:
        'Прочитайте объявление: «City Bike Pass members can ride for up to 45 minutes per trip at no extra cost. However, if a ride lasts longer than 45 minutes and the rider does not report a dock problem, an hourly fee is charged.» Как участник может избежать дополнительной платы?',
    options: [
      'Return the bike within 45 minutes',
      'Use the bike only once a week',
      'Pay an hourly fee before every trip',
      'Keep the bike overnight without reporting',
    ],
    correctIndex: 0,
    explanation:
        'Qoidaga ko‘ra, bir safar 45 daqiqagacha ("up to 45 minutes") qo‘shimcha to‘lovsiz hisoblanadi.',
    explanationRu:
        'По правилам поездка длительностью до 45 минут («up to 45 minutes») не требует дополнительной оплаты.',
    wrongFeedback:
        'Matnning birinchi gapidagi safar vaqti chegarasiga e’tibor bering.',
    wrongFeedbackRu:
        'Обратите внимание на ограничение времени одной поездки в первом предложении объявления.',
    mistakeFeedbackByOption: {
      'Return the bike within 45 minutes': LocalizedFeedback(
        uz: 'To‘g‘ri! Safarni 45 daqiqa ichida yakunlash qo‘shimcha to‘lovdan saqlaydi.',
        ru: 'Верно! Возврат велосипеда в пределах 45 минут освобождает от доплаты.',
      ),
      'Use the bike only once a week': LocalizedFeedback(
        uz: 'Haftalik cheklov haqida yozilmagan; cheklov har bir safar davomiyligiga («per trip») tegishli.',
        ru: 'Ограничение относится к длительности каждой поездки («per trip»), а не к числу поездок в неделю.',
      ),
      'Pay an hourly fee before every trip': LocalizedFeedback(
        uz: '45 daqiqagacha safar qo‘shimcha to‘lovsiz («at no extra cost»).',
        ru: 'Поездки до 45 минут бесплатны сверх абонемента («at no extra cost»).',
      ),
      'Keep the bike overnight without reporting': LocalizedFeedback(
        uz: '45 daqiqadan uzoq va xabar bermasdan saqlash aynan qo‘shimcha haqqa sabab bo‘ladi.',
        ru: 'Удержание велосипеда дольше 45 минут без сообщения о поломке как раз ведёт к доплате.',
      ),
    },
  ),
];
