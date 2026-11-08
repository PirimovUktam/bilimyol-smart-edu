enum SubjectType { mathematics, english, it, logic }

class Course {
  final String id;
  final String title;
  final SubjectType subject;
  final String description;
  final String iconName;
  final String primaryColorHex;
  final String secondaryColorHex;
  final List<String> skills;
  final List<String> lessons;
  final String? starterLessonId;
  final List<String> foundationLessonIds;
  final int totalStudentsEstimate;

  const Course({
    required this.id,
    required this.title,
    required this.subject,
    required this.description,
    required this.iconName,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    required this.skills,
    required this.lessons,
    this.starterLessonId,
    this.foundationLessonIds = const [],
    this.totalStudentsEstimate = 1000,
  });
}
