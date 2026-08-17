import 'package:flutter_test/flutter_test.dart';
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
  });
}
