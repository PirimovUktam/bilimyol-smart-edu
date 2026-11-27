import { SkillScore, SkillId } from '../entities/SkillScore';
import { Question, QuestionAnswerSubmission } from '../entities/Question';

export type MasteryLevel = 'needs_remediation' | 'developing' | 'proficient' | 'mastered';
export type ConfidenceLevel = 'low' | 'medium' | 'high';

export class SkillScoringEngine {
  public static readonly starterOnlyMaxScore = 55;

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
   * 80–100: mastered (Yuqori — requires attemptCount >= 4 when attemptCount is provided)
   */
  public static getMasteryLevel(score: number, attemptCount?: number): MasteryLevel {
    const clamped = this.clampScore(score);
    if (clamped < 40) return 'needs_remediation';
    if (clamped < 60) return 'developing';
    if (clamped < 80) return 'proficient';
    if (attemptCount !== undefined && attemptCount < 4) return 'proficient';
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

  public static getDifficultyWeight(difficulty?: 'easy' | 'medium' | 'hard'): number {
    if (difficulty === 'easy') return 0.75;
    if (difficulty === 'hard') return 1.25;
    return 1.0;
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
   * Calibrates skill mastery from lesson attempts while respecting starter
   * difficulty bounds and preserving prior diagnostic evidence (`FIX-P1-09`).
   */
  public static computeCalibratedSkillScore(params: {
    weightedCorrect: number;
    weightedTotal: number;
    priorScore?: number | null;
    priorWeight?: number;
    starterOnly?: boolean;
    hasNonStarterAttempt?: boolean;
  }): number {
    const {
      weightedCorrect,
      weightedTotal,
      priorScore = null,
      priorWeight = 4,
      starterOnly = false,
      hasNonStarterAttempt = false,
    } = params;

    if (priorScore !== null && priorScore !== undefined) {
      if (
        !hasNonStarterAttempt &&
        priorScore >= this.starterOnlyMaxScore &&
        weightedTotal > 0 &&
        weightedCorrect === weightedTotal
      ) {
        return this.clampScore(priorScore);
      }
      const priorCorrect = (priorScore / 100) * priorWeight;
      const blended = ((priorCorrect + weightedCorrect) / (priorWeight + weightedTotal)) * 100;
      const clamped = this.clampScore(blended);
      if (!hasNonStarterAttempt) {
        const starterCeiling = priorScore > this.starterOnlyMaxScore ? priorScore : this.starterOnlyMaxScore;
        return clamped > starterCeiling ? starterCeiling : clamped;
      }
      return clamped;
    }

    if (weightedTotal <= 0 || weightedCorrect <= 0) return 0;
    if (starterOnly) {
      const raw = ((weightedCorrect + 0.25) / (weightedTotal + 0.75)) * 85;
      return Math.min(this.starterOnlyMaxScore, this.clampScore(raw));
    }
    const smoothed = ((weightedCorrect + 0.5) / (weightedTotal + 1)) * 100;
    return this.clampScore(smoothed);
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
   * Difficulty-weighted statistical placement test scoring from actual student submissions.
   * Deduplicates by `questionId` using `last wins`, weights credit by item difficulty
   * (`easy: 0.75, medium: 1.0, hard: 1.25` without inflating missed `hard` denominator),
   * and sets `isWeakestFocus = true` strictly when `lowestScore < 80` (`FIX-P1-16`).
   */
  public static computePlacementScores(
    courseId: string,
    questions: ReadonlyArray<Pick<Question, 'id' | 'skillId'> & Partial<Pick<Question, 'difficulty'>>>,
    submissions: QuestionAnswerSubmission[]
  ): Record<SkillId, SkillScore> {
    const skillScoreMap: Record<SkillId, SkillScore> = {};
    const skillStats: Record<SkillId, { earned: number; possible: number; count: number }> = {};
    const questionsById = new Map(questions.map((q) => [q.id, q]));
    const dedupedSubmissions = new Map<string, QuestionAnswerSubmission>();
    for (const sub of submissions) {
      if (questionsById.has(sub.questionId)) {
        dedupedSubmissions.set(sub.questionId, sub);
      }
    }

    dedupedSubmissions.forEach((sub) => {
      const q = questionsById.get(sub.questionId);
      if (!q) return;
      if (!skillStats[q.skillId]) {
        skillStats[q.skillId] = { earned: 0, possible: 0, count: 0 };
      }
      const weight = this.getDifficultyWeight(q.difficulty);
      skillStats[q.skillId].count += 1;
      if (sub.isCorrect) {
        skillStats[q.skillId].earned += weight;
        skillStats[q.skillId].possible += weight;
      } else {
        skillStats[q.skillId].possible += Math.min(weight, 1.0);
      }
    });

    Object.keys(skillStats).forEach((skillId) => {
      const stats = skillStats[skillId];
      const finalScore = stats.possible > 0 ? this.clampScore((stats.earned / stats.possible) * 100) : 0;

      skillScoreMap[skillId] = {
        skillId,
        courseId,
        score: finalScore,
        lastUpdated: Date.now(),
        masteryLevel: this.getMasteryLevel(finalScore),
        isWeakestFocus: false,
        attemptCount: stats.count,
        confidence: this.computeConfidence(stats.count),
      };
    });

    // Find and tag weakest skill dynamically only when lowestScore < 80
    let lowestScore = 101;
    let weakestId = '';
    Object.values(skillScoreMap).forEach((s) => {
      if (s.score < lowestScore) {
        lowestScore = s.score;
        weakestId = s.skillId;
      }
    });

    if (weakestId && lowestScore < 80 && skillScoreMap[weakestId]) {
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
