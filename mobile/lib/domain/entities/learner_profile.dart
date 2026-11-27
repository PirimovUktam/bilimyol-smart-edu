import 'skill_score.dart';

enum OnboardingGoal { mastery, examPrep, skillsBoost }

enum InitialLevel { beginner, intermediate, advanced }

class FlashcardSrsRecord {
  final String status; // 'new' | 'need_practice' | 'remembered'
  final int reviewCount;
  final int intervalBucket; // 0, 1, 2, 3+
  final String lastReviewedAt;
  final String nextReviewBucket; // 'now' | 'session_next' | 'daily' | '3_days' | 'mastered'
  final String nextReviewAt;

  const FlashcardSrsRecord({
    this.status = 'new',
    this.reviewCount = 0,
    this.intervalBucket = 0,
    this.lastReviewedAt = '',
    this.nextReviewBucket = 'now',
    this.nextReviewAt = '',
  });

  FlashcardSrsRecord copyWith({
    String? status,
    int? reviewCount,
    int? intervalBucket,
    String? lastReviewedAt,
    String? nextReviewBucket,
    String? nextReviewAt,
  }) {
    return FlashcardSrsRecord(
      status: status ?? this.status,
      reviewCount: reviewCount ?? this.reviewCount,
      intervalBucket: intervalBucket ?? this.intervalBucket,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewBucket: nextReviewBucket ?? this.nextReviewBucket,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'reviewCount': reviewCount,
    'intervalBucket': intervalBucket,
    'lastReviewedAt': lastReviewedAt,
    'nextReviewBucket': nextReviewBucket,
    'nextReviewAt': nextReviewAt,
  };

  factory FlashcardSrsRecord.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] as String?)?.trim();
    final status =
        rawStatus == 'remembered' ||
            rawStatus == 'need_practice' ||
            rawStatus == 'new'
        ? rawStatus!
        : 'new';
    return FlashcardSrsRecord(
      status: status,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      intervalBucket: (json['intervalBucket'] as num?)?.toInt() ?? 0,
      lastReviewedAt: (json['lastReviewedAt'] as String?) ?? '',
      nextReviewBucket: (json['nextReviewBucket'] as String?) ?? 'now',
      nextReviewAt: (json['nextReviewAt'] as String?) ?? '',
    );
  }
}

class LearnerProfile {
  final String id;
  final String name;
  final String selectedCourseId;
  final OnboardingGoal goal;
  final int dailyMinutes;
  final InitialLevel initialLevel;
  final Map<String, InitialLevel> courseLevels;
  final int xp;
  final int streakDays;
  final String lastActiveDate;
  final Map<String, Map<String, SkillScore>>
  scoresByCourse; // courseId -> skillId -> SkillScore
  final Map<String, int> placementScoreByCourse;
  final Map<String, String> placementCefrByCourse;
  final Map<String, Map<String, SkillScore>> placementSkillScoresByCourse;
  final Map<String, Map<String, FlashcardSrsRecord>>
  flashcardSrsByCourse; // courseId -> cardId -> FlashcardSrsRecord
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
    this.courseLevels = const {},
    required this.xp,
    required this.streakDays,
    required this.lastActiveDate,
    required this.scoresByCourse,
    this.placementScoreByCourse = const {},
    this.placementCefrByCourse = const {},
    this.placementSkillScoresByCourse = const {},
    this.flashcardSrsByCourse = const {},
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
    Map<String, InitialLevel>? courseLevels,
    int? xp,
    int? streakDays,
    String? lastActiveDate,
    Map<String, Map<String, SkillScore>>? scoresByCourse,
    Map<String, int>? placementScoreByCourse,
    Map<String, String>? placementCefrByCourse,
    Map<String, Map<String, SkillScore>>? placementSkillScoresByCourse,
    Map<String, Map<String, FlashcardSrsRecord>>? flashcardSrsByCourse,
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
      courseLevels: courseLevels ?? this.courseLevels,
      xp: xp ?? this.xp,
      streakDays: streakDays ?? this.streakDays,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      scoresByCourse: scoresByCourse ?? this.scoresByCourse,
      placementScoreByCourse:
          placementScoreByCourse ?? this.placementScoreByCourse,
      placementCefrByCourse:
          placementCefrByCourse ?? this.placementCefrByCourse,
      placementSkillScoresByCourse:
          placementSkillScoresByCourse ?? this.placementSkillScoresByCourse,
      flashcardSrsByCourse: flashcardSrsByCourse ?? this.flashcardSrsByCourse,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      completedNodeIds: completedNodeIds ?? this.completedNodeIds,
      completedReinforcementIds:
          completedReinforcementIds ?? this.completedReinforcementIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
