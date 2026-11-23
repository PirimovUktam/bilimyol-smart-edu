import { Skill } from '@/domain/entities/Skill';

export const SEED_SKILLS: Skill[] = [
  // Mathematics Skills
  {
    id: 'skill_math_algebra',
    courseId: 'course_math_01',
    name: 'Algebra asoslari',
    code: 'MATH-ALG',
    description: 'Qisqa köpaytiriş formulalari, köphadlar va amallar tartibi.',
    order: 1,
    iconName: 'Percent',
  },
  {
    id: 'skill_math_equations',
    courseId: 'course_math_01',
    name: 'Tenglamalar',
    code: 'MATH-EQ',
    description: 'Çiziqli va kvadrat tenglamalarni yeçiş usullari.',
    order: 2,
    iconName: 'Equal',
  },
  {
    id: 'skill_math_functions',
    courseId: 'course_math_01',
    name: 'Funksiyalar',
    code: 'MATH-FUNC',
    description: 'Funksiya tuşunçasi, argument va funksiya qiymatini hisoblaş.',
    order: 3,
    iconName: 'Activity',
  },
  {
    id: 'skill_math_graphs',
    courseId: 'course_math_01',
    name: 'Grafiklar',
    code: 'MATH-GRAPH',
    description: 'Koordinatalar tekisligida çiziqli va kvadratik funksiyalar grafigi.',
    order: 4,
    iconName: 'LineChart',
  },

  // English Skills
  {
    id: 'skill_eng_vocab',
    courseId: 'course_eng_01',
    name: 'Vocabulary',
    code: 'ENG-VOCAB',
    description: 'Akademik va kundalik söz boyligi, kontekstual iboralar.',
    order: 1,
    iconName: 'BookOpen',
  },
  {
    id: 'skill_eng_grammar',
    courseId: 'course_eng_01',
    name: 'Grammar',
    code: 'ENG-GRAM',
    description: 'Zamonlar, modal fe’llar va gap tuzilişi qoidalari.',
    order: 2,
    iconName: 'FileText',
  },
  {
    id: 'skill_eng_listening',
    courseId: 'course_eng_01',
    name: 'Listening',
    code: 'ENG-LIST',
    description: 'Audio va suhbatlardagi asosiy ma’no va kalit sözlarni ilğaş.',
    order: 3,
    iconName: 'Headphones',
  },
  {
    id: 'skill_eng_reading',
    courseId: 'course_eng_01',
    name: 'Reading',
    code: 'ENG-READ',
    description: 'Matnni tahlil qiliş, asosiy ğoyani va detallarni topiş.',
    order: 4,
    iconName: 'Glasses',
  },

  // IT & Coding Skills
  {
    id: 'skill_it_python',
    courseId: 'course_it',
    name: 'Python asoslari',
    code: 'IT-PY',
    description: 'Özgaruvçilar, ma’lumot turlari, şart operatorlari va sikllar.',
    order: 1,
    iconName: 'Code',
  },
  {
    id: 'skill_it_web',
    courseId: 'course_it',
    name: 'Veb dasturlaş',
    code: 'IT-WEB',
    description: 'HTML struktura, CSS uslublar va sahifa elementlari bilan işlaş.',
    order: 2,
    iconName: 'Globe',
  },

  // Logic Skills
  {
    id: 'skill_logic_puzzles',
    courseId: 'course_logic',
    name: 'Mantiqiy boşqotirmalar',
    code: 'LOG-PUZ',
    description: 'Deduktiv xulosalar, şartli mulohazalar va mantiqiy jadvallar.',
    order: 1,
    iconName: 'Brain',
  },
  {
    id: 'skill_logic_patterns',
    courseId: 'course_logic',
    name: 'Qonuniyatlar va ketma-ketliklar',
    code: 'LOG-PAT',
    description: 'Sonli va şakl qonuniyatlarini topiş, keyingi elementni aniqlaş.',
    order: 2,
    iconName: 'TrendingUp',
  },
];
