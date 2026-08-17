import '../../domain/entities/lesson.dart';
import '../../domain/entities/question.dart';

final Map<String, Lesson> seedLessons = {
  'lesson_math_functions_01': Lesson(
    id: 'lesson_math_functions_01',
    courseId: 'course_math_01',
    skillId: 'skill_math_functions',
    title: 'Funksiya nima? Asosiy tushunchalar',
    estimatedMinutes: 8,
    summary: 'Funksiya ta’rifi, erkli va erksiz o‘zgaruvchilar, formulaning mohiyati.',
    steps: [
      const LessonStep(
        id: 'math_step_1',
        stepNumber: 1,
        type: LessonStepType.concept,
        title: '1. Funksiya tushunchasi',
        subtitle: 'Matematik qoida va moslik',
        content: 'Funksiya — bu bitta to‘plamdagi har bir elementga (argument x) ikkinchi to‘plamdagi yagona elementni (f(x)) mos qo‘yuvchi qoidadir.',
        highlightNotes: [
          'x — argument (kiruvchi qiymat)',
          'y yoki f(x) — funksiya qiymati (natija)',
          'Har bir argumentga yagona qiymat mos keladi.',
        ],
      ),
      const LessonStep(
        id: 'math_step_2',
        stepNumber: 2,
        type: LessonStepType.formula,
        title: '2. Chiziqli Funksiya Formulasi',
        subtitle: 'f(x) = kx + b ko‘rinishi',
        content: 'Chiziqli funksiyada x argument k ga ko‘paytiriladi va b ozod soni qo‘shiladi.',
        formulaData: LessonFormulaData(
          latex: 'f(x) = 2x + 3',
          description: 'Misol uchun f(x) = 2x + 3 funksiyasini ko‘rib chiqaylik.',
          variables: [
            {'symbol': 'x', 'meaning': 'Argument (kiruvchi son)'},
            {'symbol': '2', 'meaning': 'Burchak koeffitsiyenti (k)'},
            {'symbol': '+3', 'meaning': 'Ozod had (b)'},
          ],
        ),
      ),
      const LessonStep(
        id: 'math_step_3',
        stepNumber: 3,
        type: LessonStepType.interactiveQuestion,
        title: '3. Sinov Savoli',
        subtitle: 'Tushunchani tekshirish',
        content: 'f(x) = 2x + 3 funksiyasida x = 4 bo‘lsa, f(4) nechaga teng?',
        interactiveQuestion: Question(
          id: 'q_math_func_01_step',
          courseId: 'course_math_01',
          skillId: 'skill_math_functions',
          text: 'f(x) = 2x + 3 funksiyasida x = 4 bo‘lsa, f(4) qiymati qancha?',
          formulaLatex: 'f(4) = 2(4) + 3',
          options: ['8', '11', '14', '9'],
          correctIndex: 1, // '11'
          difficulty: QuestionDifficulty.easy,
          explanation: 'f(4) = 2(4) + 3 = 8 + 3 = 11.',
        ),
      ),
    ],
    reinforcementExercise: const Question(
      id: 'q_math_reinf_01',
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      text: 'Mustahkamlash: f(x) = 3x + 2 funksiya berilgan. Agar x = 2 bo‘lsa, f(x) nechaga teng?',
      formulaLatex: 'f(2) = 3(2) + 2',
      options: ['6', '8', '7', '5'],
      correctIndex: 1, // '8'
      difficulty: QuestionDifficulty.easy,
      explanation: 'f(2) = 3(2) + 2 = 6 + 2 = 8.',
    ),
  ),

  'lesson_math_functions_02': Lesson(
    id: 'lesson_math_functions_02',
    courseId: 'course_math_01',
    skillId: 'skill_math_functions',
    title: 'Funksiya qiymatini hisoblash',
    estimatedMinutes: 10,
    summary: 'Kvadratik funksiyalar va qavsli ifodalarda hisoblash tartibi.',
    steps: [
      const LessonStep(
        id: 'math_step_2_1',
        stepNumber: 1,
        type: LessonStepType.concept,
        title: '1. Kvadratik ifodada hisoblash',
        subtitle: 'Amallar tartibi',
        content: 'f(x) = x² - 4x + 1 kabi ifodalarda avval kvadratga ko‘tarish, so‘ng ko‘paytirish va oxirida qo‘shish/ayirish bajariladi.',
        highlightNotes: [
          'x = 3 bo‘lganda: x² = 9',
          '4x = 12',
          'Natija: 9 - 12 + 1 = -2',
        ],
      ),
      const LessonStep(
        id: 'math_step_2_2',
        stepNumber: 2,
        type: LessonStepType.interactiveQuestion,
        title: '2. Amaliy Mashq',
        subtitle: 'Kvadratik funksiya qiymati',
        content: 'f(x) = x² - 4x + 1 funksiya uchun f(3) qiymatini toping.',
        interactiveQuestion: Question(
          id: 'q_math_func_04_step',
          courseId: 'course_math_01',
          skillId: 'skill_math_functions',
          text: 'f(x) = x² - 4x + 1 funksiyada f(3) qiymatini hisoblang.',
          formulaLatex: 'f(3) = 3^2 - 4(3) + 1',
          options: ['-2', '4', '1', '-1'],
          correctIndex: 0, // '-2'
          difficulty: QuestionDifficulty.medium,
          explanation: 'f(3) = 9 - 12 + 1 = -2.',
        ),
      ),
    ],
    reinforcementExercise: const Question(
      id: 'q_math_reinf_02',
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      text: 'Mustahkamlash: f(x) = x² - 2x + 3 funksiyada f(4) ning qiymati qancha?',
      formulaLatex: 'f(4) = 4^2 - 2(4) + 3',
      options: ['11', '19', '8', '15'],
      correctIndex: 0, // '11'
      difficulty: QuestionDifficulty.medium,
      explanation: 'f(4) = 16 - 8 + 3 = 11.',
    ),
  ),

  'lesson_math_functions_03': Lesson(
    id: 'lesson_math_functions_03',
    courseId: 'course_math_01',
    skillId: 'skill_math_graphs',
    title: 'Funksiya grafigi va kesishish nuqtalari',
    estimatedMinutes: 12,
    summary: 'Ox va Oy koordinata o‘qlari bilan kesishish nuqtalarini aniqlash.',
    steps: [
      const LessonStep(
        id: 'math_step_3_1',
        stepNumber: 1,
        type: LessonStepType.concept,
        title: '1. O‘qlar bilan kesishish qoidasi',
        subtitle: 'Ox va Oy o‘qlari',
        content: 'Oy o‘qi bilan kesishganda x = 0 bo‘ladi. Ox o‘qi bilan kesishganda esa y = 0 bo‘ladi.',
        highlightNotes: [
          'y = 2x - 4 chizig‘i Oy o‘qini (0, -4) da kesadi.',
          'Ox o‘qini topish uchun 2x - 4 = 0 => x = 2, nuqta: (2, 0).',
        ],
      ),
      const LessonStep(
        id: 'math_step_3_2',
        stepNumber: 2,
        type: LessonStepType.interactiveQuestion,
        title: '2. Grafik Savoli',
        subtitle: 'Ox o‘qi bilan kesishish',
        content: 'y = -3x + 6 chizig‘i Ox o‘qini qaysi nuqtada kesib o‘tadi?',
        interactiveQuestion: Question(
          id: 'q_math_graph_02_step',
          courseId: 'course_math_01',
          skillId: 'skill_math_graphs',
          text: 'y = -3x + 6 chizig‘i Ox o‘qini qaysi nuqtada kesib o‘tadi?',
          formulaLatex: '0 = -3x + 6',
          options: ['(2, 0)', '(0, 6)', '(-2, 0)', '(6, 0)'],
          correctIndex: 0, // '(2, 0)'
          difficulty: QuestionDifficulty.easy,
          explanation: 'y = 0: -3x + 6 = 0 => 3x = 6 => x = 2.',
        ),
      ),
    ],
    reinforcementExercise: const Question(
      id: 'q_math_reinf_03',
      courseId: 'course_math_01',
      skillId: 'skill_math_graphs',
      text: 'Mustahkamlash: y = 4x - 8 chizig‘i Ox o‘qini qaysi nuqtada kesadi?',
      formulaLatex: '0 = 4x - 8',
      options: ['(2, 0)', '(0, -8)', '(4, 0)', '(-2, 0)'],
      correctIndex: 0, // '(2, 0)'
      difficulty: QuestionDifficulty.easy,
      explanation: '4x - 8 = 0 => 4x = 8 => x = 2.',
    ),
  ),
};
