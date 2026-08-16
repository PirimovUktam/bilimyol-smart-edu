import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/domain/personalization/skill_scoring_engine.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';
import 'package:bilimyol_mobile/data/datasources/questions_data.dart';

void main() {
  group('SkillScoringEngine Tests', () {
    test('clamps score strictly within [0, 100]', () {
      expect(SkillScoringEngine.clampScore(-15), equals(0));
      expect(SkillScoringEngine.clampScore(125), equals(100));
      expect(SkillScoringEngine.clampScore(41.4), equals(41));
      expect(SkillScoringEngine.clampScore(82), equals(82));
    });

    test('correctly categorizes mastery level thresholds', () {
      expect(SkillScoringEngine.getMasteryLevel(41), equals(MasteryLevel.needsRemediation));
      expect(SkillScoringEngine.getMasteryLevel(63), equals(MasteryLevel.developing));
      expect(SkillScoringEngine.getMasteryLevel(74), equals(MasteryLevel.proficient));
      expect(SkillScoringEngine.getMasteryLevel(88), equals(MasteryLevel.mastered));
    });

    test('computes calibrated deterministic placement scores for Mathematics', () {
      final mathQuestions = placementQuestionsData['course_math_01']!;

      // User gets Q1 (Algebra), Q2 (Equations), Q4 (Graphs) right; misses Q3 & Q5 (Functions)
      final submissions = [
        const QuestionAnswerSubmission(questionId: 'q_math_p1', selectedIndex: 0, isCorrect: true),
        const QuestionAnswerSubmission(questionId: 'q_math_p2', selectedIndex: 0, isCorrect: true),
        const QuestionAnswerSubmission(questionId: 'q_math_p3', selectedIndex: 1, isCorrect: false),
        const QuestionAnswerSubmission(questionId: 'q_math_p4', selectedIndex: 0, isCorrect: true),
        const QuestionAnswerSubmission(questionId: 'q_math_p5', selectedIndex: 1, isCorrect: false),
      ];

      final scores = SkillScoringEngine.computePlacementScores(
        'course_math_01',
        mathQuestions,
        submissions,
      );

      expect(scores['skill_math_algebra']?.score, equals(82));
      expect(scores['skill_math_equations']?.score, equals(74));
      expect(scores['skill_math_functions']?.score, equals(41));
      expect(scores['skill_math_graphs']?.score, equals(68));
      expect(scores['skill_math_functions']?.isWeakestFocus, isTrue);
      expect(scores['skill_math_functions']?.masteryLevel, equals(MasteryLevel.needsRemediation));
    });

    test('computes calibrated deterministic placement scores for English', () {
      final engQuestions = placementQuestionsData['course_eng_01']!;

      // User gets Vocab, Grammar, Reading right; misses Listening
      final submissions = [
        const QuestionAnswerSubmission(questionId: 'q_eng_p1', selectedIndex: 0, isCorrect: true),
        const QuestionAnswerSubmission(questionId: 'q_eng_p2', selectedIndex: 0, isCorrect: true),
        const QuestionAnswerSubmission(questionId: 'q_eng_p3', selectedIndex: 1, isCorrect: false),
        const QuestionAnswerSubmission(questionId: 'q_eng_p4', selectedIndex: 0, isCorrect: true),
        const QuestionAnswerSubmission(questionId: 'q_eng_p5', selectedIndex: 1, isCorrect: false),
      ];

      final scores = SkillScoringEngine.computePlacementScores(
        'course_eng_01',
        engQuestions,
        submissions,
      );

      expect(scores['skill_eng_vocab']?.score, equals(84));
      expect(scores['skill_eng_grammar']?.score, equals(72));
      expect(scores['skill_eng_listening']?.score, equals(43));
      expect(scores['skill_eng_reading']?.score, equals(79));
      expect(scores['skill_eng_listening']?.isWeakestFocus, isTrue);
    });

    test('calculates reinforcement score boost (+22%)', () {
      expect(SkillScoringEngine.calculateReinforcementScore(41), equals(63));
      expect(SkillScoringEngine.calculateReinforcementScore(43), equals(65));
      expect(SkillScoringEngine.calculateReinforcementScore(90), equals(100)); // Clamp test
    });
  });
}
