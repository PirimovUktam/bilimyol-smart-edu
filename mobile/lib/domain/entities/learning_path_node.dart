import '../../core/constants/adaptive_thresholds.dart';

enum NodeStatus {
  locked,
  available,
  inProgress,
  completed,
  reinforcement,
}

enum LearningNodeKind {
  lesson,
  unitCheckpoint,
  levelAssessment,
}

class NodeMastery {
  final String state;
  final int answered;
  final int correct;
  final int requiredItems;
  final int passedCheckpoints;
  final int requiredCheckpoints;
  final bool reviewDue;

  const NodeMastery({
    this.state = 'not_started',
    required this.answered,
    required this.correct,
    required this.requiredItems,
    this.passedCheckpoints = 0,
    this.requiredCheckpoints = 2,
    this.reviewDue = false,
  });

  NodeMastery copyWith({
    String? state,
    int? answered,
    int? correct,
    int? requiredItems,
    int? passedCheckpoints,
    int? requiredCheckpoints,
    bool? reviewDue,
  }) {
    return NodeMastery(
      state: state ?? this.state,
      answered: answered ?? this.answered,
      correct: correct ?? this.correct,
      requiredItems: requiredItems ?? this.requiredItems,
      passedCheckpoints: passedCheckpoints ?? this.passedCheckpoints,
      requiredCheckpoints: requiredCheckpoints ?? this.requiredCheckpoints,
      reviewDue: reviewDue ?? this.reviewDue,
    );
  }
}

class LearningPathNode {
  final String id;
  final String courseId;
  final String skillId;
  final String? skillDomain;
  final String? cefrLevel;
  final String? moduleId;
  final String? moduleTitle;
  final String? moduleTitleRu;
  final String? unitId;
  final String? canDoObjective;
  final String? canDoObjectiveRu;
  final LearningNodeKind nodeKind;
  final bool isCheckpoint;
  final bool hasRichExercise;
  final String? taskKind;
  final String title;
  final String? titleRu;
  final String description;
  final String? descriptionRu;
  final List<String> prerequisites;
  final int requiredScore;
  final NodeStatus status;
  final int? score;
  final bool isPlacementRecommended;
  final bool isPlacementUnlocked;
  final bool isReinforcement;
  final String? targetLessonId;
  final int estimatedMinutes;
  final double order;
  final bool isOptional;
  final bool serverMastery;
  final bool reviewDue;
  final NodeMastery? mastery;

  const LearningPathNode({
    required this.id,
    required this.courseId,
    required this.skillId,
    this.skillDomain,
    this.cefrLevel,
    this.moduleId,
    this.moduleTitle,
    this.moduleTitleRu,
    this.unitId,
    this.canDoObjective,
    this.canDoObjectiveRu,
    this.nodeKind = LearningNodeKind.lesson,
    this.isCheckpoint = false,
    this.hasRichExercise = false,
    this.taskKind,
    required this.title,
    this.titleRu,
    this.description = '',
    this.descriptionRu,
    required this.prerequisites,
    required this.requiredScore,
    required this.status,
    this.score,
    this.isPlacementRecommended = false,
    this.isPlacementUnlocked = false,
    required this.isReinforcement,
    this.targetLessonId,
    required this.estimatedMinutes,
    required this.order,
    this.isOptional = false,
    this.serverMastery = false,
    this.reviewDue = false,
    this.mastery,
  });

  String localizedTitle(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = titleRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    return title;
  }

  String localizedDescription(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = descriptionRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    return description;
  }

  String? localizedModuleTitle(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = moduleTitleRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    final uz = moduleTitle?.trim();
    return (uz != null && uz.isNotEmpty) ? uz : null;
  }

  String? localizedCanDo(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = canDoObjectiveRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    final uz = canDoObjective?.trim();
    return (uz != null && uz.isNotEmpty) ? uz : null;
  }

  bool get needsTargetedPractice =>
      !isReinforcement &&
      status != NodeStatus.completed &&
      status != NodeStatus.locked &&
      score != null &&
      score! >= AdaptiveThresholds.targetedPracticeMin &&
      score! <= AdaptiveThresholds.targetedPracticeMax;

  LearningPathNode copyWith({
    String? id,
    String? courseId,
    String? skillId,
    String? skillDomain,
    String? cefrLevel,
    String? moduleId,
    String? moduleTitle,
    String? moduleTitleRu,
    String? unitId,
    String? canDoObjective,
    String? canDoObjectiveRu,
    LearningNodeKind? nodeKind,
    bool? isCheckpoint,
    bool? hasRichExercise,
    String? taskKind,
    String? title,
    String? titleRu,
    String? description,
    String? descriptionRu,
    List<String>? prerequisites,
    int? requiredScore,
    NodeStatus? status,
    int? score,
    bool? isPlacementRecommended,
    bool? isPlacementUnlocked,
    bool? isReinforcement,
    String? targetLessonId,
    int? estimatedMinutes,
    double? order,
    bool? isOptional,
    bool? serverMastery,
    bool? reviewDue,
    NodeMastery? mastery,
  }) {
    return LearningPathNode(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      skillId: skillId ?? this.skillId,
      skillDomain: skillDomain ?? this.skillDomain,
      cefrLevel: cefrLevel ?? this.cefrLevel,
      moduleId: moduleId ?? this.moduleId,
      moduleTitle: moduleTitle ?? this.moduleTitle,
      moduleTitleRu: moduleTitleRu ?? this.moduleTitleRu,
      unitId: unitId ?? this.unitId,
      canDoObjective: canDoObjective ?? this.canDoObjective,
      canDoObjectiveRu: canDoObjectiveRu ?? this.canDoObjectiveRu,
      nodeKind: nodeKind ?? this.nodeKind,
      isCheckpoint: isCheckpoint ?? this.isCheckpoint,
      hasRichExercise: hasRichExercise ?? this.hasRichExercise,
      taskKind: taskKind ?? this.taskKind,
      title: title ?? this.title,
      titleRu: titleRu ?? this.titleRu,
      description: description ?? this.description,
      descriptionRu: descriptionRu ?? this.descriptionRu,
      prerequisites: prerequisites ?? this.prerequisites,
      requiredScore: requiredScore ?? this.requiredScore,
      status: status ?? this.status,
      score: score ?? this.score,
      isPlacementRecommended:
          isPlacementRecommended ?? this.isPlacementRecommended,
      isPlacementUnlocked: isPlacementUnlocked ?? this.isPlacementUnlocked,
      isReinforcement: isReinforcement ?? this.isReinforcement,
      targetLessonId: targetLessonId ?? this.targetLessonId,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      order: order ?? this.order,
      isOptional: isOptional ?? this.isOptional,
      serverMastery: serverMastery ?? this.serverMastery,
      reviewDue: reviewDue ?? this.reviewDue,
      mastery: mastery ?? this.mastery,
    );
  }
}

class LearningPath {
  final String id;
  final String courseId;
  final String title;
  final List<LearningPathNode> nodes;
  final String activeNodeId;
  final int updatedAt;

  const LearningPath({
    required this.id,
    required this.courseId,
    required this.title,
    required this.nodes,
    required this.activeNodeId,
    required this.updatedAt,
  });

  int? get masteryPercent {
    final objectives = nodes.where((node) => node.serverMastery && !node.isOptional);
    if (objectives.isEmpty) return null;
    final mastered = objectives.where((node) => node.status == NodeStatus.completed).length;
    return (100 * mastered / objectives.length).round();
  }
}
