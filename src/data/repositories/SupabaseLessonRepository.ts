import { ILessonRepository } from '@/domain/repositories/ILessonRepository';
import { Lesson } from '@/domain/entities/Lesson';
import { Question } from '@/domain/entities/Question';
import { LearningPathNode } from '@/domain/entities/LearningPathNode';
import { inMemoryLessonRepository } from './InMemoryLessonRepository';
import { supabase, isSupabaseConfigured } from '@/core/config/supabase';

export class SupabaseLessonRepository implements ILessonRepository {
  private fallback = inMemoryLessonRepository;

  async getLessonById(lessonId: string): Promise<Lesson | null> {
    if (!isSupabaseConfigured) {
      return this.fallback.getLessonById(lessonId);
    }

    try {
      // 1. Check curated lessons table
      const { data: lessonRow } = await supabase
        .from('lessons')
        .select('*')
        .eq('id', lessonId)
        .eq('is_published', true)
        .eq('is_archived', false)
        .maybeSingle();

      if (lessonRow) {
        return {
          id: lessonRow.id,
          courseId: lessonRow.course_id,
          skillId: lessonRow.skill_id,
          title: lessonRow.title,
          estimatedMinutes: lessonRow.estimated_minutes || 15,
          summary: lessonRow.summary || '',
          steps: Array.isArray(lessonRow.steps) ? lessonRow.steps : [],
          reinforcementExercise: lessonRow.reinforcement_exercise || undefined,
        };
      }

      // 2. Check generated_lessons cache table
      const { data: genRow } = await supabase
        .from('generated_lessons')
        .select('*')
        .eq('id', lessonId)
        .maybeSingle();

      if (genRow) {
        const fallbackReinf: Question = {
          id: `q_reinf_${genRow.id}`,
          courseId: genRow.course_id,
          skillId: genRow.skill_id,
          text: 'Mavzuni to‘liq o‘zlashtirdingizmi?',
          options: ['Ha, to‘liq', 'Qisman', 'Yana takrorlash kerak', 'Boshqatdan'],
          difficulty: 'medium',
          explanation: 'Mavzu bo‘yicha mustahkamlash savoli.',
        };
        return {
          id: genRow.id,
          courseId: genRow.course_id,
          skillId: genRow.skill_id,
          title: genRow.title,
          estimatedMinutes: genRow.estimated_minutes || 15,
          summary: genRow.summary || '',
          steps: Array.isArray(genRow.steps) ? genRow.steps : [],
          reinforcementExercise: genRow.reinforcement_exercise || fallbackReinf,
        };
      }

      return this.fallback.getLessonById(lessonId);
    } catch {
      return this.fallback.getLessonById(lessonId);
    }
  }

  async getLessonByCourseAndSkill(courseId: string, skillId: string): Promise<Lesson | null> {
    if (!isSupabaseConfigured) {
      return this.fallback.getLessonByCourseAndSkill(courseId, skillId);
    }

    try {
      const { data, error } = await supabase
        .from('lessons')
        .select('*')
        .eq('course_id', courseId)
        .eq('skill_id', skillId)
        .eq('is_published', true)
        .eq('is_archived', false)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (error || !data) {
        return this.fallback.getLessonByCourseAndSkill(courseId, skillId);
      }

      const fallbackReinf: Question = {
        id: `q_reinf_${data.id}`,
        courseId: data.course_id,
        skillId: data.skill_id,
        text: 'Mavzuni to‘liq o‘zlashtirdingizmi?',
        options: ['Ha, to‘liq', 'Qisman', 'Yana takrorlash kerak', 'Boshqatdan'],
        difficulty: 'medium',
        explanation: 'Mavzu bo‘yicha mustahkamlash savoli.',
      };

      return {
        id: data.id,
        courseId: data.course_id,
        skillId: data.skill_id,
        title: data.title,
        estimatedMinutes: data.estimated_minutes || 15,
        summary: data.summary || '',
        steps: Array.isArray(data.steps) ? data.steps : [],
        reinforcementExercise: data.reinforcement_exercise || fallbackReinf,
      };
    } catch {
      return this.fallback.getLessonByCourseAndSkill(courseId, skillId);
    }
  }

  async getBaseRoadmapNodes(courseId: string): Promise<LearningPathNode[]> {
    if (!isSupabaseConfigured) {
      return this.fallback.getBaseRoadmapNodes(courseId);
    }

    try {
      const { data, error } = await supabase
        .from('roadmap_nodes')
        .select('*')
        .eq('course_id', courseId)
        .eq('is_active', true)
        .order('order_index', { ascending: true });

      if (error || !data || data.length === 0) {
        return this.fallback.getBaseRoadmapNodes(courseId);
      }

      return data.map((n) => ({
        id: n.id,
        courseId: n.course_id,
        skillId: n.skill_id,
        title: n.title,
        description: n.description || '',
        prerequisites: Array.isArray(n.prerequisites) ? n.prerequisites : [],
        requiredScore: n.required_score ?? 50,
        isReinforcement: n.is_reinforcement ?? false,
        targetLessonId: n.target_lesson_id || undefined,
        estimatedMinutes: n.estimated_minutes ?? 15,
        order: Number(n.order_index ?? 0),
        orderIndex: Number(n.order_index ?? 0),
        status: 'locked' as const,
      }));
    } catch {
      return this.fallback.getBaseRoadmapNodes(courseId);
    }
  }

  async saveLesson(lesson: Lesson): Promise<void> {
    await this.fallback.saveLesson(lesson);

    if (isSupabaseConfigured) {
      try {
        await supabase.from('generated_lessons').upsert({
          id: lesson.id,
          course_id: lesson.courseId,
          skill_id: lesson.skillId,
          title: lesson.title,
          summary: lesson.summary,
          estimated_minutes: lesson.estimatedMinutes,
          steps: lesson.steps,
          reinforcement_exercise: lesson.reinforcementExercise,
        });
      } catch (err) {
        console.warn('[SupabaseLessonRepository] Failed to persist generated lesson to remote:', err);
      }
    }
  }
}

export const supabaseLessonRepository = new SupabaseLessonRepository();
