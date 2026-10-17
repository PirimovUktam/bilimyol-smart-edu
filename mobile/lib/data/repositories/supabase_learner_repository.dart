import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/i_learner_repository.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/skill_score.dart';
import '../../core/config/supabase_config.dart';
import 'in_memory_learner_repository.dart';

class SupabaseLearnerRepository implements ILearnerRepository {
  final InMemoryLearnerRepository _fallbackRepo = InMemoryLearnerRepository();

  @override
  bool get supportsNodeCompletion => !SupabaseConfig.hasRemoteConfiguration;

  @override
  bool get supportsServerPlacementPersistence =>
      SupabaseConfig.hasRemoteConfiguration;

  @override
  bool get supportsServerReinforcementPersistence =>
      SupabaseConfig.hasRemoteConfiguration;

  @override
  Future<LearnerProfile> getCurrentProfile() async {
    return getProfile();
  }

  @override
  Future<LearnerProfile> getProfile() async {
    if (!SupabaseConfig.hasRemoteConfiguration) return _fallbackRepo.getProfile();
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
          await client.from('profiles').update(editableProfile).eq('id', user.id);
        } else {
          await client.from('profiles').upsert({
            'id': user.id, 'email': user.email ?? '', ...editableProfile,
          }, onConflict: 'id', ignoreDuplicates: true);
        }
        // A signup trigger or concurrent reader may have provisioned the row.
        // Read back the winner instead of manufacturing a local profile.
        userProfile = await client.from('profiles')
            .select('id, first_name, last_name, display_name, email, avatar_url')
            .eq('id', user.id).single();
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
            ...(nodeRows as List)
                .map((row) => row['id'] as String),
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
  Future<LearnerProfile> updateProfile(LearnerProfile updated) async {
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallbackRepo.updateProfile(updated);
    }
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('Autentifikatsiyadan o‘tilmagan.');
      }

      await client.from('profiles').update({
        'first_name': updated.name,
        'display_name': updated.name,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await client.from('learner_profiles').upsert({
        'user_id': user.id,
        'selected_course_id': updated.selectedCourseId,
        'daily_minutes': updated.dailyMinutes,
        'goal': updated.goal.name,
        'initial_level': updated.initialLevel.name,
        'updated_at': DateTime.now().toIso8601String(),
      });

      return updated;
    } catch (_) {
      rethrow;
    }
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

      await client.rpc('recalculate_skill_scores', params: {'p_course_id': courseId});
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

      final result = await client.rpc('save_placement_attempt', params: {
        'p_course_id': data.courseId,
        'p_submissions': data.submissions
            .map((sub) => {
                  'question_id': sub.questionId,
                  'selected_index': sub.selectedIndex,
                })
            .toList(),
        'p_idempotency_key':
            'placement_${data.courseId}_${DateTime.now().toIso8601String().split('T').first}',
      }).eq('id', user.id);

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

    final result = await Supabase.instance.client.rpc('evaluate_placement_answer', params: {
      'p_course_id': courseId,
      'p_question_id': questionId,
      'p_selected_index': selectedIndex,
    });

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

      final result = await client.rpc('complete_lesson', params: {
        'p_lesson_id': lessonId,
        'p_course_id': courseId,
      });
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
    final result = await client.rpc('complete_reinforcement', params: {
      'p_reinforcement_node_id': reinforcementId,
      'p_course_id': courseId,
      'p_skill_id': skillId,
      'p_question_id': questionId,
      'p_xp_awarded': xpAwarded,
    });
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
        .map<AnswerAttemptRecord>(
          (raw) {
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
              timestamp: DateTime.parse(row['created_at'] as String)
                  .millisecondsSinceEpoch,
            );
          },
        )
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
      final result = await client.rpc('award_xp', params: {
        'p_amount': amount,
        'p_action_key': actionIdempotencyKey ?? 'xp_${DateTime.now().microsecondsSinceEpoch}',
      });
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
      final result = await client.rpc('record_learning_activity', params: {
        'p_activity_date': today,
      });
      if (result is! Map) throw Exception('Kunlik faollik serverda saqlanmadi.');
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
