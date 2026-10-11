import { ICourseRepository } from '@/domain/repositories/ICourseRepository';
import { Course } from '@/domain/entities/Course';
import { Skill } from '@/domain/entities/Skill';
import { Question } from '@/domain/entities/Question';
import { SubjectType } from '@/core/types/common';
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
  return 'mathematics';
}

const mapCourseRow = (c: Record<string, unknown>): Course => ({
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

  async getAllCourses(): Promise<Course[]> {
    if (!isSupabaseConfigured) {
      return this.fallback.getAllCourses();
    }

    try {
      const { data, error } = await supabase
        .from('courses')
        .select('*')
        .order('title', { ascending: true });

      if (error || !data || data.length === 0) {
        return this.fallback.getAllCourses();
      }

      const activeRows = data.filter((c) => c.is_active !== false);
      const mapped = activeRows.map(mapCourseRow);

      // Add seed courses (IT / logic) that have NO row at all yet, so pills
      // and flows stay consistent. A course that exists but was deliberately
      // deactivated by an admin is never re-added from the seed.
      const seedCourses = await this.fallback.getAllCourses();
      const missingSeeds = seedCourses.filter((seed) => !data.some((row) => row.id === seed.id));

      return [...mapped, ...missingSeeds];
    } catch {
      return this.fallback.getAllCourses();
    }
  }

  async getCourseById(courseId: string): Promise<Course | null> {
    if (!isSupabaseConfigured) {
      return this.fallback.getCourseById(courseId);
    }

    try {
      const { data, error } = await supabase
        .from('courses')
        .select('*')
        .eq('id', courseId)
        .maybeSingle();

      if (error || !data) {
        return this.fallback.getCourseById(courseId);
      }

      return mapCourseRow(data);
    } catch {
      return this.fallback.getCourseById(courseId);
    }
  }

  async getSkillsByCourseId(courseId: string): Promise<Skill[]> {
    if (!isSupabaseConfigured) {
      return this.fallback.getSkillsByCourseId(courseId);
    }

    try {
      const { data, error } = await supabase
        .from('skills')
        .select('*')
        .eq('course_id', courseId)
        .order('order_index', { ascending: true });

      if (error || !data || data.length === 0) {
        return this.fallback.getSkillsByCourseId(courseId);
      }

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
    } catch {
      return this.fallback.getSkillsByCourseId(courseId);
    }
  }

  async getPlacementQuestions(courseId: string): Promise<Question[]> {
    if (!isSupabaseConfigured) {
      return this.fallback.getPlacementQuestions(courseId);
    }

    try {
      const { data, error } = await supabase
        .from('questions')
        .select('*')
        .eq('course_id', courseId)
        .eq('is_placement', true);

      if (error || !data || data.length === 0) {
        return this.fallback.getPlacementQuestions(courseId);
      }

      return data.map((q) => ({
        id: q.id,
        courseId: q.course_id,
        skillId: q.skill_id,
        text: q.text,
        contextSnippet: q.context_snippet || undefined,
        options: Array.isArray(q.options) ? q.options : [],
        correctIndex: q.correct_index,
        difficulty: q.difficulty || 'medium',
        explanation: q.explanation || '',
        formulaLatex: q.formula_latex || undefined,
        audioSimText: q.audio_sim_text || undefined,
        audioSimSpeaker: q.audio_sim_speaker || undefined,
      }));
    } catch {
      return this.fallback.getPlacementQuestions(courseId);
    }
  }
}

export const supabaseCourseRepository = new SupabaseCourseRepository();
