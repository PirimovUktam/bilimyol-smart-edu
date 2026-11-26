import { LearningPathNode, LearningPath } from '../entities/LearningPathNode';
import { SkillScore } from '../entities/SkillScore';
import { ADAPTIVE_THRESHOLDS, getRouteStrategy } from '@/core/constants/adaptiveThresholds';

export interface AdaptRoadmapOptions {
  placementCefr?: string;
}

export class RouteEngine {
  /**
   * Generates or adapts an adaptive learning path based on skill scores and completed nodes.
   */
  public static adaptRoadmap(
    courseId: string,
    baseNodes: LearningPathNode[],
    skillScores: Record<string, SkillScore>,
    completedNodeIds: string[],
    completedReinforcementIds: string[],
    options?: AdaptRoadmapOptions
  ): LearningPath {
    if (baseNodes.some((node) => node.mastery)) {
      const next = baseNodes.find((node) => !node.isOptional && node.status !== 'locked' && node.status !== 'completed');
      return {
        id: `roadmap_${courseId}`, courseId, title: 'Moslashuvchan Yo‘l Xaritasi',
        nodes: baseNodes, activeNodeId: next?.id ?? '', updatedAt: Date.now(),
      };
    }

    const placementUnlockedIds = new Set<string>();
    let recommendedEntryId: string | undefined;
    if (courseId === 'course_eng_01' && options?.placementCefr) {
      if (options.placementCefr === 'B1' || options.placementCefr === 'B2' || options.placementCefr === 'C1' || options.placementCefr === 'C2') {
        placementUnlockedIds.add('node_eng_a2_m1_directions');
        placementUnlockedIds.add('node_eng_b1_m1_travel');
        recommendedEntryId = 'node_eng_b1_m1_travel';
      } else if (options.placementCefr === 'A2') {
        placementUnlockedIds.add('node_eng_a2_m1_directions');
        recommendedEntryId = 'node_eng_a2_m1_directions';
      } else if (options.placementCefr === 'A1' || options.placementCefr === 'Pre-A1') {
        recommendedEntryId = 'node_eng_a1_m1_greetings';
      }
    }

    const adaptedNodes: LearningPathNode[] = [];

    for (const baseNode of baseNodes) {
      const skillScoreObj = skillScores[baseNode.skillId];
      const score = skillScoreObj?.score;
      const needsPractice = score != null && score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN;
      const isCompleted = completedNodeIds.includes(baseNode.id);
      const isPlacementUnlocked = placementUnlockedIds.has(baseNode.id);

      const reinforcementId = `reinf_${baseNode.id}`;
      const isReinforcementCompleted = completedReinforcementIds.includes(reinforcementId);

      // Check prerequisites
      const prerequisitesMet =
        baseNode.prerequisites.every((prereqId) => completedNodeIds.includes(prereqId)) ||
        isPlacementUnlocked;

      let status: LearningPathNode['status'] = 'locked';

      if (isCompleted) {
        status = 'completed';
      } else if (!prerequisitesMet) {
        status = 'locked';
      } else {
        // Prerequisites are met
        if (needsPractice && !isReinforcementCompleted) {
          // Score < 50 and reinforcement not yet completed => requires reinforcement
          status = 'reinforcement';
        } else {
          status = 'available';
        }
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

      // If the node is in reinforcement or has low score, we attach reinforcement flow
      if ((needsPractice && !isCompleted) || isReinforcementCompleted) {

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
          prerequisites: [baseNode.id], // Follows after interactive lesson attempt
          requiredScore: ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN,
          status: isReinforcementCompleted ? 'completed' : prerequisitesMet ? 'available' : 'locked',
          routeStrategy: 'reinforcement',
          isReinforcement: true,
          estimatedMinutes: 5,
          order: baseNode.order + 0.5,
          score: score,
        };

        adaptedNodes.push(reinforcementNode);
      }
    }

    // Sort nodes in display order
    adaptedNodes.sort((a, b) => a.order - b.order);

    // Determine current active node (reinforcement -> placement entry -> targeted_practice -> available/in_progress)
    const activeNode =
      adaptedNodes.find((n) => n.status === 'reinforcement') ||
      adaptedNodes.find((n) => n.isPlacementRecommended && n.status !== 'completed' && n.status !== 'locked') ||
      adaptedNodes.find((n) => n.status === 'available' && n.routeStrategy === 'targeted_practice') ||
      adaptedNodes.find((n) => n.status === 'available' || n.status === 'in_progress') ||
      adaptedNodes[0];

    return {
      id: `roadmap_${courseId}`,
      courseId,
      title: `Moslashuvchan Yo‘l Xaritasi`,
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
