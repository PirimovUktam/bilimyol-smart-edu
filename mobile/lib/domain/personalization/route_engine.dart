import '../entities/learning_path_node.dart';
import '../entities/skill_score.dart';
import '../../core/constants/adaptive_thresholds.dart';

class RouteEngine {
  /// Generates or adapts an adaptive learning path based on skill scores and completed nodes.
  static LearningPath adaptRoadmap({
    required String courseId,
    required List<LearningPathNode> baseNodes,
    required Map<String, SkillScore> skillScores,
    required List<String> completedNodeIds,
    required List<String> completedReinforcementIds,
  }) {
    final List<LearningPathNode> adaptedNodes = [];

    for (final baseNode in baseNodes) {
      final skillScoreObj = skillScores[baseNode.skillId];
      final score = skillScoreObj?.score ?? 0;
      final isCompleted = completedNodeIds.contains(baseNode.id);

      // Check prerequisites
      final prerequisitesMet = baseNode.prerequisites.every(
        (prereqId) => completedNodeIds.contains(prereqId),
      );

      NodeStatus status = NodeStatus.locked;

      if (isCompleted) {
        status = NodeStatus.completed;
      } else if (!prerequisitesMet) {
        status = NodeStatus.locked;
      } else {
        // Prerequisites are met
        if (score < AdaptiveThresholds.targetedPracticeMin) {
          // Score < 50 => requires reinforcement
          status = NodeStatus.reinforcement;
        } else {
          status = NodeStatus.available;
        }
      }

      final updatedNode = baseNode.copyWith(
        score: score,
        status: status,
      );

      adaptedNodes.pushOrAdd(updatedNode);

      // If the node is in reinforcement or has low score, attach reinforcement node
      if (score < AdaptiveThresholds.targetedPracticeMin && !isCompleted) {
        final reinforcementId = 'reinf_${baseNode.id}';
        final isReinforcementCompleted = completedReinforcementIds.contains(reinforcementId);

        final reinforcementNode = LearningPathNode(
          id: reinforcementId,
          courseId: courseId,
          skillId: baseNode.skillId,
          title: 'Mustahkamlash: ${baseNode.title}',
          description: 'Yo‘lchi AI tavsiyasi: ${baseNode.title} bo‘yicha tushunchalarni mustahkamlash mashqi',
          prerequisites: [baseNode.id],
          requiredScore: AdaptiveThresholds.targetedPracticeMin,
          status: isReinforcementCompleted ? NodeStatus.completed : NodeStatus.available,
          isReinforcement: true,
          estimatedMinutes: 5,
          order: baseNode.order + 0.5,
          score: score,
        );

        adaptedNodes.pushOrAdd(reinforcementNode);
      }
    }

    // Sort nodes by order
    adaptedNodes.sort((a, b) => a.order.compareTo(b.order));

    // Determine active node
    final activeNode = adaptedNodes.firstWhere(
      (n) => n.status == NodeStatus.reinforcement || n.status == NodeStatus.available || n.status == NodeStatus.inProgress,
      orElse: () => adaptedNodes.isNotEmpty ? adaptedNodes.first : baseNodes.first,
    );

    return LearningPath(
      id: 'roadmap_$courseId',
      courseId: courseId,
      title: 'Moslashuvchan Yo‘l Xaritasi',
      nodes: adaptedNodes,
      activeNodeId: activeNode.id,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Evaluates if a specific node can be started by the learner.
  static bool canStartNode(LearningPathNode node, List<String> completedNodeIds) {
    if (node.status == NodeStatus.locked) return false;
    return node.prerequisites.every((id) => completedNodeIds.contains(id));
  }
}

extension _ListExt<T> on List<T> {
  void pushOrAdd(T item) => add(item);
}
