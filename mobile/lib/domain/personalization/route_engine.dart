import '../entities/learning_path_node.dart';
import '../entities/skill_score.dart';
import '../../core/constants/adaptive_thresholds.dart';

class RouteEngine {
  static String? _normalizedEnglishPlacementTier(String? rawTier) {
    final normalized = rawTier?.trim().toUpperCase();
    if (normalized == 'B1' ||
        normalized == 'B2' ||
        normalized == 'C1' ||
        normalized == 'C2') {
      return 'B1';
    }
    if (normalized == 'A2') return 'A2';
    if (normalized == 'A1') return 'A1';
    if (normalized == 'PRE-A1') return 'Pre-A1';
    return null;
  }

  /// Generates or adapts an adaptive learning path based on skill scores and completed nodes.
  static LearningPath adaptRoadmap({
    required String courseId,
    required List<LearningPathNode> baseNodes,
    required Map<String, SkillScore> skillScores,
    required List<String> completedNodeIds,
    required List<String> completedReinforcementIds,
    String? placementCefrTier,
  }) {
    final effectivePlacementTier = _normalizedEnglishPlacementTier(
      placementCefrTier,
    );
    if (baseNodes.any((node) => node.serverMastery)) {
      final next = baseNodes
          .where((node) => !node.isOptional && node.status != NodeStatus.locked &&
              node.status != NodeStatus.completed)
          .firstOrNull;
      return LearningPath(
        id: 'roadmap_$courseId',
        courseId: courseId,
        title: 'Moslashuvchan Yo‘l Xaritasi',
        nodes: baseNodes,
        activeNodeId: next?.id ?? '',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    final List<LearningPathNode> adaptedNodes = [];

    for (final baseNode in baseNodes) {
      final skillScoreObj = skillScores[baseNode.skillId];
      final int? score = skillScoreObj?.score;
      final bool needsPractice =
          score != null && score < AdaptiveThresholds.targetedPracticeMin;
      final isCompleted = completedNodeIds.contains(baseNode.id);

      // Check prerequisites (or placement-guided entry for English A2/B1)
      final prerequisitesMet = baseNode.prerequisites.every(
        (prereqId) => completedNodeIds.contains(prereqId),
      );
      final placementUnlocked =
          courseId == 'course_eng_01' &&
          ((effectivePlacementTier == 'A2' &&
                  baseNode.id == 'node_eng_a2_m1_directions') ||
              (effectivePlacementTier == 'B1' &&
                  (baseNode.id == 'node_eng_a2_m1_directions' ||
                      baseNode.id == 'node_eng_b1_m1_travel')));

      NodeStatus status = NodeStatus.locked;

      if (isCompleted) {
        status = NodeStatus.completed;
      } else if (!prerequisitesMet && !placementUnlocked) {
        status = NodeStatus.locked;
      } else {
        // Prerequisites are met or placement-unlocked
        if (needsPractice) {
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

      // If the node has a low assessed score (< 50), attach reinforcement node
      if ((needsPractice && !isCompleted) ||
          completedReinforcementIds.contains('reinf_${baseNode.id}')) {
        final reinforcementId = 'reinf_${baseNode.id}';
        final isReinforcementCompleted = completedReinforcementIds.contains(reinforcementId);

        final reinforcementNode = LearningPathNode(
          id: reinforcementId,
          courseId: courseId,
          skillId: baseNode.skillId,
          skillDomain: baseNode.skillDomain,
          cefrLevel: baseNode.cefrLevel,
          moduleId: baseNode.moduleId,
          moduleTitle: baseNode.moduleTitle,
          moduleTitleRu: baseNode.moduleTitleRu,
          unitId: baseNode.unitId,
          title: 'Mustahkamlash: ${baseNode.title}',
          titleRu: baseNode.titleRu != null
              ? 'Закрепление: ${baseNode.titleRu}'
              : null,
          description: 'Yo‘lchi AI tavsiyasi: ${baseNode.title} bo‘yicha tushunchalarni mustahkamlash mashqi',
          descriptionRu: baseNode.titleRu != null
              ? 'Рекомендация Yo‘lchi AI: закрепление темы «${baseNode.titleRu}»'
              : null,
          prerequisites: [baseNode.id],
          requiredScore: AdaptiveThresholds.targetedPracticeMin,
          status: isReinforcementCompleted
              ? NodeStatus.completed
              : ((prerequisitesMet || placementUnlocked)
                    ? NodeStatus.available
                    : NodeStatus.locked),
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

    // Determine active node (respect placed English entry when unlocked)
    final placedTargetId = courseId == 'course_eng_01'
        ? (effectivePlacementTier == 'B1'
              ? 'node_eng_b1_m1_travel'
              : effectivePlacementTier == 'A2'
              ? 'node_eng_a2_m1_directions'
              : null)
        : null;
    final placedEntryNode = placedTargetId == null
        ? null
        : adaptedNodes
              .where(
                (n) =>
                    n.id == placedTargetId &&
                    (n.status == NodeStatus.available ||
                        n.status == NodeStatus.reinforcement ||
                        n.status == NodeStatus.inProgress),
              )
              .firstOrNull;
    final activeNode =
        placedEntryNode ??
        adaptedNodes.firstWhere(
          (n) =>
              n.status == NodeStatus.reinforcement ||
              n.status == NodeStatus.available ||
              n.status == NodeStatus.inProgress,
          orElse: () =>
              adaptedNodes.isNotEmpty ? adaptedNodes.first : baseNodes.first,
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
  static bool canStartNode(
    LearningPathNode node,
    List<String> completedNodeIds, {
    String? placementCefrTier,
  }) {
    if (node.status == NodeStatus.locked) return false;
    if (node.serverMastery) return true;
    final effectivePlacementTier = _normalizedEnglishPlacementTier(
      placementCefrTier,
    );
    if (node.courseId == 'course_eng_01' &&
        ((effectivePlacementTier == 'A2' &&
                node.id == 'node_eng_a2_m1_directions') ||
            (effectivePlacementTier == 'B1' &&
                (node.id == 'node_eng_a2_m1_directions' ||
                    node.id == 'node_eng_b1_m1_travel')))) {
      return true;
    }
    return node.prerequisites.every((id) => completedNodeIds.contains(id));
  }
}

extension _ListExt<T> on List<T> {
  void pushOrAdd(T item) => add(item);
}
