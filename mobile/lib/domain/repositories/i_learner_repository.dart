import '../entities/learner_profile.dart';
import '../entities/placement_session.dart';
import '../entities/skill_score.dart';

enum LearnerProfileField {
  name,
  selectedCourse,
  goal,
  dailyMinutes,
  initialLevel,
  courseLevels,
  placementScoreByCourse,
  placementCefrByCourse,
  flashcardSrsByCourse,
}

class AnswerAttemptRecord {
  final String id;
  final String courseId;
  final String skillId;
  final String lessonId;
  final String questionId;
  final int selectedIndex;
  final String selectedAnswer;
  final bool isCorrect;
  final int timestamp;
  final String? correctOption;
  final String? explanation;
  final int? newSkillScore;
  final int xpAwarded;
  final bool alreadyProcessed;

  const AnswerAttemptRecord({
    required this.id,
    required this.courseId,
    required this.skillId,
    required this.lessonId,
    required this.questionId,
    required this.selectedIndex,
    required this.selectedAnswer,
    required this.isCorrect,
    required this.timestamp,
    this.correctOption,
    this.explanation,
    this.newSkillScore,
    this.xpAwarded = 0,
    this.alreadyProcessed = false,
  });
}

class PlacementAttemptSubmission {
  final String questionId;
  final int selectedIndex;
  final bool isCorrect;

  const PlacementAttemptSubmission({
    required this.questionId,
    required this.selectedIndex,
    required this.isCorrect,
  });
}

class PlacementAttemptData {
  final String courseId;
  final int score;
  final String? weakestSkillId;
  final String? cefrLevel;
  final List<PlacementAttemptSubmission> submissions;

  const PlacementAttemptData({
    required this.courseId,
    required this.score,
    this.weakestSkillId,
    this.cefrLevel,
    required this.submissions,
  });
}

class PlacementAnswerEvaluation {
  final bool isCorrect;

  const PlacementAnswerEvaluation({required this.isCorrect});
}

class ReinforcementCompletionResult {
  final int oldScore;
  final int newScore;
  final int xpAwarded;
  final bool alreadyProcessed;

  const ReinforcementCompletionResult({
    required this.oldScore,
    required this.newScore,
    required this.xpAwarded,
    required this.alreadyProcessed,
  });
}

class DailyActivitySummary {
  final String date;
  final int activeMinutes;
  final int xpEarned;
  final int lessonsCompleted;

  const DailyActivitySummary({
    required this.date,
    required this.activeMinutes,
    required this.xpEarned,
    required this.lessonsCompleted,
  });
}

abstract class ILearnerRepository {
  Future<void> _srsWriteChain = Future<void>.value();

  /// Production persistence currently completes lessons/reinforcements through
  /// server RPCs. Demo repositories may still maintain roadmap state locally.
  bool get supportsNodeCompletion => true;
  bool get supportsServerPlacementPersistence => false;
  bool get supportsPlacementSessions => false;
  bool get supportsServerReinforcementPersistence => false;

  Future<PlacementSession> advancePlacement(
    String courseId, {
    String? sessionId,
    String? questionId,
    int? selectedIndex,
    bool restart = false,
  }) async => throw UnsupportedError('Placement sessions require a server.');

  Future<LearnerProfile> getProfile();
  Future<LearnerProfile> getCurrentProfile();
  Future<LearnerProfile> updateProfile(
    LearnerProfile updated, {
    Set<LearnerProfileField>? fields,
  });
  Future<LearnerProfile> saveCourseLearningPlan({
    required String courseId,
    required OnboardingGoal goal,
    required int dailyMinutes,
    required InitialLevel initialLevel,
  }) async {
    final current = await getProfile();
    if (current.selectedCourseId != courseId) {
      throw StateError('Joriy fan o‘zgargan. Fanni qayta tanlang.');
    }
    return updateProfile(
      current.copyWith(
        goal: goal,
        dailyMinutes: dailyMinutes,
        initialLevel: initialLevel,
        courseLevels: {...current.courseLevels, courseId: initialLevel},
      ),
      fields: {
        LearnerProfileField.goal,
        LearnerProfileField.dailyMinutes,
        LearnerProfileField.initialLevel,
        LearnerProfileField.courseLevels,
      },
    );
  }

  Future<void> savePlacementSummary({
    required String courseId,
    required int score,
    required String cefrTier,
  }) async {
    final current = await getProfile();
    final nextScores = Map<String, int>.from(current.placementScoreByCourse)
      ..[courseId] = score;
    final nextCefr = Map<String, String>.from(current.placementCefrByCourse)
      ..[courseId] = cefrTier;
    await updateProfile(
      current.copyWith(
        placementScoreByCourse: nextScores,
        placementCefrByCourse: nextCefr,
      ),
      fields: {
        LearnerProfileField.placementScoreByCourse,
        LearnerProfileField.placementCefrByCourse,
      },
    );
  }

  Future<void> saveSkillScores(String courseId, Map<String, SkillScore> scores);
  Future<LearnerProfile> recordFlashcardReview({
    required String courseId,
    required String cardId,
    required bool remembered,
  }) {
    final next = _srsWriteChain
        .catchError((Object _) {})
        .then(
          (_) => _performRecordFlashcardReview(
            courseId: courseId,
            cardId: cardId,
            remembered: remembered,
          ),
        );
    _srsWriteChain = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<LearnerProfile> _performRecordFlashcardReview({
    required String courseId,
    required String cardId,
    required bool remembered,
  }) async {
    final current = await getProfile();
    final currentCourseMap = Map<String, FlashcardSrsRecord>.from(
      current.flashcardSrsByCourse[courseId] ?? const {},
    );
    final prev = currentCourseMap[cardId] ?? const FlashcardSrsRecord();
    final nowUtc = DateTime.now().toUtc();
    final nowIso = nowUtc.toIso8601String();
    final nextRecord = remembered
        ? () {
            final nextBucket = (prev.intervalBucket + 1).clamp(1, 3);
            final nextReviewBucket = switch (nextBucket) {
              1 => 'daily',
              2 => '3_days',
              _ => 'mastered',
            };
            final nextDueAt = nowUtc
                .add(
                  Duration(
                    days: nextBucket == 1
                        ? 1
                        : nextBucket == 2
                        ? 3
                        : 7,
                  ),
                )
                .toIso8601String();
            return FlashcardSrsRecord(
              status: 'remembered',
              reviewCount: prev.reviewCount + 1,
              intervalBucket: nextBucket,
              lastReviewedAt: nowIso,
              nextReviewBucket: nextReviewBucket,
              nextReviewAt: nextDueAt,
            );
          }()
        : FlashcardSrsRecord(
            status: 'need_practice',
            reviewCount: prev.reviewCount + 1,
            intervalBucket: 0,
            lastReviewedAt: nowIso,
            nextReviewBucket: 'session_next',
            nextReviewAt: nowIso,
          );
    currentCourseMap[cardId] = nextRecord;
    final nextByCourse = Map<String, Map<String, FlashcardSrsRecord>>.from(
      current.flashcardSrsByCourse,
    )..[courseId] = currentCourseMap;
    return updateProfile(
      current.copyWith(flashcardSrsByCourse: nextByCourse),
      fields: {LearnerProfileField.flashcardSrsByCourse},
    );
  }
  Future<String> savePlacementAttempt(PlacementAttemptData data);
  Future<PlacementAnswerEvaluation> evaluatePlacementAnswer({
    required String courseId,
    required String questionId,
    required int selectedIndex,
  });
  Future<void> markLessonCompleted(String lessonId, {String? courseId});
  Future<void> markNodeCompleted(String nodeId, {String? courseId});

  /// Returns authoritative persisted values online, or null for demo scoring.
  Future<ReinforcementCompletionResult?> markReinforcementCompleted({
    required String reinforcementId,
    required String courseId,
    required String skillId,
    required String questionId,
    required int beforeScore,
    required int afterScore,
    required int xpAwarded,
  });
  Future<AnswerAttemptRecord> recordAnswerAttempt({
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
    required bool isCorrect,
  });

  /// Submits an answer without accepting a client-computed correctness value.
  /// Online repositories must evaluate it against trusted server content;
  /// offline repositories may evaluate it against their bundled demo content.
  Future<AnswerAttemptRecord> submitAnswerAttempt({
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
  });
  Future<List<AnswerAttemptRecord>> getAnswerAttempts([int limit = 10]);
  Future<List<DailyActivitySummary>> getDailyActivity([int days = 7]);
  Future<int> addXp(int amount, [String? actionIdempotencyKey]);
  Future<int> recordDailyActivity([String? dateStr]);
  Future<void> clearLocalState();
  Future<LearnerProfile> resetAll();
}
