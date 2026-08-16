import '../entities/lesson.dart';
import '../entities/learning_path_node.dart';

abstract class ILessonRepository {
  Future<Lesson?> getLessonById(String lessonId);
  Future<Lesson?> getLessonByCourseAndSkill(String courseId, String skillId);
  Future<List<LearningPathNode>> getBaseRoadmapNodes(String courseId);
}
