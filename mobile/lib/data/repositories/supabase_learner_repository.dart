import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/i_learner_repository.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/placement_session.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/skill_score.dart';
import '../../core/config/supabase_config.dart';
import 'in_memory_learner_repository.dart';
import 'supabase_course_repository.dart';

class SupabaseLearnerRepository extends ILearnerRepository {
  final InMemoryLearnerRepository _fallbackRepo = InMemoryLearnerRepository();

  @override
  bool get supportsNodeCompletion => !SupabaseConfig.hasRemoteConfiguration;

  @override
  bool get supportsServerPlacementPersistence =>
      SupabaseConfig.hasRemoteConfiguration;

  @override
  bool get supportsPlacementSessions => SupabaseConfig.hasRemoteConfiguration;

  @override
  Future<PlacementSession> advancePlacement(
    String courseId, {
    String? sessionId,
    String? questionId,
    int? selectedIndex,
    bool restart = false,
  }) async {
    final data = await Supabase.instance.client.rpc(
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
                      selected: row['selected_option'] as String,
                      correct: row['correct_option'] as String,
                      explanation: row['explanation'] as String,
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
      SupabaseConfig.hasRemoteConfiguration;

  @override
  Future<LearnerProfile> getCurrentProfile() async {
    return getProfile();
  }

  @override
  Future<LearnerProfile> getProfile() async {
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.getProfile();
    }
    try {
      final client = Supabase.instance.client;
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
          'avatar_url': user.userMetadata?['avatar_url'],
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
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.saveCourseLearningPlan(
        courseId: courseId,
        goal: goal,
        dailyMinutes: dailyMinutes,
        initialLevel: initialLevel,
      );
    }
    await Supabase.instance.client.rpc(
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
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.updateProfile(updated, fields: fields);
    }
    final client = Supabase.instance.client;
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
  Future<void> saveSkillScores(
    String courseId,
    Map<String, SkillScore> scores,
  ) async {
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.saveSkillScores(courseId, scores);
    }
    try {
      final client = Supabase.instance.client;
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
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.savePlacementAttempt(data);
    }
    try {
      final client = Supabase.instance.client;
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
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.evaluatePlacementAnswer(
        courseId: courseId,
        questionId: questionId,
        selectedIndex: selectedIndex,
      );
    }

    final result = await Supabase.instance.client.rpc(
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
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.markLessonCompleted(lessonId, courseId: courseId);
    }
    try {
      final client = Supabase.instance.client;
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
    if (!SupabaseConfig.hasRemoteConfiguration) {
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
    if (!SupabaseConfig.hasRemoteConfiguration) {
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
    final client = Supabase.instance.client;
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
    if (!SupabaseConfig.hasRemoteConfiguration) {
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
      final client = Supabase.instance.client;
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
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.submitAnswerAttempt(
        courseId: courseId,
        skillId: skillId,
        lessonId: lessonId,
        questionId: questionId,
        selectedIndex: selectedIndex,
        selectedAnswer: selectedAnswer,
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
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
    final rpcRes = await Supabase.instance.client.rpc(
      'submit_answer_attempt',
      params: {
        'p_user_id': user.id,
        'p_course_id': courseId,
        'p_skill_id': skillId,
        'p_lesson_id': lessonId,
        'p_question_id': questionId,
        'p_selected_index': selectedIndex,
        'p_selected_text': selectedAnswer,
        'p_idempotency_key': '$lessonId:$questionId:$selectedIndex',
      },
    );
    final data = rpcRes is Map
        ? Map<String, dynamic>.from(rpcRes)
        : <String, dynamic>{};
    if (!data.containsKey('is_correct')) {
      throw Exception('Javobni serverda tekshirib bo‘lmadi.');
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
      correctOption: null,
      explanation: data['explanation'] as String?,
      newSkillScore: (data['new_skill_score'] as num?)?.toInt(),
      xpAwarded: (data['xp_awarded'] as num?)?.toInt() ?? 0,
      alreadyProcessed: data['already_processed'] == true,
    );
  }

  @override
  Future<List<AnswerAttemptRecord>> getAnswerAttempts([int limit = 10]) async {
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.getAnswerAttempts(limit);
    }
    final client = SupabaseConfig.client;
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
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.getDailyActivity(days);
    }
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('Autentifikatsiyadan o‘tilmagan.');
      }

      final since = DateTime.now()
          .subtract(Duration(days: days - 1))
          .toIso8601String()
          .split('T')
          .first;

      final rows = await client
          .from('daily_learning_stats')
          .select('activity_date, active_seconds, xp_earned, lessons_completed')
          .eq('user_id', user.id)
          .gte('activity_date', since)
          .order('activity_date', ascending: true);

      final byDate = <String, DailyActivitySummary>{};
      for (final row in (rows as List)) {
        final date = row['activity_date'] as String;
        byDate[date] = DailyActivitySummary(
          date: date,
          activeMinutes: ((row['active_seconds'] as num?)?.toInt() ?? 0) ~/ 60,
          xpEarned: (row['xp_earned'] as num?)?.toInt() ?? 0,
          lessonsCompleted: (row['lessons_completed'] as num?)?.toInt() ?? 0,
        );
      }

      final result = <DailyActivitySummary>[];
      final today = DateTime.now();
      for (int i = days - 1; i >= 0; i--) {
        final dateStr = today
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
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.addXp(amount, actionIdempotencyKey);
    }
    try {
      final client = Supabase.instance.client;
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

    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.recordDailyActivity(dateStr);
    }
    try {
      final client = Supabase.instance.client;
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
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.resetAll();
    }
    throw UnsupportedError(
      'Production learner reset is not supported by the server contract.',
    );
  }

  @override
  Future<void> clearLocalState() async {
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
