import { ICourseRepository } from '@/domain/repositories/ICourseRepository';
import { Course } from '@/domain/entities/Course';
import { Skill } from '@/domain/entities/Skill';
import { Question } from '@/domain/entities/Question';
import { SubjectType } from '@/core/types/common';
import { isDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { supabase, isSupabaseConfigured } from '@/core/config/supabase';

const normalizeSubjectValue = (value: string): SubjectType | null => {
  const v = value.trim().toLowerCase();
  if (['mathematics', 'math', 'matematika'].includes(v)) return 'mathematics';
  if (['english', 'ingliz', 'ingliz tili'].includes(v)) return 'english';
  if (['it', 'code', 'programming', 'dasturlash'].includes(v)) return 'it';
  if (['logic', 'mantiq', 'mantiqiy', 'mantiqiy fikrlash'].includes(v)) return 'logic';
  return null;
};

/**
 * Resolves a course subject from the DB `subject` column first (source of
 * truth), only falling back to id-based inference for legacy rows.
 * Never assumes "not english ⇒ mathematics" — that mislabeled IT/logic rows.
 */
export function mapCourseSubject(row: { id: string; subject?: string | null }): SubjectType {
  if (row.subject) {
    const normalized = normalizeSubjectValue(row.subject);
    if (normalized) return normalized;
  }
  const id = row.id.toLowerCase();
  if (id.includes('eng')) return 'english';
  if (id.includes('logic') || id.includes('mantiq')) return 'logic';
  if (id.includes('it') || id.includes('code') || id.includes('program')) return 'it';
  if (id.includes('math')) return 'mathematics';
  return 'other';
}

/**
 * Course rows describe subjects. Published lesson metadata is read separately
 * from the learner-safe view.
 */
export const mapCourseRow = (c: Record<string, unknown>): Course => ({
  id: c.id as string,
  title: c.title as string,
  subject: mapCourseSubject({ id: c.id as string, subject: (c.subject as string | null) ?? null }),
  description: (c.description as string) || '',
  iconName: (c.icon_name as string) || 'BookOpen',
  primaryColor: (c.primary_color_hex as string) || '#4F46E5',
  secondaryColor: (c.secondary_color_hex as string) || '#818CF8',
  primaryColorHex: (c.primary_color_hex as string) || '#4F46E5',
  secondaryColorHex: (c.secondary_color_hex as string) || '#818CF8',
  skills: [],
  lessons: [],
  starterLessonId: typeof c.starter_lesson_id === 'string' ? c.starter_lesson_id : undefined,
  foundationLessonIds: Array.isArray(c.foundation_lesson_ids)
    ? c.foundation_lesson_ids.filter((id): id is string => typeof id === 'string')
    : undefined,
  totalStudentsEstimate: (c.total_students_estimate as number) || 1000,
  isActive: (c.is_active as boolean | undefined) ?? true,
});

export class SupabaseCourseRepository implements ICourseRepository {
  private async demoRepository() {
    return (await import('./InMemoryCourseRepository')).inMemoryCourseRepository;
  }

  private async requireAuthenticatedUser(): Promise<void> {
    const { data, error } = await supabase.auth.getUser();
    if (error) throw error;
    if (!data.user) throw new Error('Autentifikatsiyadan o‘tilmagan.');
  }

  async getAllCourses(): Promise<Course[]> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return (await this.demoRepository()).getAllCourses();
    }

    try {
      await this.requireAuthenticatedUser();
      const [courses, lessons] = await Promise.all([
        supabase.from('courses').select('*').eq('is_active', true).order('title'),
        supabase.from('learner_lessons').select('id, course_id').order('id'),
      ]);
      if (courses.error || lessons.error) throw courses.error ?? lessons.error;
      const byCourse = new Map<string, string[]>();
      for (const lesson of lessons.data ?? []) {
        const ids = byCourse.get(lesson.course_id) ?? [];
        ids.push(lesson.id);
        byCourse.set(lesson.course_id, ids);
      }
      return (courses.data ?? []).map((row) => {
        const course = mapCourseRow(row);
        const published = byCourse.get(course.id) ?? [];
        return {
          ...course,
          lessons: published,
          starterLessonId: course.starterLessonId && published.includes(course.starterLessonId) ? course.starterLessonId : undefined,
          foundationLessonIds: course.foundationLessonIds?.filter((id) => published.includes(id)),
        };
      });
    } catch (error) {
      console.warn('Error fetching Supabase courses:', error);
      throw error;
    }
  }

  async getCourseById(courseId: string): Promise<Course | null> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return (await this.demoRepository()).getCourseById(courseId);
    }

    try {
      await this.requireAuthenticatedUser();
      const { data, error } = await supabase
        .from('courses')
        .select('*')
        .eq('id', courseId)
        .maybeSingle();

      if (error) throw error;
      if (!data) return null;

      return mapCourseRow(data);
    } catch (error) {
      console.warn(`Error fetching Supabase course "${courseId}":`, error);
      throw error;
    }
  }

  async getSkillsByCourseId(courseId: string): Promise<Skill[]> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return (await this.demoRepository()).getSkillsByCourseId(courseId);
    }

    try {
      await this.requireAuthenticatedUser();
      const { data, error } = await supabase
        .from('skills')
        .select('*')
        .eq('course_id', courseId)
        .order('order_index', { ascending: true });

      if (error) throw error;
      if (!data) return [];

      return data.map((s) => ({
        id: s.id,
        courseId: s.course_id,
        name: s.name,
        code: s.code,
        description: s.description || '',
        order: s.order_index ?? 0,
        orderIndex: s.order_index,
        iconName: s.icon_name || 'Target',
      }));
    } catch (error) {
      console.warn(`Error fetching Supabase skills for course "${courseId}":`, error);
      throw error;
    }
  }

  async getPlacementQuestions(courseId: string): Promise<Question[]> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return (await this.demoRepository()).getPlacementQuestions(courseId);
    }

    try {
      // Placement content is read only from the learner-safe view. In a
      // configured deployment an auth/query failure is an error, never a
      // fallback to seed questions containing answer keys.
      await this.requireAuthenticatedUser();
      const { data, error } = await supabase
        .from('learner_questions')
        .select('id, course_id, skill_id, text, context_snippet, options, difficulty, formula_latex, audio_sim_text, audio_sim_speaker')
        .eq('course_id', courseId)
        .eq('is_placement', true);

      if (error) throw error;
      if (!data) return [];

      return data.map((q) => ({
        id: q.id,
        courseId: q.course_id,
        skillId: q.skill_id,
        text: q.text,
        contextSnippet: q.context_snippet || undefined,
        options: Array.isArray(q.options) ? q.options : [],
        // The answer key is intentionally not exposed to the learner client.
        correctIndex: undefined,
        difficulty: q.difficulty || 'medium',
        explanation: '',
        formulaLatex: q.formula_latex || undefined,
        audioSimText: q.audio_sim_text || undefined,
        audioSimSpeaker: q.audio_sim_speaker || undefined,
      }));
    } catch (error) {
      console.warn(`Error fetching Supabase placement questions for course "${courseId}":`, error);
      throw error;
    }
  }
}

export const supabaseCourseRepository = new SupabaseCourseRepository();
