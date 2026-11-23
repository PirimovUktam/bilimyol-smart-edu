import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/data/datasources/questions_data.dart';
import 'package:bilimyol_mobile/data/datasources/lessons_data.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';

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
    RegExp(r"\(töğri\)", caseSensitive: false),
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
      expect(engQuestions.length, equals(12));

      var listeningCount = 0;
      for (final q in engQuestions) {
        expect(q.isPlacement, isTrue, reason: '${q.id} must have isPlacement=true');
        expect({'A1', 'A2', 'B1'}, contains(q.cefrLevel), reason: '${q.id} cefrLevel must be A1..B1');
        expect(q.text.contains('Audio context:'), isFalse, reason: '${q.id} must not leak inline audio script');
        expect((q.textRu ?? '').trim().isNotEmpty, isTrue, reason: '${q.id} missing textRu');
        expect((q.explanationRu ?? '').trim().isNotEmpty, isTrue, reason: '${q.id} missing explanationRu');
        expect((q.wrongFeedback ?? '').trim().isNotEmpty, isTrue, reason: '${q.id} missing wrongFeedback');
        expect((q.wrongFeedbackRu ?? '').trim().isNotEmpty, isTrue, reason: '${q.id} missing wrongFeedbackRu');
        expect(q.options.length, equals(4));
        expect(q.correctIndex, greaterThanOrEqualTo(0));
        expect(q.correctIndex, lessThan(q.options.length));
        expect(q.mistakeFeedbackByOption.keys.toSet(), containsAll(q.options));

        if (q.skillId == 'skill_eng_listening') {
          listeningCount++;
          expect(q.media, isNotNull, reason: '${q.id} missing LessonMedia');
          expect(q.media!.isApproved, isTrue);
          expect(q.media!.source, startsWith('/lesson-media/english/placement/'));
          expect(q.media!.resolvedSourceAssetPath, isNotNull);
        }

        for (final opt in q.options) {
          for (final pattern in forbiddenPatterns) {
            expect(pattern.hasMatch(opt), isFalse, reason: 'Option "$opt" matches forbidden pattern "$pattern"');
          }
        }
      }
      expect(listeningCount, equals(3));
    });

    test('verifies all interactive questions in seed lessons have clean options', () {
      void auditQuestion(Question q) {
        if (q.usesTextEvaluation) {
          expect(q.acceptedAnswers, isNotEmpty, reason: '${q.id} needs acceptedAnswers');
          expect(q.explanation.trim().length, greaterThan(5));
          for (final ans in q.acceptedAnswers) {
            expect(ans.trim().length, greaterThan(0));
            expect(
              q.text.toLowerCase().contains(ans.toLowerCase()),
              isFalse,
              reason: 'Prompt for ${q.id} should not leak accepted answer "$ans"',
            );
            for (final pattern in forbiddenPatterns) {
              expect(pattern.hasMatch(ans), isFalse, reason: 'Answer "$ans" matches forbidden pattern "$pattern"');
            }
          }
        } else if (q.mode == QuestionMode.wordMatch) {
          expect(q.matchPairs, isNotEmpty, reason: '${q.id} needs matchPairs');
        } else if (q.mode == QuestionMode.sentenceOrder) {
          expect(q.orderedTokens, isNotEmpty, reason: '${q.id} needs orderedTokens');
        } else if (q.isSelfAssessed) {
          expect(q.sampleResponse?.trim().isNotEmpty, isTrue, reason: '${q.id} needs sampleResponse');
          expect(q.rubricCriteria, isNotEmpty, reason: '${q.id} needs rubricCriteria');
        } else {
          expect(q.options.length, greaterThanOrEqualTo(3), reason: '${q.id} needs >= 3 options');
          expect(q.correctIndex, greaterThanOrEqualTo(0));
          expect(q.correctIndex, lessThan(q.options.length));

          for (final opt in q.options) {
            for (final pattern in forbiddenPatterns) {
              expect(pattern.hasMatch(opt), isFalse, reason: 'Option "$opt" matches forbidden pattern "$pattern"');
            }
          }
        }
      }

      for (final lesson in seedLessons.values) {
        for (final step in lesson.steps) {
          if (step.interactiveQuestion != null) {
            auditQuestion(step.interactiveQuestion!);
          }
        }
        auditQuestion(lesson.reinforcementExercise);
        if (lesson.alternateExercise != null) {
          auditQuestion(lesson.alternateExercise!);
        }
      }
    });

    test('placement correct answers are distributed, not all index 0', () {
      final all = placementQuestionsData.values.expand((list) => list).toList();
      expect(all.length, greaterThan(20));
      final distinctPositions = all.map((q) => q.correctIndex).toSet();
      expect(distinctPositions.length, greaterThanOrEqualTo(2));
      final zeroCount = all.where((q) => q.correctIndex == 0).length;
      expect(zeroCount, lessThan(all.length));
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
