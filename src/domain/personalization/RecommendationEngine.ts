import { Recommendation } from '../entities/Recommendation';
import { SkillScore } from '../entities/SkillScore';
import { LearningPath } from '../entities/LearningPathNode';
import { Skill } from '../entities/Skill';

export class RecommendationEngine {
  /**
   * Generates tailored next-step recommendation for the learner
   */
  public static generateRecommendation(
    courseId: string,
    skills: Skill[],
    skillScores: Record<string, SkillScore>,
    roadmap: LearningPath
  ): Recommendation {
    // 1. Find weakest skill
    let weakestSkill: SkillScore | null = null;
    const scoreList = Object.values(skillScores);
    for (const sc of scoreList) {
      if (!weakestSkill || sc.score < weakestSkill.score) {
        weakestSkill = sc;
      }
    }

    const weakestSkillId = weakestSkill ? (weakestSkill as SkillScore).skillId : '';
    const targetSkill = skills.find((s) => s.id === weakestSkillId);
    const targetSkillName = targetSkill ? targetSkill.name : 'Asosiy mavzu';

    // 2. Find next active node in roadmap
    const activeNode = roadmap.nodes.find(
      (n) => n.status === 'reinforcement' || n.status === 'available' || n.status === 'in_progress'
    ) || roadmap.nodes[0];

    const isReinforcement = activeNode ? activeNode.isReinforcement || activeNode.status === 'reinforcement' : false;
    const weakestScoreValue = weakestSkill ? (weakestSkill as SkillScore).score : 100;

    return {
      id: `rec_${courseId}_${Date.now()}`,
      courseId,
      title: isReinforcement ? `Mustahkamlash: ${targetSkillName}` : `Bugungi Reja: ${activeNode ? activeNode.title : targetSkillName}`,
      subtitle: isReinforcement
        ? `Aniqlangan bo‘shliqni to‘ldirish uchun maxsus 5 daqiqalik mashq`
        : `Keyingi bosqichga o‘tish va o‘zlashtirish darajasini oshirish`,
      targetSkillId: targetSkill ? targetSkill.id : '',
      targetSkillName,
      targetNodeId: activeNode ? activeNode.id : '',
      reason: weakestScoreValue < 50
        ? `Ushbu ko‘nikma hozirda ${weakestScoreValue}% darajasida. Tavsiya etilgan mashq orqali uni 60%+ darajaga ko‘taring.`
        : `O‘zlashtirish sur’atini saqlab qolish uchun rejadagi darsni davom ettiring.`,
      suggestedMinutes: isReinforcement ? 5 : activeNode ? activeNode.estimatedMinutes : 15,
      priority: weakestScoreValue < 50 ? 'high' : 'medium',
    };
  }
}
