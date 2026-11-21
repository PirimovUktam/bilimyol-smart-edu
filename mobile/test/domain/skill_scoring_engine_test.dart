import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/data/datasources/english/placement_questions_data.dart';
import 'package:bilimyol_mobile/domain/personalization/skill_scoring_engine.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';

void main() {
  group('SkillScoringEngine Tests', () {
    test('clamps score strictly within [0, 100]', () {
      expect(SkillScoringEngine.clampScore(-15), equals(0));
      expect(SkillScoringEngine.clampScore(125), equals(100));
      expect(SkillScoringEngine.clampScore(41.4), equals(41));
      expect(SkillScoringEngine.clampScore(82), equals(82));
    });

    test('calculates exact mathematical percentages (10/10 -> 100%, 0/10 -> 0%, 5/10 -> 50%, 7/12 -> 58%)', () {
      expect(SkillScoringEngine.computeSkillScore(10, 10), equals(100));
      expect(SkillScoringEngine.computeSkillScore(0, 10), equals(0));
      expect(SkillScoringEngine.computeSkillScore(5, 10), equals(50));
      expect(SkillScoringEngine.computeSkillScore(7, 12), equals(58));
      expect(SkillScoringEngine.computeSkillScore(0, 0), equals(0));
    });

    test('correctly categorizes mastery level thresholds (0-39, 40-59, 60-79, 80-100)', () {
      expect(SkillScoringEngine.getMasteryLevel(0), equals(MasteryLevel.needsRemediation));
      expect(SkillScoringEngine.getMasteryLevel(39), equals(MasteryLevel.needsRemediation));
      expect(SkillScoringEngine.getMasteryLabelUz(35), equals('Boshlang‘ich'));

      expect(SkillScoringEngine.getMasteryLevel(40), equals(MasteryLevel.developing));
      expect(SkillScoringEngine.getMasteryLevel(59), equals(MasteryLevel.developing));
      expect(SkillScoringEngine.getMasteryLabelUz(50), equals('Rivojlanmoqda'));

      expect(SkillScoringEngine.getMasteryLevel(60), equals(MasteryLevel.proficient));
      expect(SkillScoringEngine.getMasteryLevel(79), equals(MasteryLevel.proficient));
      expect(SkillScoringEngine.getMasteryLabelUz(70), equals('O‘rta'));

      expect(SkillScoringEngine.getMasteryLevel(80), equals(MasteryLevel.mastered));
      expect(SkillScoringEngine.getMasteryLevel(100), equals(MasteryLevel.mastered));
      expect(SkillScoringEngine.getMasteryLabelUz(95), equals('Yuqori'));
    });

    test('computes overall knowledge score as exact arithmetic mean', () {
      const scores = {
        'skill_math_algebra': SkillScore(
          skillId: 'skill_math_algebra',
          courseId: 'c1',
          score: 80,
          lastUpdated: 0,
          masteryLevel: MasteryLevel.mastered,
        ),
        'skill_math_equations': SkillScore(
          skillId: 'skill_math_equations',
          courseId: 'c1',
          score: 60,
          lastUpdated: 0,
          masteryLevel: MasteryLevel.proficient,
        ),
        'skill_math_functions': SkillScore(
          skillId: 'skill_math_functions',
          courseId: 'c1',
          score: 40,
          lastUpdated: 0,
          masteryLevel: MasteryLevel.developing,
        ),
        'skill_math_graphs': SkillScore(
          skillId: 'skill_math_graphs',
          courseId: 'c1',
          score: 70,
          lastUpdated: 0,
          masteryLevel: MasteryLevel.proficient,
        ),
      };

      // (80 + 60 + 40 + 70) / 4 = 250 / 4 = 62.5 -> 63%
      expect(SkillScoringEngine.computeOverallScore(scores), equals(63));
    });

    test('computes real placement scores from actual question responses', () {
      const questions = [
        Question(id: 'q1', courseId: 'math', skillId: 'alg', text: 'T1', options: ['A'], correctIndex: 0, difficulty: QuestionDifficulty.medium, explanation: 'E'),
        Question(id: 'q2', courseId: 'math', skillId: 'alg', text: 'T2', options: ['A'], correctIndex: 0, difficulty: QuestionDifficulty.medium, explanation: 'E'),
        Question(id: 'q3', courseId: 'math', skillId: 'func', text: 'T3', options: ['A'], correctIndex: 0, difficulty: QuestionDifficulty.medium, explanation: 'E'),
        Question(id: 'q4', courseId: 'math', skillId: 'func', text: 'T4', options: ['A'], correctIndex: 0, difficulty: QuestionDifficulty.medium, explanation: 'E'),
      ];

      final submissions = [
        const QuestionAnswerSubmission(questionId: 'q1', selectedIndex: 0, isCorrect: true),
        const QuestionAnswerSubmission(questionId: 'q2', selectedIndex: 0, isCorrect: true),
        const QuestionAnswerSubmission(questionId: 'q3', selectedIndex: 1, isCorrect: false),
        const QuestionAnswerSubmission(questionId: 'q4', selectedIndex: 1, isCorrect: false),
      ];

      final scores = SkillScoringEngine.computePlacementScores('math', questions, submissions);

      expect(scores['alg']?.score, equals(100));
      expect(scores['alg']?.masteryLevel, equals(MasteryLevel.mastered));
      expect(scores['func']?.score, equals(0));
      expect(scores['func']?.masteryLevel, equals(MasteryLevel.needsRemediation));
      expect(scores['func']?.isWeakestFocus, isTrue);
    });

    test('calculates reinforcement score boost (+22%)', () {
      expect(SkillScoringEngine.calculateReinforcementScore(41), equals(63));
      expect(SkillScoringEngine.calculateReinforcementScore(43), equals(65));
      expect(SkillScoringEngine.calculateReinforcementScore(90), equals(100));
    });

    test('computePlacementScores uses answered count as denominator in 8-of-12 adaptive English placement', () {
      final answered8 = [
        for (final q in englishPlacementQuestionsRaw.where((q) => q.difficulty != QuestionDifficulty.hard))
          QuestionAnswerSubmission(
            questionId: q.id,
            selectedIndex: q.correctIndex,
            isCorrect: true,
          ),
      ];
      expect(answered8.length, equals(8));

      final scores = SkillScoringEngine.computePlacementScores(
        'course_eng_01',
        englishPlacementQuestionsRaw,
        answered8,
      );
      expect(scores.length, equals(4));
      for (final s in scores.values) {
        expect(s.score, equals(100));
      }

      final zeroScores = SkillScoringEngine.computePlacementScores(
        'course_eng_01',
        englishPlacementQuestionsRaw,
        [
          for (final q in englishPlacementQuestionsRaw.where((q) => q.difficulty != QuestionDifficulty.hard))
            QuestionAnswerSubmission(
              questionId: q.id,
              selectedIndex: (q.correctIndex + 1) % q.options.length,
              isCorrect: false,
            ),
        ],
      );
      for (final s in zeroScores.values) {
        expect(s.score, equals(0));
      }
    });

    test('computeEnglishPlacementCefr calibrates Pre-A1..B1 and strictly caps at B1', () {
      final a1Qs = englishPlacementQuestionsRaw
          .where((q) => q.cefrLevel == 'A1')
          .toList();
      final a2Qs = englishPlacementQuestionsRaw
          .where((q) => q.cefrLevel == 'A2')
          .toList();
      final b1Qs = englishPlacementQuestionsRaw
          .where((q) => q.cefrLevel == 'B1')
          .toList();

      // 0/8 -> Pre-A1
      expect(
        SkillScoringEngine.computeEnglishPlacementCefr(
          englishPlacementQuestionsRaw,
          [
            for (final q in [...a1Qs, ...a2Qs])
              QuestionAnswerSubmission(questionId: q.id, selectedIndex: 0, isCorrect: false),
          ],
        ),
        equals('Pre-A1'),
      );

      // 4/8 A1-only -> A1
      expect(
        SkillScoringEngine.computeEnglishPlacementCefr(
          englishPlacementQuestionsRaw,
          [
            for (final q in a1Qs)
              QuestionAnswerSubmission(questionId: q.id, selectedIndex: q.correctIndex, isCorrect: true),
            for (final q in a2Qs)
              QuestionAnswerSubmission(questionId: q.id, selectedIndex: 0, isCorrect: false),
          ],
        ),
        equals('A1'),
      );

      // 6/8 (A1 + half A2) -> A2
      expect(
        SkillScoringEngine.computeEnglishPlacementCefr(
          englishPlacementQuestionsRaw,
          [
            for (final q in a1Qs)
              QuestionAnswerSubmission(questionId: q.id, selectedIndex: q.correctIndex, isCorrect: true),
            QuestionAnswerSubmission(questionId: a2Qs[0].id, selectedIndex: a2Qs[0].correctIndex, isCorrect: true),
            QuestionAnswerSubmission(questionId: a2Qs[1].id, selectedIndex: a2Qs[1].correctIndex, isCorrect: true),
            QuestionAnswerSubmission(questionId: a2Qs[2].id, selectedIndex: 0, isCorrect: false),
            QuestionAnswerSubmission(questionId: a2Qs[3].id, selectedIndex: 0, isCorrect: false),
          ],
        ),
        equals('A2'),
      );

      // 8/8 (A1 + A2 100%) -> B1 (capped)
      expect(
        SkillScoringEngine.computeEnglishPlacementCefr(
          englishPlacementQuestionsRaw,
          [
            for (final q in [...a1Qs, ...a2Qs])
              QuestionAnswerSubmission(questionId: q.id, selectedIndex: q.correctIndex, isCorrect: true),
          ],
        ),
        equals('B1'),
      );

      // 12/12 including B1 -> B1 (never B2/C1/C2)
      expect(
        SkillScoringEngine.computeEnglishPlacementCefr(
          englishPlacementQuestionsRaw,
          [
            for (final q in [...a1Qs, ...a2Qs, ...b1Qs])
              QuestionAnswerSubmission(questionId: q.id, selectedIndex: q.correctIndex, isCorrect: true),
          ],
        ),
        equals('B1'),
      );

      expect(SkillScoringEngine.englishEntryTargetForCefr('Pre-A1').lessonId, 'lesson_eng_starter');
      expect(SkillScoringEngine.englishEntryTargetForCefr('A1').lessonId, 'lesson_eng_starter');
      expect(SkillScoringEngine.englishEntryTargetForCefr('A2').nodeId, 'node_eng_a2_m1_directions');
      expect(SkillScoringEngine.englishEntryTargetForCefr('B1').nodeId, 'node_eng_b1_m1_travel');
      expect(SkillScoringEngine.englishEntryTargetForCefr('B2').cefrLevel, 'B1');
    });
  });
}
