import { describe, it, expect } from 'vitest';
import { AdaptiveQuestionSelector, AnswerHistoryItem } from '../domain/personalization/AdaptiveQuestionSelector';
import { Question } from '../domain/entities/Question';

describe('AdaptiveQuestionSelector', () => {
  const sampleBank: Question[] = [
    { id: 'q_alg_e', courseId: 'math', skillId: 'skill_math_algebra', text: 'E', options: ['A'], correctIndex: 0, difficulty: 'easy', explanation: 'E' },
    { id: 'q_alg_m', courseId: 'math', skillId: 'skill_math_algebra', text: 'M', options: ['A'], correctIndex: 0, difficulty: 'medium', explanation: 'E' },
    { id: 'q_alg_h', courseId: 'math', skillId: 'skill_math_algebra', text: 'H', options: ['A'], correctIndex: 0, difficulty: 'hard', explanation: 'E' },

    { id: 'q_eq_e', courseId: 'math', skillId: 'skill_math_equations', text: 'E', options: ['A'], correctIndex: 0, difficulty: 'easy', explanation: 'E' },
    { id: 'q_eq_m', courseId: 'math', skillId: 'skill_math_equations', text: 'M', options: ['A'], correctIndex: 0, difficulty: 'medium', explanation: 'E' },
    { id: 'q_eq_h', courseId: 'math', skillId: 'skill_math_equations', text: 'H', options: ['A'], correctIndex: 0, difficulty: 'hard', explanation: 'E' },
  ];

  const targetSkills = ['skill_math_algebra', 'skill_math_equations'];

  it('starts with medium difficulty for an untested skill', () => {
    const nextQ = AdaptiveQuestionSelector.getNextQuestion(sampleBank, targetSkills, []);
    expect(nextQ).not.toBeNull();
    expect(nextQ?.difficulty).toBe('medium');
  });

  it('increases difficulty to hard when recent answers for that skill are correct', () => {
    const history: AnswerHistoryItem[] = [
      { questionId: 'q_alg_m', skillId: 'skill_math_algebra', difficulty: 'medium', isCorrect: true },
    ];

    // Equations is least answered -> should pick Equations medium
    const nextQ = AdaptiveQuestionSelector.getNextQuestion(sampleBank, targetSkills, history);
    expect(nextQ?.skillId).toBe('skill_math_equations');
    expect(nextQ?.difficulty).toBe('medium');

    // Add correct answer for equations
    const history2: AnswerHistoryItem[] = [
      ...history,
      { questionId: 'q_eq_m', skillId: 'skill_math_equations', difficulty: 'medium', isCorrect: true },
    ];

    // Next round for algebra should be hard
    const nextQ2 = AdaptiveQuestionSelector.getNextQuestion(sampleBank, targetSkills, history2);
    expect(nextQ2?.difficulty).toBe('hard');
  });

  it('decreases difficulty to easy when user misses medium questions', () => {
    const history: AnswerHistoryItem[] = [
      { questionId: 'q_alg_m', skillId: 'skill_math_algebra', difficulty: 'medium', isCorrect: false },
      { questionId: 'q_eq_m', skillId: 'skill_math_equations', difficulty: 'medium', isCorrect: false },
    ];

    const nextQ = AdaptiveQuestionSelector.getNextQuestion(sampleBank, targetSkills, history);
    expect(nextQ?.difficulty).toBe('easy');
  });

  it('returns null when target quota per skill is fulfilled', () => {
    const history: AnswerHistoryItem[] = [
      { questionId: 'q_alg_m', skillId: 'skill_math_algebra', difficulty: 'medium', isCorrect: true },
      { questionId: 'q_alg_h', skillId: 'skill_math_algebra', difficulty: 'hard', isCorrect: true },
      { questionId: 'q_eq_m', skillId: 'skill_math_equations', difficulty: 'medium', isCorrect: true },
      { questionId: 'q_eq_h', skillId: 'skill_math_equations', difficulty: 'hard', isCorrect: true },
    ];

    const nextQ = AdaptiveQuestionSelector.getNextQuestion(sampleBank, targetSkills, history, 2);
    expect(nextQ).toBeNull();
  });
});
