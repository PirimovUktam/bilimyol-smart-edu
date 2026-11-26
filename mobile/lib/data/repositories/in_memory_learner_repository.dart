import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../core/storage/local_storage_service.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/skill_score.dart';
import '../../domain/personalization/skill_scoring_engine.dart';
import '../../domain/repositories/i_learner_repository.dart';
import '../datasources/lessons_data.dart';
import '../datasources/questions_data.dart';
import '../datasources/roadmaps_data.dart';
import '../datasources/starter_lessons_data.dart';

class _SkillBaseline {
  final int score;
  final int attemptCountAtBaseline;

  const _SkillBaseline({
    required this.score,
    required this.attemptCountAtBaseline,
  });

  Map<String, dynamic> toJson() => {
    'score': score,
    'attemptCountAtBaseline': attemptCountAtBaseline,
  };

  static _SkillBaseline? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final score = raw['score'];
    final count = raw['attemptCountAtBaseline'];
    if (score is! num || count is! num) return null;
    return _SkillBaseline(
      score: score.toInt().clamp(0, 100),
      attemptCountAtBaseline: count.toInt().clamp(0, 1000000),
    );
  }
}

class _DailyBonusEvent {
  final int timestamp;
  final int xpEarned;
  final int lessonsCompleted;

  const _DailyBonusEvent({
    required this.timestamp,
    required this.xpEarned,
    required this.lessonsCompleted,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'xpEarned': xpEarned,
    'lessonsCompleted': lessonsCompleted,
  };

  static _DailyBonusEvent? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final ts = raw['timestamp'];
    if (ts is! num) return null;
    return _DailyBonusEvent(
      timestamp: ts.toInt(),
      xpEarned: raw['xpEarned'] is num ? (raw['xpEarned'] as num).toInt() : 0,
      lessonsCompleted: raw['lessonsCompleted'] is num
          ? (raw['lessonsCompleted'] as num).toInt()
          : 0,
    );
  }
}

class InMemoryLearnerRepository extends ILearnerRepository {
  static const int _snapshotVersion = 1;

  final LocalStorageService storage;
  Future<void>? _hydrationFuture;
  bool _hydrated = false;
  int _hydrationEpoch = 0;
  bool _currentEpochHasPersisted = false;
  bool _dirtySnapshotPendingPersist = false;
  int _snapshotMutationSeq = 0;
  Future<void> _storageWriteChain = Future.value();
  Future<void> _pendingClearChain = Future.value();
  Future<void>? _activeEpochMutation;

  InMemoryLearnerRepository({LocalStorageService? storage})
    : storage = storage ?? LocalStorageService();

  @override
  bool get supportsNodeCompletion => true;

  @override
  bool get supportsServerPlacementPersistence => false;

  @override
  bool get supportsServerReinforcementPersistence => false;

  final List<AnswerAttemptRecord> _answerAttempts = [];
  final List<_DailyBonusEvent> _dailyBonusEvents = [];
  final Set<String> _processedActionKeys = {};
  final Set<String> _recordedActivityDates = {};
  final Map<String, Map<String, _SkillBaseline>> _skillBaselines = {};

  LearnerProfile _profile = _defaultProfile();

  static LearnerProfile _defaultProfile() => LearnerProfile(
    id: 'learner_mobile_01',
    name: 'Foydalanuvchi',
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

  Future<void> _ensureHydrated() {
    if (_hydrated) return Future.value();
    return _hydrationFuture ??= _hydrateFromStorage();
  }

  Future<void> _hydrateFromStorage() async {
    final epoch = _hydrationEpoch;
    try {
      final raw = await storage.getDemoLearnerSnapshot();
      if (_hydrationEpoch != epoch) return;
      if (raw == null || raw.trim().isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != _snapshotVersion) {
        return;
      }

      final profileJson = decoded['profile'];
      if (profileJson != null && profileJson is! Map<String, dynamic>) {
        return;
      }
      final parsedProfile = profileJson is Map<String, dynamic>
          ? _profileFromJson(profileJson)
          : _defaultProfile();

      final attemptsJson = decoded['answerAttempts'];
      if (attemptsJson != null && attemptsJson is! List) {
        return;
      }
      final parsedAttempts = <AnswerAttemptRecord>[];
      if (attemptsJson is List) {
        for (final item in attemptsJson) {
          if (item is! Map<String, dynamic>) {
            return;
          }
          final parsed = _attemptFromJson(item);
          if (parsed == null) {
            return;
          }
          parsedAttempts.add(parsed);
        }
      }

      final actionKeysJson = decoded['processedActionKeys'];
      if (actionKeysJson != null && actionKeysJson is! List) {
        return;
      }
      final parsedActionKeys = actionKeysJson is List
          ? actionKeysJson.whereType<String>().toSet()
          : const <String>{};

      final activityDatesJson = decoded['recordedActivityDates'];
      if (activityDatesJson != null && activityDatesJson is! List) {
        return;
      }
      final parsedActivityDates = activityDatesJson is List
          ? activityDatesJson.whereType<String>().toSet()
          : const <String>{};

      final baselinesJson = decoded['skillBaselines'];
      if (baselinesJson != null && baselinesJson is! Map) {
        return;
      }
      final parsedBaselines = <String, Map<String, _SkillBaseline>>{};
      if (baselinesJson is Map) {
        for (final courseEntry in baselinesJson.entries) {
          final courseId = courseEntry.key;
          final skillMapRaw = courseEntry.value;
          if (courseId is! String || skillMapRaw is! Map) {
            return;
          }
          final parsedSkills = <String, _SkillBaseline>{};
          for (final skillEntry in skillMapRaw.entries) {
            final skillId = skillEntry.key;
            final parsed = _SkillBaseline.fromJson(skillEntry.value);
            if (skillId is! String || parsed == null) {
              return;
            }
            parsedSkills[skillId] = parsed;
          }
          if (parsedSkills.isNotEmpty) {
            parsedBaselines[courseId] = parsedSkills;
          }
        }
      }

      final bonusEventsJson = decoded['dailyBonusEvents'];
      final parsedBonusEvents = <_DailyBonusEvent>[];
      if (bonusEventsJson is List) {
        for (final item in bonusEventsJson) {
          final parsed = _DailyBonusEvent.fromJson(item);
          if (parsed != null) {
            parsedBonusEvents.add(parsed);
          }
        }
      }

      if (_hydrationEpoch != epoch) return;
      _profile = parsedProfile;
      _answerAttempts
        ..clear()
        ..addAll(parsedAttempts);
      _dailyBonusEvents
        ..clear()
        ..addAll(parsedBonusEvents);
      _processedActionKeys
        ..clear()
        ..addAll(parsedActionKeys);
      _recordedActivityDates
        ..clear()
        ..addAll(parsedActivityDates);
      _skillBaselines
        ..clear()
        ..addAll(parsedBaselines);
    } catch (_) {
      // Corrupt snapshot payloads are ignored safely so fresh demo state loads.
    } finally {
      if (_hydrationEpoch == epoch) {
        _hydrated = true;
        _hydrationFuture = null;
      }
    }
  }

  Future<T> _runSerializedMutation<T>(
    Future<T> Function(int epoch) action,
  ) async {
    final epoch = _hydrationEpoch;
    while (epoch == _hydrationEpoch && _activeEpochMutation != null) {
      final pending = _activeEpochMutation!;
      try {
        await pending;
      } catch (_) {
        // Previous mutation failed and handled/rolled back its state.
      }
    }
    if (epoch != _hydrationEpoch) {
      return action(epoch);
    }
    final gate = Completer<void>();
    _activeEpochMutation = gate.future;
    try {
      return await action(epoch);
    } finally {
      if (identical(_activeEpochMutation, gate.future)) {
        _activeEpochMutation = null;
      }
      if (!gate.isCompleted) {
        gate.complete();
      }
    }
  }

  void _markDirty() {
    _dirtySnapshotPendingPersist = true;
    _snapshotMutationSeq++;
  }

  Future<void> _persistSnapshot({int? expectedEpoch}) async {
    final epoch = expectedEpoch ?? _hydrationEpoch;
    if (epoch != _hydrationEpoch) return;
    final store = storage;
    final writeSeq = _snapshotMutationSeq;
    final op = _storageWriteChain.then((_) async {
      final clearToWait = _pendingClearChain;
      await clearToWait;
      if (epoch != _hydrationEpoch) return;
      final payload = {
        'version': _snapshotVersion,
        'profile': _profileToJson(_profile),
        'answerAttempts': _answerAttempts.map(_attemptToJson).toList(),
        'dailyBonusEvents': _dailyBonusEvents.map((e) => e.toJson()).toList(),
        'processedActionKeys': _processedActionKeys.toList(),
        'recordedActivityDates': _recordedActivityDates.toList(),
        'skillBaselines': {
          for (final entry in _skillBaselines.entries)
            entry.key: {
              for (final skillEntry in entry.value.entries)
                skillEntry.key: skillEntry.value.toJson(),
            },
        },
      };
      final encoded = jsonEncode(payload);
      await store.setDemoLearnerSnapshot(encoded);
      if (epoch == _hydrationEpoch) {
        _currentEpochHasPersisted = true;
        if (writeSeq == _snapshotMutationSeq) {
          _dirtySnapshotPendingPersist = false;
        }
      } else if (!_currentEpochHasPersisted) {
        await store.clearDemoLearnerSnapshot();
      }
    });
    _storageWriteChain = op.catchError((_) {});
    return op;
  }

  @override
  Future<LearnerProfile> getCurrentProfile() async {
    await _ensureHydrated();
    return _profile;
  }

  @override
  Future<LearnerProfile> getProfile() async {
    await _ensureHydrated();
    return _profile;
  }

  @override
  Future<LearnerProfile> updateProfile(
    LearnerProfile updated, {
    Set<LearnerProfileField>? fields,
  }) {
    return _runSerializedMutation((epoch) async {
      await _ensureHydrated();
      if (epoch != _hydrationEpoch) return _profile;
      if (fields == null) {
        _profile = updated;
      } else {
        _profile = _profile.copyWith(
          name: fields.contains(LearnerProfileField.name) ? updated.name : null,
          selectedCourseId: fields.contains(LearnerProfileField.selectedCourse)
              ? updated.selectedCourseId
              : null,
          goal: fields.contains(LearnerProfileField.goal) ? updated.goal : null,
          dailyMinutes: fields.contains(LearnerProfileField.dailyMinutes)
              ? updated.dailyMinutes
              : null,
          initialLevel: fields.contains(LearnerProfileField.initialLevel)
              ? updated.initialLevel
              : null,
          courseLevels: fields.contains(LearnerProfileField.courseLevels)
              ? updated.courseLevels
              : null,
          placementScoreByCourse:
              fields.contains(LearnerProfileField.placementScoreByCourse)
              ? updated.placementScoreByCourse
              : null,
          placementCefrByCourse:
              fields.contains(LearnerProfileField.placementCefrByCourse)
              ? updated.placementCefrByCourse
              : null,
          flashcardSrsByCourse:
              fields.contains(LearnerProfileField.flashcardSrsByCourse)
              ? updated.flashcardSrsByCourse
              : null,
        );
      }
      _markDirty();
      await _persistSnapshot(expectedEpoch: epoch);
      return _profile;
    });
  }

  @override
  Future<void> saveSkillScores(
    String courseId,
    Map<String, SkillScore> scores,
  ) {
    return _runSerializedMutation((epoch) async {
      await _ensureHydrated();
      if (epoch != _hydrationEpoch) return;
      final currentScores = Map<String, Map<String, SkillScore>>.from(
        _profile.scoresByCourse,
      );
      final courseMap = Map<String, SkillScore>.from(
        currentScores[courseId] ?? {},
      );
      courseMap.addAll(scores);
      currentScores[courseId] = courseMap;

      final courseBaselines = Map<String, _SkillBaseline>.from(
        _skillBaselines[courseId] ?? {},
      );
      for (final entry in scores.entries) {
        final existingCount = _answerAttempts
            .where(
              (a) =>
                  a.courseId == courseId &&
                  a.skillId == entry.key &&
                  !(courseId == 'course_eng_01' &&
                      a.lessonId == 'placement_test'),
            )
            .length;
        courseBaselines[entry.key] = _SkillBaseline(
          score: entry.value.score,
          attemptCountAtBaseline: existingCount,
        );
      }
      _skillBaselines[courseId] = courseBaselines;

      _profile = _profile.copyWith(scoresByCourse: currentScores);
      _markDirty();
      await _persistSnapshot(expectedEpoch: epoch);
    });
  }

  @override
  Future<String> savePlacementAttempt(PlacementAttemptData data) {
    return _runSerializedMutation((epoch) async {
      await _ensureHydrated();
      if (epoch == _hydrationEpoch) {
        final nextPlacementScores = Map<String, int>.from(
          _profile.placementScoreByCourse,
        )..[data.courseId] = data.score;
        final nextPlacementCefr = Map<String, String>.from(
          _profile.placementCefrByCourse,
        );
        if (data.cefrLevel != null && data.cefrLevel!.trim().isNotEmpty) {
          nextPlacementCefr[data.courseId] = data.cefrLevel!.trim();
        }
        _profile = _profile.copyWith(
          placementScoreByCourse: nextPlacementScores,
          placementCefrByCourse: nextPlacementCefr,
        );
        _markDirty();
        await _persistSnapshot(expectedEpoch: epoch);
      }
      return 'plc_att_${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  @override
  Future<PlacementAnswerEvaluation> evaluatePlacementAnswer({
    required String courseId,
    required String questionId,
    required int selectedIndex,
  }) async {
    await _ensureHydrated();
    final question = placementQuestionsData[courseId]
        ?.where((item) => item.id == questionId)
        .firstOrNull;
    return PlacementAnswerEvaluation(
      isCorrect: question?.correctIndex == selectedIndex,
    );
  }

  @override
  Future<void> markLessonCompleted(String lessonId, {String? courseId}) {
    return _runSerializedMutation((epoch) async {
      await _ensureHydrated();
      if (epoch != _hydrationEpoch) return;
      if (!_profile.completedLessonIds.contains(lessonId)) {
        final list = List<String>.from(_profile.completedLessonIds)
          ..add(lessonId);
        final roadmapNodes = courseId != null
            ? (seedRoadmapNodes[courseId] ?? const [])
            : seedRoadmapNodes.values.expand((nodes) => nodes).toList();
        final targetNodeIds = roadmapNodes
            .where((node) => node.targetLessonId == lessonId)
            .map((node) => node.id);
        _profile = _profile.copyWith(
          completedLessonIds: list,
          completedNodeIds: [
            ...<String>{..._profile.completedNodeIds, ...targetNodeIds},
          ],
        );
        final addedXp = _addXpInMemory(20, 'lesson_completed_$lessonId');
        _dailyBonusEvents.add(
          _DailyBonusEvent(
            timestamp: DateTime.now().millisecondsSinceEpoch,
            xpEarned: addedXp ? 20 : 0,
            lessonsCompleted: 1,
          ),
        );
        _applyDailyActivityInMemory();
        _markDirty();
        await _persistSnapshot(expectedEpoch: epoch);
      } else if (_dirtySnapshotPendingPersist) {
        if (_applyDailyActivityInMemory()) {
          _markDirty();
        }
        await _persistSnapshot(expectedEpoch: epoch);
      }
    });
  }

  @override
  Future<void> markNodeCompleted(String nodeId, {String? courseId}) {
    return _runSerializedMutation((epoch) async {
      await _ensureHydrated();
      if (epoch != _hydrationEpoch) return;
      if (!_profile.completedNodeIds.contains(nodeId)) {
        final list = List<String>.from(_profile.completedNodeIds)..add(nodeId);
        _profile = _profile.copyWith(completedNodeIds: list);
        _markDirty();
        await _persistSnapshot(expectedEpoch: epoch);
      } else if (_dirtySnapshotPendingPersist) {
        await _persistSnapshot(expectedEpoch: epoch);
      }
    });
  }

  @override
  Future<ReinforcementCompletionResult?> markReinforcementCompleted({
    required String reinforcementId,
    required String courseId,
    required String skillId,
    required String questionId,
    required int beforeScore,
    required int afterScore,
    required int xpAwarded,
  }) {
    return _runSerializedMutation((epoch) async {
      await _ensureHydrated();
      if (epoch != _hydrationEpoch) return null;
      if (!_profile.completedReinforcementIds.contains(reinforcementId)) {
        final list = List<String>.from(_profile.completedReinforcementIds)
          ..add(reinforcementId);
        _profile = _profile.copyWith(completedReinforcementIds: list);
        _dailyBonusEvents.add(
          _DailyBonusEvent(
            timestamp: DateTime.now().millisecondsSinceEpoch,
            xpEarned: xpAwarded > 0 ? xpAwarded : 0,
            lessonsCompleted: 0,
          ),
        );
        _applyDailyActivityInMemory();
        _markDirty();
        await _persistSnapshot(expectedEpoch: epoch);
      } else if (_dirtySnapshotPendingPersist) {
        if (_applyDailyActivityInMemory()) {
          _markDirty();
        }
        await _persistSnapshot(expectedEpoch: epoch);
      }
      return null;
    });
  }

  SkillScore? _computeCourseSkillScore(String courseId, String skillId) {
    final skillAttempts = _answerAttempts
        .where(
          (a) =>
              a.courseId == courseId &&
              a.skillId == skillId &&
              !(courseId == 'course_eng_01' && a.lessonId == 'placement_test'),
        )
        .toList();
    final baseline = _skillBaselines[courseId]?[skillId];
    final postBaselineAttempts = baseline != null &&
            baseline.attemptCountAtBaseline <= skillAttempts.length
        ? skillAttempts.skip(baseline.attemptCountAtBaseline).toList()
        : skillAttempts;

    if (postBaselineAttempts.isEmpty && baseline == null) {
      return null;
    }

    final int newScoreVal;
    if (postBaselineAttempts.isEmpty) {
      newScoreVal = baseline!.score;
    } else if (courseId == 'course_eng_01' && baseline == null) {
      // English lesson attempts without a prior baseline deduplicate by
      // questionId (latest attempt wins) so retries yield full mastery.
      final latestByQuestion = <String, AnswerAttemptRecord>{};
      for (final attempt in postBaselineAttempts) {
        latestByQuestion[attempt.questionId] = attempt;
      }
      final uniqueAttempts = latestByQuestion.values.toList();
      final correctCount = uniqueAttempts.where((a) => a.isCorrect).length;
      newScoreVal = SkillScoringEngine.computeSkillScore(
        correctCount,
        uniqueAttempts.length,
      );
    } else {
      var weightedCorrect = 0.0;
      var weightedTotal = 0.0;
      var hasNonStarterAttempt = false;
      for (final attempt in postBaselineAttempts) {
        final isStarter = starterLessons.containsKey(attempt.lessonId);
        final weight = isStarter ? 0.5 : 1.0;
        if (!isStarter) {
          hasNonStarterAttempt = true;
        }
        weightedTotal += weight;
        if (attempt.isCorrect) {
          weightedCorrect += weight;
        }
      }
      newScoreVal = SkillScoringEngine.computeCalibratedSkillScore(
        weightedCorrect: weightedCorrect,
        weightedTotal: weightedTotal,
        priorScore: baseline?.score,
        starterOnly: baseline == null && !hasNonStarterAttempt,
        hasNonStarterAttempt: hasNonStarterAttempt,
      );
    }

    return SkillScore(
      skillId: skillId,
      courseId: courseId,
      score: newScoreVal,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      masteryLevel: SkillScoringEngine.getMasteryLevel(newScoreVal),
    );
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
  }) {
    if (selectedAnswer.length > 4000) {
      return Future<AnswerAttemptRecord>.error(
        ArgumentError('Javob matni uzunligi 4000 belgidan oshmasligi shart.'),
      );
    }
    final rawExplicitKey = ILearnerRepository.currentAttemptIdempotencyKey;
    String? explicitKey;
    if (rawExplicitKey != null) {
      explicitKey = rawExplicitKey.trim();
      if (explicitKey.isEmpty || explicitKey.length > 128) {
        return Future<AnswerAttemptRecord>.error(
          ArgumentError(
            'Idempotency kaliti 1..128 belgi oralig‘ida bo‘lishi shart.',
          ),
        );
      }
    }

    return _runSerializedMutation((epoch) async {
      await _ensureHydrated();
      if (explicitKey != null) {
        final existing = _answerAttempts
            .where((a) => a.idempotencyKey == explicitKey)
            .firstOrNull;
        if (existing != null) {
          if (existing.courseId != courseId ||
              existing.skillId != skillId ||
              existing.lessonId != lessonId ||
              existing.questionId != questionId ||
              existing.selectedIndex != selectedIndex ||
              existing.selectedAnswer != selectedAnswer) {
            throw ArgumentError(
              'Idempotency kaliti boshqa javob uchun ishlatilgan.',
            );
          }
          return AnswerAttemptRecord(
            id: existing.id,
            courseId: existing.courseId,
            skillId: existing.skillId,
            lessonId: existing.lessonId,
            questionId: existing.questionId,
            selectedIndex: existing.selectedIndex,
            selectedAnswer: existing.selectedAnswer,
            isCorrect: existing.isCorrect,
            timestamp: existing.timestamp,
            correctOption: existing.correctOption,
            explanation: existing.explanation,
            newSkillScore: existing.newSkillScore ??
                _profile.scoresByCourse[courseId]?[skillId]?.score,
            xpAwarded: 0,
            alreadyProcessed: true,
            idempotencyKey: explicitKey,
          );
        }
      }

      final attemptId =
          'att_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      final attemptTs = DateTime.now().millisecondsSinceEpoch;
      if (epoch != _hydrationEpoch) {
        return AnswerAttemptRecord(
          id: attemptId,
          courseId: courseId,
          skillId: skillId,
          lessonId: lessonId,
          questionId: questionId,
          selectedIndex: selectedIndex,
          selectedAnswer: selectedAnswer,
          isCorrect: isCorrect,
          timestamp: attemptTs,
          correctOption: isCorrect ? selectedAnswer : null,
          idempotencyKey: explicitKey,
        );
      }

      final prevProfile = _profile;
      final prevWasDirty = _dirtySnapshotPendingPersist;
      final today = DateTime.now().toIso8601String().split('T').first;
      final actionKey = isCorrect ? 'answer_correct_$questionId' : null;
      final attemptKeyMarker =
          explicitKey != null ? 'attempt_key:$explicitKey' : null;

      final addedActionKey =
          actionKey != null && _processedActionKeys.add(actionKey);
      final addedAttemptMarker =
          attemptKeyMarker != null &&
          _processedActionKeys.add(attemptKeyMarker);
      final provisionalRecord = AnswerAttemptRecord(
        id: attemptId,
        courseId: courseId,
        skillId: skillId,
        lessonId: lessonId,
        questionId: questionId,
        selectedIndex: selectedIndex,
        selectedAnswer: selectedAnswer,
        isCorrect: isCorrect,
        timestamp: attemptTs,
        correctOption: isCorrect ? selectedAnswer : null,
        xpAwarded: addedActionKey ? 2 : 0,
        alreadyProcessed: false,
        idempotencyKey: explicitKey,
      );
      _answerAttempts.add(provisionalRecord);
      final addedToday = _applyDailyActivityInMemory(today);

      // English placement scores remain isolated from independent lesson mastery.
      final computedScore =
          (courseId == 'course_eng_01' && lessonId == 'placement_test')
              ? null
              : _computeCourseSkillScore(courseId, skillId);
      final record = computedScore == null
          ? provisionalRecord
          : AnswerAttemptRecord(
              id: provisionalRecord.id,
              courseId: provisionalRecord.courseId,
              skillId: provisionalRecord.skillId,
              lessonId: provisionalRecord.lessonId,
              questionId: provisionalRecord.questionId,
              selectedIndex: provisionalRecord.selectedIndex,
              selectedAnswer: provisionalRecord.selectedAnswer,
              isCorrect: provisionalRecord.isCorrect,
              timestamp: provisionalRecord.timestamp,
              correctOption: provisionalRecord.correctOption,
              newSkillScore: computedScore.score,
              xpAwarded: provisionalRecord.xpAwarded,
              alreadyProcessed: false,
              idempotencyKey: explicitKey,
            );
      if (!identical(record, provisionalRecord)) {
        _answerAttempts[_answerAttempts.length - 1] = record;
      }

      final currentScores = Map<String, Map<String, SkillScore>>.from(
        _profile.scoresByCourse,
      );
      final courseMap = Map<String, SkillScore>.from(
        currentScores[courseId] ?? {},
      );
      if (computedScore != null) {
        courseMap[skillId] = computedScore;
        currentScores[courseId] = courseMap;
      }
      _profile = _profile.copyWith(
        xp: addedActionKey ? _profile.xp + 2 : _profile.xp,
        scoresByCourse: currentScores,
      );
      _markDirty();
      final mutationSeq = _snapshotMutationSeq;

      try {
        await _persistSnapshot(expectedEpoch: epoch);
      } catch (_) {
        if (epoch == _hydrationEpoch) {
          if (mutationSeq == _snapshotMutationSeq) {
            _answerAttempts.remove(record);
            if (addedActionKey) {
              _processedActionKeys.remove(actionKey);
            }
            if (addedAttemptMarker) {
              _processedActionKeys.remove(attemptKeyMarker);
            }
            if (addedToday) {
              _recordedActivityDates.remove(today);
            }
            _profile = prevProfile;
            _dirtySnapshotPendingPersist = prevWasDirty;
          } else {
            _answerAttempts.remove(record);
            if (addedActionKey && _processedActionKeys.remove(actionKey)) {
              _profile = _profile.copyWith(
                xp: (_profile.xp - 2).clamp(0, 1 << 30),
              );
            }
            if (addedAttemptMarker) {
              _processedActionKeys.remove(attemptKeyMarker);
            }
            if (addedToday) {
              _recordedActivityDates.remove(today);
              if (_profile.lastActiveDate == today) {
                _profile = _profile.copyWith(
                  streakDays: prevProfile.streakDays,
                  lastActiveDate: prevProfile.lastActiveDate,
                );
              }
            }
            final updatedScores = Map<String, Map<String, SkillScore>>.from(
              _profile.scoresByCourse,
            );
            final courseScores = Map<String, SkillScore>.from(
              updatedScores[courseId] ?? {},
            );
            final recomputed = _computeCourseSkillScore(courseId, skillId);
            if (recomputed != null) {
              courseScores[skillId] = recomputed;
            } else {
              courseScores.remove(skillId);
            }
            if (courseScores.isEmpty) {
              updatedScores.remove(courseId);
            } else {
              updatedScores[courseId] = courseScores;
            }
            _profile = _profile.copyWith(scoresByCourse: updatedScores);
          }
        }
        rethrow;
      }

      return record;
    });
  }

  @override
  Future<AnswerAttemptRecord> submitAnswerAttempt({
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
  }) async {
    await _ensureHydrated();
    Question? question;
    for (final candidate in placementQuestionsData.values.expand(
      (items) => items,
    )) {
      if (candidate.id == questionId) {
        question = candidate;
        break;
      }
    }
    if (question == null) {
      for (final lesson in seedLessons.values) {
        for (final step in lesson.steps) {
          if (step.interactiveQuestion?.id == questionId) {
            question = step.interactiveQuestion;
            break;
          }
        }
        if (lesson.reinforcementExercise.id == questionId) {
          question = lesson.reinforcementExercise;
        }
        if (lesson.alternateExercise?.id == questionId) {
          question = lesson.alternateExercise;
        }
        if (question != null) break;
      }
    }
    bool hasValidPayload(Question candidate) {
      if (candidate.isSelfAssessed) {
        final trimmed = selectedAnswer.trim();
        if (trimmed.startsWith('{')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map) {
              return (decoded['response']?.toString().trim().isNotEmpty ??
                  false);
            }
          } catch (_) {}
        }
        return trimmed.isNotEmpty;
      }
      if (candidate.usesTextEvaluation) {
        return selectedAnswer.trim().isNotEmpty;
      }
      if (candidate.mode == QuestionMode.wordMatch) {
        return selectedAnswer.trim().isNotEmpty;
      }
      if (candidate.mode == QuestionMode.sentenceOrder) {
        return selectedAnswer.trim().isNotEmpty;
      }
      return selectedIndex >= 0 && selectedIndex < candidate.options.length;
    }

    final validAnswer =
        question != null &&
        question.courseId == courseId &&
        question.skillId == skillId &&
        hasValidPayload(question);
    if (!validAnswer) {
      throw StateError('Demo savoli topilmadi yoki kontekstga mos emas.');
    }

    bool evaluateAnswer(Question candidate) {
      if (candidate.usesTextEvaluation) {
        return candidate.isTextAnswerCorrect(selectedAnswer);
      }
      if (candidate.mode == QuestionMode.wordMatch) {
        try {
          final decoded = jsonDecode(selectedAnswer);
          if (decoded is Map) {
            final map = decoded.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            );
            return candidate.isWordMatchCorrect(map);
          }
        } catch (_) {}
        return false;
      }
      if (candidate.mode == QuestionMode.sentenceOrder) {
        final trimmed = selectedAnswer.trim();
        if (trimmed.startsWith('[')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is List) {
              return candidate.isSentenceOrderCorrect(
                decoded.map((e) => e.toString()).toList(growable: false),
              );
            }
          } catch (_) {}
        }
        return candidate.isTextAnswerCorrect(selectedAnswer) ||
            candidate.orderedTokens.join(' ').trim() == trimmed;
      }
      if (candidate.isSelfAssessed) {
        final trimmed = selectedAnswer.trim();
        if (trimmed.startsWith('{')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map) {
              return (decoded['response']?.toString().trim().isNotEmpty ??
                  false);
            }
          } catch (_) {}
        }
        return trimmed.isNotEmpty;
      }
      return selectedIndex == candidate.correctIndex;
    }

    final isCorrect = evaluateAnswer(question);

    final recorded = await recordAnswerAttempt(
      courseId: courseId,
      skillId: skillId,
      lessonId: lessonId,
      questionId: questionId,
      selectedIndex: selectedIndex,
      selectedAnswer: selectedAnswer,
      isCorrect: isCorrect,
    );
    String? resolvedCorrectOption;
    if (!isCorrect) {
      if (question.usesOptionSelection &&
          question.correctIndex >= 0 &&
          question.correctIndex < question.options.length) {
        resolvedCorrectOption = question.options[question.correctIndex];
      } else if (question.usesTextEvaluation &&
          question.acceptedAnswers.isNotEmpty) {
        resolvedCorrectOption = question.acceptedAnswers.first;
      } else if (question.mode == QuestionMode.sentenceOrder &&
          question.orderedTokens.isNotEmpty) {
        resolvedCorrectOption = question.orderedTokens.join(' ');
      } else if (question.mode == QuestionMode.wordMatch &&
          question.matchPairs.isNotEmpty) {
        resolvedCorrectOption = question.matchPairs
            .map((p) => '${p.left} → ${p.right}')
            .join(', ');
      }
    }
    final resolvedExplanation = isCorrect
        ? (question.explanation.isNotEmpty ? question.explanation : null)
        : (question.explanation.isNotEmpty
              ? question.explanation
              : question.wrongFeedback);
    return AnswerAttemptRecord(
      id: recorded.id,
      courseId: recorded.courseId,
      skillId: recorded.skillId,
      lessonId: recorded.lessonId,
      questionId: recorded.questionId,
      selectedIndex: recorded.selectedIndex,
      selectedAnswer: recorded.selectedAnswer,
      isCorrect: recorded.isCorrect,
      timestamp: recorded.timestamp,
      correctOption: resolvedCorrectOption,
      explanation: resolvedExplanation,
      newSkillScore: recorded.newSkillScore,
      xpAwarded: recorded.xpAwarded,
      alreadyProcessed: recorded.alreadyProcessed,
      idempotencyKey: recorded.idempotencyKey,
    );
  }

  @override
  Future<List<AnswerAttemptRecord>> getAnswerAttempts([int limit = 10]) async {
    await _ensureHydrated();
    if (_answerAttempts.length <= limit) {
      return List.from(_answerAttempts);
    }
    return _answerAttempts.sublist(_answerAttempts.length - limit);
  }

  static String _tashkentDateFromMs(int timestampMs) =>
      DateTime.fromMillisecondsSinceEpoch(
        timestampMs,
        isUtc: true,
      ).add(const Duration(hours: 5)).toIso8601String().split('T').first;

  @override
  Future<List<DailyActivitySummary>> getDailyActivity([int days = 7]) async {
    await _ensureHydrated();
    final result = <DailyActivitySummary>[];
    final tashkentNow = DateTime.now().toUtc().add(const Duration(hours: 5));
    final todayTashkentUtc = DateTime.utc(
      tashkentNow.year,
      tashkentNow.month,
      tashkentNow.day,
    );
    for (int i = days - 1; i >= 0; i--) {
      final day = todayTashkentUtc.subtract(Duration(days: i));
      final dateStr = day.toIso8601String().split('T').first;
      final dayAttempts = _answerAttempts.where((a) {
        return _tashkentDateFromMs(a.timestamp) == dateStr;
      }).toList();
      final latestByQuestion = <String, AnswerAttemptRecord>{};
      for (final attempt in dayAttempts) {
        latestByQuestion[attempt.questionId] = attempt;
      }
      final questionsAnswered = latestByQuestion.length;
      final correctAnswers = latestByQuestion.values
          .where((a) => a.isCorrect)
          .length;
      final accuracyPercent = questionsAnswered > 0
          ? ((correctAnswers * 100) / questionsAnswered).round()
          : 0;
      var xpEarned = dayAttempts.fold<int>(0, (sum, a) => sum + a.xpAwarded);
      var lessonsCompleted = 0;
      for (final ev in _dailyBonusEvents) {
        if (_tashkentDateFromMs(ev.timestamp) == dateStr) {
          xpEarned += ev.xpEarned;
          lessonsCompleted += ev.lessonsCompleted;
        }
      }
      result.add(
        DailyActivitySummary(
          date: dateStr,
          activeMinutes: (questionsAnswered * 1.5).round(),
          xpEarned: xpEarned,
          lessonsCompleted: lessonsCompleted,
          questionsAnswered: questionsAnswered,
          correctAnswers: correctAnswers,
          accuracyPercent: accuracyPercent,
        ),
      );
    }
    return result;
  }

  bool _addXpInMemory(int amount, [String? actionIdempotencyKey]) {
    if (actionIdempotencyKey != null) {
      if (_processedActionKeys.contains(actionIdempotencyKey)) {
        return false;
      }
      _processedActionKeys.add(actionIdempotencyKey);
    }
    _profile = _profile.copyWith(xp: _profile.xp + amount);
    return true;
  }

  @override
  Future<int> addXp(int amount, [String? actionIdempotencyKey]) {
    return _runSerializedMutation((epoch) async {
      await _ensureHydrated();
      if (epoch != _hydrationEpoch) return _profile.xp;
      final added = _addXpInMemory(amount, actionIdempotencyKey);
      if (!added) {
        if (_dirtySnapshotPendingPersist) {
          await _persistSnapshot(expectedEpoch: epoch);
        }
        return _profile.xp;
      }
      final newXp = _profile.xp;
      _markDirty();
      await _persistSnapshot(expectedEpoch: epoch);
      if (epoch != _hydrationEpoch) return _profile.xp;
      return newXp;
    });
  }

  bool _applyDailyActivityInMemory([String? dateStr]) {
    final today = dateStr ?? DateTime.now().toIso8601String().split('T').first;
    if (_recordedActivityDates.contains(today)) {
      return false;
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
    return true;
  }

  @override
  Future<int> recordDailyActivity([String? dateStr]) {
    return _runSerializedMutation((epoch) async {
      await _ensureHydrated();
      if (epoch != _hydrationEpoch) return _profile.streakDays;
      final added = _applyDailyActivityInMemory(dateStr);
      if (!added) {
        if (_dirtySnapshotPendingPersist) {
          await _persistSnapshot(expectedEpoch: epoch);
        }
        return _profile.streakDays;
      }

      _markDirty();
      await _persistSnapshot(expectedEpoch: epoch);
      return _profile.streakDays;
    });
  }

  @override
  Future<LearnerProfile> resetAll() async {
    _hydrationEpoch++;
    _activeEpochMutation = null;
    _currentEpochHasPersisted = false;
    _dirtySnapshotPendingPersist = false;
    _snapshotMutationSeq = 0;
    _hydrationFuture = null;
    _hydrated = true;
    final resetProfile = _defaultProfile();
    _profile = resetProfile;
    _answerAttempts.clear();
    _dailyBonusEvents.clear();
    _processedActionKeys.clear();
    _recordedActivityDates.clear();
    _skillBaselines.clear();
    final clearOp = _pendingClearChain.then(
      (_) => storage.clearDemoLearnerSnapshot(),
    );
    _pendingClearChain = clearOp.catchError((_) {});
    await clearOp;
    return resetProfile;
  }

  @override
  Future<void> clearLocalState() async {
    await resetAll();
  }

  // --- JSON Serialization Helpers ---

  static Map<String, dynamic> _profileToJson(LearnerProfile p) => {
    'id': p.id,
    'name': p.name,
    'selectedCourseId': p.selectedCourseId,
    'goal': p.goal.name,
    'dailyMinutes': p.dailyMinutes,
    'initialLevel': p.initialLevel.name,
    'courseLevels': {
      for (final entry in p.courseLevels.entries) entry.key: entry.value.name,
    },
    'xp': p.xp,
    'streakDays': p.streakDays,
    'lastActiveDate': p.lastActiveDate,
    'scoresByCourse': {
      for (final courseEntry in p.scoresByCourse.entries)
        courseEntry.key: {
          for (final skillEntry in courseEntry.value.entries)
            skillEntry.key: _skillScoreToJson(skillEntry.value),
        },
    },
    'placementScoreByCourse': p.placementScoreByCourse,
    'placementCefrByCourse': p.placementCefrByCourse,
    'flashcardSrsByCourse': {
      for (final courseEntry in p.flashcardSrsByCourse.entries)
        courseEntry.key: {
          for (final cardEntry in courseEntry.value.entries)
            cardEntry.key: cardEntry.value.toJson(),
        },
    },
    'completedLessonIds': p.completedLessonIds,
    'completedNodeIds': p.completedNodeIds,
    'completedReinforcementIds': p.completedReinforcementIds,
    'createdAt': p.createdAt,
  };

  static LearnerProfile _profileFromJson(Map<String, dynamic> json) {
    final fallback = _defaultProfile();
    final rawCourseLevels = json['courseLevels'];
    final courseLevels = <String, InitialLevel>{};
    if (rawCourseLevels is Map) {
      for (final entry in rawCourseLevels.entries) {
        if (entry.key is String && entry.value is String) {
          final level = _parseInitialLevel(entry.value as String);
          if (level != null) {
            courseLevels[entry.key as String] = level;
          }
        }
      }
    }

    final scoresByCourse = <String, Map<String, SkillScore>>{};
    final rawScores = json['scoresByCourse'];
    if (rawScores is Map) {
      for (final courseEntry in rawScores.entries) {
        final courseId = courseEntry.key;
        final skillMap = courseEntry.value;
        if (courseId is String && skillMap is Map) {
          final parsedMap = <String, SkillScore>{};
          for (final skillEntry in skillMap.entries) {
            final skillScore = _skillScoreFromJson(skillEntry.value);
            if (skillEntry.key is String && skillScore != null) {
              parsedMap[skillEntry.key as String] = skillScore;
            }
          }
          scoresByCourse[courseId] = parsedMap;
        }
      }
    }

    final placementScoreByCourse = <String, int>{};
    final rawPlacementScores = json['placementScoreByCourse'];
    if (rawPlacementScores is Map) {
      for (final entry in rawPlacementScores.entries) {
        if (entry.key is String && entry.value is num) {
          placementScoreByCourse[entry.key as String] =
              (entry.value as num).toInt();
        }
      }
    }

    final placementCefrByCourse = <String, String>{};
    final rawPlacementCefr = json['placementCefrByCourse'];
    if (rawPlacementCefr is Map) {
      for (final entry in rawPlacementCefr.entries) {
        if (entry.key is String && entry.value is String) {
          final trimmed = (entry.value as String).trim();
          if (trimmed.isNotEmpty) {
            placementCefrByCourse[entry.key as String] = trimmed;
          }
        }
      }
    }

    final flashcardSrsByCourse = <String, Map<String, FlashcardSrsRecord>>{};
    final rawSrsByCourse = json['flashcardSrsByCourse'];
    if (rawSrsByCourse is Map) {
      for (final courseEntry in rawSrsByCourse.entries) {
        final courseId = courseEntry.key;
        final rawCardsMap = courseEntry.value;
        if (courseId is String && rawCardsMap is Map) {
          final cardsMap = <String, FlashcardSrsRecord>{};
          for (final cardEntry in rawCardsMap.entries) {
            final cardId = cardEntry.key;
            final rawRecord = cardEntry.value;
            if (cardId is String && rawRecord is Map) {
              cardsMap[cardId] = FlashcardSrsRecord.fromJson(
                Map<String, dynamic>.from(rawRecord),
              );
            }
          }
          flashcardSrsByCourse[courseId] = cardsMap;
        }
      }
    }

    return LearnerProfile(
      id: json['id'] is String ? json['id'] as String : fallback.id,
      name: json['name'] is String ? json['name'] as String : fallback.name,
      selectedCourseId: json['selectedCourseId'] is String
          ? json['selectedCourseId'] as String
          : fallback.selectedCourseId,
      goal: _parseGoal(json['goal'] is String ? json['goal'] as String : null) ??
          fallback.goal,
      dailyMinutes: json['dailyMinutes'] is num &&
              (json['dailyMinutes'] as num).toInt() >= 5 &&
              (json['dailyMinutes'] as num).toInt() <= 240
          ? (json['dailyMinutes'] as num).toInt()
          : fallback.dailyMinutes,
      initialLevel:
          _parseInitialLevel(
            json['initialLevel'] is String ? json['initialLevel'] as String : null,
          ) ??
          fallback.initialLevel,
      courseLevels: courseLevels,
      xp: json['xp'] is num ? (json['xp'] as num).toInt() : fallback.xp,
      streakDays: json['streakDays'] is num
          ? (json['streakDays'] as num).toInt()
          : fallback.streakDays,
      lastActiveDate: json['lastActiveDate'] is String
          ? json['lastActiveDate'] as String
          : fallback.lastActiveDate,
      scoresByCourse: scoresByCourse,
      placementScoreByCourse: placementScoreByCourse,
      placementCefrByCourse: placementCefrByCourse,
      flashcardSrsByCourse: flashcardSrsByCourse,
      completedLessonIds: _stringList(json['completedLessonIds']),
      completedNodeIds: _stringList(json['completedNodeIds']),
      completedReinforcementIds: _stringList(json['completedReinforcementIds']),
      createdAt: json['createdAt'] is num
          ? (json['createdAt'] as num).toInt()
          : fallback.createdAt,
    );
  }

  static Map<String, dynamic> _skillScoreToJson(SkillScore s) => {
    'skillId': s.skillId,
    'courseId': s.courseId,
    'score': s.score,
    'lastUpdated': s.lastUpdated,
    'masteryLevel': s.masteryLevel.name,
    'isWeakestFocus': s.isWeakestFocus,
  };

  static SkillScore? _skillScoreFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final skillId = raw['skillId'];
    final courseId = raw['courseId'];
    final score = raw['score'];
    final lastUpdated = raw['lastUpdated'];
    if (skillId is! String ||
        courseId is! String ||
        score is! num ||
        lastUpdated is! num) {
      return null;
    }
    final clampedScore = score.toInt().clamp(0, 100);
    final masteryName =
        raw['masteryLevel'] is String ? raw['masteryLevel'] as String : null;
    final mastery = MasteryLevel.values
            .where((m) => m.name == masteryName)
            .firstOrNull ??
        SkillScoringEngine.getMasteryLevel(clampedScore);
    return SkillScore(
      skillId: skillId,
      courseId: courseId,
      score: clampedScore,
      lastUpdated: lastUpdated.toInt(),
      masteryLevel: mastery,
      isWeakestFocus: raw['isWeakestFocus'] == true,
    );
  }

  static Map<String, dynamic> _attemptToJson(AnswerAttemptRecord a) => {
    'id': a.id,
    'courseId': a.courseId,
    'skillId': a.skillId,
    'lessonId': a.lessonId,
    'questionId': a.questionId,
    'selectedIndex': a.selectedIndex,
    'selectedAnswer': a.selectedAnswer,
    'isCorrect': a.isCorrect,
    'timestamp': a.timestamp,
    if (a.correctOption != null) 'correctOption': a.correctOption,
    if (a.explanation != null) 'explanation': a.explanation,
    if (a.newSkillScore != null) 'newSkillScore': a.newSkillScore,
    'xpAwarded': a.xpAwarded,
    'alreadyProcessed': a.alreadyProcessed,
    if (a.idempotencyKey != null) 'idempotencyKey': a.idempotencyKey,
  };

  static AnswerAttemptRecord? _attemptFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final courseId = raw['courseId'];
    final skillId = raw['skillId'];
    final lessonId = raw['lessonId'];
    final questionId = raw['questionId'];
    final selectedIndex = raw['selectedIndex'];
    final selectedAnswer = raw['selectedAnswer'];
    final isCorrect = raw['isCorrect'];
    final timestamp = raw['timestamp'];
    if (id is! String ||
        courseId is! String ||
        skillId is! String ||
        lessonId is! String ||
        questionId is! String ||
        selectedIndex is! num ||
        selectedAnswer is! String ||
        isCorrect is! bool ||
        timestamp is! num) {
      return null;
    }
    return AnswerAttemptRecord(
      id: id,
      courseId: courseId,
      skillId: skillId,
      lessonId: lessonId,
      questionId: questionId,
      selectedIndex: selectedIndex.toInt(),
      selectedAnswer: selectedAnswer,
      isCorrect: isCorrect,
      timestamp: timestamp.toInt(),
      correctOption:
          raw['correctOption'] is String ? raw['correctOption'] as String : null,
      explanation:
          raw['explanation'] is String ? raw['explanation'] as String : null,
      newSkillScore: raw['newSkillScore'] is num
          ? (raw['newSkillScore'] as num).toInt().clamp(0, 100)
          : null,
      xpAwarded: raw['xpAwarded'] is num ? (raw['xpAwarded'] as num).toInt() : 0,
      alreadyProcessed: raw['alreadyProcessed'] == true,
      idempotencyKey: raw['idempotencyKey'] is String
          ? raw['idempotencyKey'] as String
          : null,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }

  static OnboardingGoal? _parseGoal(String? name) {
    if (name == null) return null;
    return OnboardingGoal.values.where((g) => g.name == name).firstOrNull;
  }

  static InitialLevel? _parseInitialLevel(String? name) {
    if (name == null) return null;
    return InitialLevel.values.where((l) => l.name == name).firstOrNull;
  }
}
