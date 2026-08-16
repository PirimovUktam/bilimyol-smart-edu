import '../../domain/entities/skill.dart';

const List<Skill> seedSkills = [
  // Mathematics Skills
  Skill(
    id: 'skill_math_algebra',
    courseId: 'course_math_01',
    name: 'Algebra asoslari',
    code: 'MATH-ALG',
    description: 'Qisqa ko‘paytirish formulalari, ko‘phadlar va amallar tartibi.',
    order: 1,
    iconName: 'percent',
  ),
  Skill(
    id: 'skill_math_equations',
    courseId: 'course_math_01',
    name: 'Tenglamalar',
    code: 'MATH-EQ',
    description: 'Chiziqli va kvadrat tenglamalarni yechish usullari.',
    order: 2,
    iconName: 'equal',
  ),
  Skill(
    id: 'skill_math_functions',
    courseId: 'course_math_01',
    name: 'Funksiyalar',
    code: 'MATH-FUNC',
    description: 'Funksiya tushunchasi, argument va funksiya qiymatini hisoblash.',
    order: 3,
    iconName: 'activity',
  ),
  Skill(
    id: 'skill_math_graphs',
    courseId: 'course_math_01',
    name: 'Grafiklar',
    code: 'MATH-GRAPH',
    description: 'Koordinatalar tekisligida chiziqli va kvadratik funksiyalar grafigi.',
    order: 4,
    iconName: 'show_chart',
  ),

  // English Skills
  Skill(
    id: 'skill_eng_vocab',
    courseId: 'course_eng_01',
    name: 'Vocabulary',
    code: 'ENG-VOCAB',
    description: 'Akademik va kundalik so‘z boyligi, kontekstual iboralar.',
    order: 1,
    iconName: 'menu_book',
  ),
  Skill(
    id: 'skill_eng_grammar',
    courseId: 'course_eng_01',
    name: 'Grammar',
    code: 'ENG-GRAM',
    description: 'Zamonlar, modal fe’llar va gap tuzilishi qoidalari.',
    order: 2,
    iconName: 'description',
  ),
  Skill(
    id: 'skill_eng_listening',
    courseId: 'course_eng_01',
    name: 'Listening',
    code: 'ENG-LIST',
    description: 'Audio va suhbatlardagi asosiy ma’no va kalit so‘zlarni ilg‘ash.',
    order: 3,
    iconName: 'headphones',
  ),
  Skill(
    id: 'skill_eng_reading',
    courseId: 'course_eng_01',
    name: 'Reading',
    code: 'ENG-READ',
    description: 'Matnni tahlil qilish, asosiy g‘oyani va detallarni topish.',
    order: 4,
    iconName: 'chrome_reader_mode',
  ),
];
