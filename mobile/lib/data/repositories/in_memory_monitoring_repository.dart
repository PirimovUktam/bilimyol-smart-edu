import '../../domain/entities/monitoring_entities.dart';
import '../../domain/repositories/i_monitoring_repository.dart';

class InMemoryMonitoringRepository implements IMonitoringRepository {
  UserRole _role = UserRole.student;
  final List<ParentStudentLink> _links = [];
  final List<TeacherClass> _classes = [];
  final Map<String, Map<String, dynamic>> _invitations = {};

  @override
  Future<UserRole> getUserRole() async => _role;

  @override
  Future<void> setUserRole(UserRole role) async {
    _role = role;
  }

  @override
  Future<Map<String, dynamic>> createTeacherInvitation({
    String schoolName = 'BilimYo‘l Smart School',
    int maxUses = 1,
    int validityDays = 7,
  }) async {
    final randCode = 'USTOZ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7, 11)}-${DateTime.now().microsecond.toString().padLeft(4, '0')}';
    _invitations[randCode] = {
      'school_name': schoolName,
      'max_uses': maxUses,
      'used_count': 0,
      'expires_at': DateTime.now().add(Duration(days: validityDays)),
      'status': 'active',
    };
    return {
      'success': true,
      'plain_code': randCode,
      'code_prefix': '${randCode.substring(0, 10)}****',
      'school_name': schoolName,
    };
  }

  @override
  Future<Map<String, dynamic>> redeemTeacherInvitationCode(String code) async {
    final cleanCode = code.trim().toUpperCase();

    if (cleanCode.isEmpty) {
      return {'success': false, 'message': 'O‘qituvchi tasdiqlash kodini kiriting.'};
    }

    final inv = _invitations[cleanCode];
    if (inv == null || inv['status'] != 'active' || (inv['expires_at'] as DateTime).isBefore(DateTime.now()) || (inv['used_count'] as int) >= (inv['max_uses'] as int)) {
      return {'success': false, 'message': 'Kiritilgan tasdiqlash kodi yaroqsiz yoki muddati tugagan.'};
    }

    inv['used_count'] = (inv['used_count'] as int) + 1;
    if ((inv['used_count'] as int) >= (inv['max_uses'] as int)) {
      inv['status'] = 'exhausted';
    }

    _role = UserRole.teacher;
    return {
      'success': true,
      'school_name': inv['school_name'] ?? 'BilimYo‘l Boshqaruv Markazi',
      'message': 'O‘qituvchi hisobi muvaffaqiyatli tasdiqlandi va faollashtirildi!',
    };
  }

  @override
  Future<Map<String, dynamic>> createParentLinkCode() async {
    final code = 'LK${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 12)}';
    return {
      'id': 'link_1',
      'link_code': code,
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    };
  }

  @override
  Future<List<ChildSummary>> getParentChildren() async {
    return [
      const ChildSummary(
        studentId: 'stud_01',
        firstName: 'Azizbek',
        lastName: 'Karimov',
        displayName: 'Azizbek Karimov',
        todayActiveMinutes: 37,
        overallScore: 76,
        streakDays: 5,
        xp: 320,
        weakestSkillName: 'Funksiyalar',
        weakestSkillScore: 54,
        strongestSkillName: 'Algebra',
        strongestSkillScore: 82,
        todayGoalMinutes: 30,
        goalCompletionPercent: 100,
        statusTitle: 'Barqaror o‘rganmoqda',
        pedagogicalAdvice: 'Azizbek bugun 37 daqiqa faol shug‘ullandi. Funksiyalar mavzusida mustahkamlash tavsiya etiladi.',
      ),
    ];
  }

  @override
  Future<List<WeeklyActivityDay>> getChildWeeklyStats(String studentId) async {
    return [
      const WeeklyActivityDay(dayName: 'Dush', dateStr: '2026-08-11', activeMinutes: 35, lessonsCount: 2, accuracyPercent: 80),
      const WeeklyActivityDay(dayName: 'Sesh', dateStr: '2026-08-12', activeMinutes: 42, lessonsCount: 3, accuracyPercent: 78),
      const WeeklyActivityDay(dayName: 'Chor', dateStr: '2026-08-13', activeMinutes: 28, lessonsCount: 1, accuracyPercent: 70),
      const WeeklyActivityDay(dayName: 'Pay', dateStr: '2026-08-14', activeMinutes: 51, lessonsCount: 4, accuracyPercent: 85),
      const WeeklyActivityDay(dayName: 'Juma', dateStr: '2026-08-15', activeMinutes: 42, lessonsCount: 3, accuracyPercent: 75),
      const WeeklyActivityDay(dayName: 'Shan', dateStr: '2026-08-16', activeMinutes: 30, lessonsCount: 2, accuracyPercent: 80),
      const WeeklyActivityDay(dayName: 'Yak', dateStr: '2026-08-17', activeMinutes: 37, lessonsCount: 2, accuracyPercent: 76),
    ];
  }

  @override
  Future<Map<String, dynamic>> redeemParentLinkCode(String code) async {
    return {'success': true, 'message': 'Ota-onaga muvaffaqiyatli ulandingiz!'};
  }

  @override
  Future<Map<String, dynamic>> joinClassByCode(String code) async {
    final matching = _classes.where((c) => c.classCode == code.toUpperCase()).toList();
    final name = matching.isNotEmpty ? matching.first.name : 'Matematika';
    return {
      'success': true,
      'class_name': name,
      'message': '$name sinfiga muvaffaqiyatli qo‘shildingiz!',
    };
  }

  @override
  Future<TeacherClass> createTeacherClass(String name, {String subject = 'Matematika', String gradeLevel = '7-sinf'}) async {
    final newClass = TeacherClass(
      id: 'class_${DateTime.now().millisecondsSinceEpoch}',
      teacherUserId: 'teacher_01',
      name: name,
      subject: subject,
      gradeLevel: gradeLevel,
      classCode: 'MAT${name.substring(0, 1).toUpperCase()}1',
      studentCount: 0,
      averageMastery: 72,
      createdAt: DateTime.now(),
    );
    _classes.add(newClass);
    return newClass;
  }

  @override
  Future<List<TeacherClass>> getTeacherClasses() async {
    return _classes;
  }

  @override
  Future<List<ClassStudentSummary>> getClassStudents(String classId) async {
    return [
      const ClassStudentSummary(
        studentId: 'stud_1',
        name: 'Ali Valiyev',
        todayActiveMinutes: 43,
        overallScore: 82,
        completedLessonsCount: 4,
        totalAttemptsCount: 15,
        weakestSkillName: 'Grafiklar',
        weakestSkillScore: 75,
        status: 'Yaxshi',
        alertCount: 0,
        lastActiveDate: '2026-08-17',
      ),
      const ClassStudentSummary(
        studentId: 'stud_2',
        name: 'Madina Rahimova',
        todayActiveMinutes: 31,
        overallScore: 74,
        completedLessonsCount: 3,
        totalAttemptsCount: 12,
        weakestSkillName: 'Funksiyalar',
        weakestSkillScore: 62,
        status: 'Nazorat',
        alertCount: 1,
        lastActiveDate: '2026-08-17',
      ),
      const ClassStudentSummary(
        studentId: 'stud_3',
        name: 'Aziz Karimov',
        todayActiveMinutes: 18,
        overallScore: 51,
        completedLessonsCount: 1,
        totalAttemptsCount: 6,
        weakestSkillName: 'Funksiyalar',
        weakestSkillScore: 48,
        status: 'E’tibor',
        alertCount: 2,
        lastActiveDate: '2026-08-17',
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> recordHeartbeat(
    String sessionId, {
    String courseId = 'course_math_01',
    String? lessonId,
    String platform = 'android',
  }) async {
    return {'added_active_seconds': 30, 'total_session_active_seconds': 300};
  }

  void resetAll() {
    _role = UserRole.student;
    _links.clear();
    _classes.clear();
    _invitations.clear();
  }
}
