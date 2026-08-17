import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/data/datasources/questions_data.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';

void main() {
  final forbiddenPatterns = [
    RegExp(r"to['‘`]?g['‘`]?ri\s*javob", caseSensitive: false),
    RegExp(r"noto['‘`]?g['‘`]?ri", caseSensitive: false),
    RegExp(r"xato", caseSensitive: false),
    RegExp(r"hisoblangan", caseSensitive: false),
    RegExp(r"unutilgan", caseSensitive: false),
    RegExp(r"qo['‘`]?yilgan", caseSensitive: false),
    RegExp(r"deb\s+hisoblangan", caseSensitive: false),
    RegExp(r"correct\s*answer", caseSensitive: false),
    RegExp(r"incorrect", caseSensitive: false),
    RegExp(r"\(to‘g‘ri\)", caseSensitive: false),
    RegExp(r"\(xato\)", caseSensitive: false),
  ];

  group('Question Content & Assessment Audit Tests (Flutter)', () {
    test('verifies all Math questions have clean options without spoiler text', () {
      final mathQuestions = placementQuestionsData['course_math_01'] ?? [];
      expect(mathQuestions.length, greaterThanOrEqualTo(20));

      for (final q in mathQuestions) {
        expect(q.options.length, greaterThanOrEqualTo(3));
        expect(q.correctIndex, greaterThanOrEqualTo(0));
        expect(q.correctIndex, lessThan(q.options.length));
        expect(q.text.trim().length, greaterThan(5));
        expect(q.explanation.trim().length, greaterThan(5));

        for (final opt in q.options) {
          expect(opt.trim().length, greaterThan(0));
          for (final pattern in forbiddenPatterns) {
            expect(pattern.hasMatch(opt), isFalse, reason: 'Option "$opt" matches forbidden pattern "$pattern"');
          }
        }
      }
    });

    test('verifies all English questions have clean options without spoiler text', () {
      final engQuestions = placementQuestionsData['course_eng_01'] ?? [];
      expect(engQuestions.length, greaterThanOrEqualTo(5));

      for (final q in engQuestions) {
        expect(q.options.length, greaterThanOrEqualTo(3));
        expect(q.correctIndex, greaterThanOrEqualTo(0));
        expect(q.correctIndex, lessThan(q.options.length));

        for (final opt in q.options) {
          for (final pattern in forbiddenPatterns) {
            expect(pattern.hasMatch(opt), isFalse, reason: 'Option "$opt" matches forbidden pattern "$pattern"');
          }
        }
      }
    });

    test('verifies all interactive questions in seed lessons have clean options', () {
      for (final lesson in seedLessons.values) {
        for (final step in lesson.steps) {
          if (step.interactiveQuestion != null) {
            final q = step.interactiveQuestion!;
            expect(q.options.length, greaterThanOrEqualTo(3));
            expect(q.correctIndex, greaterThanOrEqualTo(0));
            expect(q.correctIndex, lessThan(q.options.length));

            for (final opt in q.options) {
              for (final pattern in forbiddenPatterns) {
                expect(pattern.hasMatch(opt), isFalse, reason: 'Option "$opt" matches forbidden pattern "$pattern"');
              }
            }
          }
        }

        final reinf = lesson.reinforcementExercise;
        expect(reinf.options.length, greaterThanOrEqualTo(3));
        expect(reinf.correctIndex, greaterThanOrEqualTo(0));
        expect(reinf.correctIndex, lessThan(reinf.options.length));

        for (final opt in reinf.options) {
          for (final pattern in forbiddenPatterns) {
            expect(pattern.hasMatch(opt), isFalse, reason: 'Option "$opt" matches forbidden pattern "$pattern"');
          }
        }
      }
    });

    test('accurately validates lesson questions mathematically', () {
      final mathLesson = seedLessons['lesson_math_functions_01']!;
      final step = mathLesson.steps.firstWhere((s) => s.interactiveQuestion != null);
      final q = step.interactiveQuestion!;

      expect(q.options[q.correctIndex], equals('11'));
      expect(q.options, contains('8'));
      expect(q.options, contains('14'));
      expect(q.options, contains('9'));

      final reinf = mathLesson.reinforcementExercise;
      expect(reinf.options[reinf.correctIndex], equals('8'));
    });
  });
}
