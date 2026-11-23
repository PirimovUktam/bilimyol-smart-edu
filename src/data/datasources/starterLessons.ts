import type { Lesson } from '@/domain/entities/Lesson';
import { ENGLISH_A1_LESSONS } from './english/a1';

export const STARTER_LESSONS: Record<string, Lesson> = {
  lesson_math_starter: {
    id: "lesson_math_starter",
    courseId: "course_math_01",
    skillId: "skill_math_algebra",
    title: "Qöşiş va ayirişdan boşlaymiz",
    estimatedMinutes: 5,
    summary: "Qöşiş ikki guruhni birlaştiradi. Ayiriş guruhdan bir qismini olib taşlaydi.",
    steps: [
      { "id":"lesson_math_starter_read","stepNumber":1,"type":"concept","title":"Asosiy tuşunça","content":"Qöşiş ikki guruhni birlaştiradi. Ayiriş guruhdan bir qismini olib taşlaydi." },
      { "id":"lesson_math_starter_example","stepNumber":2,"type":"visual_example","title":"Birga misol köramiz","content":"Sizda 3 ta olma bor. Yana 2 ta olma olsangiz, jami 5 ta böladi. Yozilişi 3 + 2 = 5. Jami 5 tadan 2 tasini bersangiz, 5 − 2 = 3 ta qoladi." },
      { "id":"lesson_math_starter_try","stepNumber":3,"type":"interactive_question","title":"Örganganingizni sinab köring","content":"Misoldan foydalanib bitta javobni tanlang.","interactiveQuestion":{"id":"q_lesson_math_starter_quiz","courseId":"course_math_01","skillId":"skill_math_algebra","text":"4 ta qalamga yana 2 ta qalam qöşilsa, jami neçta böladi?","options":["2","4","6","8"],"correctIndex":2,"difficulty":"easy","explanation":"4 ta va 2 ta qalamni birlaştiramiz. 4 + 2 = 6."} },
    ],
    reinforcementExercise: {"id":"q_lesson_math_starter_practice","courseId":"course_math_01","skillId":"skill_math_algebra","text":"6 ta daftardan 2 tasi olinsa, neçta qoladi?","options":["4","2","6","8"],"correctIndex":0,"difficulty":"easy","explanation":"6 − 2 = 4."},
  },
  lesson_eng_starter: ENGLISH_A1_LESSONS['lesson_eng_starter'],
  lesson_it_starter: {
    id: "lesson_it_starter",
    courseId: "course_it",
    skillId: "skill_it_python",
    title: "Kompyuterga birinçi buyruq",
    estimatedMinutes: 5,
    summary: "Dastur kompyuter bajaradigan buyruqlardan iborat. Python tilida print buyruği matnni ekranga çiqaradi.",
    steps: [
      { "id":"lesson_it_starter_read","stepNumber":1,"type":"concept","title":"Asosiy tuşunça","content":"Dastur kompyuter bajaradigan buyruqlardan iborat. Python tilida print buyruği matnni ekranga çiqaradi." },
      { "id":"lesson_it_starter_example","stepNumber":2,"type":"visual_example","title":"Birga misol köramiz","content":"print(\"Salom!\") buyruği ekranda Salom! yozuvini körsatadi. Qöştirnoq qayerda matn boşlanib, qayerda tugaşini bildiradi." },
      { "id":"lesson_it_starter_try","stepNumber":3,"type":"interactive_question","title":"Örganganingizni sinab köring","content":"Misoldan foydalanib bitta javobni tanlang.","interactiveQuestion":{"id":"q_lesson_it_starter_quiz","courseId":"course_it","skillId":"skill_it_python","text":"print(\"Kitob\") buyruğidan keyin ekranda nima körinadi?","options":["print","Kitob","Matn çiqmaydi"],"correctIndex":1,"difficulty":"easy","explanation":"print qöştirnoq içidagi Kitob sözini ekranga çiqaradi."} },
    ],
    reinforcementExercise: {"id":"q_lesson_it_starter_practice","courseId":"course_it","skillId":"skill_it_python","text":"Matnni ekranga çiqaradigan buyruq qaysi?","options":["print","Salom","Python"],"correctIndex":0,"difficulty":"easy","explanation":"print — ekranga çiqariş buyruği."},
  },
  lesson_logic_starter: {
    id: "lesson_logic_starter",
    courseId: "course_logic",
    skillId: "skill_logic_puzzles",
    title: "Rost va yolğon gaplar",
    estimatedMinutes: 5,
    summary: "Rost yoki yolğonligini tekşiriş mumkin bölgan gap mulohaza deyiladi. Savol esa javob söraydi.",
    steps: [
      { "id":"lesson_logic_starter_read","stepNumber":1,"type":"concept","title":"Asosiy tuşunça","content":"Rost yoki yolğonligini tekşiriş mumkin bölgan gap mulohaza deyiladi. Savol esa javob söraydi." },
      { "id":"lesson_logic_starter_example","stepNumber":2,"type":"visual_example","title":"Birga misol köramiz","content":"«2 + 3 = 5» rost mulohaza. «2 + 3 = 6» yolğon mulohaza. «Soat neça?» esa savol, uni rost yoki yolğon deb baholay olmaymiz." },
      { "id":"lesson_logic_starter_try","stepNumber":3,"type":"interactive_question","title":"Örganganingizni sinab köring","content":"Misoldan foydalanib bitta javobni tanlang.","interactiveQuestion":{"id":"q_lesson_logic_starter_quiz","courseId":"course_logic","skillId":"skill_logic_puzzles","text":"Qaysi gap rost mulohaza?","options":["4 + 1 = 7","Soat neça?","4 + 1 = 5"],"correctIndex":2,"difficulty":"easy","explanation":"4 ga 1 qöşilganda 5 böladi."} },
    ],
    reinforcementExercise: {"id":"q_lesson_logic_starter_practice","courseId":"course_logic","skillId":"skill_logic_puzzles","text":"Qaysi gap savol?","options":["Bir kunda 24 soat bor.","Bugun qaysi kun?","7 soni 5 dan katta."],"correctIndex":1,"difficulty":"easy","explanation":"«Bugun qaysi kun?» javob söraydi."},
  },

  lesson_math_foundation_02: {
  "id": "lesson_math_foundation_02",
  "courseId": "course_math_01",
  "skillId": "skill_math_algebra",
  "title": "Teng guruhlar va köpaytiriş",
  "estimatedMinutes": 5,
  "summary": "Köpaytiriş teng sonlarni takror qöşişdir. 3 × 2 uçta 2 sonini qöşişni bildiradi.",
  "steps": [
    {
      "id": "lesson_math_foundation_02_read",
      "stepNumber": 1,
      "type": "concept",
      "title": "Asosiy tuşunça",
      "content": "Köpaytiriş teng sonlarni takror qöşişdir. 3 × 2 uçta 2 sonini qöşişni bildiradi."
    },
    {
      "id": "lesson_math_foundation_02_example",
      "stepNumber": 2,
      "type": "visual_example",
      "title": "Birga misol köramiz",
      "content": "Har birida 2 ta qalam bölgan 3 quti bor. 2 + 2 + 2 = 6, şuning uçun 3 × 2 = 6."
    },
    {
      "id": "lesson_math_foundation_02_try",
      "stepNumber": 3,
      "type": "interactive_question",
      "title": "Örganganingizni sinab köring",
      "content": "Misolga tayangan holda javobni tanlang.",
      "interactiveQuestion": {
        "id": "q_lesson_math_foundation_02",
        "courseId": "course_math_01",
        "skillId": "skill_math_algebra",
        "text": "Har birida 3 ta olma bölgan 2 savatda jami neçta olma bor?",
        "options": [
          "5",
          "6",
          "3"
        ],
        "correctIndex": 1,
        "difficulty": "easy",
        "explanation": "3 + 3 = 6. Ikki guruhda uçtadan olma bor."
      }
    }
  ],
  "reinforcementExercise": {
    "id": "q_lesson_math_foundation_02_practice",
    "courseId": "course_math_01",
    "skillId": "skill_math_algebra",
    "text": "Har birida 3 ta olma bölgan 2 savatda jami neçta olma bor?",
    "options": [
      "5",
      "6",
      "3"
    ],
    "correctIndex": 1,
    "difficulty": "easy",
    "explanation": "3 + 3 = 6. Ikki guruhda uçtadan olma bor."
  }
},

  lesson_eng_foundation_02: ENGLISH_A1_LESSONS['lesson_eng_foundation_02'],

  lesson_it_foundation_02: {
  "id": "lesson_it_foundation_02",
  "courseId": "course_it",
  "skillId": "skill_it_python",
  "title": "Son va matnni farqlaş",
  "estimatedMinutes": 5,
  "summary": "Python’da qöştirnoq içidagi yozuv matn hisoblanadi. Qöştirnoqsiz sonlar bilan hisoblaş mumkin.",
  "steps": [
    {
      "id": "lesson_it_foundation_02_read",
      "stepNumber": 1,
      "type": "concept",
      "title": "Asosiy tuşunça",
      "content": "Python’da qöştirnoq içidagi yozuv matn hisoblanadi. Qöştirnoqsiz sonlar bilan hisoblaş mumkin."
    },
    {
      "id": "lesson_it_foundation_02_example",
      "stepNumber": 2,
      "type": "visual_example",
      "title": "Birga misol köramiz",
      "content": "print(2 + 3) ekranga 5 çiqaradi. print(\"2 + 3\") esa 2 + 3 yozuvini çiqaradi. Qöştirnoq yozuvni öz holiça saqlaydi."
    },
    {
      "id": "lesson_it_foundation_02_try",
      "stepNumber": 3,
      "type": "interactive_question",
      "title": "Örganganingizni sinab köring",
      "content": "Misolga tayangan holda javobni tanlang.",
      "interactiveQuestion": {
        "id": "q_lesson_it_foundation_02",
        "courseId": "course_it",
        "skillId": "skill_it_python",
        "text": "print(3 + 4) qanday natija çiqaradi?",
        "options": [
          "3 + 4",
          "34",
          "7"
        ],
        "correctIndex": 2,
        "difficulty": "easy",
        "explanation": "Qöştirnoqsiz sonlar qöşiladi. 3 + 4 = 7."
      }
    }
  ],
  "reinforcementExercise": {
    "id": "q_lesson_it_foundation_02_practice",
    "courseId": "course_it",
    "skillId": "skill_it_python",
    "text": "print(3 + 4) qanday natija çiqaradi?",
    "options": [
      "3 + 4",
      "34",
      "7"
    ],
    "correctIndex": 2,
    "difficulty": "easy",
    "explanation": "Qöştirnoqsiz sonlar qöşiladi. 3 + 4 = 7."
  }
},

  lesson_logic_foundation_02: {
  "id": "lesson_logic_foundation_02",
  "courseId": "course_logic",
  "skillId": "skill_logic_puzzles",
  "title": "Mulohazani inkor qiliş",
  "estimatedMinutes": 5,
  "summary": "Inkor bir mulohazaning rostlik qiymatini teskarisiga özgartiradi. Rost mulohazaning inkori yolğon böladi.",
  "steps": [
    {
      "id": "lesson_logic_foundation_02_read",
      "stepNumber": 1,
      "type": "concept",
      "title": "Asosiy tuşunça",
      "content": "Inkor bir mulohazaning rostlik qiymatini teskarisiga özgartiradi. Rost mulohazaning inkori yolğon böladi."
    },
    {
      "id": "lesson_logic_foundation_02_example",
      "stepNumber": 2,
      "type": "visual_example",
      "title": "Birga misol köramiz",
      "content": "«5 soni 3 dan katta» rost. Uning inkori «5 soni 3 dan katta emas» yolğon. Inkor odatda emas sözi bilan ifodalanadi."
    },
    {
      "id": "lesson_logic_foundation_02_try",
      "stepNumber": 3,
      "type": "interactive_question",
      "title": "Örganganingizni sinab köring",
      "content": "Misolga tayangan holda javobni tanlang.",
      "interactiveQuestion": {
        "id": "q_lesson_logic_foundation_02",
        "courseId": "course_logic",
        "skillId": "skill_logic_puzzles",
        "text": "«2 + 2 = 4» rost. Uning inkori qanday baholanadi?",
        "options": [
          "Rost",
          "Yolğon",
          "Savol"
        ],
        "correctIndex": 1,
        "difficulty": "easy",
        "explanation": "Rost mulohazaning inkori yolğon böladi."
      }
    }
  ],
  "reinforcementExercise": {
    "id": "q_lesson_logic_foundation_02_practice",
    "courseId": "course_logic",
    "skillId": "skill_logic_puzzles",
    "text": "«2 + 2 = 4» rost. Uning inkori qanday baholanadi?",
    "options": [
      "Rost",
      "Yolğon",
      "Savol"
    ],
    "correctIndex": 1,
    "difficulty": "easy",
    "explanation": "Rost mulohazaning inkori yolğon böladi."
  }
},
};
