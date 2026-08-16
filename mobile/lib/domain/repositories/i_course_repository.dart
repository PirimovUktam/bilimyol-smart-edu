import '../entities/course.dart';
import '../entities/skill.dart';
import '../entities/question.dart';

abstract class ICourseRepository {
  Future<List<Course>> getAllCourses();
  Future<Course?> getCourseById(String courseId);
  Future<List<Skill>> getSkillsByCourseId(String courseId);
  Future<List<Question>> getPlacementQuestions(String courseId);
}
