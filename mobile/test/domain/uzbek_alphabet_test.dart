import 'package:bilimyol_mobile/core/l10n/app_strings.dart';
import 'package:bilimyol_mobile/core/l10n/uzbek_alphabet.dart';
import 'package:bilimyol_mobile/data/repositories/supabase_lesson_repository.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('renders authored copy in the updated Uzbek alphabet', () {
    expect(AppStrings.uz.navHome, 'Boş sahifa');
    expect(AppStrings.ru.navHome, 'Главная');
  });

  test('presents legacy math content without changing ids or option order', () {
    final lesson = SupabaseLessonRepository.parseLearnerLesson({
      'id': 'lesson_legacy',
      'course_id': 'course_math_01',
      'skill_id': 'skill_legacy',
      'title': 'Qo‘shish',
      'title_ru': 'Сложение',
      'questions': [
        {
          'id': 'q_legacy',
          'text': "To'g'ri javobni tanlang",
          'options': ['Uch', 'Olti'],
        },
      ],
      'steps': [
        {'id': 'step_legacy', 'type': 'interactive_question', 'title': 'Savol'},
      ],
    });
    expect(lesson.title, 'Qöşiş');
    expect(lesson.titleRu, 'Сложение');
    expect(lesson.reinforcementExercise.id, 'q_legacy');
    expect(lesson.reinforcementExercise.text, 'Töğri javobni tanlang');
    expect(lesson.reinforcementExercise.options, ['Uç', 'Olti']);
  });

  test('accepts both Uzbek spellings while preserving English answers', () {
    expect(
      normalizeTextAnswer(" Qoʻshish, to'g'ri! ", uzbek: true),
      normalizeTextAnswer('Qöşiş töğri', uzbek: true),
    );
    expect(normalizeTextAnswer('çair'), isNot(normalizeTextAnswer('chair')));
  });

  test('preserves English examples, code, and identifiers in legacy copy', () {
    expect(
      updatedCourseText(
        'Birinchi shart: she finishes school.',
        'course_eng_01',
      ),
      'Birinçi şart: she finishes school.',
    );
    expect(
      updatedUzbekSpelling('Bog‘ ichida `push()` va Isʼhoq'),
      'Boğ içida `push()` va Isʼhoq',
    );
  });
}
