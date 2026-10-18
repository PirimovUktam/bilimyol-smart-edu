import { ICourseRepository } from '@/domain/repositories/ICourseRepository';
import { Course } from '@/domain/entities/Course';
import { Skill } from '@/domain/entities/Skill';
import { Question } from '@/domain/entities/Question';
import { SubjectType } from '@/core/types/common';
import { isDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { inMemoryCourseRepository } from './InMemoryCourseRepository';
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
 * Course rows are catalog metadata. Lesson ids are deliberately not inferred
 * here: the roadmap/lesson repositories are the source of truth for content,
 * so a Supabase course with no lesson relation stays an honest empty course.
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
  totalStudentsEstimate: (c.total_students_estimate as number) || 1000,
  isActive: (c.is_active as boolean | undefined) ?? true,
});

export class SupabaseCourseRepository implements ICourseRepository {
  private fallback = inMemoryCourseRepository;

  private async requireAuthenticatedUser(): Promise<void> {
    const { data, error } = await supabase.auth.getUser();
    if (error) throw error;
    if (!data.user) throw new Error('Autentifikatsiyadan o‘tilmagan.');
  }

  async getAllCourses(): Promise<Course[]> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return this.fallback.getAllCourses();
    }

    try {
      await this.requireAuthenticatedUser();
      const { data, error } = await supabase
        .from('courses')
        .select('*')
        .order('title', { ascending: true });

      if (error) throw error;
      if (!data) return [];

      const activeRows = data.filter((c) => c.is_active !== false);
      const mapped = activeRows.map(mapCourseRow);

      return mapped;
    } catch (error) {
      console.warn('Error fetching Supabase courses:', error);
      throw error;
    }
  }

  async getCourseById(courseId: string): Promise<Course | null> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return this.fallback.getCourseById(courseId);
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
      return this.fallback.getSkillsByCourseId(courseId);
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
      return this.fallback.getPlacementQuestions(courseId);
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
