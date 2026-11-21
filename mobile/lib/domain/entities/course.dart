enum SubjectType { mathematics, english, it, logic }

class Course {
  final String id;
  final String title;
  final String? titleRu;
  final SubjectType subject;
  final String description;
  final String? descriptionRu;
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
    this.titleRu,
    required this.subject,
    required this.description,
    this.descriptionRu,
    required this.iconName,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    required this.skills,
    required this.lessons,
    this.starterLessonId,
    this.foundationLessonIds = const [],
    this.totalStudentsEstimate = 1000,
  });

  String localizedTitle(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = titleRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    return title;
  }

  String localizedDescription(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = descriptionRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    }
    return description;
  }
}
