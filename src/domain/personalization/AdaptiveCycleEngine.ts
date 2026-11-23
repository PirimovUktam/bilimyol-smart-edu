import { ADAPTIVE_THRESHOLDS } from '@/core/constants/adaptiveThresholds';
import { DailyTimeCommitment, InitialLevel, OnboardingGoal } from '@/core/types/common';
import { Course } from '../entities/Course';
import { LearnerProfile } from '../entities/LearnerProfile';
import { LearningPath, LearningPathNode } from '../entities/LearningPathNode';
import { DailyMicroTask, ExplainableFactor } from '../entities/Recommendation';
import { Skill } from '../entities/Skill';
import { SkillScore } from '../entities/SkillScore';
import { SkillScoringEngine } from './SkillScoringEngine';

export type AdaptiveStepId = 1 | 2 | 3 | 4 | 5;
export type AdaptiveStepKey = 'diagnostic' | 'profile' | 'path' | 'practice' | 'progress';

export interface AdaptiveStepState {
  step: AdaptiveStepId;
  code: '01' | '02' | '03' | '04' | '05';
  key: AdaptiveStepKey;
  status: 'completed' | 'active' | 'upcoming';
  metricLabel: string;
}

export interface AdaptiveCycleSnapshot {
  activeStep: AdaptiveStepId;
  steps: AdaptiveStepState[];
  loopUpdateSummary: string;
  weakestSkillName: string | null;
  weakestScore: number | null;
  strongSkillsCount: number;
  weakSkillsCount: number;
  needsReinforcement: boolean;
  activeNodeTitle: string | null;
}

export interface AdaptiveSkillDelta {
  skillId: string;
  skillName: string;
  baseline: number;
  current: number;
  delta: number;
  status: 'gap_detected' | 'reinforcing' | 'closed_gap' | 'mastered' | 'unassessed';
}

export interface AdaptiveEffectivenessMetrics {
  baselineScore: number;
  currentScore: number;
  growthDelta: number;
  detectedGapsCount: number;
  closedGapsCount: number;
  adaptiveUpdatesCount: number;
  dailyMinutesBudget: DailyTimeCommitment;
  paceEfficiencyPct: number;
  skillDeltas: AdaptiveSkillDelta[];
}

export interface AdaptiveContextInput {
  course?: Course | null;
  profile?: LearnerProfile | null;
  skills: Skill[];
  skillScores: Record<string, SkillScore>;
  roadmap?: LearningPath | null;
}

const BASELINE_BY_LEVEL: Record<InitialLevel, number> = {
  beginner: 25,
  intermediate: 45,
  advanced: 65,
};

const GOAL_LABEL_UZ: Record<OnboardingGoal, string> = {
  mastery: 'Asosiy mavzularni özlaştiriş',
  exam_prep: 'Imtihon va testlarga tayyorgarlik',
  skills_boost: 'Amaliy könikmalarni kuçaytiriş',
};

function findWeakestSkill(
  skills: Skill[],
  skillScores: Record<string, SkillScore>
): { skill: Skill | null; scoreObj: SkillScore | null } {
  let weakest: SkillScore | null = null;
  for (const sc of Object.values(skillScores)) {
    if (!weakest || sc.score < weakest.score) {
      weakest = sc;
    }
  }
  if (!weakest) return { skill: null, scoreObj: null };
  const skill = skills.find((s) => s.id === weakest!.skillId) ?? null;
  return { skill, scoreObj: weakest };
}

function getCourseLevel(course: Course | null | undefined, profile: LearnerProfile | null | undefined): InitialLevel {
  if (course && profile?.courseLevels?.[course.id]) {
    return profile.courseLevels[course.id];
  }
  return profile?.initialLevel ?? 'beginner';
}

function resolveActiveNode(roadmap: LearningPath | null | undefined): LearningPathNode | null {
  if (!roadmap || roadmap.nodes.length === 0) return null;
  return (
    roadmap.nodes.find((n) => n.id === roadmap.activeNodeId) ||
    roadmap.nodes.find((n) => n.status === 'reinforcement' || n.status === 'available' || n.status === 'in_progress') ||
    roadmap.nodes[0]
  );
}

/**
 * Pure domain engine implementing BilimYöl's 5-step Adaptive Learning Cycle,
 * 6-input Explainable AI transparent reasoning, and cycle effectiveness metrics.
 */
export class AdaptiveCycleEngine {
  public static evaluateCycle(input: AdaptiveContextInput): AdaptiveCycleSnapshot {
    const { course, profile, skills, skillScores, roadmap } = input;
    const scoreValues = Object.values(skillScores);
    const hasDiagnostics = scoreValues.length > 0;
    const completedLessonsCount = course
      ? course.lessons.filter((id) => profile?.completedLessonIds.includes(id)).length
      : (profile?.completedLessonIds.length ?? 0);
    const completedNodesCount = roadmap
      ? roadmap.nodes.filter((n) => !n.isReinforcement && n.status === 'completed').length
      : (profile?.completedNodeIds.length ?? 0);
    const completedReinforcementsCount = roadmap
      ? roadmap.nodes.filter((n) => n.isReinforcement && n.status === 'completed').length
      : (profile?.completedReinforcementIds.length ?? 0);

    const weakScores = scoreValues.filter((s) => s.score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN);
    const strongScores = scoreValues.filter((s) => s.score >= ADAPTIVE_THRESHOLDS.STANDARD_MIN);
    const { skill: weakestSkill, scoreObj: weakestScoreObj } = findWeakestSkill(skills, skillScores);
    const activeNode = resolveActiveNode(roadmap);
    const needsReinforcement =
      weakScores.length > 0 || Boolean(activeNode && (activeNode.isReinforcement || activeNode.status === 'reinforcement'));

    const hasCourseConfigured = Boolean(
      course && (profile?.courseLevels?.[course.id] || hasDiagnostics || completedLessonsCount > 0)
    );
    const hasPathSelected = Boolean(hasCourseConfigured && (roadmap?.nodes.length || activeNode));
    const hasPracticeActivity = completedLessonsCount > 0 || completedReinforcementsCount > 0 || completedNodesCount > 0;
    const hasProgressMeasured = hasDiagnostics && (hasPracticeActivity || scoreValues.some((s) => s.score >= 50));

    let activeStep: AdaptiveStepId = 1;
    if (!hasDiagnostics && !hasCourseConfigured) {
      activeStep = 1;
    } else if (!hasDiagnostics) {
      activeStep = 1;
    } else if (needsReinforcement && !hasPracticeActivity) {
      activeStep = 3;
    } else if (hasPracticeActivity && hasProgressMeasured) {
      activeStep = 5;
    } else if (hasPathSelected && needsReinforcement) {
      activeStep = 4;
    } else if (hasPathSelected) {
      activeStep = 3;
    } else {
      activeStep = 2;
    }

    const stepStatus = (stepNum: AdaptiveStepId, doneCondition: boolean): AdaptiveStepState['status'] => {
      if (activeStep === stepNum) return 'active';
      if (doneCondition || stepNum < activeStep) return 'completed';
      return 'upcoming';
    };

    const overall = SkillScoringEngine.computeOverallScore(skillScores);

    const steps: AdaptiveStepState[] = [
      {
        step: 1,
        code: '01',
        key: 'diagnostic',
        status: stepStatus(1, hasDiagnostics),
        metricLabel: hasDiagnostics
          ? `${scoreValues.length} könikma baholangan`
          : hasCourseConfigured
          ? 'Reja tanlangan'
          : 'Boşlanğiç tekşiruv',
      },
      {
        step: 2,
        code: '02',
        key: 'profile',
        status: stepStatus(2, hasDiagnostics),
        metricLabel: hasDiagnostics
          ? weakScores.length > 0
            ? `${weakScores.length} böşliq · ${strongScores.length} kuçli`
            : `${strongScores.length} kuçli mavzu`
          : 'Böşliqlar tahlili',
      },
      {
        step: 3,
        code: '03',
        key: 'path',
        status: stepStatus(3, hasPathSelected),
        metricLabel: activeNode
          ? activeNode.title
          : 'Mos qadam tanlanadi',
      },
      {
        step: 4,
        code: '04',
        key: 'practice',
        status: stepStatus(4, hasPracticeActivity),
        metricLabel: needsReinforcement
          ? `Mustahkamlaş: ${weakestSkill?.name ?? 'zaif mavzu'}`
          : `${completedLessonsCount + completedReinforcementsCount} maşq bajarilgan`,
      },
      {
        step: 5,
        code: '05',
        key: 'progress',
        status: stepStatus(5, hasProgressMeasured),
        metricLabel: hasDiagnostics
          ? `${overall}% özlaştiriş`
          : 'Qayta ölçaş',
      },
    ];

    const hasTargetedPractice =
      !needsReinforcement &&
      Boolean(
        weakestSkill &&
          weakestScoreObj &&
          weakestScoreObj.score >= ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN &&
          weakestScoreObj.score <= ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MAX
      );

    const loopUpdateSummary = !hasDiagnostics
      ? 'Diagnostika yoki ilk dars natijasi profilga yozilişi bilan keyingi şaxsiy qadam avtomatik yangilanadi.'
      : needsReinforcement && weakestSkill
      ? `"${weakestSkill.name}" mavzusida ${weakestScoreObj?.score ?? 0}% körsatkiç qayd etildi — şu sababli keyingi qadam sifatida mustahkamlaş maşqi tanlandi.`
      : hasTargetedPractice && weakestSkill
      ? `"${weakestSkill.name}" mavzusi ${weakestScoreObj?.score ?? 0}% (50–69%) darajada — 70%+ mustahkam natija uçun maqsadli maşq tavsiya qilindi.`
      : `Sönggi natijalar asosida umumiy özlaştiriş ${overall}% ga yetdi va navbatdagi bosqiç "${activeNode?.title ?? 'keyingi mavzu'}" oçildi.`;

    return {
      activeStep,
      steps,
      loopUpdateSummary,
      weakestSkillName: weakestSkill?.name ?? null,
      weakestScore: weakestScoreObj?.score ?? null,
      strongSkillsCount: strongScores.length,
      weakSkillsCount: weakScores.length,
      needsReinforcement,
      activeNodeTitle: activeNode?.title ?? null,
    };
  }

  public static buildExplainableFactors(input: AdaptiveContextInput): ExplainableFactor[] {
    const { course, profile, skills, skillScores, roadmap } = input;
    const scoreValues = Object.values(skillScores);
    const overall = SkillScoringEngine.computeOverallScore(skillScores);
    const { skill: weakestSkill, scoreObj: weakestScoreObj } = findWeakestSkill(skills, skillScores);
    const goal = profile?.goal ?? 'mastery';
    const dailyMinutes = profile?.dailyMinutes ?? 15;
    const completedCount = course
      ? course.lessons.filter((id) => profile?.completedLessonIds.includes(id)).length
      : (profile?.completedLessonIds.length ?? 0);
    const streakDays = profile?.streakDays ?? 0;
    const activeNode = resolveActiveNode(roadmap);

    const speedLabel =
      completedCount >= 4 || streakDays >= 5
        ? 'Yuqori sur’at'
        : completedCount >= 1
        ? 'Barqaror ritm'
        : 'Boşlanğiç temp';

    const weakCount = scoreValues.filter((s) => s.score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN).length;
    const targetedCount = scoreValues.filter(
      (s) =>
        s.score >= ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN &&
        s.score <= ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MAX
    ).length;

    return [
      {
        key: 'goal',
        label: 'Maqsad',
        value: GOAL_LABEL_UZ[goal],
        impact:
          goal === 'exam_prep'
            ? 'Yuqori ball beruvçi mavzular va test aniqligi birinçi öringa qöyiladi.'
            : goal === 'skills_boost'
            ? 'Amaliy maşqlar va xatoni tuşuniş uluşi oşiriladi.'
            : 'Tayanç tuşunçalar ketma-ket va mustahkam özlaştiriladi.',
      },
      {
        key: 'skill_profile',
        label: 'Könikmalar profili',
        value: weakestSkill
          ? `Fokus: ${weakestSkill.name}`
          : `${skills.length} ta tayanç könikma`,
        impact: weakestSkill
          ? `Eng past körsatkiç (${weakestScoreObj?.score ?? 0}%) şu mavzuda aniqlangani uçun ustuvor etib belgilandi.`
          : 'Diagnostikadan söng kuçli va zaif mavzular xaritasi şakllanadi.',
      },
      {
        key: 'knowledge_level',
        label: 'Bilim darajasi',
        value: scoreValues.length > 0 ? `${overall}% (${SkillScoringEngine.getMasteryLabelUz(overall)})` : 'Boşlanğiç baholaş kutilmoqda',
        impact:
          overall < 50
            ? 'Murakkab bosqiçga ötişdan oldin asosiy böşliqni yopiş tavsiya qilinadi.'
            : 'Keyingi bosqiçga çiqiş uçun mos qiyinlikdagi topşiriq tanlandi.',
      },
      {
        key: 'error_pattern',
        label: 'Xatolar va böşliq',
        value:
          weakCount > 0
            ? `${weakCount} ta böşliq (<50%)`
            : targetedCount > 0
            ? `${targetedCount} ta maqsadli maşq (50–69%)`
            : scoreValues.length > 0
            ? 'Kritik böşliq yöq'
            : 'Xatolar hali qayd etilmagan',
        impact:
          weakCount > 0
            ? `"${activeNode?.title ?? weakestSkill?.name ?? 'Mavzu'}" böyiça mustahkamlaş maşqi yöl xaritasiga qöşildi.`
            : targetedCount > 0
            ? `"${weakestSkill?.name ?? activeNode?.title ?? 'Mavzu'}" böyiça 70%+ ga çiqiş uçun maqsadli maşq tavsiya etildi.`
            : 'Xato aniqlanişi bilan tizim avtomatik tarzda qayta maşq tavsiya qiladi.',
      },
      {
        key: 'learning_speed',
        label: 'Örganiş tezligi',
        value: speedLabel,
        impact: `${completedCount} dars yakunlangan · ${streakDays} kun ketma-ket faollik asosida qadam yuklamasi moslandi.`,
      },
      {
        key: 'daily_time',
        label: 'Kunlik vaqt',
        value: `${dailyMinutes} daqiqa / kun`,
        impact: `${dailyMinutes} daqiqalik byudjetga mos qisqa dars + 5 daqiqalik nazorat maşqi rejalaştirildi.`,
      },
    ];
  }

  public static buildDailyMicroTasks(input: AdaptiveContextInput): DailyMicroTask[] {
    const { skills, skillScores, roadmap, profile } = input;
    const dailyMinutes = profile?.dailyMinutes ?? 15;
    const activeNode = resolveActiveNode(roadmap);
    const { skill: weakestSkill, scoreObj: weakestScoreObj } = findWeakestSkill(skills, skillScores);
    const hasScores = Object.keys(skillScores).length > 0;
    const tasks: DailyMicroTask[] = [];

    if (!hasScores) {
      tasks.push({
        id: 'micro_diag',
        title: '5 daqiqalik adaptiv diagnostika',
        minutes: 5,
        type: 'diagnostic',
        reason: 'Bilim profili va zaif mavzularni aniq xaritalaş uçun boşlanğiç qadam.',
      });
    } else if (weakestSkill && weakestScoreObj && weakestScoreObj.score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN) {
      tasks.push({
        id: 'micro_reinf',
        title: `Böşliqni yopiş: ${weakestSkill.name}`,
        minutes: 5,
        type: 'reinforcement',
        targetNodeId: `reinf_${activeNode?.id ?? weakestSkill.id}`,
        reason: `${weakestScoreObj.score}% natijani 60%+ darajaga kötariş uçun maqsadli maşq.`,
      });
    } else if (
      weakestSkill &&
      weakestScoreObj &&
      weakestScoreObj.score <= ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MAX
    ) {
      tasks.push({
        id: 'micro_targeted',
        title: `Maqsadli maşq: ${weakestSkill.name}`,
        minutes: 5,
        type: 'reinforcement',
        targetNodeId: activeNode?.id,
        reason: `${weakestScoreObj.score}% (50–69%) natijani 70%+ mustahkam darajaga olib çiqiş uçun qöşimça maşq.`,
      });
    }

    if (activeNode) {
      tasks.push({
        id: `micro_node_${activeNode.id}`,
        title: activeNode.title,
        minutes: Math.min(activeNode.estimatedMinutes, dailyMinutes >= 30 ? 15 : 10),
        type: activeNode.isReinforcement ? 'reinforcement' : 'lesson',
        targetNodeId: activeNode.id,
        reason: activeNode.isReinforcement
          ? 'Oldingi xatolarni qayta mustahkamlaş bosqiçi.'
          : 'Ta’lim yölingizdagi navbatdagi asosiy bosqiç.',
      });
    }

    tasks.push({
      id: 'micro_review',
      title: 'Yölçi AI bilan 1 ta tezkor savol-javob tahlili',
      minutes: dailyMinutes >= 30 ? 10 : 5,
      type: 'lesson',
      reason: 'Formative feedback: qoidani mustaqil tuşuntira oliş darajasini tekşiriş.',
    });

    return tasks.slice(0, 3);
  }

  public static measureEffectiveness(input: AdaptiveContextInput): AdaptiveEffectivenessMetrics {
    const { course, profile, skills, skillScores, roadmap } = input;
    const level = getCourseLevel(course, profile);
    const baseEstimate = BASELINE_BY_LEVEL[level];
    const scoreValues = Object.values(skillScores);
    const hasScores = scoreValues.length > 0;
    const currentScore = hasScores ? SkillScoringEngine.computeOverallScore(skillScores) : 0;

    const completedReinforcements = new Set(profile?.completedReinforcementIds ?? []);
    const completedLessons = course
      ? course.lessons.filter((id) => profile?.completedLessonIds.includes(id)).length
      : (profile?.completedLessonIds.length ?? 0);

    const reinforcementBonusCount = roadmap
      ? roadmap.nodes.filter((n) => n.isReinforcement && completedReinforcements.has(n.id)).length
      : completedReinforcements.size;

    const baselineScore = hasScores
      ? Math.max(15, Math.min(currentScore, reinforcementBonusCount > 0 ? currentScore - reinforcementBonusCount * 12 : baseEstimate))
      : baseEstimate;

    const growthDelta = hasScores ? Math.max(0, currentScore - baselineScore) : 0;

    let detectedGapsCount = 0;
    let closedGapsCount = 0;

    const skillDeltas: AdaptiveSkillDelta[] = skills.map((skill) => {
      const scoreObj = skillScores[skill.id];
      const hasReinforcementCompleted = Array.from(completedReinforcements).some((rid) =>
        roadmap?.nodes.some((n) => n.id === rid && n.skillId === skill.id)
      );

      if (!scoreObj) {
        return {
          skillId: skill.id,
          skillName: skill.name,
          baseline: baseEstimate,
          current: 0,
          delta: 0,
          status: 'unassessed',
        };
      }

      const skillBaseline = hasReinforcementCompleted
        ? Math.max(15, scoreObj.score - 22)
        : Math.min(scoreObj.score, baseEstimate);
      const isGapNow = scoreObj.score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN;
      const wasGapClosed = hasReinforcementCompleted && scoreObj.score >= ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN;

      if (isGapNow || hasReinforcementCompleted) {
        detectedGapsCount += 1;
      }
      if (wasGapClosed) {
        closedGapsCount += 1;
      }

      const status: AdaptiveSkillDelta['status'] = scoreObj.score >= ADAPTIVE_THRESHOLDS.STANDARD_MIN
        ? wasGapClosed
          ? 'closed_gap'
          : 'mastered'
        : isGapNow
        ? 'gap_detected'
        : wasGapClosed
        ? 'closed_gap'
        : 'reinforcing';

      return {
        skillId: skill.id,
        skillName: skill.name,
        baseline: skillBaseline,
        current: scoreObj.score,
        delta: Math.max(0, scoreObj.score - skillBaseline),
        status,
      };
    });

    const adaptiveUpdatesCount =
      completedLessons + completedReinforcements.size + (hasScores ? 1 : 0);
    const dailyMinutesBudget = profile?.dailyMinutes ?? 15;
    const paceEfficiencyPct = Math.min(
      100,
      hasScores || completedLessons > 0
        ? Math.round(45 + Math.min(55, (completedLessons * 14 + completedReinforcements.size * 18)))
        : 0
    );

    return {
      baselineScore,
      currentScore,
      growthDelta,
      detectedGapsCount,
      closedGapsCount,
      adaptiveUpdatesCount,
      dailyMinutesBudget,
      paceEfficiencyPct,
      skillDeltas,
    };
  }
}
