import '../entities/course.dart';
import '../entities/learner_profile.dart';

bool hasStartedCourse(Course course, LearnerProfile? profile) =>
    profile != null &&
    (profile.courseLevels.containsKey(course.id) ||
        (profile.scoresByCourse[course.id]?.isNotEmpty ?? false) ||
        course.lessons.any(profile.completedLessonIds.contains));

List<String> foundationLessons(Course course) {
  if (course.foundationLessonIds.isNotEmpty) return course.foundationLessonIds;
  final starter = course.starterLessonId;
  return starter == null ? const [] : [starter];
}

String? pendingFoundationLesson(Course? course, LearnerProfile? profile) {
  if (course == null ||
      profile == null ||
      profile.courseLevels[course.id] != InitialLevel.beginner) {
    return null;
  }
  return foundationLessons(
    course,
  ).where((id) => !profile.completedLessonIds.contains(id)).firstOrNull;
}
