import { LearningPathNode, LearningPath } from '../entities/LearningPathNode';
import { SkillScore } from '../entities/SkillScore';
import { ADAPTIVE_THRESHOLDS, getRouteStrategy } from '@/core/constants/adaptiveThresholds';
import type { DailyTimeCommitment, OnboardingGoal } from '@/core/types/common';

export interface AdaptRoadmapOptions {
  placementCefr?: string;
  goal?: OnboardingGoal;
  dailyMinutes?: DailyTimeCommitment | number;
}

function normalizeEnglishPlacementTier(rawTier?: string): 'Pre-A1' | 'A1' | 'A2' | 'B1' | null {
  const normalized = rawTier?.trim().toUpperCase();
  if (normalized === 'B1' || normalized === 'B2' || normalized === 'C1' || normalized === 'C2') {
    return 'B1';
  }
  if (normalized === 'A2') return 'A2';
  if (normalized === 'A1') return 'A1';
  if (normalized === 'PRE-A1') return 'Pre-A1';
  return null;
}

export class RouteEngine {
  /**
   * Generates or adapts an adaptive learning path based on skill scores, completed nodes,
   * diagnostic mastery pass-through (>= 80% keeps status 'available' without fabricating
   * 'completed'), returning-learner reinforcement, and learner goal/time preferences.
   */
  public static adaptRoadmap(
    courseId: string,
    baseNodes: LearningPathNode[],
    skillScores: Record<string, SkillScore>,
    completedNodeIds: string[],
    completedReinforcementIds: string[],
    options?: AdaptRoadmapOptions
  ): LearningPath {
    const goal: OnboardingGoal = options?.goal ?? 'mastery';

    if (baseNodes.some((node) => node.mastery)) {
      const nonOptionalOpen = baseNodes.filter(
        (node) => !node.isOptional && node.status !== 'locked' && node.status !== 'completed'
      );
      const urgentPilot = nonOptionalOpen.find(
        (node) => node.status === 'reinforcement' || node.status === 'in_progress'
      );
      const unmasteredInPlacement = nonOptionalOpen.filter(
        (node) => (skillScores[node.skillId]?.score ?? -1) < node.requiredScore
      );
      const next =
        urgentPilot ??
        (goal === 'exam_prep' && unmasteredInPlacement.length === 0
          ? nonOptionalOpen.at(-1)
          : unmasteredInPlacement[0]) ??
        nonOptionalOpen[0];

      return {
        id: `roadmap_${courseId}`,
        courseId,
        title: 'Moslashuvchan Yo‘l Xaritasi',
        nodes: baseNodes,
        activeNodeId: next?.id ?? '',
        updatedAt: Date.now(),
      };
    }

    const effectivePlacementTier = normalizeEnglishPlacementTier(options?.placementCefr);
    const placementUnlockedIds = new Set<string>();
    let recommendedEntryId: string | undefined;
    if (courseId === 'course_eng_01' && effectivePlacementTier) {
      if (effectivePlacementTier === 'B1') {
        placementUnlockedIds.add('node_eng_a2_m1_directions');
        placementUnlockedIds.add('node_eng_b1_m1_travel');
        recommendedEntryId = 'node_eng_b1_m1_travel';
      } else if (effectivePlacementTier === 'A2') {
        placementUnlockedIds.add('node_eng_a2_m1_directions');
        recommendedEntryId = 'node_eng_a2_m1_directions';
      } else {
        recommendedEntryId = 'node_eng_a1_m1_greetings';
      }
    }

    const orderedBase = [...baseNodes].sort((a, b) => a.order - b.order);
    const completedSet = new Set<string>(completedNodeIds);
    const effectivePrereqIds = new Set<string>(completedNodeIds);
    const diagnosticSkippedIds = new Set<string>();
    const adaptedNodes: LearningPathNode[] = [];

    for (const baseNode of orderedBase) {
      const skillScoreObj = skillScores[baseNode.skillId];
      const score = skillScoreObj?.score;
      const needsPractice = score != null && score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN;
      const isCompleted = completedSet.has(baseNode.id);
      const strictPrereqsMet = baseNode.prerequisites.every((prereqId) => completedSet.has(prereqId));
      const prerequisitesMet = baseNode.prerequisites.every((prereqId) => effectivePrereqIds.has(prereqId));
      const cefrUnlocked = placementUnlockedIds.has(baseNode.id);

      const allowDiagnosticSkip =
        courseId !== 'course_eng_01' || (!baseNode.hasRichExercise && !baseNode.isCheckpoint);
      const unlockedViaDiagnostic =
        !isCompleted &&
        allowDiagnosticSkip &&
        score != null &&
        (prerequisitesMet || cefrUnlocked) &&
        score >= ADAPTIVE_THRESHOLDS.DIAGNOSTIC_MASTERY_MIN;

      if (isCompleted || unlockedViaDiagnostic) {
        effectivePrereqIds.add(baseNode.id);
      }
      if (unlockedViaDiagnostic) {
        diagnosticSkippedIds.add(baseNode.id);
      }

      const isUnlocked = prerequisitesMet || cefrUnlocked;
      const isPlacementUnlocked = cefrUnlocked || unlockedViaDiagnostic || (isUnlocked && !strictPrereqsMet);

      const reinforcementId = `reinf_${baseNode.id}`;
      const isReinforcementCompleted = completedReinforcementIds.includes(reinforcementId);

      let status: LearningPathNode['status'] = 'locked';
      if (isCompleted) {
        status = 'completed';
      } else if (!isUnlocked) {
        status = 'locked';
      } else if (needsPractice && !isReinforcementCompleted) {
        status = 'reinforcement';
      } else {
        status = 'available';
      }

      const routeStrategy = score != null ? getRouteStrategy(score) : undefined;
      const isPlacementRecommended = Boolean(
        recommendedEntryId && baseNode.id === recommendedEntryId && !isCompleted
      );

      const updatedNode: LearningPathNode = {
        ...baseNode,
        score,
        routeStrategy,
        isPlacementRecommended,
        isPlacementUnlocked,
        status,
      };

      adaptedNodes.push(updatedNode);

      // Attach reinforcement node when < 50% (even for returning completed nodes) or when previously completed
      if (needsPractice || isReinforcementCompleted) {
        const reinfUnlocked = isCompleted || isUnlocked;
        const reinforcementNode: LearningPathNode = {
          id: reinforcementId,
          courseId,
          skillId: baseNode.skillId,
          skillDomain: baseNode.skillDomain,
          cefrLevel: baseNode.cefrLevel,
          moduleId: baseNode.moduleId,
          moduleTitle: baseNode.moduleTitle,
          moduleTitleRu: baseNode.moduleTitleRu,
          unitId: baseNode.unitId,
          title: `Mustahkamlash: ${baseNode.title}`,
          titleRu: baseNode.titleRu ? `Закрепление: ${baseNode.titleRu}` : undefined,
          description: `Yo‘lchi AI tavsiyasi: ${baseNode.title} bo‘yicha tushunchalarni mustahkamlash mashqi`,
          descriptionRu: baseNode.titleRu
            ? `Рекомендация Yo‘lchi AI: закрепление темы «${baseNode.titleRu}»`
            : undefined,
          prerequisites: baseNode.prerequisites,
          requiredScore: ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN,
          status: isReinforcementCompleted ? 'completed' : reinfUnlocked ? 'available' : 'locked',
          routeStrategy: 'reinforcement',
          isPlacementUnlocked: isPlacementUnlocked || (reinfUnlocked && !strictPrereqsMet),
          isReinforcement: true,
          targetLessonId: baseNode.targetLessonId,
          estimatedMinutes: 5,
          order: baseNode.order + 0.5,
          score,
        };

        adaptedNodes.push(reinforcementNode);
      }
    }

    adaptedNodes.sort((a, b) => a.order - b.order);

    const placedEntryNode =
      recommendedEntryId && (effectivePlacementTier === 'A2' || effectivePlacementTier === 'B1')
        ? adaptedNodes.find(
            (n) =>
              n.id === recommendedEntryId &&
              (n.status === 'available' || n.status === 'reinforcement' || n.status === 'in_progress')
          )
        : undefined;

    const urgentRemediations = adaptedNodes.filter(
      (n) =>
        !n.isOptional &&
        (n.status === 'reinforcement' || (n.isReinforcement && n.status === 'available'))
    );
    const prioritizedRemediation =
      goal === 'exam_prep' && urgentRemediations.length > 1
        ? [...urgentRemediations].sort(
            (a, b) => (a.score ?? 0) - (b.score ?? 0) || a.order - b.order
          )[0]
        : urgentRemediations[0];

    const nonSkippedCandidates = adaptedNodes.filter(
      (n) =>
        !n.isOptional &&
        !n.isReinforcement &&
        !diagnosticSkippedIds.has(n.id) &&
        (n.status === 'available' || n.status === 'in_progress')
    );

    let selectedCandidate: LearningPathNode | undefined;
    if (goal === 'exam_prep') {
      selectedCandidate =
        nonSkippedCandidates.find((n) => n.isCheckpoint) ??
        [...nonSkippedCandidates].sort(
          (a, b) => (a.score ?? 100) - (b.score ?? 100) || a.order - b.order
        )[0];
    } else if (goal === 'skills_boost') {
      selectedCandidate =
        nonSkippedCandidates.find((n) => n.routeStrategy === 'targeted_practice') ??
        nonSkippedCandidates.find(
          (n) => n.hasRichExercise || (n.taskKind && n.taskKind !== 'standard')
        ) ??
        nonSkippedCandidates[0];
    } else {
      selectedCandidate =
        nonSkippedCandidates.find((n) => n.routeStrategy === 'targeted_practice') ??
        nonSkippedCandidates[0];
    }

    const skippedAvailable = adaptedNodes.filter(
      (n) =>
        !n.isOptional &&
        !n.isReinforcement &&
        (n.status === 'available' || n.status === 'in_progress')
    );
    const fallbackSkipped =
      goal === 'exam_prep'
        ? skippedAvailable.find((n) => n.isCheckpoint) ?? skippedAvailable.at(-1)
        : skippedAvailable[0];

    const activeNode =
      placedEntryNode ||
      prioritizedRemediation ||
      selectedCandidate ||
      fallbackSkipped ||
      adaptedNodes[0];

    return {
      id: `roadmap_${courseId}`,
      courseId,
      title: 'Moslashuvchan Yo‘l Xaritasi',
      nodes: adaptedNodes,
      activeNodeId: activeNode ? activeNode.id : '',
      updatedAt: Date.now(),
    };
  }

  /**
   * Evaluates if a specific node can be started by the learner.
   */
  public static canStartNode(node: LearningPathNode, completedNodeIds: string[]): boolean {
    if (node.status === 'locked') return false;
    if (node.mastery || node.isPlacementUnlocked || node.isPlacementRecommended) return true;
    return node.prerequisites.every((id) => completedNodeIds.includes(id));
  }
}
