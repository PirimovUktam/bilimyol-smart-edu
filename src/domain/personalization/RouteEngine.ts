import { LearningPathNode, LearningPath } from '../entities/LearningPathNode';
import { SkillScore } from '../entities/SkillScore';
import { ADAPTIVE_THRESHOLDS } from '@/core/constants/adaptiveThresholds';

export class RouteEngine {
  /**
   * Generates or adapts an adaptive learning path based on skill scores and completed nodes.
   */
  public static adaptRoadmap(
    courseId: string,
    baseNodes: LearningPathNode[],
    skillScores: Record<string, SkillScore>,
    completedNodeIds: string[],
    completedReinforcementIds: string[]
  ): LearningPath {
    const adaptedNodes: LearningPathNode[] = [];

    for (const baseNode of baseNodes) {
      const skillScoreObj = skillScores[baseNode.skillId];
      const score = skillScoreObj ? skillScoreObj.score : 0;
      const isCompleted = completedNodeIds.includes(baseNode.id);

      // Check prerequisites
      const prerequisitesMet = baseNode.prerequisites.every((prereqId) =>
        completedNodeIds.includes(prereqId)
      );

      let status: LearningPathNode['status'] = 'locked';

      if (isCompleted) {
        status = 'completed';
      } else if (!prerequisitesMet) {
        status = 'locked';
      } else {
        // Prerequisites are met
        if (score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN) {
          // Score < 50 => requires reinforcement
          status = 'reinforcement';
        } else {
          status = 'available';
        }
      }

      const updatedNode: LearningPathNode = {
        ...baseNode,
        score,
        status,
      };

      adaptedNodes.push(updatedNode);

      // If the node is in reinforcement or has low score, we attach reinforcement flow
      if (score < ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN && !isCompleted) {
        const reinforcementId = `reinf_${baseNode.id}`;
        const isReinforcementCompleted = completedReinforcementIds.includes(reinforcementId);

        const reinforcementNode: LearningPathNode = {
          id: reinforcementId,
          courseId,
          skillId: baseNode.skillId,
          title: `Mustahkamlash: ${baseNode.title}`,
          description: `Yo‘lchi AI tavsiyasi: ${baseNode.title} bo‘yicha tushunchalarni mustahkamlash mashqi`,
          prerequisites: [baseNode.id], // Follows after interactive lesson attempt
          requiredScore: ADAPTIVE_THRESHOLDS.TARGETED_PRACTICE_MIN,
          status: isReinforcementCompleted ? 'completed' : 'available',
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

    // Determine current active node
    const activeNode =
      adaptedNodes.find((n) => n.status === 'reinforcement' || n.status === 'available' || n.status === 'in_progress') ||
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
    return node.prerequisites.every((id) => completedNodeIds.includes(id));
  }
}
