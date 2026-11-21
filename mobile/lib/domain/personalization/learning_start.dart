import '../entities/course.dart';
import '../entities/learner_profile.dart';
import '../entities/learning_path_node.dart';
import '../../core/config/supabase_config.dart';

const mathMasteryCourse = 'course_math_01';

bool usesMathMastery(String? courseId) =>
    courseId == mathMasteryCourse && SupabaseConfig.hasRemoteConfiguration;

bool hasStartedCourse(Course course, LearnerProfile? profile) =>
    profile != null &&
    (profile.courseLevels.containsKey(course.id) ||
        (profile.scoresByCourse[course.id]?.isNotEmpty ?? false) ||
        profile.placementScoreByCourse.containsKey(course.id) ||
        profile.placementCefrByCourse.containsKey(course.id) ||
        course.lessons.any(profile.completedLessonIds.contains));

List<String> foundationLessons(Course course) {
  if (course.foundationLessonIds.isNotEmpty) return course.foundationLessonIds;
  final starter = course.starterLessonId;
  return starter == null ? const [] : [starter];
}

String? pendingFoundationLesson(Course? course, LearnerProfile? profile) {
  if (course == null ||
      usesMathMastery(course.id) ||
      profile == null ||
      profile.courseLevels[course.id] != InitialLevel.beginner) {
    return null;
  }
  final placedCefr = profile.placementCefrByCourse[course.id]
      ?.trim()
      .toUpperCase();
  if (placedCefr == 'A1' ||
      placedCefr == 'A2' ||
      placedCefr == 'B1' ||
      placedCefr == 'B2' ||
      placedCefr == 'C1' ||
      placedCefr == 'C2') {
    return null;
  }
  return foundationLessons(
    course,
  ).where((id) => !profile.completedLessonIds.contains(id)).firstOrNull;
}

String? resolveNextLearningLesson(
  Course? course,
  LearnerProfile? profile,
  LearningPath? path,
) {
  if (course == null) return null;
  final validPath = path != null && path.courseId == course.id ? path : null;
  if (validPath != null && validPath.nodes.any((node) => node.serverMastery)) {
    final objectives = validPath.nodes
        .where((node) => !node.isReinforcement && !node.isOptional)
        .toList();
    final active = objectives
        .where(
          (node) =>
              node.id == validPath.activeNodeId &&
              node.status != NodeStatus.locked &&
              node.status != NodeStatus.completed,
        )
        .firstOrNull;
    final next =
        active ??
        objectives
            .where(
              (node) =>
                  node.status == NodeStatus.available ||
                  node.status == NodeStatus.inProgress ||
                  node.status == NodeStatus.reinforcement,
            )
            .firstOrNull;
    final lessonId = next?.targetLessonId;
    return (lessonId == null || lessonId.trim().isEmpty) ? null : lessonId;
  }
  if (!hasStartedCourse(course, profile)) return null;
  final foundation = pendingFoundationLesson(course, profile);
  if (foundation != null && foundation.trim().isNotEmpty) return foundation;
  if (validPath != null) {
    final next = validPath.nodes
        .where(
          (node) =>
              !node.isReinforcement &&
              !node.isOptional &&
              (node.status == NodeStatus.available ||
                  node.status == NodeStatus.inProgress ||
                  node.status == NodeStatus.reinforcement),
        )
        .firstOrNull;
    final lessonId = next?.targetLessonId;
    if (lessonId != null && lessonId.trim().isNotEmpty) return lessonId;
  }
  return null;
}
