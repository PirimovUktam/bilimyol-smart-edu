import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/skill_score.dart';
import '../../domain/personalization/skill_scoring_engine.dart';
import '../../domain/repositories/i_learner_repository.dart';
import '../datasources/lessons_data.dart';
import '../datasources/questions_data.dart';
import '../datasources/roadmaps_data.dart';

class InMemoryLearnerRepository extends ILearnerRepository {
  static const String _storageKey = 'bilimyol_demo_progress_v1';

  final Future<SharedPreferences> Function() _preferencesProvider;

  InMemoryLearnerRepository({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  @override
  bool get supportsNodeCompletion => true;

  @override
  bool get supportsServerPlacementPersistence => false;

  @override
  bool get supportsServerReinforcementPersistence => false;

  final List<AnswerAttemptRecord> _answerAttempts = [];
  final Set<String> _processedActionKeys = {};
  final Set<String> _recordedActivityDates = {};

  bool _hydrated = false;
  Future<void>? _loadFuture;

  LearnerProfile _profile = _defaultProfile();

  static LearnerProfile _defaultProfile() {
    return LearnerProfile(
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
  }

  static bool _isWidgetTestBinding() {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains(
        'TestWidgetsFlutterBinding',
      );
    } catch (_) {
      return false;
    }
  }

  Future<SharedPreferences?> _getPrefs() async {
    try {
      final future = _preferencesProvider();
      if (identical(_preferencesProvider, SharedPreferences.getInstance) &&
          _isWidgetTestBinding()) {
        // In WidgetTester (FakeAsync), an unmocked MethodChannel stalls
        // indefinitely because platform replies are not pumped. Mocked
        // InMemorySharedPreferencesStore resolves within a few microtasks.
        SharedPreferences? resolved;
        var done = false;
        unawaited(
          future.then(
            (prefs) {
              resolved = prefs;
              done = true;
            },
            onError: (_, _) {
              done = true;
            },
          ),
        );
        for (var i = 0; i < 32 && !done; i++) {
          await Future<void>.microtask(() {});
        }
        return done ? resolved : null;
      }
      return await future;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureLoaded() async {
    if (_hydrated) return;
    _loadFuture ??= _loadFromPrefs();
    await _loadFuture;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await _getPrefs();
      if (prefs == null) {
        _hydrated = true;
        return;
      }
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) {
        _hydrated = true;
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _hydrated = true;
        return;
      }
      final data = Map<String, dynamic>.from(decoded);
      final rawProfile = data['profile'];
      if (rawProfile is Map) {
        _profile = _decodeProfile(Map<String, dynamic>.from(rawProfile));
      }
      final rawAttempts = data['answerAttempts'];
      if (rawAttempts is List) {
        _answerAttempts
          ..clear()
          ..addAll(
            rawAttempts
                .whereType<Map>()
                .map((item) => _decodeAttempt(Map<String, dynamic>.from(item))),
          );
      }
      final rawKeys = data['processedActionKeys'];
      if (rawKeys is List) {
        _processedActionKeys
          ..clear()
          ..addAll(rawKeys.whereType<String>());
      }
      final rawDates = data['recordedActivityDates'];
      if (rawDates is List) {
        _recordedActivityDates
          ..clear()
          ..addAll(rawDates.whereType<String>());
      }
    } catch (_) {
      // Ignore corrupt or unavailable persisted demo snapshot.
    } finally {
      _hydrated = true;
    }
  }

  Future<void> _persist() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    try {
      final payload = jsonEncode({
        'profile': _encodeProfile(_profile),
        'answerAttempts': _answerAttempts.map(_encodeAttempt).toList(),
        'processedActionKeys': _processedActionKeys.toList(),
        'recordedActivityDates': _recordedActivityDates.toList(),
      });
      await prefs.setString(_storageKey, payload);
    } catch (_) {
      // Best-effort local persistence in demo mode.
    }
  }

  static OnboardingGoal _parseGoal(Object? raw) {
    for (final goal in OnboardingGoal.values) {
      if (goal.name == raw) return goal;
    }
    return OnboardingGoal.mastery;
  }

  static InitialLevel _parseLevel(Object? raw) {
    for (final level in InitialLevel.values) {
      if (level.name == raw) return level;
    }
    return InitialLevel.intermediate;
  }

  static MasteryLevel _parseMastery(Object? raw) {
    for (final level in MasteryLevel.values) {
      if (level.name == raw) return level;
    }
    return MasteryLevel.developing;
  }

  static Map<String, dynamic> _encodeProfile(LearnerProfile profile) {
    return {
      'id': profile.id,
      'name': profile.name,
      'selectedCourseId': profile.selectedCourseId,
      'goal': profile.goal.name,
      'dailyMinutes': profile.dailyMinutes,
      'initialLevel': profile.initialLevel.name,
      'courseLevels': profile.courseLevels.map(
        (key, value) => MapEntry(key, value.name),
      ),
      'xp': profile.xp,
      'streakDays': profile.streakDays,
      'lastActiveDate': profile.lastActiveDate,
      'scoresByCourse': profile.scoresByCourse.map(
        (courseId, skillMap) => MapEntry(
          courseId,
          skillMap.map(
            (skillId, score) => MapEntry(skillId, {
              'skillId': score.skillId,
              'courseId': score.courseId,
              'score': score.score,
              'lastUpdated': score.lastUpdated,
              'masteryLevel': score.masteryLevel.name,
              'isWeakestFocus': score.isWeakestFocus,
            }),
          ),
        ),
      ),
      'placementScoreByCourse': profile.placementScoreByCourse,
      'placementCefrByCourse': profile.placementCefrByCourse,
      'flashcardSrsByCourse': profile.flashcardSrsByCourse.map(
        (courseId, cardsMap) => MapEntry(
          courseId,
          cardsMap.map((cardId, entry) => MapEntry(cardId, entry.toJson())),
        ),
      ),
      'completedLessonIds': profile.completedLessonIds,
      'completedNodeIds': profile.completedNodeIds,
      'completedReinforcementIds': profile.completedReinforcementIds,
      'createdAt': profile.createdAt,
    };
  }

  static LearnerProfile _decodeProfile(Map<String, dynamic> raw) {
    final fallback = _defaultProfile();
    final rawCourseLevels = raw['courseLevels'];
    final courseLevels = <String, InitialLevel>{};
    if (rawCourseLevels is Map) {
      for (final entry in rawCourseLevels.entries) {
        courseLevels[entry.key.toString()] = _parseLevel(entry.value);
      }
    }

    final rawScoresByCourse = raw['scoresByCourse'];
    final scoresByCourse = <String, Map<String, SkillScore>>{};
    if (rawScoresByCourse is Map) {
      for (final courseEntry in rawScoresByCourse.entries) {
        final courseId = courseEntry.key.toString();
        final rawSkillMap = courseEntry.value;
        if (rawSkillMap is! Map) continue;
        final skillMap = <String, SkillScore>{};
        for (final skillEntry in rawSkillMap.entries) {
          final skillId = skillEntry.key.toString();
          final rawScore = skillEntry.value;
          if (rawScore is! Map) continue;
          final scoreVal = (rawScore['score'] as num?)?.toInt() ?? 0;
          skillMap[skillId] = SkillScore(
            skillId: rawScore['skillId'] as String? ?? skillId,
            courseId: rawScore['courseId'] as String? ?? courseId,
            score: scoreVal,
            lastUpdated:
                (rawScore['lastUpdated'] as num?)?.toInt() ??
                fallback.createdAt,
            masteryLevel: _parseMastery(rawScore['masteryLevel']),
            isWeakestFocus: rawScore['isWeakestFocus'] == true,
          );
        }
        scoresByCourse[courseId] = skillMap;
      }
    }

    final rawPlacementScores = raw['placementScoreByCourse'];
    final placementScoreByCourse = <String, int>{};
    if (rawPlacementScores is Map) {
      for (final entry in rawPlacementScores.entries) {
        final score = (entry.value as num?)?.toInt();
        if (score != null) {
          placementScoreByCourse[entry.key.toString()] = score;
        }
      }
    }

    final rawPlacementCefr = raw['placementCefrByCourse'];
    final placementCefrByCourse = <String, String>{};
    if (rawPlacementCefr is Map) {
      for (final entry in rawPlacementCefr.entries) {
        final val = entry.value?.toString().trim();
        if (val != null && val.isNotEmpty) {
          placementCefrByCourse[entry.key.toString()] = val;
        }
      }
    }

    final rawSrsByCourse = raw['flashcardSrsByCourse'];
    final flashcardSrsByCourse = <String, Map<String, FlashcardSrsRecord>>{};
    if (rawSrsByCourse is Map) {
      for (final courseEntry in rawSrsByCourse.entries) {
        final courseId = courseEntry.key.toString();
        final rawCardsMap = courseEntry.value;
        if (rawCardsMap is! Map) continue;
        final cardsMap = <String, FlashcardSrsRecord>{};
        for (final cardEntry in rawCardsMap.entries) {
          final cardId = cardEntry.key.toString();
          final rawRecord = cardEntry.value;
          if (rawRecord is! Map) continue;
          cardsMap[cardId] = FlashcardSrsRecord.fromJson(
            Map<String, dynamic>.from(rawRecord),
          );
        }
        flashcardSrsByCourse[courseId] = cardsMap;
      }
    }

    List<String> stringList(Object? value) =>
        value is List ? value.whereType<String>().toList() : const [];

    return LearnerProfile(
      id: raw['id'] as String? ?? fallback.id,
      name: raw['name'] as String? ?? fallback.name,
      selectedCourseId:
          raw['selectedCourseId'] as String? ?? fallback.selectedCourseId,
      goal: _parseGoal(raw['goal']),
      dailyMinutes: (raw['dailyMinutes'] as num?)?.toInt() ?? fallback.dailyMinutes,
      initialLevel: _parseLevel(raw['initialLevel']),
      courseLevels: courseLevels,
      xp: (raw['xp'] as num?)?.toInt() ?? 0,
      streakDays: (raw['streakDays'] as num?)?.toInt() ?? 1,
      lastActiveDate:
          raw['lastActiveDate'] as String? ?? fallback.lastActiveDate,
      scoresByCourse: scoresByCourse,
      placementScoreByCourse: placementScoreByCourse,
      placementCefrByCourse: placementCefrByCourse,
      flashcardSrsByCourse: flashcardSrsByCourse,
      completedLessonIds: stringList(raw['completedLessonIds']),
      completedNodeIds: stringList(raw['completedNodeIds']),
      completedReinforcementIds: stringList(raw['completedReinforcementIds']),
      createdAt: (raw['createdAt'] as num?)?.toInt() ?? fallback.createdAt,
    );
  }

  static Map<String, dynamic> _encodeAttempt(AnswerAttemptRecord record) {
    return {
      'id': record.id,
      'courseId': record.courseId,
      'skillId': record.skillId,
      'lessonId': record.lessonId,
      'questionId': record.questionId,
      'selectedIndex': record.selectedIndex,
      'selectedAnswer': record.selectedAnswer,
      'isCorrect': record.isCorrect,
      'timestamp': record.timestamp,
      'correctOption': record.correctOption,
      'explanation': record.explanation,
      'newSkillScore': record.newSkillScore,
      'xpAwarded': record.xpAwarded,
      'alreadyProcessed': record.alreadyProcessed,
    };
  }

  static AnswerAttemptRecord _decodeAttempt(Map<String, dynamic> raw) {
    return AnswerAttemptRecord(
      id: raw['id'] as String? ?? '',
      courseId: raw['courseId'] as String? ?? '',
      skillId: raw['skillId'] as String? ?? '',
      lessonId: raw['lessonId'] as String? ?? '',
      questionId: raw['questionId'] as String? ?? '',
      selectedIndex: (raw['selectedIndex'] as num?)?.toInt() ?? 0,
      selectedAnswer: raw['selectedAnswer'] as String? ?? '',
      isCorrect: raw['isCorrect'] == true,
      timestamp: (raw['timestamp'] as num?)?.toInt() ?? 0,
      correctOption: raw['correctOption'] as String?,
      explanation: raw['explanation'] as String?,
      newSkillScore: (raw['newSkillScore'] as num?)?.toInt(),
      xpAwarded: (raw['xpAwarded'] as num?)?.toInt() ?? 0,
      alreadyProcessed: raw['alreadyProcessed'] == true,
    );
  }

  @override
  Future<LearnerProfile> getCurrentProfile() async {
    await _ensureLoaded();
    return _profile;
  }

  @override
  Future<LearnerProfile> getProfile() async {
    await _ensureLoaded();
    return _profile;
  }

  @override
  Future<LearnerProfile> updateProfile(
    LearnerProfile updated, {
    Set<LearnerProfileField>? fields,
  }) async {
    await _ensureLoaded();
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
    await _persist();
    return _profile;
  }

  @override
  Future<void> saveSkillScores(
    String courseId,
    Map<String, SkillScore> scores,
  ) async {
    await _ensureLoaded();
    final currentScores = Map<String, Map<String, SkillScore>>.from(
      _profile.scoresByCourse,
    );
    final courseMap = Map<String, SkillScore>.from(
      currentScores[courseId] ?? {},
    );
    courseMap.addAll(scores);
    currentScores[courseId] = courseMap;

    _profile = _profile.copyWith(scoresByCourse: currentScores);
    await _persist();
  }

  @override
  Future<String> savePlacementAttempt(PlacementAttemptData data) async {
    await _ensureLoaded();
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
    await _persist();
    return 'plc_att_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<PlacementAnswerEvaluation> evaluatePlacementAnswer({
    required String courseId,
    required String questionId,
    required int selectedIndex,
  }) async {
    await _ensureLoaded();
    final question = placementQuestionsData[courseId]
        ?.where((item) => item.id == questionId)
        .firstOrNull;
    return PlacementAnswerEvaluation(
      isCorrect: question?.correctIndex == selectedIndex,
    );
  }

  @override
  Future<void> markLessonCompleted(String lessonId, {String? courseId}) async {
    await _ensureLoaded();
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
      await addXp(20, 'lesson_completed_$lessonId');
      await recordDailyActivity();
      await _persist();
    }
  }

  @override
  Future<void> markNodeCompleted(String nodeId, {String? courseId}) async {
    await _ensureLoaded();
    if (!_profile.completedNodeIds.contains(nodeId)) {
      final list = List<String>.from(_profile.completedNodeIds)..add(nodeId);
      _profile = _profile.copyWith(completedNodeIds: list);
      await _persist();
    }
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
  }) async {
    await _ensureLoaded();
    if (!_profile.completedReinforcementIds.contains(reinforcementId)) {
      final list = List<String>.from(_profile.completedReinforcementIds)
        ..add(reinforcementId);
      _profile = _profile.copyWith(completedReinforcementIds: list);
      await recordDailyActivity();
      await _persist();
    }
    return null;
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
    await _ensureLoaded();
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
      correctOption: isCorrect ? selectedAnswer : null,
    );
    _answerAttempts.add(record);

    if (isCorrect) {
      await addXp(2, 'answer_${questionId}_${record.id}');
    }
    await recordDailyActivity();

    // English placement scores remain isolated from independent lesson mastery.
    if (courseId == 'course_eng_01' && lessonId == 'placement_test') {
      await _persist();
      return record;
    }

    // Recalculate cumulative skill score over unique questionIds (latest attempt wins),
    // excluding English placement attempts.
    final latestByQuestion = <String, AnswerAttemptRecord>{};
    for (final attempt in _answerAttempts) {
      if (attempt.courseId == courseId &&
          attempt.skillId == skillId &&
          !(courseId == 'course_eng_01' &&
              attempt.lessonId == 'placement_test')) {
        latestByQuestion[attempt.questionId] = attempt;
      }
    }
    final uniqueAttempts = latestByQuestion.values.toList();
    final correctCount = uniqueAttempts.where((a) => a.isCorrect).length;
    final newScoreVal = SkillScoringEngine.computeSkillScore(
      correctCount,
      uniqueAttempts.length,
    );

    final currentScores = Map<String, Map<String, SkillScore>>.from(
      _profile.scoresByCourse,
    );
    final courseMap = Map<String, SkillScore>.from(
      currentScores[courseId] ?? {},
    );
    courseMap[skillId] = SkillScore(
      skillId: skillId,
      courseId: courseId,
      score: newScoreVal,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
      masteryLevel: SkillScoringEngine.getMasteryLevel(newScoreVal),
    );
    currentScores[courseId] = courseMap;
    _profile = _profile.copyWith(scoresByCourse: currentScores);
    await _persist();

    return record;
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
    await _ensureLoaded();
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
      if (candidate.usesTextEvaluation || candidate.isSelfAssessed) {
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
        return candidate.isTextAnswerCorrect(selectedAnswer) ||
            candidate.orderedTokens.join(' ').trim() == selectedAnswer.trim();
      }
      if (candidate.isSelfAssessed) {
        return selectedAnswer.trim().isNotEmpty;
      }
      return selectedIndex == candidate.correctIndex;
    }

    final isCorrect = evaluateAnswer(question);

    return recordAnswerAttempt(
      courseId: courseId,
      skillId: skillId,
      lessonId: lessonId,
      questionId: questionId,
      selectedIndex: selectedIndex,
      selectedAnswer: selectedAnswer,
      isCorrect: isCorrect,
    );
  }

  @override
  Future<List<AnswerAttemptRecord>> getAnswerAttempts([int limit = 10]) async {
    await _ensureLoaded();
    if (_answerAttempts.length <= limit) {
      return List.from(_answerAttempts);
    }
    return _answerAttempts.sublist(_answerAttempts.length - limit);
  }

  @override
  Future<List<DailyActivitySummary>> getDailyActivity([int days = 7]) async {
    await _ensureLoaded();
    final result = <DailyActivitySummary>[];
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dateStr = day.toIso8601String().split('T').first;
      final dayAttempts = _answerAttempts.where((a) {
        return DateTime.fromMillisecondsSinceEpoch(
              a.timestamp,
            ).toIso8601String().split('T').first ==
            dateStr;
      }).toList();
      final correct = dayAttempts.where((a) => a.isCorrect).length;
      result.add(
        DailyActivitySummary(
          date: dateStr,
          activeMinutes: (dayAttempts.length * 1.5).round(),
          xpEarned: correct * 2,
          lessonsCompleted: 0,
        ),
      );
    }
    return result;
  }

  @override
  Future<int> addXp(int amount, [String? actionIdempotencyKey]) async {
    await _ensureLoaded();
    if (actionIdempotencyKey != null) {
      if (_processedActionKeys.contains(actionIdempotencyKey)) {
        return _profile.xp;
      }
      _processedActionKeys.add(actionIdempotencyKey);
    }
    final newXp = _profile.xp + amount;
    _profile = _profile.copyWith(xp: newXp);
    await _persist();
    return newXp;
  }

  @override
  Future<int> recordDailyActivity([String? dateStr]) async {
    await _ensureLoaded();
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
    await _persist();
    return newStreak;
  }

  @override
  Future<LearnerProfile> resetAll() async {
    if (_loadFuture != null) {
      await _loadFuture;
    }
    _profile = _defaultProfile();
    _answerAttempts.clear();
    _processedActionKeys.clear();
    _recordedActivityDates.clear();
    _hydrated = true;
    _loadFuture = null;
    final prefs = await _getPrefs();
    try {
      await prefs?.remove(_storageKey);
    } catch (_) {
      // Ignore storage removal failures in unmocked environments.
    }
    return _profile;
  }

  @override
  Future<void> clearLocalState() async {
    await resetAll();
  }
}
