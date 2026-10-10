import { ICourseRepository } from '@/domain/repositories/ICourseRepository';
import { Course } from '@/domain/entities/Course';
import { Skill } from '@/domain/entities/Skill';
import { Question } from '@/domain/entities/Question';
import { inMemoryCourseRepository } from './InMemoryCourseRepository';
import { supabase, isSupabaseConfigured } from '@/core/config/supabase';

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
        .eq('is_active', true)
        .order('title', { ascending: true });

      if (error || !data || data.length === 0) {
        return this.fallback.getAllCourses();
      }

      return data.map((c) => ({
        id: c.id,
        title: c.title,
        subject: (c.id.includes('eng') ? 'english' : 'mathematics') as 'english' | 'mathematics',
        description: c.description || '',
        iconName: c.icon_name || 'BookOpen',
        primaryColor: c.primary_color_hex || '#4F46E5',
        secondaryColor: c.secondary_color_hex || '#818CF8',
        primaryColorHex: c.primary_color_hex || '#4F46E5',
        secondaryColorHex: c.secondary_color_hex || '#818CF8',
        skills: [],
        lessons: [],
        totalStudentsEstimate: c.total_students_estimate || 1000,
        isActive: c.is_active ?? true,
      }));
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

      return {
        id: data.id,
        title: data.title,
        subject: (data.id.includes('eng') ? 'english' : 'mathematics') as 'english' | 'mathematics',
        description: data.description || '',
        iconName: data.icon_name || 'BookOpen',
        primaryColor: data.primary_color_hex || '#4F46E5',
        secondaryColor: data.secondary_color_hex || '#818CF8',
        primaryColorHex: data.primary_color_hex || '#4F46E5',
        secondaryColorHex: data.secondary_color_hex || '#818CF8',
        skills: [],
        lessons: [],
        totalStudentsEstimate: data.total_students_estimate || 1000,
        isActive: data.is_active ?? true,
      };
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
