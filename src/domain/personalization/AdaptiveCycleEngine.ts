import { ADAPTIVE_THRESHOLDS } from '@/core/constants/adaptiveThresholds';
import { DailyTimeCommitment, OnboardingGoal } from '@/core/types/common';
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
  hasDiagnosticBaseline: boolean;
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

const GOAL_LABEL_UZ: Record<OnboardingGoal, string> = {
  mastery: 'Asosiy mavzularni o‘zlashtirish',
  exam_prep: 'Imtihon va testlarga tayyorgarlik',
  skills_boost: 'Amaliy ko‘nikmalarni kuchaytirish',
};

function resolveCourseId(input: AdaptiveContextInput): string | undefined {
  return input.course?.id ?? input.roadmap?.courseId ?? input.profile?.selectedCourseId;
}

function resolveEffectiveContext(input: AdaptiveContextInput): {
  courseId?: string;
  skills: Skill[];
  skillScores: Record<string, SkillScore>;
  placementSkillScores: Record<string, SkillScore>;
  isMathPilot: boolean;
  mathObjectives: LearningPathNode[];
} {
  const courseId = resolveCourseId(input);
  const placementSkillScores: Record<string, SkillScore> = courseId
    ? (input.profile?.placementSkillScoresByCourse?.[courseId] ?? {})
    : {};
  const mergedScores: Record<string, SkillScore> = {
    ...placementSkillScores,
    ...input.skillScores,
  };
  const mergedSkills: Skill[] = [...input.skills];
  const mathObjectives = (input.roadmap?.nodes ?? []).filter(
    (node) => Boolean(node.mastery) && !node.isOptional
  );
  const isMathPilot = mathObjectives.length > 0;

  if (isMathPilot) {
    for (const node of mathObjectives) {
      if (!mergedSkills.some((s) => s.id === node.skillId)) {
        mergedSkills.push({
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
        mergedScores[node.skillId] = {
          skillId: node.skillId,
          courseId: node.courseId,
          score: pilotScore,
          lastUpdated: input.roadmap?.updatedAt ?? Date.now(),
          masteryLevel: SkillScoringEngine.getMasteryLevel(pilotScore),
        };
      }
    }
  }

  return {
    courseId,
    skills: mergedSkills,
    skillScores: mergedScores,
    placementSkillScores,
    isMathPilot,
    mathObjectives,
  };
}

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

function resolveActiveNode(roadmap: LearningPath | null | undefined): LearningPathNode | null {
  if (!roadmap || roadmap.nodes.length === 0) return null;
  return (
    roadmap.nodes.find((n) => n.id === roadmap.activeNodeId) ||
    roadmap.nodes.find(
      (n) => n.status === 'reinforcement' || n.status === 'available' || n.status === 'in_progress'
    ) ||
    roadmap.nodes[0]
  );
}

function resolveReinforcementTargetNodeId(
  roadmap: LearningPath | null | undefined,
  weakestSkillId: string
): string {
  if (roadmap) {
    const activeReinf = roadmap.nodes.find(
      (n) => n.isReinforcement && n.skillId === weakestSkillId && n.status !== 'completed'
    );
    if (activeReinf) return activeReinf.id;

    const anyReinf = roadmap.nodes.find(
      (n) => n.isReinforcement && n.skillId === weakestSkillId
    );
    if (anyReinf) return anyReinf.id;

    const baseNode =
      roadmap.nodes.find(
        (n) => !n.isReinforcement && n.skillId === weakestSkillId && n.status !== 'completed'
      ) ?? roadmap.nodes.find((n) => !n.isReinforcement && n.skillId === weakestSkillId);
    if (baseNode) {
      return baseNode.mastery ? baseNode.id : `reinf_${baseNode.id}`;
    }
  }
  return `reinf_${weakestSkillId}`;
}

/**
 * Pure domain engine implementing BilimYo'l's 5-step Adaptive Learning Cycle,
 * 6-input Explainable AI transparent reasoning, and honest cycle effectiveness metrics.
 */
export class AdaptiveCycleEngine {
  public static evaluateCycle(input: AdaptiveContextInput): AdaptiveCycleSnapshot {
    const { course, profile, roadmap } = input;
    const {
      courseId,
      skills,
      skillScores,
      isMathPilot,
      mathObjectives,
    } = resolveEffectiveContext(input);

    const scoreValues = Object.values(skillScores);
    const hasDiagnostics =
      scoreValues.length > 0 ||
      Boolean(courseId && profile?.placementScoreByCourse?.[courseId] != null);

    const completedLessonsCount = course
      ? course.lessons.filter((id) => profile?.completedLessonIds.includes(id)).length
      : (profile?.completedLessonIds.length ?? 0);
    const completedNodesCount = roadmap
      ? roadmap.nodes.filter(
          (n) => !n.isReinforcement && !n.isOptional && n.status === 'completed'
        ).length
      : (profile?.completedNodeIds.length ?? 0);
    const completedReinforcementsCount = roadmap
      ? roadmap.nodes.filter((n) => n.isReinforcement && n.status === 'completed').length
      : (profile?.completedReinforcementIds.length ?? 0);

    const weakScores = scoreValues.filter((s) => s.score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN);
    const strongScores = scoreValues.filter((s) => s.score >= ADAPTIVE_THRESHOLDS.STANDARD_MIN);
    const { skill: weakestSkill, scoreObj: weakestScoreObj } = findWeakestSkill(skills, skillScores);
    const activeNode = resolveActiveNode(roadmap);

    const hasPilotRemediation = mathObjectives.some(
      (n) =>
        n.status === 'reinforcement' ||
        n.mastery?.state === 'needs_review' ||
        Boolean(n.mastery?.reviewDue)
    );
    const needsReinforcement =
      weakScores.length > 0 ||
      hasPilotRemediation ||
      Boolean(
        activeNode &&
          (activeNode.isReinforcement ||
            activeNode.status === 'reinforcement' ||
            activeNode.mastery?.state === 'needs_review')
      );

    const hasPracticeActivity =
      completedLessonsCount > 0 || completedReinforcementsCount > 0 || completedNodesCount > 0;
    const hasCourseConfigured = Boolean(
      (course && profile?.courseLevels?.[course.id]) ||
        hasDiagnostics ||
        hasPracticeActivity ||
        isMathPilot
    );
    const hasPathSelected = Boolean(hasCourseConfigured && (roadmap?.nodes.length || activeNode));
    const hasProgressMeasured = hasPracticeActivity && (hasDiagnostics || isMathPilot);

    let activeStep: AdaptiveStepId = 1;
    if (!hasDiagnostics && !hasPracticeActivity) {
      activeStep = 1;
    } else if (hasPracticeActivity && hasProgressMeasured) {
      activeStep = 5;
    } else if (hasPathSelected) {
      activeStep = 3;
    } else {
      activeStep = 2;
    }

    const stepStatus = (
      stepNum: AdaptiveStepId,
      doneCondition: boolean
    ): AdaptiveStepState['status'] => {
      if (activeStep === stepNum) return 'active';
      if (doneCondition || stepNum < activeStep) return 'completed';
      return 'upcoming';
    };

    const overall =
      scoreValues.length > 0
        ? SkillScoringEngine.computeOverallScore(skillScores)
        : isMathPilot && mathObjectives.length > 0
        ? Math.round((100 * completedNodesCount) / mathObjectives.length)
        : 0;

    const steps: AdaptiveStepState[] = [
      {
        step: 1,
        code: '01',
        key: 'diagnostic',
        status: stepStatus(1, hasDiagnostics || hasPracticeActivity),
        metricLabel: hasDiagnostics
          ? `${scoreValues.length} ko‘nikma baholangan`
          : hasCourseConfigured
          ? 'Reja tanlangan'
          : 'Boshlang‘ich tekshiruv',
      },
      {
        step: 2,
        code: '02',
        key: 'profile',
        status: stepStatus(2, hasDiagnostics || hasPracticeActivity),
        metricLabel:
          hasDiagnostics || hasPracticeActivity
            ? weakScores.length > 0
              ? `${weakScores.length} bo‘shliq · ${strongScores.length} kuchli`
              : `${strongScores.length} kuchli mavzu`
            : 'Bo‘shliqlar tahlili',
      },
      {
        step: 3,
        code: '03',
        key: 'path',
        status: stepStatus(3, hasPathSelected),
        metricLabel: activeNode ? activeNode.title : 'Mos qadam tanlanadi',
      },
      {
        step: 4,
        code: '04',
        key: 'practice',
        status: stepStatus(4, hasPracticeActivity),
        metricLabel: needsReinforcement
          ? `Mustahkamlash: ${weakestSkill?.name ?? activeNode?.title ?? 'zaif mavzu'}`
          : `${Math.max(completedLessonsCount, completedNodesCount) + completedReinforcementsCount} mashq bajarilgan`,
      },
      {
        step: 5,
        code: '05',
        key: 'progress',
        status: stepStatus(5, hasProgressMeasured),
        metricLabel: hasProgressMeasured
          ? `${overall}% o‘zlashtirish`
          : 'Qayta o‘lchash',
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

    const loopUpdateSummary =
      !hasDiagnostics && !hasPracticeActivity
        ? 'Diagnostika yoki ilk dars natijasi profilga yozilishi bilan keyingi shaxsiy qadam avtomatik yangilanadi.'
        : needsReinforcement && (weakestSkill || activeNode)
        ? `"${weakestSkill?.name ?? activeNode?.title ?? 'Mavzu'}" mavzusida ${weakestScoreObj?.score ?? 0}% ko‘rsatkich qayd etildi — shu sababli keyingi qadam sifatida mustahkamlash mashqi tanlandi.`
        : hasTargetedPractice && weakestSkill
        ? `"${weakestSkill.name}" mavzusi ${weakestScoreObj?.score ?? 0}% (50–69%) darajada — 70%+ mustahkam natija uchun maqsadli mashq tavsiya qilindi.`
        : `So‘nggi natijalar asosida umumiy o‘zlashtirish ${overall}% ga yetdi va navbatdagi bosqich "${activeNode?.title ?? 'keyingi mavzu'}" ochildi.`;

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
    const { course, profile, roadmap } = input;
    const { skills, skillScores, mathObjectives, isMathPilot } = resolveEffectiveContext(input);
    const scoreValues = Object.values(skillScores);
    const completedNodesCount = mathObjectives.filter((n) => n.status === 'completed').length;
    const overall =
      scoreValues.length > 0
        ? SkillScoringEngine.computeOverallScore(skillScores)
        : isMathPilot && mathObjectives.length > 0
        ? Math.round((100 * completedNodesCount) / mathObjectives.length)
        : 0;
    const { skill: weakestSkill, scoreObj: weakestScoreObj } = findWeakestSkill(skills, skillScores);
    const goal = profile?.goal ?? 'mastery';
    const dailyMinutes = profile?.dailyMinutes ?? 15;
    const completedLessons = course
      ? course.lessons.filter((id) => profile?.completedLessonIds.includes(id)).length
      : (profile?.completedLessonIds.length ?? 0);
    const completedCount = Math.max(completedLessons, completedNodesCount);
    const streakDays = profile?.streakDays ?? 0;
    const activeNode = resolveActiveNode(roadmap);

    const speedLabel =
      completedCount >= 4 || streakDays >= 5
        ? 'Yuqori sur’at'
        : completedCount >= 1
        ? 'Barqaror ritm'
        : 'Boshlang‘ich temp';

    const weakCount = scoreValues.filter(
      (s) => s.score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN
    ).length;
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
            ? 'Nazorat bosqichlari va eng zaif mavzular birinchi o‘ringa qo‘yiladi.'
            : goal === 'skills_boost'
            ? 'Amaliy mashqlar va interaktiv topshiriqlar ulushi oshiriladi.'
            : 'Tayanch tushunchalar ketma-ket va mustahkam o‘zlashtiriladi.',
      },
      {
        key: 'skill_profile',
        label: 'Ko‘nikmalar profili',
        value: weakestSkill
          ? `Fokus: ${weakestSkill.name}`
          : `${skills.length} ta tayanch ko‘nikma`,
        impact: weakestSkill
          ? `Eng past ko‘rsatkich (${weakestScoreObj?.score ?? 0}%) shu mavzuda aniqlangani uchun ustuvor etib belgilandi.`
          : 'Diagnostikadan so‘ng kuchli va zaif mavzular xaritasi shakllanadi.',
      },
      {
        key: 'knowledge_level',
        label: 'Bilim darajasi',
        value:
          scoreValues.length > 0
            ? `${overall}% (${SkillScoringEngine.getMasteryLabelUz(overall)})`
            : 'Boshlang‘ich baholash kutilmoqda',
        impact:
          scoreValues.length > 0 && overall < 50
            ? 'Murakkab bosqichga o‘tishdan oldin asosiy bo‘shliqni yopish tavsiya qilinadi.'
            : 'Keyingi bosqichga chiqish uchun mos qiyinlikdagi topshiriq tanlandi.',
      },
      {
        key: 'error_pattern',
        label: 'Xatolar va bo‘shliq',
        value:
          weakCount > 0
            ? `${weakCount} ta bo‘shliq (<50%)`
            : targetedCount > 0
            ? `${targetedCount} ta maqsadli mashq (50–69%)`
            : scoreValues.length > 0
            ? 'Kritik bo‘shliq yo‘q'
            : 'Xatolar hali qayd etilmagan',
        impact:
          weakCount > 0
            ? `"${weakestSkill?.name ?? activeNode?.title ?? 'Mavzu'}" bo‘yicha mustahkamlash mashqi yo‘l xaritasiga qo‘shildi.`
            : targetedCount > 0
            ? `"${weakestSkill?.name ?? activeNode?.title ?? 'Mavzu'}" bo‘yicha 70%+ ga chiqish uchun maqsadli mashq tavsiya etildi.`
            : 'Xato aniqlanishi bilan tizim avtomatik tarzda qayta mashq tavsiya qiladi.',
      },
      {
        key: 'learning_speed',
        label: 'O‘rganish tezligi',
        value: speedLabel,
        impact: `${completedCount} dars yakunlangan · ${streakDays} kun ketma-ket faollik asosida qadam yuklamasi moslandi.`,
      },
      {
        key: 'daily_time',
        label: 'Kunlik vaqt',
        value: `${dailyMinutes} daqiqa / kun`,
        impact:
          dailyMinutes <= 5
            ? '5 daqiqalik mikro-byudjetga mos bitta aniq vazifa ajratildi.'
            : `${dailyMinutes} daqiqalik byudjetga mos dars va nazorat mashqlari taqsimlandi.`,
      },
    ];
  }

  public static buildDailyMicroTasks(input: AdaptiveContextInput): DailyMicroTask[] {
    const { roadmap, profile } = input;
    const { skills, skillScores } = resolveEffectiveContext(input);
    const dailyMinutes = profile?.dailyMinutes ?? 15;
    const activeNode = resolveActiveNode(roadmap);
    const { skill: weakestSkill, scoreObj: weakestScoreObj } = findWeakestSkill(skills, skillScores);
    const hasScores = Object.keys(skillScores).length > 0;
    const tasks: DailyMicroTask[] = [];
    const usedNodeIds = new Set<string>();

    if (!hasScores) {
      tasks.push({
        id: 'micro_diag',
        title: '5 daqiqalik adaptiv diagnostika',
        minutes: 5,
        type: 'diagnostic',
        reason: 'Bilim profili va zaif mavzularni aniq xaritalash uchun boshlang‘ich qadam.',
      });
    } else if (
      weakestSkill &&
      weakestScoreObj &&
      weakestScoreObj.score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN
    ) {
      const reinfNodeId = resolveReinforcementTargetNodeId(roadmap, weakestSkill.id);
      usedNodeIds.add(reinfNodeId);
      tasks.push({
        id: 'micro_reinf',
        title: `Bo‘shliqni yopish: ${weakestSkill.name}`,
        minutes: 5,
        type: 'reinforcement',
        targetNodeId: reinfNodeId,
        reason: `${weakestScoreObj.score}% natijani 50%+ darajaga ko‘tarish uchun maqsadli mashq.`,
      });
    } else if (
      weakestSkill &&
      weakestScoreObj &&
      weakestScoreObj.score <= ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MAX
    ) {
      const targetedNode =
        roadmap?.nodes.find(
          (n) => !n.isReinforcement && n.skillId === weakestSkill.id && n.status !== 'completed' && n.status !== 'locked'
        ) ?? activeNode;
      if (targetedNode?.id) usedNodeIds.add(targetedNode.id);
      tasks.push({
        id: 'micro_targeted',
        title: `Maqsadli mashq: ${weakestSkill.name}`,
        minutes: 5,
        type: 'reinforcement',
        targetNodeId: targetedNode?.id,
        reason: `${weakestScoreObj.score}% (50–69%) natijani 70%+ mustahkam darajaga olib chiqish uchun qo‘shimcha mashq.`,
      });
    }

    const nextLessonNode =
      activeNode && !usedNodeIds.has(activeNode.id)
        ? activeNode
        : roadmap?.nodes.find(
            (n) =>
              !n.isOptional &&
              !usedNodeIds.has(n.id) &&
              (n.status === 'available' || n.status === 'reinforcement' || n.status === 'in_progress')
          );

    if (nextLessonNode) {
      tasks.push({
        id: `micro_node_${nextLessonNode.id}`,
        title: nextLessonNode.title,
        minutes: Math.min(nextLessonNode.estimatedMinutes, dailyMinutes >= 30 ? 15 : 10),
        type: nextLessonNode.isReinforcement ? 'reinforcement' : 'lesson',
        targetNodeId: nextLessonNode.id,
        reason: nextLessonNode.isReinforcement
          ? 'Oldingi xatolarni qayta mustahkamlash bosqichi.'
          : 'Ta’lim yo‘lingizdagi navbatdagi asosiy bosqich.',
      });
    }

    tasks.push({
      id: 'micro_review',
      title: 'Yo‘lchi AI bilan 1 ta tezkor savol-javob tahlili',
      minutes: dailyMinutes >= 60 ? 15 : dailyMinutes >= 30 ? 10 : 5,
      type: 'lesson',
      reason: 'Formative feedback: qoidani mustaqil tushuntira olish darajasini tekshirish.',
    });

    const maxTasks = dailyMinutes <= 5 ? 1 : dailyMinutes <= 15 ? 2 : 3;
    return tasks.slice(0, maxTasks);
  }

  public static measureEffectiveness(input: AdaptiveContextInput): AdaptiveEffectivenessMetrics {
    const { course, profile, roadmap } = input;
    const {
      courseId,
      skills,
      skillScores,
      placementSkillScores,
      mathObjectives,
    } = resolveEffectiveContext(input);

    const scoreValues = Object.values(skillScores);
    const hasScores = scoreValues.length > 0;
    const currentScore = hasScores ? SkillScoringEngine.computeOverallScore(skillScores) : 0;

    const explicitPlacementScore =
      courseId != null ? profile?.placementScoreByCourse?.[courseId] : undefined;
    const hasPlacementSkills = Object.keys(placementSkillScores).length > 0;
    const hasDiagnosticBaseline = explicitPlacementScore != null || hasPlacementSkills;

    const completedReinforcements = new Set(profile?.completedReinforcementIds ?? []);
    const completedLessons = course
      ? course.lessons.filter((id) => profile?.completedLessonIds.includes(id)).length
      : (profile?.completedLessonIds.length ?? 0);
    const completedNodesCount = roadmap
      ? roadmap.nodes.filter(
          (n) => !n.isReinforcement && !n.isOptional && n.status === 'completed'
        ).length
      : mathObjectives.filter((n) => n.status === 'completed').length;
    const completedCourseReinforcements = roadmap
      ? roadmap.nodes.filter((n) => n.isReinforcement && completedReinforcements.has(n.id)).length
      : completedReinforcements.size;

    const hasPracticeActivity =
      completedLessons > 0 || completedCourseReinforcements > 0 || completedNodesCount > 0;

    const baselineScore = hasDiagnosticBaseline
      ? explicitPlacementScore ?? SkillScoringEngine.computeOverallScore(placementSkillScores)
      : 0;

    const growthDelta =
      hasDiagnosticBaseline && hasPracticeActivity && hasScores
        ? Math.max(0, currentScore - baselineScore)
        : 0;

    let detectedGapsCount = 0;
    let closedGapsCount = 0;

    const skillDeltas: AdaptiveSkillDelta[] = skills.map((skill) => {
      const scoreObj = skillScores[skill.id];
      const plcObj = placementSkillScores[skill.id];
      const hasReinforcementCompleted = Array.from(completedReinforcements).some(
        (rid) =>
          roadmap?.nodes.some((n) => n.id === rid && n.skillId === skill.id) ?? false
      );

      if (!scoreObj) {
        return {
          skillId: skill.id,
          skillName: skill.name,
          baseline: plcObj?.score ?? 0,
          current: 0,
          delta: 0,
          status: 'unassessed',
        };
      }

      const skillBaseline = plcObj ? plcObj.score : 0;
      const isGapNow = scoreObj.score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN;
      const hadDiagnosticGap =
        plcObj != null && plcObj.score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN;
      const wasGapClosed =
        hasPracticeActivity &&
        (hasReinforcementCompleted || hadDiagnosticGap) &&
        scoreObj.score >= ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN;

      if (isGapNow || hasReinforcementCompleted || hadDiagnosticGap) {
        detectedGapsCount += 1;
      }
      if (wasGapClosed) {
        closedGapsCount += 1;
      }

      const status: AdaptiveSkillDelta['status'] =
        scoreObj.score >= ADAPTIVE_THRESHOLDS.STANDARD_MIN
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
        delta: plcObj && hasPracticeActivity ? Math.max(0, scoreObj.score - skillBaseline) : 0,
        status,
      };
    });

    const adaptiveUpdatesCount =
      Math.max(completedLessons, completedNodesCount) +
      completedCourseReinforcements +
      (hasDiagnosticBaseline ? 1 : 0);
    const dailyMinutesBudget = profile?.dailyMinutes ?? 15;
    const paceEfficiencyPct = hasPracticeActivity
      ? Math.min(
          100,
          Math.round(
            45 +
              Math.min(
                55,
                Math.max(completedLessons, completedNodesCount) * 14 +
                  completedCourseReinforcements * 18
              )
          )
        )
      : 0;

    return {
      hasDiagnosticBaseline,
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
