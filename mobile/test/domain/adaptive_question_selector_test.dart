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

    test('course_eng_01 starts at easy (A1), advances easy -> medium -> hard, and falls back to nearest difficulty', () {
      const engBank = [
        Question(id: 'e_v_e', courseId: 'course_eng_01', skillId: 'skill_eng_vocab', text: 'V-A1', options: ['A'], correctIndex: 0, difficulty: QuestionDifficulty.easy, cefrLevel: 'A1', explanation: 'E'),
        Question(id: 'e_v_m', courseId: 'course_eng_01', skillId: 'skill_eng_vocab', text: 'V-A2', options: ['A'], correctIndex: 0, difficulty: QuestionDifficulty.medium, cefrLevel: 'A2', explanation: 'E'),
        Question(id: 'e_v_h', courseId: 'course_eng_01', skillId: 'skill_eng_vocab', text: 'V-B1', options: ['A'], correctIndex: 0, difficulty: QuestionDifficulty.hard, cefrLevel: 'B1', explanation: 'E'),
      ];
      const skills = ['skill_eng_vocab'];

      final q1 = AdaptiveQuestionSelector.getNextQuestion(engBank, skills, [], 3);
      expect(q1?.id, equals('e_v_e'));
      expect(q1?.difficulty, equals(QuestionDifficulty.easy));

      final q2 = AdaptiveQuestionSelector.getNextQuestion(engBank, skills, [
        const AnswerHistoryItem(questionId: 'e_v_e', skillId: 'skill_eng_vocab', difficulty: QuestionDifficulty.easy, isCorrect: true),
      ], 3);
      expect(q2?.id, equals('e_v_m'));
      expect(q2?.difficulty, equals(QuestionDifficulty.medium));

      final q3 = AdaptiveQuestionSelector.getNextQuestion(engBank, skills, [
        const AnswerHistoryItem(questionId: 'e_v_e', skillId: 'skill_eng_vocab', difficulty: QuestionDifficulty.easy, isCorrect: true),
        const AnswerHistoryItem(questionId: 'e_v_m', skillId: 'skill_eng_vocab', difficulty: QuestionDifficulty.medium, isCorrect: true),
      ], 3);
      expect(q3?.id, equals('e_v_h'));
      expect(q3?.difficulty, equals(QuestionDifficulty.hard));

      // Miss on easy stays easy, and falls back to nearest difficulty (medium) when easy is exhausted
      final qFallback = AdaptiveQuestionSelector.getNextQuestion(engBank, skills, [
        const AnswerHistoryItem(questionId: 'e_v_e', skillId: 'skill_eng_vocab', difficulty: QuestionDifficulty.easy, isCorrect: false),
      ], 3);
      expect(qFallback?.id, equals('e_v_m'));
    });
  });
}
