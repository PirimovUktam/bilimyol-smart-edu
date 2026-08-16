import { describe, it, expect } from 'vitest';
import { SkillScoringEngine } from '../domain/personalization/SkillScoringEngine';
import { PLACEMENT_QUESTIONS } from '../data/datasources/questions';
import { QuestionAnswerSubmission } from '../domain/entities/Question';

describe('SkillScoringEngine', () => {
  it('should clamp scores strictly between 0 and 100', () => {
    expect(SkillScoringEngine.clampScore(-15)).toBe(0);
    expect(SkillScoringEngine.clampScore(125)).toBe(100);
    expect(SkillScoringEngine.clampScore(41.4)).toBe(41);
    expect(SkillScoringEngine.clampScore(NaN)).toBe(0);
  });

  it('should classify mastery levels accurately', () => {
    expect(SkillScoringEngine.getMasteryLevel(41)).toBe('needs_remediation');
    expect(SkillScoringEngine.getMasteryLevel(55)).toBe('developing');
    expect(SkillScoringEngine.getMasteryLevel(74)).toBe('proficient');
    expect(SkillScoringEngine.getMasteryLevel(92)).toBe('mastered');
  });

  it('should compute calibrated placement scores for Mathematics', () => {
    const mathQuestions = PLACEMENT_QUESTIONS['course_math_01'];
    // Submit Q1 (Algebra) correct, Q2 (Equations) correct, Q3 (Functions) wrong, Q4 (Graphs) correct, Q5 (Functions) wrong
    const submissions: QuestionAnswerSubmission[] = [
      { questionId: 'q_math_p1', selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 },
      { questionId: 'q_math_p2', selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 },
      { questionId: 'q_math_p3', selectedIndex: 1, isCorrect: false, timeSpentSeconds: 5 },
      { questionId: 'q_math_p4', selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 },
      { questionId: 'q_math_p5', selectedIndex: 1, isCorrect: false, timeSpentSeconds: 5 },
    ];

    const scores = SkillScoringEngine.computePlacementScores('course_math_01', mathQuestions, submissions);

    expect(scores['skill_math_algebra'].score).toBe(82);
    expect(scores['skill_math_equations'].score).toBe(74);
    expect(scores['skill_math_functions'].score).toBe(41); // Weakest focus
    expect(scores['skill_math_graphs'].score).toBe(68);
    expect(scores['skill_math_functions'].isWeakestFocus).toBe(true);
  });

  it('should compute calibrated placement scores for English', () => {
    const engQuestions = PLACEMENT_QUESTIONS['course_eng_01'];
    // Submit Q1, Q2, Q4 correct; Miss Q3 & Q5 (Listening)
    const submissions: QuestionAnswerSubmission[] = [
      { questionId: 'q_eng_p1', selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 },
      { questionId: 'q_eng_p2', selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 },
      { questionId: 'q_eng_p3', selectedIndex: 1, isCorrect: false, timeSpentSeconds: 5 },
      { questionId: 'q_eng_p4', selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 },
      { questionId: 'q_eng_p5', selectedIndex: 1, isCorrect: false, timeSpentSeconds: 5 },
    ];

    const scores = SkillScoringEngine.computePlacementScores('course_eng_01', engQuestions, submissions);

    expect(scores['skill_eng_vocab'].score).toBe(84);
    expect(scores['skill_eng_grammar'].score).toBe(72);
    expect(scores['skill_eng_listening'].score).toBe(43); // Weakest focus
    expect(scores['skill_eng_reading'].score).toBe(79);
    expect(scores['skill_eng_listening'].isWeakestFocus).toBe(true);
  });

  it('should calculate reinforcement score boost correctly', () => {
    const mathBoosted = SkillScoringEngine.calculateReinforcementScore(41);
    expect(mathBoosted).toBe(63); // 41 + 22 = 63

    const engBoosted = SkillScoringEngine.calculateReinforcementScore(43);
    expect(engBoosted).toBe(65); // 43 + 22 = 65

    const maxCapped = SkillScoringEngine.calculateReinforcementScore(95);
    expect(maxCapped).toBe(100);
  });
});
