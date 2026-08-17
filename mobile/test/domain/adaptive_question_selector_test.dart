import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/domain/personalization/adaptive_question_selector.dart';
import 'package:bilimyol_mobile/domain/entities/question.dart';

void main() {
  group('AdaptiveQuestionSelector Tests (Flutter)', () {
    const sampleBank = [
      Question(id: 'q_alg_e', courseId: 'math', skillId: 'skill_math_algebra', text: 'E', options: ['A'], correctIndex: 0, difficulty: QuestionDifficulty.easy, explanation: 'E'),
      Question(id: 'q_alg_m', courseId: 'math', skillId: 'skill_math_algebra', text: 'M', options: ['A'], correctIndex: 0, difficulty: QuestionDifficulty.medium, explanation: 'E'),
      Question(id: 'q_alg_h', courseId: 'math', skillId: 'skill_math_algebra', text: 'H', options: ['A'], correctIndex: 0, difficulty: QuestionDifficulty.hard, explanation: 'E'),
      Question(id: 'q_eq_e', courseId: 'math', skillId: 'skill_math_equations', text: 'E', options: ['A'], correctIndex: 0, difficulty: QuestionDifficulty.easy, explanation: 'E'),
      Question(id: 'q_eq_m', courseId: 'math', skillId: 'skill_math_equations', text: 'M', options: ['A'], correctIndex: 0, difficulty: QuestionDifficulty.medium, explanation: 'E'),
      Question(id: 'q_eq_h', courseId: 'math', skillId: 'skill_math_equations', text: 'H', options: ['A'], correctIndex: 0, difficulty: QuestionDifficulty.hard, explanation: 'E'),
    ];

    const targetSkills = ['skill_math_algebra', 'skill_math_equations'];

    test('starts with medium difficulty for an untested skill', () {
      final nextQ = AdaptiveQuestionSelector.getNextQuestion(sampleBank, targetSkills, []);
      expect(nextQ, isNotNull);
      expect(nextQ?.difficulty, equals(QuestionDifficulty.medium));
    });

    test('increases difficulty to hard when recent answers for that skill are correct', () {
      const history = [
        AnswerHistoryItem(questionId: 'q_alg_m', skillId: 'skill_math_algebra', difficulty: QuestionDifficulty.medium, isCorrect: true),
        AnswerHistoryItem(questionId: 'q_eq_m', skillId: 'skill_math_equations', difficulty: QuestionDifficulty.medium, isCorrect: true),
      ];

      final nextQ = AdaptiveQuestionSelector.getNextQuestion(sampleBank, targetSkills, history);
      expect(nextQ?.difficulty, equals(QuestionDifficulty.hard));
    });

    test('decreases difficulty to easy when user misses medium questions', () {
      const history = [
        AnswerHistoryItem(questionId: 'q_alg_m', skillId: 'skill_math_algebra', difficulty: QuestionDifficulty.medium, isCorrect: false),
        AnswerHistoryItem(questionId: 'q_eq_m', skillId: 'skill_math_equations', difficulty: QuestionDifficulty.medium, isCorrect: false),
      ];

      final nextQ = AdaptiveQuestionSelector.getNextQuestion(sampleBank, targetSkills, history);
      expect(nextQ?.difficulty, equals(QuestionDifficulty.easy));
    });

    test('returns null when target quota per skill is fulfilled', () {
      const history = [
        AnswerHistoryItem(questionId: 'q_alg_m', skillId: 'skill_math_algebra', difficulty: QuestionDifficulty.medium, isCorrect: true),
        AnswerHistoryItem(questionId: 'q_alg_h', skillId: 'skill_math_algebra', difficulty: QuestionDifficulty.hard, isCorrect: true),
        AnswerHistoryItem(questionId: 'q_eq_m', skillId: 'skill_math_equations', difficulty: QuestionDifficulty.medium, isCorrect: true),
        AnswerHistoryItem(questionId: 'q_eq_h', skillId: 'skill_math_equations', difficulty: QuestionDifficulty.hard, isCorrect: true),
      ];

      final nextQ = AdaptiveQuestionSelector.getNextQuestion(sampleBank, targetSkills, history, 2);
      expect(nextQ, isNull);
    });
  });
}
