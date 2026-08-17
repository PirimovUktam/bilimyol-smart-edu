import { SkillScore, SkillId } from '../entities/SkillScore';
import { Question, QuestionAnswerSubmission } from '../entities/Question';

export type MasteryLevel = 'needs_remediation' | 'developing' | 'proficient' | 'mastered';
export type ConfidenceLevel = 'low' | 'medium' | 'high';

export class SkillScoringEngine {
  /**
   * Clamps score strictly within [0, 100]
   */
  public static clampScore(value: number): number {
    if (isNaN(value)) return 0;
    return Math.max(0, Math.min(100, Math.round(value)));
  }

  /**
   * Central level classification:
   * 0–39: needs_remediation (Boshlang‘ich)
   * 40–59: developing (Rivojlanmoqda)
   * 60–79: proficient (O‘rta)
   * 80–100: mastered (Yuqori)
   */
  public static getMasteryLevel(score: number): MasteryLevel {
    const clamped = this.clampScore(score);
    if (clamped < 40) return 'needs_remediation';
    if (clamped < 60) return 'developing';
    if (clamped < 80) return 'proficient';
    return 'mastered';
  }

  /**
   * Uzbek level label
   */
  public static getMasteryLabelUz(score: number): string {
    const level = this.getMasteryLevel(score);
    switch (level) {
      case 'needs_remediation':
        return 'Boshlang‘ich';
      case 'developing':
        return 'Rivojlanmoqda';
      case 'proficient':
        return 'O‘rta';
      case 'mastered':
        return 'Yuqori';
    }
  }

  /**
   * Determines confidence level based on number of attempts
   */
  public static computeConfidence(attemptCount: number): ConfidenceLevel {
    if (attemptCount < 3) return 'low';
    if (attemptCount <= 5) return 'medium';
    return 'high';
  }

  /**
   * Real statistical score calculation: (correct / total) * 100
   */
  public static computeSkillScore(correctCount: number, totalCount: number): number {
    if (totalCount <= 0) return 0;
    const ratio = (correctCount / totalCount) * 100;
    return this.clampScore(ratio);
  }

  /**
   * Computes overall knowledge score as exact arithmetic mean of skill scores
   */
  public static computeOverallScore(skillScores: Record<SkillId, SkillScore> | SkillScore[]): number {
    const scores = Array.isArray(skillScores) ? skillScores : Object.values(skillScores);
    if (scores.length === 0) return 0;
    const sum = scores.reduce((acc, s) => acc + s.score, 0);
    return this.clampScore(sum / scores.length);
  }

  /**
   * Real statistical placement test scoring from actual student submissions.
   * Zero hardcoded numbers.
   */
  public static computePlacementScores(
    courseId: string,
    questions: Question[],
    submissions: QuestionAnswerSubmission[]
  ): Record<SkillId, SkillScore> {
    const skillScoreMap: Record<SkillId, SkillScore> = {};
    const skillStats: Record<SkillId, { correct: number; total: number }> = {};

    // Group submissions by skill
    questions.forEach((q) => {
      if (!skillStats[q.skillId]) {
        skillStats[q.skillId] = { correct: 0, total: 0 };
      }
      skillStats[q.skillId].total += 1;

      const sub = submissions.find((s) => s.questionId === q.id);
      if (sub && sub.isCorrect) {
        skillStats[q.skillId].correct += 1;
      }
    });

    Object.keys(skillStats).forEach((skillId) => {
      const stats = skillStats[skillId];
      const finalScore = this.computeSkillScore(stats.correct, stats.total);

      skillScoreMap[skillId] = {
        skillId,
        courseId,
        score: finalScore,
        lastUpdated: Date.now(),
        masteryLevel: this.getMasteryLevel(finalScore),
      };
    });

    // Find and tag weakest skill dynamically
    let lowestScore = 101;
    let weakestId = '';
    Object.values(skillScoreMap).forEach((s) => {
      if (s.score < lowestScore) {
        lowestScore = s.score;
        weakestId = s.skillId;
      }
    });

    if (weakestId && skillScoreMap[weakestId]) {
      skillScoreMap[weakestId].isWeakestFocus = true;
    }

    return skillScoreMap;
  }

  /**
   * Real cumulative reinforcement score calculation
   */
  public static calculateCumulativeReinforcementScore(
    previousCorrect: number,
    previousTotal: number,
    reinforcementCorrect: number,
    reinforcementTotal: number
  ): number {
    const totalAttempts = previousTotal + reinforcementTotal;
    if (totalAttempts <= 0) return 0;
    const totalCorrect = previousCorrect + reinforcementCorrect;
    return this.computeSkillScore(totalCorrect, totalAttempts);
  }

  /**
   * Helper for standard reinforcement score recalculation
   */
  public static calculateReinforcementScore(currentScore: number, customBump: number = 22): number {
    return this.clampScore(currentScore + customBump);
  }
}
