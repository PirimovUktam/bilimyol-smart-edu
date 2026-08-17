import '../entities/monitoring_entities.dart';

abstract class IMonitoringRepository {
  Future<UserRole> getUserRole();
  Future<void> setUserRole(UserRole role);

  // Parent
  Future<Map<String, dynamic>> createParentLinkCode();
  Future<List<ChildSummary>> getParentChildren();
  Future<List<WeeklyActivityDay>> getChildWeeklyStats(String studentId);

  // Student
  Future<Map<String, dynamic>> redeemParentLinkCode(String code);
  Future<Map<String, dynamic>> joinClassByCode(String code);

  // Teacher
  Future<TeacherClass> createTeacherClass(String name, {String subject, String gradeLevel});
  Future<List<TeacherClass>> getTeacherClasses();
  Future<List<ClassStudentSummary>> getClassStudents(String classId);

  // Heartbeat
  Future<Map<String, dynamic>> recordHeartbeat(String sessionId, {String courseId, String? lessonId, String platform});
}
