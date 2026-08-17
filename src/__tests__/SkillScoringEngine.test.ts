import { describe, it, expect } from 'vitest';
import { SkillScoringEngine } from '../domain/personalization/SkillScoringEngine';
import { Question, QuestionAnswerSubmission } from '../domain/entities/Question';

describe('Real Adaptive Learning - SkillScoringEngine', () => {
  it('should clamp scores strictly between 0 and 100', () => {
    expect(SkillScoringEngine.clampScore(-15)).toBe(0);
    expect(SkillScoringEngine.clampScore(125)).toBe(100);
    expect(SkillScoringEngine.clampScore(41.4)).toBe(41);
    expect(SkillScoringEngine.clampScore(NaN)).toBe(0);
  });

  it('should calculate exact mathematical percentages (10/10 -> 100%, 0/10 -> 0%, 5/10 -> 50%, 7/12 -> 58%)', () => {
    expect(SkillScoringEngine.computeSkillScore(10, 10)).toBe(100);
    expect(SkillScoringEngine.computeSkillScore(0, 10)).toBe(0);
    expect(SkillScoringEngine.computeSkillScore(5, 10)).toBe(50);
    expect(SkillScoringEngine.computeSkillScore(7, 12)).toBe(58);
    expect(SkillScoringEngine.computeSkillScore(0, 0)).toBe(0);
  });

  it('should classify central mastery level thresholds correctly (0-39 Boshlang‘ich, 40-59 Rivojlanmoqda, 60-79 O‘rta, 80-100 Yuqori)', () => {
    expect(SkillScoringEngine.getMasteryLevel(0)).toBe('needs_remediation');
    expect(SkillScoringEngine.getMasteryLevel(39)).toBe('needs_remediation');
    expect(SkillScoringEngine.getMasteryLabelUz(35)).toBe('Boshlang‘ich');

    expect(SkillScoringEngine.getMasteryLevel(40)).toBe('developing');
    expect(SkillScoringEngine.getMasteryLevel(59)).toBe('developing');
    expect(SkillScoringEngine.getMasteryLabelUz(50)).toBe('Rivojlanmoqda');

    expect(SkillScoringEngine.getMasteryLevel(60)).toBe('proficient');
    expect(SkillScoringEngine.getMasteryLevel(79)).toBe('proficient');
    expect(SkillScoringEngine.getMasteryLabelUz(70)).toBe('O‘rta');

    expect(SkillScoringEngine.getMasteryLevel(80)).toBe('mastered');
    expect(SkillScoringEngine.getMasteryLevel(100)).toBe('mastered');
    expect(SkillScoringEngine.getMasteryLabelUz(95)).toBe('Yuqori');
  });

  it('should compute confidence metrics based on attempt count', () => {
    expect(SkillScoringEngine.computeConfidence(1)).toBe('low');
    expect(SkillScoringEngine.computeConfidence(2)).toBe('low');
    expect(SkillScoringEngine.computeConfidence(3)).toBe('medium');
    expect(SkillScoringEngine.computeConfidence(5)).toBe('medium');
    expect(SkillScoringEngine.computeConfidence(6)).toBe('high');
    expect(SkillScoringEngine.computeConfidence(15)).toBe('high');
  });

  it('should compute overall knowledge score as exact arithmetic mean', () => {
    const scores = {
      skill_math_algebra: { skillId: 'skill_math_algebra', courseId: 'c1', score: 80, lastUpdated: 0, masteryLevel: 'mastered' as const },
      skill_math_equations: { skillId: 'skill_math_equations', courseId: 'c1', score: 60, lastUpdated: 0, masteryLevel: 'proficient' as const },
      skill_math_functions: { skillId: 'skill_math_functions', courseId: 'c1', score: 40, lastUpdated: 0, masteryLevel: 'developing' as const },
      skill_math_graphs: { skillId: 'skill_math_graphs', courseId: 'c1', score: 70, lastUpdated: 0, masteryLevel: 'proficient' as const },
    };

    // (80 + 60 + 40 + 70) / 4 = 250 / 4 = 62.5 -> 63%
    expect(SkillScoringEngine.computeOverallScore(scores)).toBe(63);
  });

  it('should compute real placement scores from actual question responses', () => {
    const questions: Question[] = [
      { id: 'q1', courseId: 'math', skillId: 'alg', text: 'T1', options: ['A', 'B'], correctIndex: 0, difficulty: 'medium', explanation: 'E' },
      { id: 'q2', courseId: 'math', skillId: 'alg', text: 'T2', options: ['A', 'B'], correctIndex: 0, difficulty: 'medium', explanation: 'E' },
      { id: 'q3', courseId: 'math', skillId: 'func', text: 'T3', options: ['A', 'B'], correctIndex: 0, difficulty: 'medium', explanation: 'E' },
      { id: 'q4', courseId: 'math', skillId: 'func', text: 'T4', options: ['A', 'B'], correctIndex: 0, difficulty: 'medium', explanation: 'E' },
    ];

    // Alg: 2/2 correct (100%), Func: 0/2 correct (0%)
    const submissions: QuestionAnswerSubmission[] = [
      { questionId: 'q1', selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 },
      { questionId: 'q2', selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 },
      { questionId: 'q3', selectedIndex: 1, isCorrect: false, timeSpentSeconds: 5 },
      { questionId: 'q4', selectedIndex: 1, isCorrect: false, timeSpentSeconds: 5 },
    ];

    const result = SkillScoringEngine.computePlacementScores('math', questions, submissions);

    expect(result['alg'].score).toBe(100);
    expect(result['alg'].masteryLevel).toBe('mastered');
    expect(result['func'].score).toBe(0);
    expect(result['func'].masteryLevel).toBe('needs_remediation');
    expect(result['func'].isWeakestFocus).toBe(true);
  });

  it('should calculate real cumulative reinforcement score without artificial boosts', () => {
    // Old score: 4/10 (40%), Reinforcement: 3/5 (60%) -> Total: 7/15 (46.67% -> 47%)
    const cumulative = SkillScoringEngine.calculateCumulativeReinforcementScore(4, 10, 3, 5);
    expect(cumulative).toBe(47);
  });
});
