import 'dart:math';
import '../../domain/repositories/i_learner_repository.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/skill_score.dart';
import '../../domain/personalization/skill_scoring_engine.dart';

class InMemoryLearnerRepository implements ILearnerRepository {
  final List<AnswerAttemptRecord> _answerAttempts = [];
  final Set<String> _processedActionKeys = {};
  final Set<String> _recordedActivityDates = {};

  LearnerProfile _profile = LearnerProfile(
    id: 'learner_mobile_01',
    name: 'O‘quvchi',
    selectedCourseId: 'course_math_01',
    goal: OnboardingGoal.mastery,
    dailyMinutes: 15,
    initialLevel: InitialLevel.intermediate,
    xp: 0,
    streakDays: 1,
    lastActiveDate: DateTime.now().toIso8601String().split('T').first,
    scoresByCourse: {},
    completedLessonIds: [],
    completedNodeIds: [],
    completedReinforcementIds: [],
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );

  @override
  Future<LearnerProfile> getProfile() async {
    return _profile;
  }

  @override
  Future<LearnerProfile> updateProfile(LearnerProfile updated) async {
    _profile = updated;
    return _profile;
  }

  @override
  Future<void> saveSkillScores(String courseId, Map<String, SkillScore> scores) async {
    final currentScores = Map<String, Map<String, SkillScore>>.from(_profile.scoresByCourse);
    final courseMap = Map<String, SkillScore>.from(currentScores[courseId] ?? {});
    courseMap.addAll(scores);
    currentScores[courseId] = courseMap;

    _profile = _profile.copyWith(scoresByCourse: currentScores);
  }

  @override
  Future<String> savePlacementAttempt(PlacementAttemptData data) async {
    return 'plc_att_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<void> markLessonCompleted(String lessonId) async {
    if (!_profile.completedLessonIds.contains(lessonId)) {
      final list = List<String>.from(_profile.completedLessonIds)..add(lessonId);
      _profile = _profile.copyWith(completedLessonIds: list);
      await addXp(20, 'lesson_completed_$lessonId');
      await recordDailyActivity();
    }
  }

  @override
  Future<void> markNodeCompleted(String nodeId) async {
    if (!_profile.completedNodeIds.contains(nodeId)) {
      final list = List<String>.from(_profile.completedNodeIds)..add(nodeId);
      _profile = _profile.copyWith(completedNodeIds: list);
    }
  }

  @override
  Future<void> markReinforcementCompleted(String reinforcementId) async {
    if (!_profile.completedReinforcementIds.contains(reinforcementId)) {
      final list = List<String>.from(_profile.completedReinforcementIds)..add(reinforcementId);
      _profile = _profile.copyWith(completedReinforcementIds: list);
      await addXp(15, 'reinforcement_completed_$reinforcementId');
      await recordDailyActivity();
    }
  }

  @override
  Future<AnswerAttemptRecord> recordAnswerAttempt({
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
    required bool isCorrect,
  }) async {
    final record = AnswerAttemptRecord(
      id: 'att_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      courseId: courseId,
      skillId: skillId,
      lessonId: lessonId,
      questionId: questionId,
      selectedIndex: selectedIndex,
      selectedAnswer: selectedAnswer,
      isCorrect: isCorrect,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _answerAttempts.add(record);

    if (isCorrect) {
      await addXp(2, 'answer_${questionId}_${record.id}');
    }
    await recordDailyActivity();

    // Recalculate cumulative skill score
    final skillAttempts = _answerAttempts
        .where((a) => a.courseId == courseId && a.skillId == skillId)
        .toList();
    final correctCount = skillAttempts.where((a) => a.isCorrect).length;
    final newScoreVal = SkillScoringEngine.computeSkillScore(correctCount, skillAttempts.length);

    final currentScores = Map<String, Map<String, SkillScore>>.from(_profile.scoresByCourse);
    final courseMap = Map<String, SkillScore>.from(currentScores[courseId] ?? {});
    courseMap[skillId] = SkillScore(
      skillId: skillId,
      courseId: courseId,
      score: newScoreVal,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      masteryLevel: SkillScoringEngine.getMasteryLevel(newScoreVal),
    );
    currentScores[courseId] = courseMap;
    _profile = _profile.copyWith(scoresByCourse: currentScores);

    return record;
  }

  @override
  Future<List<AnswerAttemptRecord>> getAnswerAttempts([int limit = 10]) async {
    if (_answerAttempts.length <= limit) {
      return List.from(_answerAttempts);
    }
    return _answerAttempts.sublist(_answerAttempts.length - limit);
  }

  @override
  Future<int> addXp(int amount, [String? actionIdempotencyKey]) async {
    if (actionIdempotencyKey != null) {
      if (_processedActionKeys.contains(actionIdempotencyKey)) {
        return _profile.xp;
      }
      _processedActionKeys.add(actionIdempotencyKey);
    }
    final newXp = _profile.xp + amount;
    _profile = _profile.copyWith(xp: newXp);
    return newXp;
  }

  @override
  Future<int> recordDailyActivity([String? dateStr]) async {
    final today = dateStr ?? DateTime.now().toIso8601String().split('T').first;
    if (_recordedActivityDates.contains(today)) {
      return _profile.streakDays;
    }

    _recordedActivityDates.add(today);
    final lastDate = _profile.lastActiveDate;

    int newStreak = _profile.streakDays;
    if (lastDate.isEmpty) {
      newStreak = 1;
    } else if (lastDate == today) {
      // unchanged
    } else {
      try {
        final prevDt = DateTime.parse(lastDate);
        final currDt = DateTime.parse(today);
        final diffDays = currDt.difference(prevDt).inDays;
        if (diffDays == 1) {
          newStreak = _profile.streakDays + 1;
        } else {
          newStreak = 1;
        }
      } catch (_) {
        newStreak = 1;
      }
    }

    _profile = _profile.copyWith(streakDays: newStreak, lastActiveDate: today);
    return newStreak;
  }

  @override
  Future<LearnerProfile> resetAll() async {
    _profile = LearnerProfile(
      id: 'learner_mobile_01',
      name: 'O‘quvchi',
      selectedCourseId: 'course_math_01',
      goal: OnboardingGoal.mastery,
      dailyMinutes: 15,
      initialLevel: InitialLevel.intermediate,
      xp: 0,
      streakDays: 1,
      lastActiveDate: DateTime.now().toIso8601String().split('T').first,
      scoresByCourse: {},
      completedLessonIds: [],
      completedNodeIds: [],
      completedReinforcementIds: [],
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _answerAttempts.clear();
    _processedActionKeys.clear();
    _recordedActivityDates.clear();
    return _profile;
  }
}
