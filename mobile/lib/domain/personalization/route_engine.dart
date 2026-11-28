import '../entities/learner_profile.dart';
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

  /// Generates or adapts an adaptive learning path based on skill scores, completed nodes,
  /// diagnostic mastery pass-through (>= 80% keeps status 'available' without fabricating
  /// 'completed'), returning-learner reinforcement, and learner goal/time preferences.
  static LearningPath adaptRoadmap({
    required String courseId,
    required List<LearningPathNode> baseNodes,
    required Map<String, SkillScore> skillScores,
    required List<String> completedNodeIds,
    required List<String> completedReinforcementIds,
    String? placementCefrTier,
    OnboardingGoal? goal,
    int? dailyMinutes,
  }) {
    final effectiveGoal = goal ?? OnboardingGoal.mastery;
    final effectivePlacementTier = _normalizedEnglishPlacementTier(
      placementCefrTier,
    );

    if (baseNodes.any((node) => node.serverMastery)) {
      final nonOptionalOpen = baseNodes
          .where(
            (node) =>
                !node.isOptional &&
                node.status != NodeStatus.locked &&
                node.status != NodeStatus.completed,
          )
          .toList();
      final urgentPilot = nonOptionalOpen
          .where(
            (node) =>
                node.status == NodeStatus.reinforcement ||
                node.status == NodeStatus.inProgress,
          )
          .firstOrNull;
      final unmasteredInPlacement = nonOptionalOpen
          .where(
            (node) =>
                (skillScores[node.skillId]?.score ?? -1) < node.requiredScore,
          )
          .toList();
      final next =
          urgentPilot ??
          (effectiveGoal == OnboardingGoal.examPrep &&
                  unmasteredInPlacement.isEmpty
              ? nonOptionalOpen.lastOrNull
              : unmasteredInPlacement.firstOrNull) ??
          nonOptionalOpen.firstOrNull;

      return LearningPath(
        id: 'roadmap_$courseId',
        courseId: courseId,
        title: 'Moslashuvchan Yo‘l Xaritasi',
        nodes: baseNodes,
        activeNodeId: next?.id ?? '',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }

    final placementUnlockedIds = <String>{};
    String? recommendedEntryId;
    if (courseId == 'course_eng_01' && effectivePlacementTier != null) {
      if (effectivePlacementTier == 'B1') {
        placementUnlockedIds.add('node_eng_a2_m1_directions');
        placementUnlockedIds.add('node_eng_b1_m1_travel');
        recommendedEntryId = 'node_eng_b1_m1_travel';
      } else if (effectivePlacementTier == 'A2') {
        placementUnlockedIds.add('node_eng_a2_m1_directions');
        recommendedEntryId = 'node_eng_a2_m1_directions';
      } else {
        recommendedEntryId = 'node_eng_a1_m1_greetings';
      }
    }

    final orderedBase = [...baseNodes]
      ..sort((a, b) => a.order.compareTo(b.order));
    final completedSet = <String>{...completedNodeIds};
    final effectivePrereqIds = <String>{...completedNodeIds};
    final diagnosticSkippedIds = <String>{};
    final List<LearningPathNode> adaptedNodes = [];

    for (final baseNode in orderedBase) {
      final skillScoreObj = skillScores[baseNode.skillId];
      final int? score = skillScoreObj?.score;
      final bool needsPractice =
          score != null && score < AdaptiveThresholds.targetedPracticeMin;
      final bool isCompleted = completedSet.contains(baseNode.id);
      final bool strictPrereqsMet = baseNode.prerequisites.every(
        completedSet.contains,
      );
      final bool prerequisitesMet = baseNode.prerequisites.every(
        effectivePrereqIds.contains,
      );
      final bool cefrUnlocked = placementUnlockedIds.contains(baseNode.id);

      final bool allowDiagnosticSkip =
          courseId != 'course_eng_01' ||
          (!baseNode.hasRichExercise && !baseNode.isCheckpoint);
      final bool unlockedViaDiagnostic =
          !isCompleted &&
          allowDiagnosticSkip &&
          score != null &&
          (prerequisitesMet || cefrUnlocked) &&
          score >= AdaptiveThresholds.diagnosticMasteryMin;

      if (isCompleted || unlockedViaDiagnostic) {
        effectivePrereqIds.add(baseNode.id);
      }
      if (unlockedViaDiagnostic) {
        diagnosticSkippedIds.add(baseNode.id);
      }

      final bool isUnlocked = prerequisitesMet || cefrUnlocked;
      final bool isPlacementUnlocked =
          cefrUnlocked || unlockedViaDiagnostic || (isUnlocked && !strictPrereqsMet);

      final reinforcementId = 'reinf_${baseNode.id}';
      final isReinforcementCompleted = completedReinforcementIds.contains(
        reinforcementId,
      );

      NodeStatus status = NodeStatus.locked;
      if (isCompleted) {
        status = NodeStatus.completed;
      } else if (!isUnlocked) {
        status = NodeStatus.locked;
      } else if (needsPractice && !isReinforcementCompleted) {
        status = NodeStatus.reinforcement;
      } else {
        status = NodeStatus.available;
      }

      final bool isPlacementRecommended =
          recommendedEntryId != null &&
          baseNode.id == recommendedEntryId &&
          !isCompleted;

      final updatedNode = baseNode.copyWith(
        score: score,
        status: status,
        isPlacementRecommended: isPlacementRecommended,
        isPlacementUnlocked: isPlacementUnlocked,
      );

      adaptedNodes.add(updatedNode);

      // Attach reinforcement node when < 50% is not yet remediated (including returning completed nodes)
      // or retain completed reinforcement once score rises >= 50% (FIX-P1-19 + W1-B2 FIX-P1-40).
      if ((needsPractice && !isReinforcementCompleted) ||
          (isReinforcementCompleted && !needsPractice)) {
        final bool reinfUnlocked = isCompleted || isUnlocked;
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
              : (reinfUnlocked ? NodeStatus.available : NodeStatus.locked),
          isPlacementUnlocked:
              isPlacementUnlocked || (reinfUnlocked && !strictPrereqsMet),
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

    final placedEntryNode =
        recommendedEntryId != null &&
            (effectivePlacementTier == 'A2' || effectivePlacementTier == 'B1')
        ? adaptedNodes
              .where(
                (n) =>
                    n.id == recommendedEntryId &&
                    (n.status == NodeStatus.available ||
                        n.status == NodeStatus.reinforcement ||
                        n.status == NodeStatus.inProgress),
              )
              .firstOrNull
        : null;

    final urgentRemediations = adaptedNodes
        .where(
          (n) =>
              !n.isOptional &&
              (n.status == NodeStatus.reinforcement ||
                  (n.isReinforcement && n.status == NodeStatus.available)),
        )
        .toList();
    LearningPathNode? prioritizedRemediation;
    if (urgentRemediations.isNotEmpty) {
      if (effectiveGoal == OnboardingGoal.examPrep &&
          urgentRemediations.length > 1) {
        final sorted = [...urgentRemediations]
          ..sort((a, b) {
            final cmp = (a.score ?? 0).compareTo(b.score ?? 0);
            return cmp != 0 ? cmp : a.order.compareTo(b.order);
          });
        prioritizedRemediation = sorted.first;
      } else {
        prioritizedRemediation = urgentRemediations.first;
      }
    }

    final nonSkippedCandidates = adaptedNodes
        .where(
          (n) =>
              !n.isOptional &&
              !n.isReinforcement &&
              !diagnosticSkippedIds.contains(n.id) &&
              (n.status == NodeStatus.available ||
                  n.status == NodeStatus.inProgress),
        )
        .toList();

    LearningPathNode? selectedCandidate;
    if (effectiveGoal == OnboardingGoal.examPrep) {
      selectedCandidate = nonSkippedCandidates
          .where((n) => n.isCheckpoint)
          .firstOrNull;
      if (selectedCandidate == null && nonSkippedCandidates.isNotEmpty) {
        final sorted = [...nonSkippedCandidates]
          ..sort((a, b) {
            final cmp = (a.score ?? 100).compareTo(b.score ?? 100);
            return cmp != 0 ? cmp : a.order.compareTo(b.order);
          });
        selectedCandidate = sorted.first;
      }
    } else if (effectiveGoal == OnboardingGoal.skillsBoost) {
      selectedCandidate =
          nonSkippedCandidates
              .where((n) => n.needsTargetedPractice)
              .firstOrNull ??
          nonSkippedCandidates
              .where(
                (n) =>
                    n.hasRichExercise ||
                    (n.taskKind != null && n.taskKind != 'standard'),
              )
              .firstOrNull ??
          nonSkippedCandidates.firstOrNull;
    } else {
      selectedCandidate =
          nonSkippedCandidates
              .where((n) => n.needsTargetedPractice)
              .firstOrNull ??
          nonSkippedCandidates.firstOrNull;
    }

    final skippedAvailable = adaptedNodes
        .where(
          (n) =>
              !n.isOptional &&
              !n.isReinforcement &&
              (n.status == NodeStatus.available ||
                  n.status == NodeStatus.inProgress),
        )
        .toList();
    final fallbackSkipped = effectiveGoal == OnboardingGoal.examPrep
        ? (skippedAvailable.where((n) => n.isCheckpoint).firstOrNull ??
              skippedAvailable.lastOrNull)
        : skippedAvailable.firstOrNull;

    final activeNode =
        placedEntryNode ??
        prioritizedRemediation ??
        selectedCandidate ??
        fallbackSkipped ??
        (adaptedNodes.isNotEmpty ? adaptedNodes.first : baseNodes.first);

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
    if (node.serverMastery ||
        node.isPlacementUnlocked ||
        node.isPlacementRecommended) {
      return true;
    }
    final effectivePlacementTier = _normalizedEnglishPlacementTier(
      placementCefrTier,
    );
    if (node.courseId == 'course_eng_01' &&
        ((effectivePlacementTier == 'A2' &&
                (node.id == 'node_eng_a2_m1_directions' ||
                    node.id == 'reinf_node_eng_a2_m1_directions')) ||
            (effectivePlacementTier == 'B1' &&
                (node.id == 'node_eng_a2_m1_directions' ||
                    node.id == 'reinf_node_eng_a2_m1_directions' ||
                    node.id == 'node_eng_b1_m1_travel' ||
                    node.id == 'reinf_node_eng_b1_m1_travel')))) {
      return true;
    }
    return node.prerequisites.every((id) => completedNodeIds.contains(id));
  }
}
