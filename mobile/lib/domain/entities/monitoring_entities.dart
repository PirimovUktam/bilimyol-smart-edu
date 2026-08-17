enum UserRole { student, parent, teacher, admin }

class ParentStudentLink {
  final String id;
  final String parentUserId;
  final String? studentUserId;
  final String linkCode;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;

  const ParentStudentLink({
    required this.id,
    required this.parentUserId,
    this.studentUserId,
    required this.linkCode,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });
}

class TeacherClass {
  final String id;
  final String teacherUserId;
  final String name;
  final String subject;
  final String gradeLevel;
  final String classCode;
  final int studentCount;
  final int averageMastery;
  final DateTime createdAt;

  const TeacherClass({
    required this.id,
    required this.teacherUserId,
    required this.name,
    required this.subject,
    required this.gradeLevel,
    required this.classCode,
    this.studentCount = 0,
    this.averageMastery = 0,
    required this.createdAt,
  });
}

class ChildSummary {
  final String studentId;
  final String firstName;
  final String lastName;
  final String displayName;
  final String avatarUrl;
  final int todayActiveMinutes;
  final int overallScore;
  final int streakDays;
  final int xp;
  final String weakestSkillName;
  final int weakestSkillScore;
  final String strongestSkillName;
  final int strongestSkillScore;
  final int todayGoalMinutes;
  final int goalCompletionPercent;
  final String statusTitle;
  final String pedagogicalAdvice;

  const ChildSummary({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    this.avatarUrl = '',
    required this.todayActiveMinutes,
    required this.overallScore,
    required this.streakDays,
    required this.xp,
    required this.weakestSkillName,
    required this.weakestSkillScore,
    required this.strongestSkillName,
    required this.strongestSkillScore,
    required this.todayGoalMinutes,
    required this.goalCompletionPercent,
    required this.statusTitle,
    required this.pedagogicalAdvice,
  });
}

class ClassStudentSummary {
  final String studentId;
  final String name;
  final String email;
  final int todayActiveMinutes;
  final int overallScore;
  final int completedLessonsCount;
  final int totalAttemptsCount;
  final String weakestSkillName;
  final int weakestSkillScore;
  final String status;
  final int alertCount;
  final String lastActiveDate;

  const ClassStudentSummary({
    required this.studentId,
    required this.name,
    this.email = '',
    required this.todayActiveMinutes,
    required this.overallScore,
    required this.completedLessonsCount,
    required this.totalAttemptsCount,
    required this.weakestSkillName,
    required this.weakestSkillScore,
    required this.status,
    required this.alertCount,
    required this.lastActiveDate,
  });
}

class WeeklyActivityDay {
  final String dayName;
  final String dateStr;
  final int activeMinutes;
  final int lessonsCount;
  final int accuracyPercent;

  const WeeklyActivityDay({
    required this.dayName,
    required this.dateStr,
    required this.activeMinutes,
    required this.lessonsCount,
    required this.accuracyPercent,
  });
}
