import '../../domain/entities/course.dart';

const List<Course> seedCourses = [
  Course(
    id: 'course_math_01',
    title: 'Matematika',
    subject: SubjectType.mathematics,
    description: 'Mantiqiy fikrlash, masalalar va funksiyalarni chuqur mustahkamlash kursi.',
    iconName: 'calculator',
    primaryColorHex: '#2563EB',
    secondaryColorHex: '#3B82F6',
    skills: ['skill_math_algebra', 'skill_math_equations', 'skill_math_functions', 'skill_math_graphs'],
    lessons: ['lesson_math_functions_01'],
    totalStudentsEstimate: 1420,
  ),
  Course(
    id: 'course_eng_01',
    title: 'Ingliz tili',
    subject: SubjectType.english,
    description: 'Lug‘at, grammatika, tinglab tushunish va o‘qish ko‘nikmalarini rivojlantirish.',
    iconName: 'headphones',
    primaryColorHex: '#14B8A6',
    secondaryColorHex: '#0D9488',
    skills: ['skill_eng_vocab', 'skill_eng_grammar', 'skill_eng_listening', 'skill_eng_reading'],
    lessons: ['lesson_eng_listening_01'],
    totalStudentsEstimate: 1890,
  ),
];
