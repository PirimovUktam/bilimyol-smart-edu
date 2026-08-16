import '../../domain/repositories/i_course_repository.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/skill.dart';
import '../../domain/entities/question.dart';
import '../datasources/courses_data.dart';
import '../datasources/skills_data.dart';
import '../datasources/questions_data.dart';

class InMemoryCourseRepository implements ICourseRepository {
  @override
  Future<List<Course>> getAllCourses() async {
    return List.unmodifiable(seedCourses);
  }

  @override
  Future<Course?> getCourseById(String courseId) async {
    return seedCourses.where((c) => c.id == courseId).firstOrNull;
  }

  @override
  Future<List<Skill>> getSkillsByCourseId(String courseId) async {
    return seedSkills.where((s) => s.courseId == courseId).toList();
  }

  @override
  Future<List<Question>> getPlacementQuestions(String courseId) async {
    return List.unmodifiable(placementQuestionsData[courseId] ?? []);
  }
}
