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
  mastery: 'Asosiy mavzularni o‘zlashtirish',
  exam_prep: 'Imtihon va testlarga tayyorgarlik',
  skills_boost: 'Amaliy ko‘nikmalarni kuchaytirish',
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
 * Pure domain engine implementing BilimYo'l's 5-step Adaptive Learning Cycle,
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
          ? `${scoreValues.length} ko‘nikma baholangan`
          : hasCourseConfigured
          ? 'Reja tanlangan'
          : 'Boshlang‘ich tekshiruv',
      },
      {
        step: 2,
        code: '02',
        key: 'profile',
        status: stepStatus(2, hasDiagnostics),
        metricLabel: hasDiagnostics
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
          ? `Mustahkamlash: ${weakestSkill?.name ?? 'zaif mavzu'}`
          : `${completedLessonsCount + completedReinforcementsCount} mashq bajarilgan`,
      },
      {
        step: 5,
        code: '05',
        key: 'progress',
        status: stepStatus(5, hasProgressMeasured),
        metricLabel: hasDiagnostics
          ? `${overall}% o‘zlashtirish`
          : 'Qayta o‘lchash',
      },
    ];

    const loopUpdateSummary = !hasDiagnostics
      ? 'Diagnostika yoki ilk dars natijasi profilga yozilishi bilan keyingi shaxsiy qadam avtomatik yangilanadi.'
      : needsReinforcement && weakestSkill
      ? `"${weakestSkill.name}" mavzusida ${weakestScoreObj?.score ?? 0}% ko‘rsatkich qayd etildi — shu sababli keyingi qadam sifatida mustahkamlash mashqi tanlandi.`
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
        : 'Boshlang‘ich temp';

    const weakCount = scoreValues.filter((s) => s.score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN).length;

    return [
      {
        key: 'goal',
        label: 'Maqsad',
        value: GOAL_LABEL_UZ[goal],
        impact:
          goal === 'exam_prep'
            ? 'Yuqori ball beruvchi mavzular va test aniqligi birinchi o‘ringa qo‘yiladi.'
            : goal === 'skills_boost'
            ? 'Amaliy mashqlar va xatoni tushunish ulushi oshiriladi.'
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
        value: scoreValues.length > 0 ? `${overall}% (${SkillScoringEngine.getMasteryLabelUz(overall)})` : 'Boshlang‘ich baholash kutilmoqda',
        impact:
          overall < 50
            ? 'Murakkab bosqichga o‘tishdan oldin asosiy bo‘shliqni yopish tavsiya qilinadi.'
            : 'Keyingi bosqichga chiqish uchun mos qiyinlikdagi topshiriq tanlandi.',
      },
      {
        key: 'error_pattern',
        label: 'Xatolar va bo‘shliq',
        value:
          weakCount > 0
            ? `${weakCount} ta bo‘shliq (<50%)`
            : scoreValues.length > 0
            ? 'Kritik bo‘shliq yo‘q'
            : 'Xatolar hali qayd etilmagan',
        impact:
          weakCount > 0
            ? `"${activeNode?.title ?? weakestSkill?.name ?? 'Mavzu'}" bo‘yicha mustahkamlash mashqi yo‘l xaritasiga qo‘shildi.`
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
        impact: `${dailyMinutes} daqiqalik byudjetga mos qisqa dars + 5 daqiqalik nazorat mashqi rejalashtirildi.`,
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
        reason: 'Bilim profili va zaif mavzularni aniq xaritalash uchun boshlang‘ich qadam.',
      });
    } else if (weakestSkill && weakestScoreObj && weakestScoreObj.score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN) {
      tasks.push({
        id: 'micro_reinf',
        title: `Bo‘shliqni yopish: ${weakestSkill.name}`,
        minutes: 5,
        type: 'reinforcement',
        targetNodeId: `reinf_${activeNode?.id ?? weakestSkill.id}`,
        reason: `${weakestScoreObj.score}% natijani 60%+ darajaga ko‘tarish uchun maqsadli mashq.`,
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
          ? 'Oldingi xatolarni qayta mustahkamlash bosqichi.'
          : 'Ta’lim yo‘lingizdagi navbatdagi asosiy bosqich.',
      });
    }

    tasks.push({
      id: 'micro_review',
      title: 'Yo‘lchi AI bilan 1 ta tezkor savol-javob tahlili',
      minutes: dailyMinutes >= 30 ? 10 : 5,
      type: 'lesson',
      reason: 'Formative feedback: qoidani mustaqil tushuntira olish darajasini tekshirish.',
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
