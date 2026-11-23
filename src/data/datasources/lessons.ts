import logic from '../../../content/logic/published.json';
import { Lesson } from '@/domain/entities/Lesson';
import { permuteQuestionOptions } from '@/core/utils/questionOptionOrder';
import { STARTER_LESSONS } from './starterLessons';
import { ENGLISH_ALL_LESSONS } from './english';

// Raw authored lessons. The correct option is written first for readability,
// then deterministically permuted below. Both the learner UI and the
// in-memory scorer import the transformed SEED_LESSONS, so they always agree.
const SEED_LESSONS_RAW: Record<string, Lesson> = {
  lesson_math_algebra_01: {
    id: 'lesson_math_algebra_01',
    courseId: 'course_math_01',
    skillId: 'skill_math_algebra',
    title: 'Kvadratni oçiş',
    estimatedMinutes: 8,
    summary: '(a+b)² ni oçişda a² va b² orasidagi 2ab hadini yozing. Bu (a+b)(a+b) ni köpaytirişda hosil böladigan ikki bir xil ab hadining yiğindisi.',
    steps: [
      { id: 'lesson_math_algebra_01_concept', stepNumber: 1, type: 'concept', title: 'Qoida', content: '(a+b)² ni oçişda a² va b² orasidagi 2ab hadini yozing. Bu (a+b)(a+b) ni köpaytirişda hosil böladigan ikki bir xil ab hadining yiğindisi.' },
      { id: 'lesson_math_algebra_01_example', stepNumber: 2, type: 'visual_example', title: 'Işlangan misol', content: 'Masalan, (x+3)² = x² + 6x + 9. Manfiy işorali holatda (x−3)² = x² − 6x + 9.' },
      {
        id: 'lesson_math_algebra_01_test', stepNumber: 3, type: 'interactive_question', title: 'Bilimingizni tekşiring',
        content: 'Variantlardan birini tanlang.',
        interactiveQuestion: {
          "id": "q_demo_math_algebra_01_quiz",
          "courseId": "course_math_01",
          "skillId": "skill_math_algebra",
          "text": "(x + 2)² yoyilmasida x oldidagi koeffitsiyent neçaga teng?",
          "options": [
            "2",
            "4",
            "8",
            "1"
          ],
          "correctIndex": 1,
          "explanation": "Aralaş had 2 · x · 2 = 4x.",
          "difficulty": "medium"
        },
      },
    ],
    reinforcementExercise: {
      "id": "q_demo_math_algebra_01_practice",
      "courseId": "course_math_01",
      "skillId": "skill_math_algebra",
      "text": "(x − 5)² ni oçing.",
      "options": [
        "x² − 5x + 25",
        "x² + 10x + 25",
        "x² − 25",
        "x² − 10x + 25"
      ],
      "correctIndex": 3,
      "explanation": "Örtadagi had −2 · 5 · x = −10x, oxirgi had esa (−5)² = 25.",
      "difficulty": "medium"
    },
  },
  lesson_math_equations_01: {
    id: 'lesson_math_equations_01',
    courseId: 'course_math_01',
    skillId: 'skill_math_equations',
    title: 'Çiziqli tenglamani yeçiş',
    estimatedMinutes: 9,
    summary: 'Tenglikni saqlaş uçun ikkala tomonga bir xil amal qöllanadi. Avval noma’lumli hadni ajrating, keyin uning koeffitsiyentiga böling.',
    steps: [
      { id: 'lesson_math_equations_01_concept', stepNumber: 1, type: 'concept', title: 'Qoida', content: 'Tenglikni saqlaş uçun ikkala tomonga bir xil amal qöllanadi. Avval noma’lumli hadni ajrating, keyin uning koeffitsiyentiga böling.' },
      { id: 'lesson_math_equations_01_example', stepNumber: 2, type: 'visual_example', title: 'Işlangan misol', content: '2x + 3 = 11 bölsa, ikkala tomondan 3 ayirib 2x = 8 ni olamiz. Ikkala tomonni 2 ga bölsak, x = 4.' },
      {
        id: 'lesson_math_equations_01_test', stepNumber: 3, type: 'interactive_question', title: 'Bilimingizni tekşiring',
        content: 'Variantlardan birini tanlang.',
        interactiveQuestion: {
          "id": "q_demo_math_equations_01_quiz",
          "courseId": "course_math_01",
          "skillId": "skill_math_equations",
          "text": "5x − 4 = 16 tenglamasini yeçing.",
          "options": [
            "3",
            "5",
            "4",
            "−4"
          ],
          "correctIndex": 2,
          "explanation": "Ikkala tomonga 4 qöşsak, 5x = 20. Javob 4.",
          "difficulty": "medium"
        },
      },
    ],
    reinforcementExercise: {
      "id": "q_demo_math_equations_01_practice",
      "courseId": "course_math_01",
      "skillId": "skill_math_equations",
      "text": "3x + 8 = −4 tenglamasida x ni toping.",
      "options": [
        "4",
        "−12",
        "−4",
        "−2"
      ],
      "correctIndex": 2,
      "explanation": "8 ni ayirsak, 3x = −12. Demak, x = −4.",
      "difficulty": "medium"
    },
  },
  lesson_math_functions_01: {
    id: 'lesson_math_functions_01',
    courseId: 'course_math_01',
    skillId: 'skill_math_functions',
    title: 'Funksiya nima? Asosiy tuşunçalar',
    estimatedMinutes: 10,
    summary: 'Funksiya tuşunçasi, argument örniga son qöyiş va qiymatni töğri hisoblaş qoidalari.',
    steps: [
      {
        id: 'math_step_1',
        stepNumber: 1,
        type: 'concept',
        title: '1. Funksiya nima?',
        subtitle: 'Asosiy tuşunça va mantiq',
        content: 'Funksiya — bu bitta töplamdagi har bir elementga (argument $x$) ikkinçi töplamdagi yagona elementni (funksiya qiymati $f(x)$) mos qöyuvçi qoidadir.',
        highlightNotes: [
          'x — erkli özgaruvçi (argument, kiruvçi qiymat)',
          'f(x) — erksiz özgaruvçi (natija, çiquvçi qiymat)',
          'Har bir x ga faqat BITTA y mos kelişi şart.',
        ],
      },
      {
        id: 'math_step_2',
        stepNumber: 2,
        type: 'formula',
        title: '2. Çiziqli Funksiya Formulasi',
        subtitle: 'f(x) = ax + b körinişi',
        content: 'Çiziqli funksiyada har qanday $x$ berilganda, avval uni $a$ koeffitsiyentiga köpaytiramiz, söng $b$ ozod hadini qöşamiz.',
        formulaData: {
          latex: 'f(x) = 2x + 3',
          description: 'Misol uçun f(x) = 2x + 3 funksiyasini körib çiqaylik.',
          variables: [
            { symbol: 'x', meaning: 'Argument (kiruvçi son)' },
            { symbol: '2', meaning: 'Burçak koeffitsiyenti (köpaytuvçi)' },
            { symbol: '+3', meaning: 'Ozod son (qöşiluvçi)' },
          ],
        },
      },
      {
        id: 'math_step_3',
        stepNumber: 3,
        type: 'visual_example',
        title: '3. Vizual Nuqtalar va Moslik',
        subtitle: 'Grafikda qiymatlarning joylaşuvi',
        content: 'Agar $x = 1$ bölsa: $f(1) = 2(1) + 3 = 5$. Nuqta: (1, 5).\nAgar $x = 2$ bölsa: $f(2) = 2(2) + 3 = 7$. Nuqta: (2, 7).\nAgar $x = 0$ bölsa: $f(0) = 3$. Töğri çiziq hosil böladi.',
        visualModelData: {
          type: 'function_graph',
          functionExpr: 'f(x) = 2x + 3',
          points: [
            { x: 0, y: 3, label: '(0, 3)' },
            { x: 1, y: 5, label: '(1, 5)' },
            { x: 2, y: 7, label: '(2, 7)' },
            { x: 4, y: 11, label: '(4, 11)' },
          ],
        },
      },
      {
        id: 'math_step_4',
        stepNumber: 4,
        type: 'interactive_question',
        title: '4. Amaliy Maşq',
        subtitle: 'Bilimingizni sinab köring',
        content: 'f(x) = 2x + 3 funksiyasi berilgan. Agar x = 4 bölsa, f(x) ning qiymati neçaga teng?',
        interactiveQuestion: {
          id: 'q_math_func_01_lesson',
          courseId: 'course_math_01',
          skillId: 'skill_math_functions',
          text: 'f(x) = 2x + 3 funksiyasida x = 4 bölsa, f(4) ni toping:',
          formulaLatex: 'f(4) = 2 \\cdot 4 + 3 = ?',
          options: ['11', '8', '14', '9'],
          correctIndex: 0,
          difficulty: 'medium',
          explanation: 'x = 4 qöyilganda: f(4) = 2(4) + 3 = 8 + 3 = 11 böladi.',
        },
      },
    ],
    reinforcementExercise: {
      id: 'q_math_func_02_lesson',
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      text: 'Mustahkamlaş: f(x) = 3x + 2 funksiya berilgan. Agar x = 2 bölsa, f(x) neçaga teng böladi?',
      formulaLatex: 'f(2) = 3(2) + 2 = ?',
      options: ['8', '6', '7', '5'],
      correctIndex: 0,
      difficulty: 'easy',
      explanation: 'f(2) = 3 × 2 + 2 = 6 + 2 = 8.',
    },
  },

  lesson_math_functions_02: {
    id: 'lesson_math_functions_02',
    courseId: 'course_math_01',
    skillId: 'skill_math_functions',
    title: 'Funksiya qiymatini topiş va tenglama tuziş',
    estimatedMinutes: 12,
    summary: 'Berilgan funksiya qiymatidan argumentni topiş va teskari amallarni bajariş usullari.',
    steps: [
      {
        id: 'math2_step_1',
        stepNumber: 1,
        type: 'concept',
        title: '1. Teskari masalalar',
        subtitle: 'f(x) ma’lum bölganda x ni topiş',
        content: 'Ba’zida funksiyaning natijasi beriladi va argumentni topiş söraladi. Bu çiziqli tenglamaga aylanadi.',
        highlightNotes: [
          'Agar f(x) = y berilsa, ax + b = y tenglama yeçiladi.',
          'Noma’lum x ni yolğizlatiş uçun ozod son narigi tomonga qarama-qarşi işora bilan ötadi.',
        ],
      },
      {
        id: 'math2_step_2',
        stepNumber: 2,
        type: 'formula',
        title: '2. Misol tahlili',
        subtitle: 'f(x) = 3x - 5 = 13',
        content: 'Misol: f(x) = 3x - 5 funksiyasi berilgan. Qaysi x da f(x) = 13 böladi?',
        formulaData: {
          latex: '3x - 5 = 13 \\implies 3x = 18 \\implies x = 6',
          description: 'Demak, x = 6 bölganda funksiya qiymati 13 ga teng.',
          variables: [
            { symbol: '3x', meaning: 'Noma’lumli had' },
            { symbol: '18', meaning: '13 + 5 yiğindisi' },
            { symbol: 'x = 6', meaning: 'Javob: 18 / 3' },
          ],
        },
      },
      {
        id: 'math2_step_3',
        stepNumber: 3,
        type: 'interactive_question',
        title: '3. Amaliy Sinov',
        subtitle: 'Teskari qiymatni toping',
        content: 'f(x) = 5 - 2x funksiyasi berilgan. Agar f(x) = 1 bölsa, x neçaga teng?',
        interactiveQuestion: {
          id: 'q_math_func_04_lesson',
          courseId: 'course_math_01',
          skillId: 'skill_math_functions',
          text: '5 - 2x = 1 tenglamani yeçing:',
          formulaLatex: '5 - 2x = 1',
          options: ['x = 2', 'x = -2', 'x = 3', 'x = 1'],
          correctIndex: 0,
          difficulty: 'medium',
          explanation: '5 - 2x = 1 => -2x = -4 => x = 2.',
        },
      },
    ],
    reinforcementExercise: {
      id: 'q_math_func_03_lesson',
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      text: 'Mustahkamlaş: f(x) = 4x + 1 berilgan. f(x) = 13 bölsa, x ni toping.',
      formulaLatex: '4x + 1 = 13',
      options: ['x = 3', 'x = 4', 'x = 2', 'x = 5'],
      correctIndex: 0,
      difficulty: 'easy',
      explanation: '4x = 12 => x = 3.',
    },
  },

  lesson_math_functions_03: {
    id: 'lesson_math_functions_03',
    courseId: 'course_math_01',
    skillId: 'skill_math_graphs',
    title: 'Çiziqli funksiya grafigi va kesişiş nuqtalari',
    estimatedMinutes: 15,
    summary: 'Koordinatalar tekisligida töğri çiziq yasaş, burçak koeffitsiyenti va öqlar bilan kesişiş nuqtalarini aniqlaş.',
    steps: [
      {
        id: 'math3_step_1',
        stepNumber: 1,
        type: 'concept',
        title: '1. Grafik yasaş qoidasi',
        subtitle: 'Töğri çiziq uçun 2 ta nuqta yetarli',
        content: 'Çiziqli funksiya $y = kx + b$ ning grafigi doimo töğri çiziq böladi. Uni yasaş uçun 2 ta nuqta koordinatasini topiş kifoya.',
        highlightNotes: [
          'x = 0 qöyib, Oy öqi bilan kesişiş nuqtasi (0, b) topiladi.',
          'y = 0 qöyib, Ox öqi bilan kesişiş nuqtasi topiladi.',
          'k > 0 bölsa — funksiya ösuvçi, k < 0 bölsa — kamayuvçi.',
        ],
      },
      {
        id: 'math3_step_2',
        stepNumber: 2,
        type: 'visual_example',
        title: '2. Vizual Grafik',
        subtitle: 'y = 2x - 4 töğri çiziği',
        content: 'x = 0 bölsa, y = -4 (Oy öqidagi nuqta: (0, -4)).\ny = 0 bölsa, 2x = 4 => x = 2 (Ox öqidagi nuqta: (2, 0)).',
        visualModelData: {
          type: 'function_graph',
          functionExpr: 'y = 2x - 4',
          points: [
            { x: 0, y: -4, label: '(0, -4)' },
            { x: 2, y: 0, label: '(2, 0)' },
            { x: 3, y: 2, label: '(3, 2)' },
          ],
        },
      },
      {
        id: 'math3_step_3',
        stepNumber: 3,
        type: 'interactive_question',
        title: '3. Amaliy Maşq',
        subtitle: 'Nuqtani aniqlang',
        content: 'y = 3x - 6 töğri çiziği Ox öqini qaysi nuqtada kesib ötadi?',
        interactiveQuestion: {
          id: 'q_math_graph_02_lesson',
          courseId: 'course_math_01',
          skillId: 'skill_math_graphs',
          text: 'y = 3x - 6 funksiyaning Ox öqi bilan kesişiş nuqtasi:',
          formulaLatex: '3x - 6 = 0',
          options: ['(2, 0)', '(0, -6)', '(-2, 0)', '(6, 0)'],
          correctIndex: 0,
          difficulty: 'medium',
          explanation: 'Ox öqida y = 0 böladi: 3x - 6 = 0 => 3x = 6 => x = 2. Nuqta: (2, 0).',
        },
      },
    ],
    reinforcementExercise: {
      id: 'q_math_graph_01_lesson',
      courseId: 'course_math_01',
      skillId: 'skill_math_graphs',
      text: 'Mustahkamlaş: y = 2x - 4 funksiyasi Oy öqini qaysi nuqtada kesadi?',
      formulaLatex: 'x = 0 \\implies y = -4',
      options: ['(0, -4)', '(2, 0)', '(0, 4)', '(-4, 0)'],
      correctIndex: 0,
      difficulty: 'easy',
      explanation: 'x = 0 da y = 2(0) - 4 = -4. Nuqta: (0, -4).',
    },
  },

  ...ENGLISH_ALL_LESSONS,

  // =========================================================================
  // IT & CODING — darslar
  // =========================================================================
  lesson_it_python_01: {
    id: 'lesson_it_python_01',
    courseId: 'course_it',
    skillId: 'skill_it_python',
    title: 'Python’ga kiriş: özgaruvçilar va amallar',
    estimatedMinutes: 12,
    summary: 'Python’da özgaruvçi e’lon qiliş, asosiy ma’lumot turlari va arifmetik amallar.',
    steps: [
      {
        id: 'it_py_step_1',
        stepNumber: 1,
        type: 'concept',
        title: '1. Özgaruvçi nima?',
        subtitle: 'Ma’lumot saqlaş uçun nomlangan joy',
        content: 'Özgaruvçi — bu qiymatni saqlaydigan nom. Python’da turini oldindan yoziş şart emas — `x = 10` deb yozsangiz, Python özi tuşunadi.',
        highlightNotes: [
          'x = 10 — butun son (int)',
          'ism = "Ali" — matn (string / str)',
          'ball = 4.5 — önlik son (float)',
        ],
      },
      {
        id: 'it_py_step_2',
        stepNumber: 2,
        type: 'formula',
        title: '2. Asosiy amallar',
        subtitle: 'Arifmetik va matn amallari',
        content: 'Python’da arifmetik amallar oddiy matematikadagidek işlaydi. Satrlarni ham "qöşiş" (bittaga birlaştiriş) mumkin.',
        formulaData: {
          latex: 'a = 5 + 3 \\quad b = 5 * 3 \\quad c = 5 / 3',
          description: 'Qöşiş, köpaytiriş, böliş arifmetikasi.',
          variables: [
            { symbol: '+', meaning: 'Qöşiş' },
            { symbol: '*', meaning: 'Köpaytiriş' },
            { symbol: '/', meaning: 'Böliş (önlik natija)' },
          ],
        },
      },
      {
        id: 'it_py_step_3',
        stepNumber: 3,
        type: 'interactive_question',
        title: '3. Amaliy Maşq',
        subtitle: 'Python’da özgaruvçi',
        content: 'Quyidagi kod nima natija beradi?\n`n = 7 * 3`',
        interactiveQuestion: {
          id: 'q_it_py_q01',
          courseId: 'course_it',
          skillId: 'skill_it_python',
          text: '`n = 7 * 3` bajarilgaç n ning qiymati qanday?',
          options: ['21', '73', '10', '7*3'],
          correctIndex: 0,
          difficulty: 'easy',
          explanation: '7 * 3 = 21 — köpaytiriş amali.',
        },
      },
    ],
    reinforcementExercise: {
      id: 'q_it_py_reinf_01',
      courseId: 'course_it',
      skillId: 'skill_it_python',
      text: 'Mustahkamlaş: `print(10 // 3)` nimani çiqaradi?',
      options: ['3', '3.333', '10', '30'],
      correctIndex: 0,
      difficulty: 'medium',
      explanation: '`//` — butun böliş (floor division): 10 // 3 = 3.',
    },
  },

  lesson_it_web_01: {
    id: 'lesson_it_web_01',
    courseId: 'course_it',
    skillId: 'skill_it_web',
    title: 'Veb sahifa: HTML asoslari',
    estimatedMinutes: 15,
    summary: 'HTML hujjat tuzilişi, asosiy teglar va sahifa elementlarini joylaştiriş.',
    steps: [
      {
        id: 'it_web_step_1',
        stepNumber: 1,
        type: 'concept',
        title: '1. HTML — sahifaning skeleti',
        subtitle: 'Teqlar va ularning ma’nosi',
        content: 'HTML (HyperText Markup Language) sahifa tuzilişini teglar yordamida belgilaydi. Har bir teg `<tagnom>` va `</tagnom>` körinişida oçilib-yopiladi.',
        highlightNotes: [
          '<html> — butun sahifani öraydi',
          '<body> — körinadigan mazmun',
          '<h1>–<h6> — sarlavhalar (kattadan kiçik)',
        ],
      },
      {
        id: 'it_web_step_2',
        stepNumber: 2,
        type: 'formula',
        title: '2. Oddiy sahifa namunasi',
        subtitle: 'Sarlavha va xatboşidan iborat sahifa',
        content: 'Quyidagi kod sarlavha va bitta xatboşidan iborat minimal sahifa yaratadi.',
        formulaData: {
          latex: '<h1>Salom, dunyo!</h1> <p>Bu mening birinçi sahifam.</p>',
          description: 'Sarlavha va xatboşi teglarining qöllanişi.',
          variables: [
            { symbol: '<h1>', meaning: 'Eng katta sarlavha' },
            { symbol: '<p>', meaning: 'Xatboşi (abzats)' },
          ],
        },
      },
      {
        id: 'it_web_step_3',
        stepNumber: 3,
        type: 'interactive_question',
        title: '3. Amaliy Maşq',
        subtitle: 'HTML teglarni tanlaş',
        content: 'Giperhavola (link) yaratiş uçun qaysi teg işlatiladi?',
        interactiveQuestion: {
          id: 'q_it_web_q01',
          courseId: 'course_it',
          skillId: 'skill_it_web',
          text: 'Boşqa sahifaga ötiş (link) uçun qaysi HTML teği kerak?',
          options: ['<a>', '<link>', '<href>', '<img>'],
          correctIndex: 0,
          difficulty: 'medium',
          explanation: '`<a href="...">matn</a>` — giperhavola yaratadi.',
        },
      },
    ],
    reinforcementExercise: {
      id: 'q_it_web_reinf_01',
      courseId: 'course_it',
      skillId: 'skill_it_web',
      text: 'Mustahkamlaş: matn rangini özgartiruvçi CSS xossasi qaysi?',
      options: ['color', 'font-color', 'text-color', 'bgcolor'],
      correctIndex: 0,
      difficulty: 'easy',
      explanation: 'CSS’da matn rangi `color` xossasi bilan beriladi.',
    },
  },

  ...STARTER_LESSONS,
  ...Object.fromEntries((logic.lessons as Lesson[]).map((lesson) => [lesson.id, lesson])),
};

const UNPERMUTED_QUESTION_IDS = new Set(['q_eng_a1_u1_cp_main']);

const permuteQuestion = <T extends Lesson['reinforcementExercise']>(question: T): T =>
  UNPERMUTED_QUESTION_IDS.has(question.id) ? question : permuteQuestionOptions(question);

const permuteLesson = (lesson: Lesson): Lesson => ({
  ...lesson,
  steps: lesson.steps.map((step) =>
    step.interactiveQuestion
      ? { ...step, interactiveQuestion: permuteQuestion(step.interactiveQuestion) }
      : step
  ),
  reinforcementExercise: lesson.reinforcementExercise
    ? permuteQuestion(lesson.reinforcementExercise)
    : lesson.reinforcementExercise,
  alternateExercise: lesson.alternateExercise
    ? permuteQuestion(lesson.alternateExercise)
    : lesson.alternateExercise,
});

export const SEED_LESSONS: Record<string, Lesson> = Object.fromEntries(
  Object.entries(SEED_LESSONS_RAW).map(([id, lesson]) => [id, permuteLesson(lesson)])
);
