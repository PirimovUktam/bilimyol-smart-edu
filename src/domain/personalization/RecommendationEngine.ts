import { Recommendation } from '../entities/Recommendation';
import { SkillScore } from '../entities/SkillScore';
import { LearningPath } from '../entities/LearningPathNode';
import { Skill } from '../entities/Skill';
import { LearnerProfile } from '../entities/LearnerProfile';
import { ADAPTIVE_THRESHOLDS } from '@/core/constants/adaptiveThresholds';
import { AdaptiveCycleEngine } from './AdaptiveCycleEngine';
import { SkillScoringEngine } from './SkillScoringEngine';

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
    const effectiveSkills: Skill[] = [...skills];
    const effectiveScores: Record<string, SkillScore> = {
      ...(courseId !== 'course_eng_01' ? (profile?.placementSkillScoresByCourse?.[courseId] ?? {}) : {}),
      ...skillScores,
    };

    const mathObjectives = roadmap.nodes.filter((n) => n.mastery && !n.isOptional);
    if (mathObjectives.length > 0) {
      if (profile?.placementSkillScoresByCourse?.[courseId]) {
        for (const [sid, sc] of Object.entries(profile.placementSkillScoresByCourse[courseId])) {
          if (!effectiveScores[sid]) {
            effectiveScores[sid] = sc;
          }
        }
      }
      for (const node of mathObjectives) {
        if (!effectiveSkills.some((s) => s.id === node.skillId)) {
          effectiveSkills.push({
            id: node.skillId,
            courseId: node.courseId,
            name: node.title,
            code: node.skillId.toUpperCase(),
            description: node.description ?? '',
            order: node.order,
            iconName: 'calculator',
          });
        }
        if (node.mastery && node.mastery.answered > 0) {
          const rawPct = Math.round((100 * node.mastery.correct) / node.mastery.answered);
          const pilotScore =
            node.status === 'reinforcement' || node.mastery.state === 'needs_review'
              ? Math.min(rawPct, 45)
              : rawPct;
          effectiveScores[node.skillId] = {
            skillId: node.skillId,
            courseId: node.courseId,
            score: pilotScore,
            lastUpdated: roadmap.updatedAt,
            masteryLevel: SkillScoringEngine.getMasteryLevel(pilotScore),
          };
        }
      }
    }

    // 1. Find weakest skill
    let weakestSkill: SkillScore | null = null;
    const scoreList = Object.values(effectiveScores);
    for (const sc of scoreList) {
      if (!weakestSkill || sc.score < weakestSkill.score) {
        weakestSkill = sc;
      }
    }

    const weakestSkillId = weakestSkill ? (weakestSkill as SkillScore).skillId : '';
    const targetSkill = effectiveSkills.find((s) => s.id === weakestSkillId);
    const targetSkillName = targetSkill ? targetSkill.name : 'Asosiy mavzu';

    // 2. Find next active node in roadmap (respecting RouteEngine.activeNodeId first)
    const activeNode =
      roadmap.nodes.find(
        (n) => n.id === roadmap.activeNodeId && n.status !== 'locked' && n.status !== 'completed'
      ) ||
      roadmap.nodes.find(
        (n) => n.status === 'reinforcement' || n.status === 'available' || n.status === 'in_progress'
      ) ||
      roadmap.nodes[0];

    const isReinforcement = activeNode
      ? activeNode.isReinforcement ||
        activeNode.status === 'reinforcement' ||
        activeNode.mastery?.state === 'needs_review'
      : false;
    const weakestScoreValue = weakestSkill ? (weakestSkill as SkillScore).score : 100;
    const isTargetedPractice =
      !isReinforcement &&
      weakestScoreValue >= ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN &&
      weakestScoreValue <= ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MAX;

    const cycle = AdaptiveCycleEngine.evaluateCycle({
      skills: effectiveSkills,
      skillScores: effectiveScores,
      roadmap,
      profile,
    });
    const explainableFactors = AdaptiveCycleEngine.buildExplainableFactors({
      skills: effectiveSkills,
      skillScores: effectiveScores,
      roadmap,
      profile,
    });
    const dailyMicroTasks = AdaptiveCycleEngine.buildDailyMicroTasks({
      skills: effectiveSkills,
      skillScores: effectiveScores,
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
