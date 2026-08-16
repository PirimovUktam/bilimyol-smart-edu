import { ILearnerRepository } from '../../domain/repositories/ILearnerRepository';
import { LearnerProfile } from '../../domain/entities/LearnerProfile';
import { SkillScore } from '../../domain/entities/SkillScore';
import { InMemoryLearnerRepository } from './InMemoryLearnerRepository';
import { supabase, isSupabaseConfigured } from '../../core/config/supabase';

export class SupabaseLearnerRepository implements ILearnerRepository {
  private fallbackRepo = new InMemoryLearnerRepository();

  async getProfile(): Promise<LearnerProfile> {
    if (!isSupabaseConfigured) {
      return this.fallbackRepo.getProfile();
    }

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        return this.fallbackRepo.getProfile();
      }

      // Fetch learner profile
      const { data: learnerData } = await supabase
        .from('learner_profiles')
        .select('*')
        .eq('user_id', user.id)
        .single();

      // Fetch gamification profile
      const { data: gamifyData } = await supabase
        .from('gamification_profiles')
        .select('*')
        .eq('user_id', user.id)
        .single();

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

      return {
        id: user.id,
        name: user.user_metadata?.first_name || 'Azizbek',
        selectedCourseId: learnerData?.selected_course_id || 'course_math_01',
        goal: learnerData?.goal || 'mastery',
        dailyMinutes: learnerData?.daily_minutes || 15,
        initialLevel: learnerData?.initial_level || 'intermediate',
        xp: gamifyData?.xp || 120,
        streakDays: gamifyData?.streak_days || 3,
        lastActiveDate: gamifyData?.last_activity_date || new Date().toISOString().split('T')[0],
        scoresByCourse,
        completedLessonIds: (progressRows || []).map((r) => r.lesson_id),
        completedNodeIds: ['node_math_alg', 'node_math_eq'],
        completedReinforcementIds: (reinfRows || []).map((r) => r.reinforcement_node_id),
        createdAt: new Date(learnerData?.created_at || Date.now()).getTime(),
      };
    } catch (err) {
      console.warn('Error fetching Supabase learner profile, using local state:', err);
      return this.fallbackRepo.getProfile();
    }
  }

  async updateProfile(profile: LearnerProfile): Promise<LearnerProfile> {
    if (!isSupabaseConfigured) {
      return this.fallbackRepo.updateProfile(profile);
    }

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        return this.fallbackRepo.updateProfile(profile);
      }

      await supabase.from('learner_profiles').upsert({
        user_id: user.id,
        selected_course_id: profile.selectedCourseId,
        goal: profile.goal,
        daily_minutes: profile.dailyMinutes,
        initial_level: profile.initialLevel,
        updated_at: new Date().toISOString(),
      });

      await supabase.from('gamification_profiles').upsert({
        user_id: user.id,
        xp: profile.xp,
        streak_days: profile.streakDays,
        last_activity_date: profile.lastActiveDate,
        updated_at: new Date().toISOString(),
      });

      return profile;
    } catch (err) {
      console.warn('Error updating Supabase learner profile, updating locally:', err);
      return this.fallbackRepo.updateProfile(profile);
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

  async markLessonCompleted(lessonId: string): Promise<void> {
    if (!isSupabaseConfigured) {
      return this.fallbackRepo.markLessonCompleted(lessonId);
    }

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        return this.fallbackRepo.markLessonCompleted(lessonId);
      }

      await supabase.from('lesson_progress').upsert({
        user_id: user.id,
        lesson_id: lessonId,
        course_id: lessonId.includes('math') ? 'course_math_01' : 'course_eng_01',
        status: 'completed',
        progress_percent: 100,
        completed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id,lesson_id',
      });
    } catch (err) {
      console.warn('Error marking lesson completed in Supabase:', err);
      return this.fallbackRepo.markLessonCompleted(lessonId);
    }
  }

  async markNodeCompleted(nodeId: string): Promise<void> {
    return this.fallbackRepo.markNodeCompleted(nodeId);
  }

  async markReinforcementCompleted(reinforcementId: string): Promise<void> {
    if (!isSupabaseConfigured) {
      return this.fallbackRepo.markReinforcementCompleted(reinforcementId);
    }

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        return this.fallbackRepo.markReinforcementCompleted(reinforcementId);
      }

      await supabase.from('reinforcement_attempts').upsert({
        user_id: user.id,
        course_id: reinforcementId.includes('math') ? 'course_math_01' : 'course_eng_01',
        skill_id: reinforcementId.includes('math') ? 'skill_math_functions' : 'skill_eng_listening',
        reinforcement_node_id: reinforcementId,
        before_score: 41,
        after_score: 63,
        is_correct: true,
        xp_awarded: 30,
        created_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id,reinforcement_node_id',
      });
    } catch (err) {
      console.warn('Error marking reinforcement completed in Supabase:', err);
      return this.fallbackRepo.markReinforcementCompleted(reinforcementId);
    }
  }

  async resetAll(): Promise<LearnerProfile> {
    return this.fallbackRepo.resetAll();
  }
}
