import '../../domain/repositories/i_lesson_repository.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/learning_path_node.dart';
import '../datasources/lessons_data.dart';
import '../datasources/roadmaps_data.dart';

class InMemoryLessonRepository implements ILessonRepository {
  @override
  Future<Lesson?> getLessonById(String lessonId) async {
    return seedLessons[lessonId];
  }

  @override
  Future<Lesson?> getLessonByCourseAndSkill(String courseId, String skillId) async {
    return seedLessons.values
        .where((l) => l.courseId == courseId && l.skillId == skillId)
        .firstOrNull;
  }

  @override
  Future<List<LearningPathNode>> getBaseRoadmapNodes(String courseId) async {
    return List.of(seedRoadmapNodes[courseId] ?? []);
  }
}
