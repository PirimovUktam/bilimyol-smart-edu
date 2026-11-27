import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/i_learner_repository.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/placement_session.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/skill_score.dart';
import '../../domain/personalization/skill_scoring_engine.dart';
import '../../core/config/supabase_config.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/attempt_uuid.dart';
import 'in_memory_learner_repository.dart';
import 'supabase_course_repository.dart';

class SupabaseLearnerRepository extends ILearnerRepository {
  static final RegExp _httpsAvatarRegex = RegExp(
    r'^https://[^\s<>"]+$',
    caseSensitive: false,
  );

  static String? _sanitizeAvatarUrl(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= 2048 && _httpsAvatarRegex.hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  final InMemoryLearnerRepository _fallbackRepo;
  final SupabaseClient? _clientOverride;
  Future<void> _srsWriteChain = Future<void>.value();

  SupabaseLearnerRepository({
    LocalStorageService? storage,
    SupabaseClient? client,
  }) : _fallbackRepo = InMemoryLearnerRepository(storage: storage),
       _clientOverride = client;

  LocalStorageService get _storage => _fallbackRepo.storage;

  SupabaseClient get _client =>
      _clientOverride ?? SupabaseConfig.client ?? Supabase.instance.client;

  @override
  bool get supportsNodeCompletion => SupabaseConfig.isDemoModeActive;

  @override
  bool get supportsServerPlacementPersistence =>
      !SupabaseConfig.isDemoModeActive;

  @override
  bool get supportsPlacementSessions => !SupabaseConfig.isDemoModeActive;

  @override
  Future<PlacementSession> advancePlacement(
    String courseId, {
    String? sessionId,
    String? questionId,
    int? selectedIndex,
    bool restart = false,
  }) async {
    final client = _client;
    if (client.auth.currentUser == null) {
      throw StateError('Autentifikatsiyadan o‘tilmagan.');
    }
    final data = await client.rpc(
      'advance_placement',
      params: {
        'p_course_id': courseId,
        if (sessionId != null) ...{
          'p_session_id': sessionId,
          'p_question_id': questionId,
          'p_selected_index': selectedIndex,
        },
        if (restart) 'p_restart': true,
      },
    ) as Map<String, dynamic>;
    final question = data['question'] as Map<String, dynamic>?;
    final result = data['result'] as Map<String, dynamic>?;
    Map<String, SkillScore>? parsedResultSkills;
    if (result != null && result['skill_scores'] is Map) {
      parsedResultSkills = _parseSkillScoreMap(
        courseId,
        result['skill_scores'] as Map,
      );
    }
    return PlacementSession(
      id: data['session_id'] as String,
      questionNumber: data['question_number'] as int,
      totalQuestions: data['total_questions'] as int,
      question: question == null
          ? null
          : SupabaseCourseRepository.questionFromRow(question),
      result: result == null
          ? null
          : CompletedPlacement(
              attemptId: result['attempt_id'] as String,
              weakestSkillId: result['weakest_skill_id'] as String? ?? '',
              overallScore: (result['score'] as num?)?.toInt(),
              placementCefr: result['placement_cefr'] as String?,
              assessedCefr: result['assessed_cefr'] as String?,
              unlockedCefrFloor: result['unlocked_cefr_floor'] as String?,
              skillScores: parsedResultSkills,
              completedAt: DateTime.parse(result['completed_at'] as String),
              review: (result['answers'] as List)
                  .map((answer) {
                    final row = answer as Map<String, dynamic>;
                    return PlacementReview(
                      submission: QuestionAnswerSubmission(
                        questionId: row['question_id'] as String,
                        selectedIndex: row['selected_index'] as int,
                        isCorrect: row['is_correct'] as bool,
                        timeSpentSeconds: row['time_spent_seconds'] as int,
                      ),
                      question: row['question_text'] as String,
                      questionRu: row['question_text_ru'] as String?,
                      selected: row['selected_option'] as String,
                      correct: row['correct_option'] as String,
                      explanation: row['explanation'] as String,
                      explanationRu: row['explanation_ru'] as String?,
                    );
                  })
                  .toList(growable: false),
            ),
      wasReset: data['reset'] == true,
      canRetake: data['can_retake'] == true,
    );
  }

  @override
  bool get supportsServerReinforcementPersistence =>
      !SupabaseConfig.isDemoModeActive;

  @override
  Future<LearnerProfile> getCurrentProfile() async {
    return getProfile();
  }

  @override
  Future<LearnerProfile> getProfile() async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.getProfile();
    }
    try {
      final client = _client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('Autentifikatsiyadan o‘tilmagan.');
      }

      // Fetch user profile from public.profiles table
      var userProfile = await client
          .from('profiles')
          .select('id, first_name, last_name, display_name, email, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (userProfile == null ||
          userProfile['first_name'] == null ||
          userProfile['first_name'] == 'Foydalanuvchi') {
        final metaFirst = (user.userMetadata?['first_name'] as String? ?? '')
            .trim();
        final metaLast = (user.userMetadata?['last_name'] as String? ?? '')
            .trim();
        final resolvedFirst = metaFirst.isNotEmpty
            ? metaFirst
            : (user.email != null
                  ? user.email!.split('@').first
                  : 'Foydalanuvchi');
        final resolvedLast = metaLast;
        final resolvedDisplay = resolvedLast.isNotEmpty
            ? '$resolvedFirst $resolvedLast'
            : resolvedFirst;

        final editableProfile = {
          'first_name': resolvedFirst,
          'last_name': resolvedLast,
          'display_name': resolvedDisplay,
          'avatar_url': _sanitizeAvatarUrl(user.userMetadata?['avatar_url']),
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (userProfile != null) {
          await client
              .from('profiles')
              .update(editableProfile)
              .eq('id', user.id);
        } else {
          await client
              .from('profiles')
              .upsert(
                {'id': user.id, 'email': user.email ?? '', ...editableProfile},
                onConflict: 'id',
                ignoreDuplicates: true,
              );
        }
        // A signup trigger or concurrent reader may have provisioned the row.
        // Read back the winner instead of manufacturing a local profile.
        userProfile = await client
            .from('profiles')
            .select(
              'id, first_name, last_name, display_name, email, avatar_url',
            )
            .eq('id', user.id)
            .single();
      }

      // Fetch learner profile
      final learnerData = await client
          .from('learner_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      // Fetch gamification profile
      final gamifyData = await client
          .from('gamification_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      // Fetch skill scores
      final scoreRows = await client
          .from('learner_skill_scores')
          .select()
          .eq('user_id', user.id);

      // Fetch completed lessons
      final progressRows = await client
          .from('lesson_progress')
          .select('lesson_id')
          .eq('user_id', user.id)
          .eq('status', 'completed');

      // Fetch completed reinforcements
      final reinfRows = await client
          .from('reinforcement_attempts')
          .select('reinforcement_node_id')
          .eq('user_id', user.id)
          .eq('is_correct', true);

      final Map<String, Map<String, SkillScore>> scoresByCourse = {};
      for (final row in scoreRows) {
        final courseId = row['course_id'] as String;
        final skillId = row['skill_id'] as String;
        final attemptCount = (row['attempt_count'] as num?)?.toInt();
        final confidence = _parseConfidence(
          row['confidence'],
          attemptCount: attemptCount,
        );
        scoresByCourse[courseId] ??= {};
        scoresByCourse[courseId]![skillId] = SkillScore(
          skillId: skillId,
          courseId: courseId,
          score: (row['score'] as num).toInt(),
          lastUpdated: DateTime.parse(
            row['last_updated'],
          ).millisecondsSinceEpoch,
          masteryLevel: _parseMasteryLevel(row['mastery_level']),
          isWeakestFocus: row['is_weakest_focus'] == true,
          attemptCount: attemptCount,
          confidence: confidence,
        );
      }

      final completedLessonIds =
          (progressRows as List?)
              ?.map((e) => e['lesson_id'] as String)
              .toList() ??
          [];

      var completedNodeIds = List<String>.from(completedLessonIds);
      if (completedLessonIds.isNotEmpty) {
        final nodeRows = await client
            .from('roadmap_nodes')
            .select('id, target_lesson_id')
            .inFilter('target_lesson_id', completedLessonIds)
            .eq('is_active', true);
        completedNodeIds = [
          ...<String>{
            ...completedNodeIds,
            ...(nodeRows as List).map((row) => row['id'] as String),
          },
        ];
      }

      final completedReinfIds =
          (reinfRows as List?)
              ?.map((e) => e['reinforcement_node_id'] as String)
              .toList() ??
          [];

      final firstName =
          userProfile['first_name'] as String? ??
          user.userMetadata?['first_name'] as String? ??
          (user.email != null ? user.email!.split('@').first : 'Foydalanuvchi');

      final placementScoreByCourse = <String, int>{
        for (final entry
            in (learnerData?['placement_score_by_course']
                        as Map<String, dynamic>? ??
                    {})
                .entries)
          if (entry.value is num) entry.key: (entry.value as num).toInt(),
      };
      final placementCefrByCourse = <String, String>{
        for (final entry
            in (learnerData?['placement_cefr_by_course']
                        as Map<String, dynamic>? ??
                    {})
                .entries)
          if (entry.value is String &&
              (entry.value as String).trim().isNotEmpty)
            entry.key: (entry.value as String).trim(),
      };
      final placementSkillScoresByCourse = <String, Map<String, SkillScore>>{};
      final rawPlacementSkills =
          learnerData?['placement_skill_scores_by_course'];
      if (rawPlacementSkills is Map) {
        for (final entry in rawPlacementSkills.entries) {
          if (entry.key is String && entry.value is Map) {
            final parsed = _parseSkillScoreMap(
              entry.key as String,
              entry.value as Map,
            );
            if (parsed.isNotEmpty) {
              placementSkillScoresByCourse[entry.key as String] = parsed;
            }
          }
        }
      }

      final userSrs = await _readUserFlashcardSrs(user.id);
      if (client.auth.currentUser?.id != user.id) {
        throw StateError('Faol sessiya o‘zgargan. Qayta kiring.');
      }

      return LearnerProfile(
        id: user.id,
        name: firstName,
        selectedCourseId:
            learnerData?['selected_course_id'] ?? 'course_math_01',
        goal: _parseGoal(learnerData?['goal']),
        dailyMinutes: (learnerData?['daily_minutes'] as num?)?.toInt() ?? 15,
        initialLevel: _parseInitialLevel(learnerData?['initial_level']),
        courseLevels: {
          for (final entry
              in (learnerData?['course_levels'] as Map<String, dynamic>? ?? {})
                  .entries)
            if (InitialLevel.values.any((level) => level.name == entry.value))
              entry.key: _parseInitialLevel(entry.value),
        },
        xp: gamifyData?['xp'] ?? 0,
        streakDays: gamifyData?['streak_days'] ?? 1,
        lastActiveDate:
            gamifyData?['last_activity_date'] ??
            DateTime.now().toIso8601String().split('T').first,
        scoresByCourse: scoresByCourse,
        placementScoreByCourse: placementScoreByCourse,
        placementCefrByCourse: placementCefrByCourse,
        placementSkillScoresByCourse: placementSkillScoresByCourse,
        flashcardSrsByCourse: userSrs,
        completedLessonIds: completedLessonIds,
        completedNodeIds: completedNodeIds,
        completedReinforcementIds: completedReinfIds,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // An authenticated user's failed remote read must not be replaced by a
      // previous/demo profile. Let the caller render a retry state instead.
      rethrow;
    }
  }

  @override
  Future<LearnerProfile> saveCourseLearningPlan({
    required String courseId,
    required OnboardingGoal goal,
    required int dailyMinutes,
    required InitialLevel initialLevel,
  }) async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.saveCourseLearningPlan(
        courseId: courseId,
        goal: goal,
        dailyMinutes: dailyMinutes,
        initialLevel: initialLevel,
      );
    }
    final client = _client;
    if (client.auth.currentUser == null) {
      throw StateError('Autentifikatsiyadan o‘tilmagan.');
    }
    await client.rpc(
      'save_course_learning_plan',
      params: {
        'p_course_id': courseId,
        'p_goal': switch (goal) {
          OnboardingGoal.mastery => 'mastery',
          OnboardingGoal.examPrep => 'exam_prep',
          OnboardingGoal.skillsBoost => 'skills_boost',
        },
        'p_daily_minutes': dailyMinutes,
        'p_level': initialLevel.name,
      },
    );
    return getProfile();
  }

  @override
  Future<LearnerProfile> updateProfile(
    LearnerProfile updated, {
    Set<LearnerProfileField>? fields,
  }) async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.updateProfile(updated, fields: fields);
    }
    final client = _client;
    final user = client.auth.currentUser;
    if (user == null || updated.id != user.id) {
      throw StateError('Faol sessiya o‘zgargan. Qayta kiring.');
    }
    final selected = fields ?? LearnerProfileField.values.toSet();
    final now = DateTime.now().toIso8601String();
    if (selected.contains(LearnerProfileField.name)) {
      await client
          .from('profiles')
          .update({
            'first_name': updated.name,
            'display_name': updated.name,
            'updated_at': now,
          })
          .eq('id', user.id)
          .select('id')
          .single();
    }
    final preferences = <String, dynamic>{
      if (selected.contains(LearnerProfileField.selectedCourse))
        'selected_course_id': updated.selectedCourseId,
      if (selected.contains(LearnerProfileField.dailyMinutes))
        'daily_minutes': updated.dailyMinutes,
      if (selected.contains(LearnerProfileField.goal))
        'goal': switch (updated.goal) {
          OnboardingGoal.mastery => 'mastery',
          OnboardingGoal.examPrep => 'exam_prep',
          OnboardingGoal.skillsBoost => 'skills_boost',
        },
      if (selected.contains(LearnerProfileField.initialLevel))
        'initial_level': updated.initialLevel.name,
    };
    if (preferences.isNotEmpty) {
      await client.from('learner_profiles').upsert({
        ...preferences,
        'user_id': user.id,
        'updated_at': now,
      });
    }
    if (client.auth.currentUser?.id != user.id) {
      throw StateError('Faol sessiya o‘zgargan. Qayta kiring.');
    }
    return getProfile();
  }

  @override
  Future<LearnerProfile> recordFlashcardReview({
    required String courseId,
    required String cardId,
    required bool remembered,
  }) {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.recordFlashcardReview(
        courseId: courseId,
        cardId: cardId,
        remembered: remembered,
      );
    }
    final initialUser = _client.auth.currentUser;
    if (initialUser == null) {
      return Future.error(StateError('Autentifikatsiyadan o‘tilmagan.'));
    }
    final expectedUserId = initialUser.id;
    final next = _srsWriteChain
        .catchError((Object _) {})
        .then((_) async {
          final activeUser = _client.auth.currentUser;
          if (activeUser == null || activeUser.id != expectedUserId) {
            throw StateError('Faol sessiya o‘zgargan. Qayta kiring.');
          }

          final currentByCourse = await _readUserFlashcardSrs(expectedUserId);
          if (_client.auth.currentUser?.id != expectedUserId) {
            throw StateError('Faol sessiya o‘zgargan. Qayta kiring.');
          }

          final currentCourseMap = Map<String, FlashcardSrsRecord>.from(
            currentByCourse[courseId] ?? const {},
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
          final nextByCourse =
              Map<String, Map<String, FlashcardSrsRecord>>.from(currentByCourse)
                ..[courseId] = currentCourseMap;

          await _writeUserFlashcardSrs(expectedUserId, nextByCourse);
          final remoteProfile = await getProfile();
          if (_client.auth.currentUser?.id != expectedUserId ||
              remoteProfile.id != expectedUserId) {
            throw StateError('Faol sessiya o‘zgargan. Qayta kiring.');
          }
          return remoteProfile.copyWith(flashcardSrsByCourse: nextByCourse);
        });
    _srsWriteChain = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<Map<String, Map<String, FlashcardSrsRecord>>> _readUserFlashcardSrs(
    String userId,
  ) async {
    final raw = await _storage.getUserFlashcardSrsJson(userId);
    if (raw == null || raw.trim().isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final result = <String, Map<String, FlashcardSrsRecord>>{};
      for (final courseEntry in decoded.entries) {
        final courseId = courseEntry.key;
        final rawCards = courseEntry.value;
        if (courseId is String && rawCards is Map) {
          final cardsMap = <String, FlashcardSrsRecord>{};
          for (final cardEntry in rawCards.entries) {
            final cardId = cardEntry.key;
            final rawRecord = cardEntry.value;
            if (cardId is String && rawRecord is Map) {
              cardsMap[cardId] = FlashcardSrsRecord.fromJson(
                Map<String, dynamic>.from(rawRecord),
              );
            }
          }
          if (cardsMap.isNotEmpty) {
            result[courseId] = cardsMap;
          }
        }
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  Future<void> _writeUserFlashcardSrs(
    String userId,
    Map<String, Map<String, FlashcardSrsRecord>> srsByCourse,
  ) async {
    final payload = <String, Map<String, Map<String, dynamic>>>{
      for (final courseEntry in srsByCourse.entries)
        courseEntry.key: {
          for (final cardEntry in courseEntry.value.entries)
            cardEntry.key: cardEntry.value.toJson(),
        },
    };
    await _storage.setUserFlashcardSrsJson(userId, jsonEncode(payload));
  }

  @override
  Future<void> saveSkillScores(
    String courseId,
    Map<String, SkillScore> scores,
  ) async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.saveSkillScores(courseId, scores);
    }
    try {
      final client = _client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('Autentifikatsiyadan o‘tilmagan.');
      }

      await client.rpc(
        'recalculate_skill_scores',
        params: {'p_course_id': courseId},
      );
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<String> savePlacementAttempt(PlacementAttemptData data) async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.savePlacementAttempt(data);
    }
    try {
      final client = _client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('Autentifikatsiyadan o‘tilmagan.');
      }

      final result = await client
          .rpc(
            'save_placement_attempt',
            params: {
              'p_course_id': data.courseId,
              'p_submissions': data.submissions
                  .map(
                    (sub) => {
                      'question_id': sub.questionId,
                      'selected_index': sub.selectedIndex,
                    },
                  )
                  .toList(),
              'p_idempotency_key':
                  'placement_${data.courseId}_${DateTime.now().toIso8601String().split('T').first}',
            },
          )
          .eq('id', user.id);

      if (result is! Map || result['attempt_id'] == null) {
        throw Exception('Placement natijasini serverga saqlab bo‘lmadi.');
      }
      return result['attempt_id'].toString();
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<PlacementAnswerEvaluation> evaluatePlacementAnswer({
    required String courseId,
    required String questionId,
    required int selectedIndex,
  }) async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.evaluatePlacementAnswer(
        courseId: courseId,
        questionId: questionId,
        selectedIndex: selectedIndex,
      );
    }

    final client = _client;
    if (client.auth.currentUser == null) {
      throw StateError('Autentifikatsiyadan o‘tilmagan.');
    }
    final result = await client.rpc(
      'evaluate_placement_answer',
      params: {
        'p_course_id': courseId,
        'p_question_id': questionId,
        'p_selected_index': selectedIndex,
      },
    );

    if (result is! Map || result['is_correct'] is! bool) {
      throw Exception('Javobni serverda tekshirib bo‘lmadi.');
    }
    return PlacementAnswerEvaluation(isCorrect: result['is_correct'] == true);
  }

  @override
  Future<void> markLessonCompleted(String lessonId, {String? courseId}) async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.markLessonCompleted(lessonId, courseId: courseId);
    }
    try {
      final client = _client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('Autentifikatsiyadan o‘tilmagan.');
      }
      if (courseId == null || courseId.isEmpty) {
        throw ArgumentError('Darsni saqlash uchun courseId talab qilinadi.');
      }

      final result = await client.rpc(
        'complete_lesson',
        params: {'p_lesson_id': lessonId, 'p_course_id': courseId},
      );
      if (result is! Map || result['completed'] != true) {
        throw StateError('Dars yakuni serverda tasdiqlanmadi.');
      }
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<void> markNodeCompleted(String nodeId, {String? courseId}) async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.markNodeCompleted(nodeId, courseId: courseId);
    }
    throw UnsupportedError(
      'Production roadmap-node completion is managed by the server contract.',
    );
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
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.markReinforcementCompleted(
        reinforcementId: reinforcementId,
        courseId: courseId,
        skillId: skillId,
        questionId: questionId,
        beforeScore: beforeScore,
        afterScore: afterScore,
        xpAwarded: xpAwarded,
      );
    }
    final client = _client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Autentifikatsiyadan o‘tilmagan.');
    }

    // A signed-in completion must not fall back to demo state: that would make
    // the UI report success while the required remote row was not persisted.
    final result = await client.rpc(
      'complete_reinforcement',
      params: {
        'p_reinforcement_node_id': reinforcementId,
        'p_course_id': courseId,
        'p_skill_id': skillId,
        'p_question_id': questionId,
        'p_xp_awarded': xpAwarded,
      },
    );
    if (result is! Map || result['already_processed'] is! bool) {
      throw const FormatException('Malformed complete_reinforcement result.');
    }

    int readInteger(String key, {int? max}) {
      final value = result[key];
      if (value is! num ||
          !value.isFinite ||
          value != value.truncateToDouble() ||
          value < 0 ||
          (max != null && value > max)) {
        throw FormatException('Malformed complete_reinforcement result: $key.');
      }
      return value.toInt();
    }

    return ReinforcementCompletionResult(
      oldScore: readInteger('old_score', max: 100),
      newScore: readInteger('new_score', max: 100),
      xpAwarded: readInteger('xp_awarded'),
      alreadyProcessed: result['already_processed'] as bool,
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
  }) async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.recordAnswerAttempt(
        courseId: courseId,
        skillId: skillId,
        lessonId: lessonId,
        questionId: questionId,
        selectedIndex: selectedIndex,
        selectedAnswer: selectedAnswer,
        isCorrect: isCorrect,
      );
    }
    try {
      final client = _client;
      final user = client.auth.currentUser;
      if (user != null) {
        return _submitServerAnswer(
          user: user,
          courseId: courseId,
          skillId: skillId,
          lessonId: lessonId,
          questionId: questionId,
          selectedIndex: selectedIndex,
          selectedAnswer: selectedAnswer,
        );
      }
      throw Exception('Autentifikatsiyadan o‘tilmagan.');
    } catch (_) {
      // Do not turn a failed authenticated RPC into a locally successful
      // answer. The caller owns the loading/error state and can retry.
      rethrow;
    }
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
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.submitAnswerAttempt(
        courseId: courseId,
        skillId: skillId,
        lessonId: lessonId,
        questionId: questionId,
        selectedIndex: selectedIndex,
        selectedAnswer: selectedAnswer,
      );
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Autentifikatsiyadan o‘tilmagan.');
    }
    try {
      return await _submitServerAnswer(
        user: user,
        courseId: courseId,
        skillId: skillId,
        lessonId: lessonId,
        questionId: questionId,
        selectedIndex: selectedIndex,
        selectedAnswer: selectedAnswer,
      );
    } catch (_) {
      // Authenticated scoring failures are retryable, never demo fallbacks.
      rethrow;
    }
  }

  Future<AnswerAttemptRecord> _submitServerAnswer({
    required User user,
    required String courseId,
    required String skillId,
    required String lessonId,
    required String questionId,
    required int selectedIndex,
    required String selectedAnswer,
  }) async {
    if (selectedAnswer.length > 4000) {
      throw ArgumentError(
        'Javob matni uzunligi 4000 belgidan oshmasligi shart.',
      );
    }
    final explicitKey = ILearnerRepository.currentAttemptIdempotencyKey;
    if (explicitKey != null) {
      final trimmedKey = explicitKey.trim();
      if (trimmedKey.isEmpty || trimmedKey.length > 128) {
        throw ArgumentError(
          'Idempotency kaliti 1..128 belgi oralig‘ida bo‘lishi shart.',
        );
      }
    }

    final client = _client;
    final payloadSig = '$selectedIndex:$selectedAnswer';
    final existingPending = await _storage.getPendingAttempt(
      accountScope: user.id,
      courseId: courseId,
      lessonId: lessonId,
      questionId: questionId,
    );
    final managedBySession =
        existingPending?['managedBySession'] == true && explicitKey != null;
    final String requestKey;
    if (managedBySession) {
      requestKey = explicitKey.trim();
    } else if (existingPending != null &&
        existingPending['payloadSig'] == payloadSig &&
        existingPending['attemptId'] is String &&
        (existingPending['attemptId'] as String).trim().isNotEmpty) {
      requestKey = (existingPending['attemptId'] as String).trim();
    } else {
      requestKey = explicitKey != null
          ? explicitKey.trim()
          : generateAttemptUuidV4();
      await _storage.setPendingAttempt(
        accountScope: user.id,
        courseId: courseId,
        lessonId: lessonId,
        questionId: questionId,
        data: {
          'attemptId': requestKey,
          'payloadSig': payloadSig,
          'selectedIndex': selectedIndex,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );
    }

    final rpcRes = await client.rpc(
      'submit_answer_attempt',
      params: {
        'p_user_id': user.id,
        'p_course_id': courseId,
        'p_skill_id': skillId,
        'p_lesson_id': lessonId,
        'p_question_id': questionId,
        'p_selected_index': selectedIndex,
        'p_selected_text': selectedAnswer,
        'p_idempotency_key': requestKey,
      },
    );
    final data = rpcRes is Map
        ? Map<String, dynamic>.from(rpcRes)
        : <String, dynamic>{};
    if (!data.containsKey('is_correct')) {
      throw Exception('Javobni serverda tekshirib bo‘lmadi.');
    }
    if (!managedBySession) {
      await _storage.clearPendingAttempt(
        accountScope: user.id,
        courseId: courseId,
        lessonId: lessonId,
        questionId: questionId,
      );
    }
    String? correctOption;
    String? feedbackExplanation;
    if (data['is_correct'] == false) {
      try {
        final feedback = await client.rpc('get_mistake_feedback', params: {
          'p_course_id': courseId, 'p_skill_id': skillId, 'p_question_id': questionId,
        });
        if (feedback is Map) {
          if (feedback['correctOption'] is String) {
            correctOption = feedback['correctOption'] as String;
          }
          if (feedback['explanation'] is String &&
              (feedback['explanation'] as String).trim().isNotEmpty) {
            feedbackExplanation = feedback['explanation'] as String;
          }
        }
      } catch (_) {
        // The graded answer is saved even when the additional feedback read fails.
      }
    }
    return AnswerAttemptRecord(
      id: 'server_${DateTime.now().microsecondsSinceEpoch}',
      courseId: courseId,
      skillId: skillId,
      lessonId: lessonId,
      questionId: questionId,
      selectedIndex: selectedIndex,
      selectedAnswer: selectedAnswer,
      isCorrect: data['is_correct'] == true,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      // The scoring RPC intentionally never returns the answer key.
      correctOption: correctOption,
      explanation: feedbackExplanation ?? data['explanation'] as String?,
      newSkillScore: (data['new_skill_score'] as num?)?.toInt(),
      xpAwarded: (data['xp_awarded'] as num?)?.toInt() ?? 0,
      alreadyProcessed: data['already_processed'] == true,
      idempotencyKey: requestKey,
    );
  }

  @override
  Future<List<AnswerAttemptRecord>> getAnswerAttempts([int limit = 10]) async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.getAnswerAttempts(limit);
    }
    final client = _clientOverride ?? SupabaseConfig.client;
    if (client == null) {
      throw StateError('Supabase ishga tushmadi. Qayta urinib ko‘ring.');
    }
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Autentifikatsiyadan o‘tilmagan.');
    }

    final rows = await client
        .from('answer_attempts')
        .select(
          'id, user_id, course_id, skill_id, lesson_id, question_id, '
          'selected_index, selected_answer, is_correct, created_at',
        )
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .whereType<Map>()
        .map<AnswerAttemptRecord>((raw) {
          final row = Map<String, dynamic>.from(raw);
          return AnswerAttemptRecord(
            id: row['id'].toString(),
            courseId: row['course_id'] as String,
            skillId: row['skill_id'] as String,
            lessonId: row['lesson_id']?.toString() ?? 'general',
            questionId: row['question_id'] as String,
            selectedIndex: (row['selected_index'] as num).toInt(),
            selectedAnswer: row['selected_answer'] as String? ?? '',
            isCorrect: row['is_correct'] == true,
            timestamp: DateTime.parse(
              row['created_at'] as String,
            ).millisecondsSinceEpoch,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<DailyActivitySummary>> getDailyActivity([int days = 7]) async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.getDailyActivity(days);
    }
    try {
      final client = _client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('Autentifikatsiyadan o‘tilmagan.');
      }

      final todayTashkent = DateTime.now().toUtc().add(
        const Duration(hours: 5),
      );
      final since = todayTashkent
          .subtract(Duration(days: days - 1))
          .toIso8601String()
          .split('T')
          .first;

      final rows = await client
          .from('daily_learning_stats')
          .select(
            'activity_date, active_seconds, xp_earned, lessons_completed, '
            'questions_answered, correct_answers, accuracy_percent',
          )
          .eq('user_id', user.id)
          .gte('activity_date', since)
          .order('activity_date', ascending: true);

      final byDate = <String, DailyActivitySummary>{};
      for (final row in (rows as List)) {
        final date = row['activity_date'] as String;
        final qAns = (row['questions_answered'] as num?)?.toInt() ?? 0;
        final cAns = (row['correct_answers'] as num?)?.toInt() ?? 0;
        final acc = (row['accuracy_percent'] as num?)?.toInt() ??
            (qAns > 0 ? ((cAns * 100) / qAns).round() : 0);
        byDate[date] = DailyActivitySummary(
          date: date,
          activeMinutes: ((row['active_seconds'] as num?)?.toInt() ?? 0) ~/ 60,
          xpEarned: (row['xp_earned'] as num?)?.toInt() ?? 0,
          lessonsCompleted: (row['lessons_completed'] as num?)?.toInt() ?? 0,
          questionsAnswered: qAns,
          correctAnswers: cAns,
          accuracyPercent: acc,
        );
      }

      final result = <DailyActivitySummary>[];
      for (int i = days - 1; i >= 0; i--) {
        final dateStr = todayTashkent
            .subtract(Duration(days: i))
            .toIso8601String()
            .split('T')
            .first;
        result.add(
          byDate[dateStr] ??
              DailyActivitySummary(
                date: dateStr,
                activeMinutes: 0,
                xpEarned: 0,
                lessonsCompleted: 0,
              ),
        );
      }
      return result;
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<int> addXp(int amount, [String? actionIdempotencyKey]) async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.addXp(amount, actionIdempotencyKey);
    }
    try {
      final client = _client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('Autentifikatsiyadan o‘tilmagan.');
      }
      final result = await client.rpc(
        'award_xp',
        params: {
          'p_amount': amount,
          'p_action_key':
              actionIdempotencyKey ??
              'xp_${DateTime.now().microsecondsSinceEpoch}',
        },
      );
      if (result is! Map) throw Exception('XP serverda saqlanmadi.');
      return (result['xp'] as num?)?.toInt() ?? 0;
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<int> recordDailyActivity([String? dateStr]) async {
    // Uzbekistan local day (UTC+5) — matches the server-side scoring RPC.
    final tashkent = DateTime.now().toUtc().add(const Duration(hours: 5));
    final today = dateStr ?? tashkent.toIso8601String().split('T').first;

    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.recordDailyActivity(dateStr);
    }
    try {
      final client = _client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('Autentifikatsiyadan o‘tilmagan.');
      }
      final result = await client.rpc(
        'record_learning_activity',
        params: {'p_activity_date': today},
      );
      if (result is! Map) {
        throw Exception('Kunlik faollik serverda saqlanmadi.');
      }
      return (result['streak_days'] as num?)?.toInt() ?? 0;
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<LearnerProfile> resetAll() async {
    if (SupabaseConfig.isDemoModeActive) {
      return _fallbackRepo.resetAll();
    }
    throw UnsupportedError(
      'Production learner reset is not supported by the server contract.',
    );
  }

  @override
  Future<void> clearLocalState() async {
    _srsWriteChain = Future<void>.value();
    await _fallbackRepo.resetAll();
  }

  static OnboardingGoal _parseGoal(Object? raw) {
    final value = raw?.toString().trim().toLowerCase();
    switch (value) {
      case 'examprep':
      case 'exam_prep':
      case 'exam-prep':
        return OnboardingGoal.examPrep;
      case 'skillsboost':
      case 'skills_boost':
      case 'skills-boost':
        return OnboardingGoal.skillsBoost;
      case 'mastery':
      default:
        return OnboardingGoal.mastery;
    }
  }

  static MasteryLevel _parseMasteryLevel(Object? raw) {
    switch (raw?.toString()) {
      case 'needs_remediation':
      case 'needsRemediation':
        return MasteryLevel.needsRemediation;
      case 'proficient':
        return MasteryLevel.proficient;
      case 'mastered':
        return MasteryLevel.mastered;
      default:
        return MasteryLevel.developing;
    }
  }

  static ConfidenceLevel? _parseConfidence(Object? raw, {int? attemptCount}) {
    switch (raw?.toString()) {
      case 'low':
        return ConfidenceLevel.low;
      case 'medium':
        return ConfidenceLevel.medium;
      case 'high':
        return ConfidenceLevel.high;
      default:
        return attemptCount != null
            ? SkillScoringEngine.computeConfidence(attemptCount)
            : null;
    }
  }

  static Map<String, SkillScore> _parseSkillScoreMap(
    String courseId,
    Map<dynamic, dynamic> rawMap,
  ) {
    final out = <String, SkillScore>{};
    for (final entry in rawMap.entries) {
      final skillId = entry.key;
      final val = entry.value;
      if (skillId is! String || val is! Map) continue;
      final scoreNum = val['score'];
      if (scoreNum is! num) continue;
      final clamped = scoreNum.toInt().clamp(0, 100);
      final attemptCount = (val['attemptCount'] as num?)?.toInt() ??
          (val['attempt_count'] as num?)?.toInt();
      final lastUpdatedRaw = val['lastUpdated'] ?? val['last_updated'];
      final lastUpdated = lastUpdatedRaw is num
          ? lastUpdatedRaw.toInt()
          : (lastUpdatedRaw is String
                ? (DateTime.tryParse(lastUpdatedRaw)?.millisecondsSinceEpoch ??
                      0)
                : 0);
      out[skillId] = SkillScore(
        skillId: skillId,
        courseId: courseId,
        score: clamped,
        lastUpdated: lastUpdated,
        masteryLevel: _parseMasteryLevel(val['masteryLevel'] ?? val['mastery_level']),
        isWeakestFocus:
            val['isWeakestFocus'] == true || val['is_weakest_focus'] == true,
        attemptCount: attemptCount,
        confidence: _parseConfidence(
          val['confidence'],
          attemptCount: attemptCount,
        ),
      );
    }
    return out;
  }

  static InitialLevel _parseInitialLevel(Object? raw) {
    final value = raw?.toString().trim().toLowerCase();
    switch (value) {
      case 'beginner':
        return InitialLevel.beginner;
      case 'advanced':
        return InitialLevel.advanced;
      case 'intermediate':
      default:
        return InitialLevel.intermediate;
    }
  }
}
