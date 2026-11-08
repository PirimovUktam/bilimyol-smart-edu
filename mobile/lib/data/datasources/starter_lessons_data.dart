import '../../domain/entities/lesson.dart';
import '../../domain/entities/question.dart';

const starterLessons = <String, Lesson>{
  'lesson_math_starter': Lesson(
    id: 'lesson_math_starter',
    courseId: 'course_math_01',
    skillId: 'skill_math_algebra',
    title: 'Qo‘shish va ayirishdan boshlaymiz',
    estimatedMinutes: 5,
    summary:
        'Qo‘shish ikki guruhni birlashtiradi. Ayirish guruhdan bir qismini olib tashlaydi.',
    steps: [
      LessonStep(
        id: 'lesson_math_starter_read',
        stepNumber: 1,
        type: LessonStepType.concept,
        title: 'Asosiy tushuncha',
        content:
            'Qo‘shish ikki guruhni birlashtiradi. Ayirish guruhdan bir qismini olib tashlaydi.',
      ),
      LessonStep(
        id: 'lesson_math_starter_example',
        stepNumber: 2,
        type: LessonStepType.visualExample,
        title: 'Birga misol ko‘ramiz',
        content:
            'Sizda 3 ta olma bor. Yana 2 ta olma olsangiz, jami 5 ta bo‘ladi. Yozilishi 3 + 2 = 5. Jami 5 tadan 2 tasini bersangiz, 5 − 2 = 3 ta qoladi.',
      ),
      LessonStep(
        id: 'lesson_math_starter_try',
        stepNumber: 3,
        type: LessonStepType.interactiveQuestion,
        title: 'O‘rganganingizni sinab ko‘ring',
        content: 'Misoldan foydalanib bitta javobni tanlang.',
        interactiveQuestion: Question(
          id: 'q_lesson_math_starter_quiz',
          courseId: 'course_math_01',
          skillId: 'skill_math_algebra',
          text: '4 ta qalamga yana 2 ta qalam qo‘shilsa, jami nechta bo‘ladi?',
          options: ['2', '4', '6', '8'],
          correctIndex: 2,
          difficulty: QuestionDifficulty.easy,
          explanation: '4 ta va 2 ta qalamni birlashtiramiz. 4 + 2 = 6.',
        ),
      ),
    ],
    reinforcementExercise: Question(
      id: 'q_lesson_math_starter_practice',
      courseId: 'course_math_01',
      skillId: 'skill_math_algebra',
      text: '6 ta daftardan 2 tasi olinsa, nechta qoladi?',
      options: ['4', '2', '6', '8'],
      correctIndex: 0,
      difficulty: QuestionDifficulty.easy,
      explanation: '6 − 2 = 4.',
    ),
  ),
  'lesson_eng_starter': Lesson(
    id: 'lesson_eng_starter',
    courseId: 'course_eng_01',
    skillId: 'skill_eng_vocab',
    title: 'Birinchi inglizcha so‘zlar',
    estimatedMinutes: 5,
    summary:
        'Ingliz tilida «Hello» — salom, «Thank you» — rahmat, «Goodbye» — xayr. O‘zingizni tanishtirish uchun «I am» dan keyin ismingizni ayting.',
    steps: [
      LessonStep(
        id: 'lesson_eng_starter_read',
        stepNumber: 1,
        type: LessonStepType.concept,
        title: 'Asosiy tushuncha',
        content:
            'Ingliz tilida «Hello» — salom, «Thank you» — rahmat, «Goodbye» — xayr. O‘zingizni tanishtirish uchun «I am» dan keyin ismingizni ayting.',
      ),
      LessonStep(
        id: 'lesson_eng_starter_example',
        stepNumber: 2,
        type: LessonStepType.audioSimulation,
        title: 'Birga misol ko‘ramiz',
        content:
            'Ikki kishining ilk suhbati.\n\nAziza — Hello! I am Aziza. (Salom! Men Azizaman.)\n\nSardor — Hello! I am Sardor. (Salom! Men Sardorman.)\n\nXayrlashayotganda «Goodbye!» deymiz.',
        visualModelData: LessonVisualModelData(
          type: 'audio_wave',
          audioTranscript: 'Hello! I am Aziza. Hello! I am Sardor. Goodbye!',
          speakerName: 'Inglizcha salomlashish',
        ),
      ),
      LessonStep(
        id: 'lesson_eng_starter_try',
        stepNumber: 3,
        type: LessonStepType.interactiveQuestion,
        title: 'O‘rganganingizni sinab ko‘ring',
        content: 'Misoldan foydalanib bitta javobni tanlang.',
        interactiveQuestion: Question(
          id: 'q_lesson_eng_starter_quiz',
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          text: 'Ingliz tilida salomlashish uchun qaysi so‘zni aytamiz?',
          options: ['Goodbye', 'Hello', 'Thank you'],
          correctIndex: 1,
          difficulty: QuestionDifficulty.easy,
          explanation: 'Hello — salom. Uni suhbatni boshlaganda aytamiz.',
        ),
      ),
    ],
    reinforcementExercise: Question(
      id: 'q_lesson_eng_starter_practice',
      courseId: 'course_eng_01',
      skillId: 'skill_eng_vocab',
      text: '«Thank you» o‘zbekchada nima degani?',
      options: ['Salom', 'Xayr', 'Rahmat'],
      correctIndex: 2,
      difficulty: QuestionDifficulty.easy,
      explanation: 'Thank you — rahmat.',
    ),
  ),
  'lesson_it_starter': Lesson(
    id: 'lesson_it_starter',
    courseId: 'course_it',
    skillId: 'skill_it_python',
    title: 'Kompyuterga birinchi buyruq',
    estimatedMinutes: 5,
    summary:
        'Dastur kompyuter bajaradigan buyruqlardan iborat. Python tilida print buyrug‘i matnni ekranga chiqaradi.',
    steps: [
      LessonStep(
        id: 'lesson_it_starter_read',
        stepNumber: 1,
        type: LessonStepType.concept,
        title: 'Asosiy tushuncha',
        content:
            'Dastur kompyuter bajaradigan buyruqlardan iborat. Python tilida print buyrug‘i matnni ekranga chiqaradi.',
      ),
      LessonStep(
        id: 'lesson_it_starter_example',
        stepNumber: 2,
        type: LessonStepType.visualExample,
        title: 'Birga misol ko‘ramiz',
        content:
            'print("Salom!") buyrug‘i ekranda Salom! yozuvini ko‘rsatadi. Qo‘shtirnoq qayerda matn boshlanib, qayerda tugashini bildiradi.',
      ),
      LessonStep(
        id: 'lesson_it_starter_try',
        stepNumber: 3,
        type: LessonStepType.interactiveQuestion,
        title: 'O‘rganganingizni sinab ko‘ring',
        content: 'Misoldan foydalanib bitta javobni tanlang.',
        interactiveQuestion: Question(
          id: 'q_lesson_it_starter_quiz',
          courseId: 'course_it',
          skillId: 'skill_it_python',
          text: 'print("Kitob") buyrug‘idan keyin ekranda nima ko‘rinadi?',
          options: ['print', 'Kitob', 'Matn chiqmaydi'],
          correctIndex: 1,
          difficulty: QuestionDifficulty.easy,
          explanation:
              'print qo‘shtirnoq ichidagi Kitob so‘zini ekranga chiqaradi.',
        ),
      ),
    ],
    reinforcementExercise: Question(
      id: 'q_lesson_it_starter_practice',
      courseId: 'course_it',
      skillId: 'skill_it_python',
      text: 'Matnni ekranga chiqaradigan buyruq qaysi?',
      options: ['print', 'Salom', 'Python'],
      correctIndex: 0,
      difficulty: QuestionDifficulty.easy,
      explanation: 'print — ekranga chiqarish buyrug‘i.',
    ),
  ),
  'lesson_logic_starter': Lesson(
    id: 'lesson_logic_starter',
    courseId: 'course_logic',
    skillId: 'skill_logic_puzzles',
    title: 'Rost va yolg‘on gaplar',
    estimatedMinutes: 5,
    summary:
        'Rost yoki yolg‘onligini tekshirish mumkin bo‘lgan gap mulohaza deyiladi. Savol esa javob so‘raydi.',
    steps: [
      LessonStep(
        id: 'lesson_logic_starter_read',
        stepNumber: 1,
        type: LessonStepType.concept,
        title: 'Asosiy tushuncha',
        content:
            'Rost yoki yolg‘onligini tekshirish mumkin bo‘lgan gap mulohaza deyiladi. Savol esa javob so‘raydi.',
      ),
      LessonStep(
        id: 'lesson_logic_starter_example',
        stepNumber: 2,
        type: LessonStepType.visualExample,
        title: 'Birga misol ko‘ramiz',
        content:
            '«2 + 3 = 5» rost mulohaza. «2 + 3 = 6» yolg‘on mulohaza. «Soat necha?» esa savol, uni rost yoki yolg‘on deb baholay olmaymiz.',
      ),
      LessonStep(
        id: 'lesson_logic_starter_try',
        stepNumber: 3,
        type: LessonStepType.interactiveQuestion,
        title: 'O‘rganganingizni sinab ko‘ring',
        content: 'Misoldan foydalanib bitta javobni tanlang.',
        interactiveQuestion: Question(
          id: 'q_lesson_logic_starter_quiz',
          courseId: 'course_logic',
          skillId: 'skill_logic_puzzles',
          text: 'Qaysi gap rost mulohaza?',
          options: ['4 + 1 = 7', 'Soat necha?', '4 + 1 = 5'],
          correctIndex: 2,
          difficulty: QuestionDifficulty.easy,
          explanation: '4 ga 1 qo‘shilganda 5 bo‘ladi.',
        ),
      ),
    ],
    reinforcementExercise: Question(
      id: 'q_lesson_logic_starter_practice',
      courseId: 'course_logic',
      skillId: 'skill_logic_puzzles',
      text: 'Qaysi gap savol?',
      options: [
        'Bir kunda 24 soat bor.',
        'Bugun qaysi kun?',
        '7 soni 5 dan katta.',
      ],
      correctIndex: 1,
      difficulty: QuestionDifficulty.easy,
      explanation: '«Bugun qaysi kun?» javob so‘raydi.',
    ),
  ),

  "lesson_math_foundation_02": Lesson(
    id: "lesson_math_foundation_02",
    courseId: "course_math_01",
    skillId: "skill_math_algebra",
    title: "Teng guruhlar va ko‘paytirish",
    estimatedMinutes: 5,
    summary:
        "Ko‘paytirish teng sonlarni takror qo‘shishdir. 3 × 2 uchta 2 sonini qo‘shishni bildiradi.",
    steps: [
      LessonStep(
        id: "lesson_math_foundation_02_read",
        stepNumber: 1,
        type: LessonStepType.concept,
        title: "Asosiy tushuncha",
        content:
            "Ko‘paytirish teng sonlarni takror qo‘shishdir. 3 × 2 uchta 2 sonini qo‘shishni bildiradi.",
      ),
      LessonStep(
        id: "lesson_math_foundation_02_example",
        stepNumber: 2,
        type: LessonStepType.visualExample,
        title: "Birga misol ko‘ramiz",
        content:
            "Har birida 2 ta qalam bo‘lgan 3 quti bor. 2 + 2 + 2 = 6, shuning uchun 3 × 2 = 6.",
      ),
      LessonStep(
        id: "lesson_math_foundation_02_try",
        stepNumber: 3,
        type: LessonStepType.interactiveQuestion,
        title: "O‘rganganingizni sinab ko‘ring",
        content: "Misolga tayangan holda javobni tanlang.",
        interactiveQuestion: Question(
          id: "q_lesson_math_foundation_02",
          courseId: "course_math_01",
          skillId: "skill_math_algebra",
          text: "Har birida 3 ta olma bo‘lgan 2 savatda jami nechta olma bor?",
          options: ["5", "6", "3"],
          correctIndex: 1,
          difficulty: QuestionDifficulty.easy,
          explanation: "3 + 3 = 6. Ikki guruhda uchtadan olma bor.",
        ),
      ),
    ],
    reinforcementExercise: Question(
      id: "q_lesson_math_foundation_02_practice",
      courseId: "course_math_01",
      skillId: "skill_math_algebra",
      text: "Har birida 3 ta olma bo‘lgan 2 savatda jami nechta olma bor?",
      options: ["5", "6", "3"],
      correctIndex: 1,
      difficulty: QuestionDifficulty.easy,
      explanation: "3 + 3 = 6. Ikki guruhda uchtadan olma bor.",
    ),
  ),

  "lesson_eng_foundation_02": Lesson(
    id: "lesson_eng_foundation_02",
    courseId: "course_eng_01",
    skillId: "skill_eng_grammar",
    title: "Men, siz va oddiy gaplar",
    estimatedMinutes: 5,
    summary:
        "I — men, you — siz, he — u (erkak), she — u (ayol). I bilan am, you bilan are, he va she bilan is ishlatiladi. Student — o‘quvchi.",
    steps: [
      LessonStep(
        id: "lesson_eng_foundation_02_read",
        stepNumber: 1,
        type: LessonStepType.concept,
        title: "Asosiy tushuncha",
        content:
            "I — men, you — siz, he — u (erkak), she — u (ayol). I bilan am, you bilan are, he va she bilan is ishlatiladi. Student — o‘quvchi.",
      ),
      LessonStep(
        id: "lesson_eng_foundation_02_example",
        stepNumber: 2,
        type: LessonStepType.visualExample,
        title: "Birga misol ko‘ramiz",
        content:
            "I am a student. — Men o‘quvchiman. You are a student. — Siz o‘quvchisiz. She is a student. — U o‘quvchi. A so‘zi bu yerda bitta o‘quvchi haqida gapirilayotganini bildiradi.",
      ),
      LessonStep(
        id: "lesson_eng_foundation_02_try",
        stepNumber: 3,
        type: LessonStepType.interactiveQuestion,
        title: "O‘rganganingizni sinab ko‘ring",
        content: "Misolga tayangan holda javobni tanlang.",
        interactiveQuestion: Question(
          id: "q_lesson_eng_foundation_02",
          courseId: "course_eng_01",
          skillId: "skill_eng_grammar",
          text: "«Men o‘quvchiman» gapini to‘ldiring. I ___ a student.",
          options: ["is", "am", "are"],
          correctIndex: 1,
          difficulty: QuestionDifficulty.easy,
          explanation:
              "I bilan am ishlatiladi. I am a student — Men o‘quvchiman.",
        ),
      ),
    ],
    reinforcementExercise: Question(
      id: "q_lesson_eng_foundation_02_practice",
      courseId: "course_eng_01",
      skillId: "skill_eng_grammar",
      text: "«Men o‘quvchiman» gapini to‘ldiring. I ___ a student.",
      options: ["is", "am", "are"],
      correctIndex: 1,
      difficulty: QuestionDifficulty.easy,
      explanation: "I bilan am ishlatiladi. I am a student — Men o‘quvchiman.",
    ),
  ),

  "lesson_it_foundation_02": Lesson(
    id: "lesson_it_foundation_02",
    courseId: "course_it",
    skillId: "skill_it_python",
    title: "Son va matnni farqlash",
    estimatedMinutes: 5,
    summary:
        "Python’da qo‘shtirnoq ichidagi yozuv matn hisoblanadi. Qo‘shtirnoqsiz sonlar bilan hisoblash mumkin.",
    steps: [
      LessonStep(
        id: "lesson_it_foundation_02_read",
        stepNumber: 1,
        type: LessonStepType.concept,
        title: "Asosiy tushuncha",
        content:
            "Python’da qo‘shtirnoq ichidagi yozuv matn hisoblanadi. Qo‘shtirnoqsiz sonlar bilan hisoblash mumkin.",
      ),
      LessonStep(
        id: "lesson_it_foundation_02_example",
        stepNumber: 2,
        type: LessonStepType.visualExample,
        title: "Birga misol ko‘ramiz",
        content:
            "print(2 + 3) ekranga 5 chiqaradi. print(\"2 + 3\") esa 2 + 3 yozuvini chiqaradi. Qo‘shtirnoq yozuvni o‘z holicha saqlaydi.",
      ),
      LessonStep(
        id: "lesson_it_foundation_02_try",
        stepNumber: 3,
        type: LessonStepType.interactiveQuestion,
        title: "O‘rganganingizni sinab ko‘ring",
        content: "Misolga tayangan holda javobni tanlang.",
        interactiveQuestion: Question(
          id: "q_lesson_it_foundation_02",
          courseId: "course_it",
          skillId: "skill_it_python",
          text: "print(3 + 4) qanday natija chiqaradi?",
          options: ["3 + 4", "34", "7"],
          correctIndex: 2,
          difficulty: QuestionDifficulty.easy,
          explanation: "Qo‘shtirnoqsiz sonlar qo‘shiladi. 3 + 4 = 7.",
        ),
      ),
    ],
    reinforcementExercise: Question(
      id: "q_lesson_it_foundation_02_practice",
      courseId: "course_it",
      skillId: "skill_it_python",
      text: "print(3 + 4) qanday natija chiqaradi?",
      options: ["3 + 4", "34", "7"],
      correctIndex: 2,
      difficulty: QuestionDifficulty.easy,
      explanation: "Qo‘shtirnoqsiz sonlar qo‘shiladi. 3 + 4 = 7.",
    ),
  ),

  "lesson_logic_foundation_02": Lesson(
    id: "lesson_logic_foundation_02",
    courseId: "course_logic",
    skillId: "skill_logic_puzzles",
    title: "Mulohazani inkor qilish",
    estimatedMinutes: 5,
    summary:
        "Inkor bir mulohazaning rostlik qiymatini teskarisiga o‘zgartiradi. Rost mulohazaning inkori yolg‘on bo‘ladi.",
    steps: [
      LessonStep(
        id: "lesson_logic_foundation_02_read",
        stepNumber: 1,
        type: LessonStepType.concept,
        title: "Asosiy tushuncha",
        content:
            "Inkor bir mulohazaning rostlik qiymatini teskarisiga o‘zgartiradi. Rost mulohazaning inkori yolg‘on bo‘ladi.",
      ),
      LessonStep(
        id: "lesson_logic_foundation_02_example",
        stepNumber: 2,
        type: LessonStepType.visualExample,
        title: "Birga misol ko‘ramiz",
        content:
            "«5 soni 3 dan katta» rost. Uning inkori «5 soni 3 dan katta emas» yolg‘on. Inkor odatda emas so‘zi bilan ifodalanadi.",
      ),
      LessonStep(
        id: "lesson_logic_foundation_02_try",
        stepNumber: 3,
        type: LessonStepType.interactiveQuestion,
        title: "O‘rganganingizni sinab ko‘ring",
        content: "Misolga tayangan holda javobni tanlang.",
        interactiveQuestion: Question(
          id: "q_lesson_logic_foundation_02",
          courseId: "course_logic",
          skillId: "skill_logic_puzzles",
          text: "«2 + 2 = 4» rost. Uning inkori qanday baholanadi?",
          options: ["Rost", "Yolg‘on", "Savol"],
          correctIndex: 1,
          difficulty: QuestionDifficulty.easy,
          explanation: "Rost mulohazaning inkori yolg‘on bo‘ladi.",
        ),
      ),
    ],
    reinforcementExercise: Question(
      id: "q_lesson_logic_foundation_02_practice",
      courseId: "course_logic",
      skillId: "skill_logic_puzzles",
      text: "«2 + 2 = 4» rost. Uning inkori qanday baholanadi?",
      options: ["Rost", "Yolg‘on", "Savol"],
      correctIndex: 1,
      difficulty: QuestionDifficulty.easy,
      explanation: "Rost mulohazaning inkori yolg‘on bo‘ladi.",
    ),
  ),
};
