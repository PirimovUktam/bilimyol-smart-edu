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

List<LearningPathNode> availablePlanNodes(
  String courseId,
  LearnerProfile profile,
  LearningPath? path,
) {
  if (path == null || path.courseId != courseId) return [];
  final nodes = path.nodes.where((n) {
    final id = n.targetLessonId;
    return n.courseId == courseId &&
        id != null &&
        id.isNotEmpty &&
        !n.isReinforcement &&
        n.status != NodeStatus.locked &&
        (n.reviewDue ||
            (!n.isOptional &&
                n.status != NodeStatus.completed &&
                !profile.completedLessonIds.contains(id)));
  }).toList();
  final mastery = nodes.any((n) => n.serverMastery);
  int priority(LearningPathNode n) {
    if (n.reviewDue) return 0;
    if (!mastery &&
        profile.goal == OnboardingGoal.examPrep &&
        (n.isCheckpoint || n.nodeKind != LearningNodeKind.lesson)) {
      return 1;
    }
    if (!mastery &&
        profile.goal == OnboardingGoal.skillsBoost &&
        (n.needsTargetedPractice || n.status == NodeStatus.reinforcement)) {
      return 1;
    }
    return n.id == path.activeNodeId ? 2 : 3;
  }

  nodes.sort((a, b) {
    final rank = priority(a).compareTo(priority(b));
    return rank == 0 ? a.order.compareTo(b.order) : rank;
  });
  return nodes;
}

String? resolveNextLearningLesson(
  Course? course,
  LearnerProfile? profile,
  LearningPath? path,
) {
  if (course == null) return null;
  final validPath = path != null && path.courseId == course.id ? path : null;
  if (profile == null) return null;
  if (!(validPath?.nodes.any((n) => n.serverMastery) ?? false)) {
    if (!hasStartedCourse(course, profile)) return null;
    final foundation = pendingFoundationLesson(course, profile);
    if (foundation != null) return foundation;
  }
  return availablePlanNodes(
    course.id,
    profile,
    validPath,
  ).firstOrNull?.targetLessonId;
}
