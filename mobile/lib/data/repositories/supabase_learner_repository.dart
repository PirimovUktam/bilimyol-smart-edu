import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/i_learner_repository.dart';
import '../../domain/entities/learner_profile.dart';
import '../../domain/entities/skill_score.dart';
import 'in_memory_learner_repository.dart';

class SupabaseLearnerRepository implements ILearnerRepository {
  final InMemoryLearnerRepository _fallbackRepo = InMemoryLearnerRepository();

  @override
  Future<LearnerProfile> getCurrentProfile() async {
    return getProfile();
  }

  @override
  Future<LearnerProfile> getProfile() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        return _fallbackRepo.getProfile();
      }

      // Fetch user profile from public.profiles table
      var userProfile = await client
          .from('profiles')
          .select('id, first_name, last_name, display_name, email, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (userProfile == null || userProfile['first_name'] == null || userProfile['first_name'] == 'Foydalanuvchi') {
        final metaFirst = (user.userMetadata?['first_name'] as String? ?? '').trim();
        final metaLast = (user.userMetadata?['last_name'] as String? ?? '').trim();
        final resolvedFirst = metaFirst.isNotEmpty ? metaFirst : (user.email != null ? user.email!.split('@').first : 'Foydalanuvchi');
        final resolvedLast = metaLast;
        final resolvedDisplay = resolvedLast.isNotEmpty ? '$resolvedFirst $resolvedLast' : resolvedFirst;

        await client.from('profiles').upsert({
          'id': user.id,
          'first_name': resolvedFirst,
          'last_name': resolvedLast,
          'display_name': resolvedDisplay,
          'email': user.email ?? '',
          'avatar_url': user.userMetadata?['avatar_url'],
          'updated_at': DateTime.now().toIso8601String(),
        });

        userProfile = {
          'id': user.id,
          'first_name': resolvedFirst,
          'last_name': resolvedLast,
          'display_name': resolvedDisplay,
          'email': user.email ?? '',
        };
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
          lastUpdated: DateTime.parse(row['last_updated']).millisecondsSinceEpoch,
          masteryLevel: row['mastery_level'] ?? 'developing',
          isWeakestFocus: row['is_weakest_focus'] == true,
        );
      }

      final completedLessonIds = (progressRows as List?)
              ?.map((e) => e['lesson_id'] as String)
              .toList() ??
          [];

      final completedReinfIds = (reinfRows as List?)
              ?.map((e) => e['reinforcement_node_id'] as String)
              .toList() ??
          [];

      final firstName = userProfile['first_name'] as String? ??
          user.userMetadata?['first_name'] as String? ??
          (user.email != null ? user.email!.split('@').first : 'Foydalanuvchi');

      return LearnerProfile(
        id: user.id,
        name: firstName,
        selectedCourseId: learnerData?['selected_course_id'] ?? 'course_math_01',
        goal: OnboardingGoal.mastery,
        dailyMinutes: learnerData?['daily_minutes'] ?? 15,
        initialLevel: InitialLevel.intermediate,
        xp: gamifyData?['xp'] ?? 0,
        streakDays: gamifyData?['streak_days'] ?? 1,
        lastActiveDate: gamifyData?['last_activity_date'] ??
            DateTime.now().toIso8601String().split('T').first,
        scoresByCourse: scoresByCourse,
        completedLessonIds: completedLessonIds,
        completedNodeIds: completedLessonIds,
        completedReinforcementIds: completedReinfIds,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return _fallbackRepo.getProfile();
    }
  }

  @override
  Future<LearnerProfile> updateProfile(LearnerProfile updated) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        return _fallbackRepo.updateProfile(updated);
      }

      await client.from('profiles').upsert({
        'id': user.id,
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
      return _fallbackRepo.updateProfile(updated);
    }
  }

  @override
  Future<void> saveSkillScores(String courseId, Map<String, SkillScore> scores) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        return _fallbackRepo.saveSkillScores(courseId, scores);
      }

      for (final entry in scores.entries) {
        await client.from('learner_skill_scores').upsert({
          'user_id': user.id,
          'course_id': courseId,
          'skill_id': entry.key,
          'score': entry.value.score,
          'mastery_level': entry.value.masteryLevel,
          'is_weakest_focus': entry.value.isWeakestFocus,
          'last_updated': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {
      await _fallbackRepo.saveSkillScores(courseId, scores);
    }
  }

  @override
  Future<String> savePlacementAttempt(PlacementAttemptData data) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        return _fallbackRepo.savePlacementAttempt(data);
      }

      final attemptRow = await client
          .from('placement_attempts')
          .insert({
            'user_id': user.id,
            'course_id': data.courseId,
            'score': data.score,
            'weakest_skill_id': data.weakestSkillId,
            'started_at': DateTime.now().toIso8601String(),
            'completed_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      final attemptId = attemptRow['id'] as String;

      if (data.submissions.isNotEmpty) {
        final answerRows = data.submissions
            .map((sub) => {
                  'attempt_id': attemptId,
                  'user_id': user.id,
                  'question_id': sub.questionId,
                  'selected_index': sub.selectedIndex,
                  'is_correct': sub.isCorrect,
                  'created_at': DateTime.now().toIso8601String(),
                })
            .toList();

        await client.from('placement_answers').insert(answerRows);
      }

      return attemptId;
    } catch (_) {
      return _fallbackRepo.savePlacementAttempt(data);
    }
  }

  @override
  Future<void> markLessonCompleted(String lessonId) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        return _fallbackRepo.markLessonCompleted(lessonId);
      }

      await client.from('lesson_progress').upsert({
        'user_id': user.id,
        'lesson_id': lessonId,
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      });
      await addXp(20, 'lesson_completed_$lessonId');
    } catch (_) {
      await _fallbackRepo.markLessonCompleted(lessonId);
    }
  }

  @override
  Future<void> markNodeCompleted(String nodeId) async {
    await markLessonCompleted(nodeId);
  }

  @override
  Future<void> markReinforcementCompleted(String reinforcementId) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        return _fallbackRepo.markReinforcementCompleted(reinforcementId);
      }

      await client.from('reinforcement_attempts').upsert({
        'user_id': user.id,
        'reinforcement_node_id': reinforcementId,
        'is_correct': true,
        'created_at': DateTime.now().toIso8601String(),
      });
      await addXp(15, 'reinforcement_completed_$reinforcementId');
    } catch (_) {
      await _fallbackRepo.markReinforcementCompleted(reinforcementId);
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
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        await client.rpc('submit_answer_attempt', params: {
          'p_user_id': user.id,
          'p_course_id': courseId,
          'p_skill_id': skillId,
          'p_lesson_id': lessonId,
          'p_question_id': questionId,
          'p_selected_index': selectedIndex,
          'p_selected_text': selectedAnswer,
        });
      }
      return _fallbackRepo.recordAnswerAttempt(
        courseId: courseId,
        skillId: skillId,
        lessonId: lessonId,
        questionId: questionId,
        selectedIndex: selectedIndex,
        selectedAnswer: selectedAnswer,
        isCorrect: isCorrect,
      );
    } catch (_) {
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
  }

  @override
  Future<List<AnswerAttemptRecord>> getAnswerAttempts([int limit = 10]) async {
    return _fallbackRepo.getAnswerAttempts(limit);
  }

  @override
  Future<int> addXp(int amount, [String? actionIdempotencyKey]) async {
    return _fallbackRepo.addXp(amount, actionIdempotencyKey);
  }

  @override
  Future<int> recordDailyActivity([String? dateStr]) async {
    return _fallbackRepo.recordDailyActivity(dateStr);
  }

  @override
  Future<LearnerProfile> resetAll() async {
    return _fallbackRepo.resetAll();
  }
}
