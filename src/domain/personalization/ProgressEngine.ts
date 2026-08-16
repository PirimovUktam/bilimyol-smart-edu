import { SkillScore } from '../entities/SkillScore';
import { LearningPathNode } from '../entities/LearningPathNode';
import { REINFORCEMENT_XP_REWARD, LESSON_XP_REWARD } from '@/core/constants/adaptiveThresholds';

export class ProgressEngine {
  /**
   * Calculates overall course mastery % based on average skill scores
   */
  public static calculateCourseMastery(skillScores: Record<string, SkillScore>): number {
    const scores = Object.values(skillScores);
    if (scores.length === 0) return 0;
    const total = scores.reduce((sum, item) => sum + item.score, 0);
    return Math.round(total / scores.length);
  }

  /**
   * Calculates roadmap completion percentage
   */
  public static calculateRoadmapProgress(nodes: LearningPathNode[]): number {
    if (nodes.length === 0) return 0;
    const completedCount = nodes.filter((n) => n.status === 'completed').length;
    return Math.round((completedCount / nodes.length) * 100);
  }

  /**
   * Safe idempotent XP adder preventing double-awarding
   */
  public static calculateNewXP(
    currentXP: number,
    actionType: 'lesson_completion' | 'reinforcement_completion',
    actionId: string,
    completedActionIds: string[]
  ): { newXP: number; wasAwarded: boolean } {
    if (completedActionIds.includes(actionId)) {
      return { newXP: currentXP, wasAwarded: false };
    }

    const reward = actionType === 'reinforcement_completion' ? REINFORCEMENT_XP_REWARD : LESSON_XP_REWARD;
    return {
      newXP: currentXP + reward,
      wasAwarded: true,
    };
  }
}
