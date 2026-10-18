import {
  ILearnerRepository,
  AnswerAttemptRecord,
  PlacementAttemptData,
  PlacementAnswerEvaluation,
  ReinforcementCompletionContext,
  ReinforcementCompletionResult,
  SubmitAnswerAttemptRequest,
  SubmitAnswerAttemptResult,
  DailyActivitySummary,
} from '../../domain/repositories/ILearnerRepository';
import { LearnerProfile } from '../../domain/entities/LearnerProfile';
import { SkillScore } from '../../domain/entities/SkillScore';
import { InMemoryLearnerRepository } from './InMemoryLearnerRepository';
import { supabaseLessonRepository } from './SupabaseLessonRepository';
import { isDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { supabase, isSupabaseConfigured } from '../../core/config/supabase';

/**
 * Resolves which course a lesson belongs to: explicit caller context first,
 * then the lesson repository chain (curated lessons → generated lessons →
 * seeds). Returns null when the lesson is unknown — callers must NOT fall
 * back to a hardcoded course (that is exactly what caused cross-course mixing).
 */
export async function resolveLessonCourseId(
  lessonId: string,
  explicitCourseId?: string | null,
  lessonRepo: { getLessonById(id: string): Promise<{ courseId: string } | null> } = supabaseLessonRepository
): Promise<string | null> {
  if (explicitCourseId) return explicitCourseId;
  try {
    const lesson = await lessonRepo.getLessonById(lessonId);
    return lesson?.courseId || null;
  } catch {
    return null;
  }
}

export class SupabaseLearnerRepository implements ILearnerRepository {
  private fallbackRepo = new InMemoryLearnerRepository();
  get supportsNodeCompletion(): boolean {
    return isDemoRuntimeActive() || !isSupabaseConfigured;
  }

  get supportsServerPlacementPersistence(): boolean {
    return isSupabaseConfigured && !isDemoRuntimeActive();
  }

  get supportsServerReinforcementPersistence(): boolean {
    return isSupabaseConfigured && !isDemoRuntimeActive();
  }

  private async requireAuthenticatedUser() {
    const { data, error } = await supabase.auth.getUser();
    if (error) throw error;
    if (!data.user) throw new Error('Autentifikatsiyadan o‘tilmagan.');
    return data.user;
  }

  async getCurrentProfile(): Promise<LearnerProfile> {
    return this.getProfile();
  }

  async getProfile(): Promise<LearnerProfile> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return this.fallbackRepo.getProfile();
    }

    try {
      const user = await this.requireAuthenticatedUser();

      // Fetch user profile from public.profiles table
      let { data: userProfileData, error: profileError } = await supabase
        .from('profiles')
        .select('id, first_name, last_name, display_name, email, avatar_url, created_at, updated_at')
        .eq('id', user.id)
        .maybeSingle();
      if (profileError) throw profileError;

      // If public.profiles row is missing or empty, provision it
      if (!userProfileData || !userProfileData.first_name) {
        const metaFirst = (user.user_metadata?.first_name || '').trim();
        const metaLast = (user.user_metadata?.last_name || '').trim();
        const resolvedFirst = metaFirst || (user.email ? user.email.split('@')[0] : 'Foydalanuvchi');
        const resolvedDisplay = metaLast ? `${resolvedFirst} ${metaLast}` : resolvedFirst;

        const editableProfile = {
            first_name: resolvedFirst,
            last_name: metaLast,
            display_name: resolvedDisplay,
            avatar_url: user.user_metadata?.avatar_url || null,
            updated_at: new Date().toISOString(),
        };
        // Existing profiles permit only safe-column UPDATE. A normal upsert
        // also updates id/email and fails the anti-escalation column grants.
        const provision = userProfileData
          ? supabase.from('profiles').update(editableProfile).eq('id', user.id)
          : supabase.from('profiles').upsert(
              { id: user.id, email: user.email || '', ...editableProfile },
              { onConflict: 'id', ignoreDuplicates: true }
            );
        const { error: provisionError } = await provision;
        if (provisionError) throw provisionError;
        const { data: provisioned, error: readError } = await supabase.from('profiles')
          .select('id, first_name, last_name, display_name, email, avatar_url, created_at, updated_at')
          .eq('id', user.id).single();
        if (readError) throw readError;
        userProfileData = provisioned;
      }

      // Fetch learner profile
      const { data: learnerData, error: learnerError } = await supabase
        .from('learner_profiles')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();
      if (learnerError) throw learnerError;

      // Fetch gamification profile
      const { data: gamifyData, error: gamifyError } = await supabase
        .from('gamification_profiles')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();
      if (gamifyError) throw gamifyError;

      // Fetch skill scores
      const { data: scoreRows, error: scoresError } = await supabase
        .from('learner_skill_scores')
        .select('*')
        .eq('user_id', user.id);
      if (scoresError) throw scoresError;

      // Fetch completed lessons
      const { data: progressRows, error: progressError } = await supabase
        .from('lesson_progress')
        .select('lesson_id, status')
        .eq('user_id', user.id)
        .eq('status', 'completed');
      if (progressError) throw progressError;

      const completedLessonIds = (progressRows || []).map((row) => row.lesson_id);
      let completedNodeIds = [...completedLessonIds];
      if (completedLessonIds.length > 0) {
        const { data: nodeRows, error: nodeError } = await supabase
          .from('roadmap_nodes')
          .select('id, target_lesson_id')
          .in('target_lesson_id', completedLessonIds)
          .eq('is_active', true);
        if (nodeError) throw nodeError;
        completedNodeIds = [
          ...new Set([
            ...completedNodeIds,
            ...(nodeRows || []).map((row) => row.id),
          ]),
        ];
      }

      // Fetch completed reinforcements
      const { data: reinfRows, error: reinfError } = await supabase
        .from('reinforcement_attempts')
        .select('reinforcement_node_id, is_correct')
        .eq('user_id', user.id)
        .eq('is_correct', true);
      if (reinfError) throw reinfError;

      const scoresByCourse: Record<string, Record<string, SkillScore>> = {};
      if (scoreRows) {
        for (const row of scoreRows) {
          scoresByCourse[row.course_id] = scoresByCourse[row.course_id] || {};
          scoresByCourse[row.course_id][row.skill_id] = {
            skillId: row.skill_id,
            courseId: row.course_id,
            score: row.score,
            lastUpdated: new Date(row.last_updated).getTime(),
            masteryLevel: row.mastery_level,
            isWeakestFocus: row.is_weakest_focus,
          };
        }
      }

      const firstName = userProfileData?.first_name ||
        user.user_metadata?.first_name ||
        (user.email ? user.email.split('@')[0] : 'Foydalanuvchi');
      const lastName = userProfileData?.last_name || user.user_metadata?.last_name || '';

      return {
        id: user.id,
        name: firstName,
        firstName,
        lastName,
        email: user.email || userProfileData?.email || '',
        avatarUrl: userProfileData?.avatar_url || '',
         selectedCourseId: learnerData?.selected_course_id || '',
        goal: learnerData?.goal || 'mastery',
        dailyMinutes: learnerData?.daily_minutes || 15,
        initialLevel: learnerData?.initial_level || 'intermediate',
        xp: gamifyData?.xp || 0,
        streakDays: gamifyData?.streak_days || 1,
        lastActiveDate: gamifyData?.last_activity_date || new Date().toISOString().split('T')[0],
        scoresByCourse,
        completedLessonIds,
        completedNodeIds,
        completedReinforcementIds: (reinfRows || []).map((r) => r.reinforcement_node_id),
        createdAt: new Date(learnerData?.created_at || Date.now()).getTime(),
      };
    } catch (err) {
      console.warn('Error fetching Supabase learner profile:', err);
      throw err;
    }
  }

  async updateProfile(updates: Partial<LearnerProfile>): Promise<LearnerProfile> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return this.fallbackRepo.updateProfile(updates);
    }

    try {
      const user = await this.requireAuthenticatedUser();

      const currentProfile = await this.getProfile();
      const merged: LearnerProfile = {
        ...currentProfile,
        ...updates,
        scoresByCourse: updates.scoresByCourse || currentProfile.scoresByCourse,
      };

      // Sync public.profiles if name/names/avatar are updated
      if (updates.name !== undefined || updates.firstName !== undefined || updates.lastName !== undefined || updates.avatarUrl !== undefined) {
        const newFirst = updates.firstName || updates.name || currentProfile.firstName || 'Foydalanuvchi';
        const newLast = updates.lastName ?? currentProfile.lastName ?? '';
        const newDisplay = newLast ? `${newFirst} ${newLast}` : newFirst;

        const { error: profileUpdateError } = await supabase.from('profiles').update({
          first_name: newFirst,
          last_name: newLast,
          display_name: newDisplay,
          avatar_url: updates.avatarUrl ?? currentProfile.avatarUrl ?? null,
          updated_at: new Date().toISOString(),
        }).eq('id', user.id);
        if (profileUpdateError) throw profileUpdateError;
      }

      const { error: learnerUpdateError } = await supabase.from('learner_profiles').upsert({
        user_id: user.id,
        selected_course_id: merged.selectedCourseId,
        goal: merged.goal,
        daily_minutes: merged.dailyMinutes,
        initial_level: merged.initialLevel,
        updated_at: new Date().toISOString(),
      });
      if (learnerUpdateError) throw learnerUpdateError;

      return merged;
    } catch (err) {
      console.warn('Error updating Supabase learner profile:', err);
      throw err;
    }
  }

  async saveSkillScores(courseId: string, scores: Record<string, SkillScore>): Promise<void> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return this.fallbackRepo.saveSkillScores(courseId, scores);
    }

    try {
       await this.requireAuthenticatedUser();

      const { error } = await supabase.rpc('recalculate_skill_scores', {
        p_course_id: courseId,
      });
      if (error) throw error;
    } catch (err) {
      console.warn('Error recalculating skill scores in Supabase:', err);
      throw err;
    }
  }

  async savePlacementAttempt(data: PlacementAttemptData): Promise<string> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return this.fallbackRepo.savePlacementAttempt(data);
    }

    try {
       await this.requireAuthenticatedUser();

      const { data: result, error } = await supabase.rpc('save_placement_attempt', {
        p_course_id: data.courseId,
        p_submissions: data.submissions.map((submission) => ({
          question_id: submission.questionId,
          selected_index: submission.selectedIndex,
        })),
        p_idempotency_key: `placement_${data.courseId}_${new Date().toISOString().slice(0, 10)}`,
      });

      if (error || !result?.attempt_id) {
        throw new Error(error?.message || 'Placement natijasini serverga saqlab bo‘lmadi.');
      }

      return String(result.attempt_id);
    } catch (err) {
      console.warn('Exception saving placement attempt to Supabase:', err);
      throw err;
    }
  }

  async evaluatePlacementAnswer(
    courseId: string,
    questionId: string,
    selectedIndex: number
  ): Promise<PlacementAnswerEvaluation> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return this.fallbackRepo.evaluatePlacementAnswer(courseId, questionId, selectedIndex);
    }

    const { data, error } = await supabase.rpc('evaluate_placement_answer', {
      p_course_id: courseId,
      p_question_id: questionId,
      p_selected_index: selectedIndex,
    });

    if (error || !data || typeof data.is_correct !== 'boolean') {
      throw new Error(error?.message || 'Javobni serverda tekshirib bo‘lmadi.');
    }

    return { isCorrect: Boolean(data.is_correct) };
  }

  async markLessonCompleted(lessonId: string, courseId?: string | null): Promise<void> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      await this.fallbackRepo.markLessonCompleted(lessonId, courseId);
      return;
    }

    try {
      await this.requireAuthenticatedUser();

      const resolvedCourseId = await resolveLessonCourseId(lessonId, courseId);
      if (!resolvedCourseId) {
        throw new Error(`Dars kursi aniqlanmadi: ${lessonId}`);
      }

      const { data, error } = await supabase.rpc('complete_lesson', {
        p_lesson_id: lessonId,
        p_course_id: resolvedCourseId,
      });
      if (error || data?.completed !== true) throw error || new Error('Dars yakuni serverda tasdiqlanmadi.');
    } catch (err) {
      console.warn('Error marking lesson completed in Supabase:', err);
      throw err;
    }
  }

  async markNodeCompleted(nodeId: string): Promise<void> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) return this.fallbackRepo.markNodeCompleted(nodeId);
    throw new Error(`Roadmap node completion is not available through the production contract: ${nodeId}`);
  }

  async markReinforcementCompleted(reinforcementId: string, context?: ReinforcementCompletionContext): Promise<ReinforcementCompletionResult | void> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      await this.fallbackRepo.markReinforcementCompleted(reinforcementId, context);
      return;
    }

    if (!context?.courseId || !context?.skillId || !context?.questionId) {
      throw new Error(`Mustahkamlash uchun course/skill/question konteksti yetishmaydi: ${reinforcementId}`);
    }

    try {
      const { data, error } = await supabase.rpc('complete_reinforcement', {
        p_reinforcement_node_id: reinforcementId,
        p_course_id: context.courseId,
        p_skill_id: context.skillId,
        p_question_id: context.questionId,
        p_xp_awarded: context.xpAwarded,
      });
      if (error || !data) throw error || new Error('Mustahkamlash serverda saqlanmadi.');
      if (
        typeof data.old_score !== 'number' || !Number.isFinite(data.old_score) ||
        data.old_score < 0 || data.old_score > 100 ||
        typeof data.new_score !== 'number' || !Number.isFinite(data.new_score) ||
        data.new_score < 0 || data.new_score > 100 ||
        typeof data.xp_awarded !== 'number' || !Number.isInteger(data.xp_awarded) ||
        data.xp_awarded < 0 || typeof data.already_processed !== 'boolean'
      ) {
        throw new Error('Mustahkamlash server natijasi noto‘g‘ri.');
      }
      return {
        oldScore: data.old_score,
        newScore: data.new_score,
        xpAwarded: data.xp_awarded,
        alreadyProcessed: data.already_processed,
      };
    } catch (err) {
      console.warn('Error marking reinforcement completed in Supabase:', err);
      throw err;
    }
  }

  async submitAnswerAttempt(request: SubmitAnswerAttemptRequest): Promise<SubmitAnswerAttemptResult> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return this.fallbackRepo.submitAnswerAttempt(request);
    }

    try {
      const user = await this.requireAuthenticatedUser();

      const { data, error } = await supabase.rpc('submit_answer_attempt', {
        p_user_id: user.id,
        p_course_id: request.courseId,
        p_skill_id: request.skillId,
        p_lesson_id: request.lessonId || 'general',
        p_question_id: request.questionId,
        p_selected_index: request.selectedIndex,
        p_selected_text: request.selectedAnswer,
        p_idempotency_key: request.idempotencyKey || null,
      });

      if (error || !data) {
        throw new Error(error?.message || 'Javob serverda saqlanmadi.');
      }

      const result: SubmitAnswerAttemptResult = {
        isCorrect: Boolean(data.is_correct),
        explanation: data.explanation || 'To‘g‘ri yechim.',
        newSkillScore: typeof data.new_skill_score === 'number' ? data.new_skill_score : 50,
        overallScore: typeof data.overall_score === 'number' ? data.overall_score : 50,
        xpAwarded: typeof data.xp_awarded === 'number' ? data.xp_awarded : 0,
        totalXp: typeof data.total_xp === 'number' ? data.total_xp : undefined,
        totalAttempts: typeof data.total_attempts === 'number' ? data.total_attempts : undefined,
        correctAttempts: typeof data.correct_attempts === 'number' ? data.correct_attempts : undefined,
        alreadyProcessed: Boolean(data.already_processed),
      };

       return result;
    } catch (err) {
      console.warn('Exception during submitAnswerAttempt RPC:', err);
      throw err;
    }
  }

  async recordAnswerAttempt(attempt: Omit<AnswerAttemptRecord, 'id' | 'timestamp'>): Promise<AnswerAttemptRecord> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) return this.fallbackRepo.recordAnswerAttempt(attempt);

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Autentifikatsiyadan o‘tilmagan.');

      // Invoke server-side RPC if available
      const { data, error } = await supabase.rpc('submit_answer_attempt', {
        p_user_id: user.id,
        p_course_id: attempt.courseId,
        p_skill_id: attempt.skillId,
        p_lesson_id: attempt.lessonId || 'general',
        p_question_id: attempt.questionId,
        p_selected_index: attempt.selectedIndex,
        p_selected_text: attempt.selectedAnswer,
        p_idempotency_key: `${attempt.lessonId || 'general'}:${attempt.questionId}:${attempt.selectedIndex}`,
      });

      if (error || !data) throw new Error(error?.message || 'Javob serverda saqlanmadi.');

      return {
        ...attempt,
        id: `server_${Date.now()}`,
        timestamp: Date.now(),
        isCorrect: Boolean(data.is_correct),
      };
    } catch (err) {
      console.warn('Error recording answer attempt to Supabase:', err);
      throw err;
    }
  }

  async getAnswerAttempts(limit: number = 10): Promise<AnswerAttemptRecord[]> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) return this.fallbackRepo.getAnswerAttempts(limit);
    const user = await this.requireAuthenticatedUser();
    const { data, error } = await supabase
      .from('answer_attempts')
      .select('id, user_id, course_id, skill_id, lesson_id, question_id, selected_index, selected_answer, is_correct, created_at')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw error;
    return (data || []).map((row) => ({
      id: row.id,
      userId: row.user_id,
      courseId: row.course_id,
      skillId: row.skill_id,
      lessonId: row.lesson_id,
      questionId: row.question_id,
      selectedIndex: row.selected_index,
      selectedAnswer: row.selected_answer,
      isCorrect: row.is_correct,
      timestamp: new Date(row.created_at).getTime(),
    }));
  }

  async getDailyActivity(days: number = 7): Promise<DailyActivitySummary[]> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return this.fallbackRepo.getDailyActivity(days);
    }

    try {
      const user = await this.requireAuthenticatedUser();

      const since = new Date(Date.now() - (days - 1) * 24 * 60 * 60 * 1000)
        .toISOString()
        .split('T')[0];

       const { data, error } = await supabase
        .from('daily_learning_stats')
        .select('activity_date, active_seconds, xp_earned, lessons_completed')
        .eq('user_id', user.id)
        .gte('activity_date', since)
        .order('activity_date', { ascending: true });
      if (error) throw error;

      const byDate = new Map<string, DailyActivitySummary>();
      for (const row of data || []) {
        byDate.set(row.activity_date, {
          date: row.activity_date,
          activeMinutes: Math.round((row.active_seconds || 0) / 60),
          xpEarned: row.xp_earned || 0,
          lessonsCompleted: row.lessons_completed || 0,
        });
      }

      // Pad missing days with zeroes so the chart always has `days` columns.
      const result: DailyActivitySummary[] = [];
      const dayMs = 24 * 60 * 60 * 1000;
      for (let i = days - 1; i >= 0; i--) {
        const dateStr = new Date(Date.now() - i * dayMs).toISOString().split('T')[0];
        result.push(
          byDate.get(dateStr) || { date: dateStr, activeMinutes: 0, xpEarned: 0, lessonsCompleted: 0 }
        );
      }
      return result;
    } catch (err) {
      console.warn('Error fetching daily activity:', err);
      throw err;
    }
  }

  async addXp(amount: number, actionIdempotencyKey?: string): Promise<number> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) return this.fallbackRepo.addXp(amount, actionIdempotencyKey);
    const { data, error } = await supabase.rpc('award_xp', {
      p_amount: amount,
      p_action_key: actionIdempotencyKey || `xp_${Date.now()}`,
    });
    if (error || !data) throw error || new Error('XP serverda saqlanmadi.');
    return Number(data.xp || 0);
  }

  async recordDailyActivity(dateStr?: string): Promise<number> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) return this.fallbackRepo.recordDailyActivity(dateStr);
    const { data, error } = await supabase.rpc('record_learning_activity', {
      p_activity_date: dateStr || null,
    });
    if (error || !data) throw error || new Error('Kunlik faollik serverda saqlanmadi.');
    return Number(data.streak_days || 0);
  }

  async resetAll(): Promise<LearnerProfile> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) return this.fallbackRepo.resetAll();
    throw new Error('Production learner reset is not supported by the server contract.');
  }
}

export const supabaseLearnerRepository = new SupabaseLearnerRepository();
