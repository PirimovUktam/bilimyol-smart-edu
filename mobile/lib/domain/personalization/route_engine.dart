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
          .where(
            (node) =>
                !node.isOptional &&
                node.status != NodeStatus.locked &&
                node.status != NodeStatus.completed,
          )
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

    final orderedBase = [...baseNodes]
      ..sort((a, b) => a.order.compareTo(b.order));
    final effectiveCompletedIds = <String>{...completedNodeIds};
    final List<LearningPathNode> adaptedNodes = [];

    for (final baseNode in orderedBase) {
      final skillScoreObj = skillScores[baseNode.skillId];
      final int? score = skillScoreObj?.score;
      final bool needsPractice =
          score != null && score < AdaptiveThresholds.targetedPracticeMin;
      final prerequisitesMet = baseNode.prerequisites.every(
        (prereqId) => effectiveCompletedIds.contains(prereqId),
      );
      final placementUnlocked =
          courseId == 'course_eng_01' &&
          ((effectivePlacementTier == 'A2' &&
                  baseNode.id == 'node_eng_a2_m1_directions') ||
              (effectivePlacementTier == 'B1' &&
                  (baseNode.id == 'node_eng_a2_m1_directions' ||
                      baseNode.id == 'node_eng_b1_m1_travel')));
      // Diagnostic >= 80% skips linear/foundational skill nodes, while keeping
      // rich CEFR modules, unit checkpoints, and level exit exams gated.
      final allowDiagnosticSkip =
          courseId != 'course_eng_01' ||
          (!baseNode.hasRichExercise && !baseNode.isCheckpoint);
      final masteredViaDiagnostic =
          allowDiagnosticSkip &&
          skillScoreObj != null &&
          prerequisitesMet &&
          score! >= AdaptiveThresholds.diagnosticMasteryMin;
      final isCompleted =
          completedNodeIds.contains(baseNode.id) || masteredViaDiagnostic;

      if (isCompleted) {
        effectiveCompletedIds.add(baseNode.id);
      }

      NodeStatus status = NodeStatus.locked;
      if (isCompleted) {
        status = NodeStatus.completed;
      } else if (!prerequisitesMet && !placementUnlocked) {
        status = NodeStatus.locked;
      } else if (needsPractice) {
        // Score < 50 => requires reinforcement
        status = NodeStatus.reinforcement;
      } else {
        status = NodeStatus.available;
      }

      final updatedNode = baseNode.copyWith(
        score: score,
        status: status,
      );

      adaptedNodes.add(updatedNode);

      // Attach reinforcement node for low scores (< 50) not yet completed
      if (needsPractice && !isCompleted) {
        final reinforcementId = 'reinf_${baseNode.id}';
        final isReinforcementCompleted =
            completedReinforcementIds.contains(reinforcementId);

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
          description:
              'Yo‘lchi AI tavsiyasi: ${baseNode.title} bo‘yicha tushunchalarni mustahkamlash mashqi',
          descriptionRu: baseNode.titleRu != null
              ? 'Рекомендация Yo‘lchi AI: закрепление темы «${baseNode.titleRu}»'
              : null,
          prerequisites: baseNode.prerequisites,
          requiredScore: AdaptiveThresholds.targetedPracticeMin,
          status: isReinforcementCompleted
              ? NodeStatus.completed
              : ((prerequisitesMet || placementUnlocked)
                    ? NodeStatus.available
                    : NodeStatus.locked),
          targetLessonId: baseNode.targetLessonId,
          isReinforcement: true,
          estimatedMinutes: 5,
          order: baseNode.order + 0.5,
          score: score,
        );

        adaptedNodes.add(reinforcementNode);
      }
    }

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
    if (node.status == NodeStatus.available ||
        node.status == NodeStatus.inProgress ||
        node.status == NodeStatus.reinforcement) {
      return true;
    }
    return node.prerequisites.every((id) => completedNodeIds.contains(id));
  }
}
