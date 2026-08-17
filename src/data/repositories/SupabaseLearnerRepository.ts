import { ILearnerRepository, AnswerAttemptRecord, PlacementAttemptData } from '../../domain/repositories/ILearnerRepository';
import { LearnerProfile } from '../../domain/entities/LearnerProfile';
import { SkillScore } from '../../domain/entities/SkillScore';
import { InMemoryLearnerRepository } from './InMemoryLearnerRepository';
import { supabase, isSupabaseConfigured } from '../../core/config/supabase';

export class SupabaseLearnerRepository implements ILearnerRepository {
  private fallbackRepo = new InMemoryLearnerRepository();

  async getCurrentProfile(): Promise<LearnerProfile> {
    return this.getProfile();
  }

  async getProfile(): Promise<LearnerProfile> {
    if (!isSupabaseConfigured) {
      return this.fallbackRepo.getProfile();
    }

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        return this.fallbackRepo.getProfile();
      }

      // Fetch user profile from public.profiles table
      let { data: userProfileData } = await supabase
        .from('profiles')
        .select('id, first_name, last_name, display_name, email, avatar_url, created_at, updated_at')
        .eq('id', user.id)
        .maybeSingle();

      // If public.profiles row is missing or empty, provision it
      if (!userProfileData || !userProfileData.first_name) {
        const metaFirst = (user.user_metadata?.first_name || '').trim();
        const metaLast = (user.user_metadata?.last_name || '').trim();
        const resolvedFirst = metaFirst || (user.email ? user.email.split('@')[0] : 'Foydalanuvchi');
        const resolvedDisplay = metaLast ? `${resolvedFirst} ${metaLast}` : resolvedFirst;

        const { data: provisioned } = await supabase
          .from('profiles')
          .upsert({
            id: user.id,
            first_name: resolvedFirst,
            last_name: metaLast,
            display_name: resolvedDisplay,
            email: user.email || '',
            avatar_url: user.user_metadata?.avatar_url || null,
            updated_at: new Date().toISOString(),
          })
          .select()
          .maybeSingle();

        if (provisioned) {
          userProfileData = provisioned;
        }
      }

      // Fetch learner profile
      const { data: learnerData } = await supabase
        .from('learner_profiles')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

      // Fetch gamification profile
      const { data: gamifyData } = await supabase
        .from('gamification_profiles')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

      // Fetch skill scores
      const { data: scoreRows } = await supabase
        .from('learner_skill_scores')
        .select('*')
        .eq('user_id', user.id);

      // Fetch completed lessons
      const { data: progressRows } = await supabase
        .from('lesson_progress')
        .select('lesson_id, status')
        .eq('user_id', user.id)
        .eq('status', 'completed');

      // Fetch completed reinforcements
      const { data: reinfRows } = await supabase
        .from('reinforcement_attempts')
        .select('reinforcement_node_id, is_correct')
        .eq('user_id', user.id)
        .eq('is_correct', true);

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
        selectedCourseId: learnerData?.selected_course_id || 'course_math_01',
        goal: learnerData?.goal || 'mastery',
        dailyMinutes: learnerData?.daily_minutes || 15,
        initialLevel: learnerData?.initial_level || 'intermediate',
        xp: gamifyData?.xp || 0,
        streakDays: gamifyData?.streak_days || 1,
        lastActiveDate: gamifyData?.last_activity_date || new Date().toISOString().split('T')[0],
        scoresByCourse,
        completedLessonIds: (progressRows || []).map((r) => r.lesson_id),
        completedNodeIds: [],
        completedReinforcementIds: (reinfRows || []).map((r) => r.reinforcement_node_id),
        createdAt: new Date(learnerData?.created_at || Date.now()).getTime(),
      };
    } catch (err) {
      console.warn('Error fetching Supabase learner profile, using local state:', err);
      return this.fallbackRepo.getProfile();
    }
  }

  async updateProfile(updates: Partial<LearnerProfile>): Promise<LearnerProfile> {
    if (!isSupabaseConfigured) {
      return this.fallbackRepo.updateProfile(updates);
    }

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        return this.fallbackRepo.updateProfile(updates);
      }

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

        await supabase.from('profiles').upsert({
          id: user.id,
          first_name: newFirst,
          last_name: newLast,
          display_name: newDisplay,
          avatar_url: updates.avatarUrl ?? currentProfile.avatarUrl ?? null,
          updated_at: new Date().toISOString(),
        });
      }

      await supabase.from('learner_profiles').upsert({
        user_id: user.id,
        selected_course_id: merged.selectedCourseId,
        goal: merged.goal,
        daily_minutes: merged.dailyMinutes,
        initial_level: merged.initialLevel,
        updated_at: new Date().toISOString(),
      });

      if (updates.xp !== undefined || updates.streakDays !== undefined || updates.lastActiveDate !== undefined) {
        await supabase.from('gamification_profiles').upsert({
          user_id: user.id,
          xp: merged.xp,
          streak_days: merged.streakDays,
          last_activity_date: merged.lastActiveDate,
          updated_at: new Date().toISOString(),
        });
      }

      return merged;
    } catch (err) {
      console.warn('Error updating Supabase learner profile, using local state:', err);
      return this.fallbackRepo.updateProfile(updates);
    }
  }

  async saveSkillScores(courseId: string, scores: Record<string, SkillScore>): Promise<void> {
    if (!isSupabaseConfigured) {
      return this.fallbackRepo.saveSkillScores(courseId, scores);
    }

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        return this.fallbackRepo.saveSkillScores(courseId, scores);
      }

      const rows = Object.values(scores).map((s) => ({
        user_id: user.id,
        course_id: courseId,
        skill_id: s.skillId,
        score: s.score,
        mastery_level: s.masteryLevel,
        is_weakest_focus: Boolean(s.isWeakestFocus),
        last_updated: new Date().toISOString(),
      }));

      await supabase.from('learner_skill_scores').upsert(rows, {
        onConflict: 'user_id,course_id,skill_id',
      });
    } catch (err) {
      console.warn('Error saving skill scores to Supabase, saving locally:', err);
      return this.fallbackRepo.saveSkillScores(courseId, scores);
    }
  }

  async savePlacementAttempt(data: PlacementAttemptData): Promise<string> {
    if (!isSupabaseConfigured) {
      return this.fallbackRepo.savePlacementAttempt(data);
    }

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        return this.fallbackRepo.savePlacementAttempt(data);
      }

      const { data: attemptRow, error: attemptErr } = await supabase
        .from('placement_attempts')
        .insert({
          user_id: user.id,
          course_id: data.courseId,
          score: data.score,
          weakest_skill_id: data.weakestSkillId || null,
          started_at: new Date().toISOString(),
          completed_at: new Date().toISOString(),
        })
        .select('id')
        .single();

      if (attemptErr || !attemptRow) {
        console.warn('Error inserting placement attempt to Supabase:', attemptErr);
        return this.fallbackRepo.savePlacementAttempt(data);
      }

      const attemptId = attemptRow.id;

      if (data.submissions && data.submissions.length > 0) {
        const answerRows = data.submissions.map((sub) => ({
          attempt_id: attemptId,
          user_id: user.id,
          question_id: sub.questionId,
          selected_index: sub.selectedIndex,
          is_correct: sub.isCorrect,
          created_at: new Date().toISOString(),
        }));

        const { error: answersErr } = await supabase
          .from('placement_answers')
          .insert(answerRows);

        if (answersErr) {
          console.warn('Error inserting placement answers to Supabase:', answersErr);
        }
      }

      return attemptId;
    } catch (err) {
      console.warn('Exception saving placement attempt to Supabase:', err);
      return this.fallbackRepo.savePlacementAttempt(data);
    }
  }

  async markLessonCompleted(lessonId: string): Promise<void> {
    await this.fallbackRepo.markLessonCompleted(lessonId);
    if (!isSupabaseConfigured) return;

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      await supabase.from('lesson_progress').upsert({
        user_id: user.id,
        lesson_id: lessonId,
        course_id: 'course_math_01',
        status: 'completed',
        progress_percent: 100,
        completed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id,lesson_id',
      });
    } catch (err) {
      console.warn('Error marking lesson completed in Supabase:', err);
    }
  }

  async markNodeCompleted(nodeId: string): Promise<void> {
    return this.fallbackRepo.markNodeCompleted(nodeId);
  }

  async markReinforcementCompleted(reinforcementId: string): Promise<void> {
    await this.fallbackRepo.markReinforcementCompleted(reinforcementId);
    if (!isSupabaseConfigured) return;

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      await supabase.from('reinforcement_attempts').upsert({
        user_id: user.id,
        course_id: 'course_math_01',
        skill_id: 'skill_math_functions',
        reinforcement_node_id: reinforcementId,
        before_score: 40,
        after_score: 60,
        is_correct: true,
        xp_awarded: 15,
        created_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id,reinforcement_node_id',
      });
    } catch (err) {
      console.warn('Error marking reinforcement completed in Supabase:', err);
    }
  }

  async recordAnswerAttempt(attempt: Omit<AnswerAttemptRecord, 'id' | 'timestamp'>): Promise<AnswerAttemptRecord> {
    const record = await this.fallbackRepo.recordAnswerAttempt(attempt);
    if (!isSupabaseConfigured) return record;

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return record;

      // Invoke server-side RPC if available
      await supabase.rpc('submit_answer_attempt', {
        p_user_id: user.id,
        p_course_id: attempt.courseId,
        p_skill_id: attempt.skillId,
        p_lesson_id: attempt.lessonId || 'general',
        p_question_id: attempt.questionId,
        p_selected_index: attempt.selectedIndex,
        p_selected_text: attempt.selectedAnswer,
      });
    } catch (err) {
      console.warn('Error recording answer attempt to Supabase, logged locally:', err);
    }

    return record;
  }

  async getAnswerAttempts(limit: number = 10): Promise<AnswerAttemptRecord[]> {
    return this.fallbackRepo.getAnswerAttempts(limit);
  }

  async addXp(amount: number, actionIdempotencyKey?: string): Promise<number> {
    return this.fallbackRepo.addXp(amount, actionIdempotencyKey);
  }

  async recordDailyActivity(dateStr?: string): Promise<number> {
    return this.fallbackRepo.recordDailyActivity(dateStr);
  }

  async resetAll(): Promise<LearnerProfile> {
    return this.fallbackRepo.resetAll();
  }
}

export const supabaseLearnerRepository = new SupabaseLearnerRepository();
