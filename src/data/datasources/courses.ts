import { Course } from '@/domain/entities/Course';

export const SEED_COURSES: Course[] = [
  {
    id: 'course_math_01',
    title: 'Matematika',
    subject: 'mathematics',
    description: 'Mantiqiy fikrlash, masalalar va funksiyalarni chuqur mustahkamlash kursi.',
    iconName: 'Calculator',
    primaryColor: '#2563EB',
    secondaryColor: '#3B82F6',
    skills: ['skill_math_algebra', 'skill_math_equations', 'skill_math_functions', 'skill_math_graphs'],
    lessons: ['lesson_math_functions_01'],
    totalStudentsEstimate: 1420,
  },
  {
    id: 'course_eng_01',
    title: 'Ingliz tili',
    subject: 'english',
    description: 'Lug‘at, grammatika, tinglab tushunish va o‘qish ko‘nikmalarini rivojlantirish.',
    iconName: 'Headphones',
    primaryColor: '#14B8A6',
    secondaryColor: '#0D9488',
    skills: ['skill_eng_vocab', 'skill_eng_grammar', 'skill_eng_listening', 'skill_eng_reading'],
    lessons: ['lesson_eng_listening_01'],
    totalStudentsEstimate: 1890,
  },
];
