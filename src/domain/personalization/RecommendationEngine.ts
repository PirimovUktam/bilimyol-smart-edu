import { Recommendation } from '../entities/Recommendation';
import { SkillScore } from '../entities/SkillScore';
import { LearningPath } from '../entities/LearningPathNode';
import { Skill } from '../entities/Skill';
import { LearnerProfile } from '../entities/LearnerProfile';
import { ADAPTIVE_THRESHOLDS } from '@/core/constants/adaptiveThresholds';
import { AdaptiveCycleEngine } from './AdaptiveCycleEngine';

export class RecommendationEngine {
  /**
   * Generates tailored next-step recommendation with Explainable AI factors and cycle impact
   */
  public static generateRecommendation(
    courseId: string,
    skills: Skill[],
    skillScores: Record<string, SkillScore>,
    roadmap: LearningPath,
    profile?: LearnerProfile | null
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
    const isTargetedPractice =
      !isReinforcement &&
      weakestScoreValue >= ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN &&
      weakestScoreValue <= ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MAX;

    const cycle = AdaptiveCycleEngine.evaluateCycle({ skills, skillScores, roadmap, profile });
    const explainableFactors = AdaptiveCycleEngine.buildExplainableFactors({
      skills,
      skillScores,
      roadmap,
      profile,
    });
    const dailyMicroTasks = AdaptiveCycleEngine.buildDailyMicroTasks({
      skills,
      skillScores,
      roadmap,
      profile,
    });

    return {
      id: `rec_${courseId}_${Date.now()}`,
      courseId,
      title: isReinforcement
        ? `Mustahkamlash: ${targetSkillName}`
        : isTargetedPractice
        ? `Maqsadli mashq: ${targetSkillName}`
        : `Bugungi Reja: ${activeNode ? activeNode.title : targetSkillName}`,
      subtitle: isReinforcement
        ? `Aniqlangan bo‘shliqni to‘ldirish uchun maxsus 5 daqiqalik mashq`
        : isTargetedPractice
        ? `50–69% oraliqdagi natijani 70%+ darajaga ko‘tarish mashqi`
        : `Keyingi bosqichga o‘tish va o‘zlashtirish darajasini oshirish`,
      targetSkillId: targetSkill ? targetSkill.id : '',
      targetSkillName,
      targetNodeId: activeNode ? activeNode.id : '',
      reason: weakestScoreValue < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN
        ? `Ushbu ko‘nikma hozirda ${weakestScoreValue}% darajasida. Tavsiya etilgan mashq orqali uni 60%+ darajaga ko‘taring.`
        : isTargetedPractice
        ? `Ushbu ko‘nikma hozirda ${weakestScoreValue}% (50–69%) darajasida. 70%+ mustahkam bosqichga chiqish uchun maqsadli mashqni bajaring.`
        : `O‘zlashtirish sur’atini saqlab qolish uchun rejadagi darsni davom ettiring.`,
      suggestedMinutes: isReinforcement ? 5 : activeNode ? activeNode.estimatedMinutes : 15,
      priority: weakestScoreValue < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN ? 'high' : 'medium',
      explainableFactors,
      cycleImpact: cycle.loopUpdateSummary,
      dailyMicroTasks,
    };
  }
}
