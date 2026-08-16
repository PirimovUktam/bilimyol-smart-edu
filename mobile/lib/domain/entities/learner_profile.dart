import 'skill_score.dart';

enum OnboardingGoal {
  mastery,
  examPrep,
  skillsBoost,
}

enum InitialLevel {
  beginner,
  intermediate,
  advanced,
}

class LearnerProfile {
  final String id;
  final String name;
  final String selectedCourseId;
  final OnboardingGoal goal;
  final int dailyMinutes;
  final InitialLevel initialLevel;
  final int xp;
  final int streakDays;
  final String lastActiveDate;
  final Map<String, Map<String, SkillScore>> scoresByCourse; // courseId -> skillId -> SkillScore
  final List<String> completedLessonIds;
  final List<String> completedNodeIds;
  final List<String> completedReinforcementIds;
  final int createdAt;

  const LearnerProfile({
    required this.id,
    required this.name,
    required this.selectedCourseId,
    required this.goal,
    required this.dailyMinutes,
    required this.initialLevel,
    required this.xp,
    required this.streakDays,
    required this.lastActiveDate,
    required this.scoresByCourse,
    required this.completedLessonIds,
    required this.completedNodeIds,
    required this.completedReinforcementIds,
    required this.createdAt,
  });

  LearnerProfile copyWith({
    String? id,
    String? name,
    String? selectedCourseId,
    OnboardingGoal? goal,
    int? dailyMinutes,
    InitialLevel? initialLevel,
    int? xp,
    int? streakDays,
    String? lastActiveDate,
    Map<String, Map<String, SkillScore>>? scoresByCourse,
    List<String>? completedLessonIds,
    List<String>? completedNodeIds,
    List<String>? completedReinforcementIds,
    int? createdAt,
  }) {
    return LearnerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      selectedCourseId: selectedCourseId ?? this.selectedCourseId,
      goal: goal ?? this.goal,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      initialLevel: initialLevel ?? this.initialLevel,
      xp: xp ?? this.xp,
      streakDays: streakDays ?? this.streakDays,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      scoresByCourse: scoresByCourse ?? this.scoresByCourse,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      completedNodeIds: completedNodeIds ?? this.completedNodeIds,
      completedReinforcementIds: completedReinforcementIds ?? this.completedReinforcementIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
