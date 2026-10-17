import '../../domain/repositories/i_lesson_repository.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/learning_path_node.dart';
import '../datasources/lessons_data.dart';
import '../datasources/roadmaps_data.dart';
import '../../core/config/supabase_config.dart';

class InMemoryLessonRepository implements ILessonRepository {
  @override
  Future<Lesson?> getLessonById(String lessonId) async {
    // Seed lessons contain answer keys for demo mode only. Once Supabase is
    // configured, a content outage must not quietly reveal that seed data.
    if (SupabaseConfig.hasRemoteConfiguration) return null;
    return seedLessons[lessonId];
  }

  @override
  Future<Lesson?> getLessonByCourseAndSkill(String courseId, String skillId) async {
    if (SupabaseConfig.hasRemoteConfiguration) return null;
    return seedLessons.values
        .where((l) => l.courseId == courseId && l.skillId == skillId)
        .firstOrNull;
  }

  @override
  Future<List<LearningPathNode>> getBaseRoadmapNodes(String courseId) async {
    if (SupabaseConfig.hasRemoteConfiguration) return const [];
    return List.of(seedRoadmapNodes[courseId] ?? []);
  }
}
