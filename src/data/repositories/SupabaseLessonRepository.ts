import { ILessonRepository } from '@/domain/repositories/ILessonRepository';
import { Lesson } from '@/domain/entities/Lesson';
import { Question } from '@/domain/entities/Question';
import { LearningPathNode } from '@/domain/entities/LearningPathNode';
import { inMemoryLessonRepository } from './InMemoryLessonRepository';
import { supabase, isSupabaseConfigured } from '@/core/config/supabase';

const sanitizeQuestion = (raw: any, courseId: string, skillId: string): Question => ({
  id: raw.id,
  courseId,
  skillId,
  text: raw.text,
  contextSnippet: raw.contextSnippet || raw.context_snippet || undefined,
  formulaLatex: raw.formulaLatex || raw.formula_latex || undefined,
  audioSimText: raw.audioSimText || raw.audio_sim_text || undefined,
  audioSimSpeaker: raw.audioSimSpeaker || raw.audio_sim_speaker || undefined,
  options: Array.isArray(raw.options) ? raw.options : [],
  difficulty: raw.difficulty || 'medium',
  explanation: '',
});

const sanitizeSteps = (steps: unknown, courseId: string, skillId: string, fallbackQuestion?: Question): Lesson['steps'] => {
  if (!Array.isArray(steps)) return [];
  return steps.map((step: any, index) => {
    const rawQuestion = step.interactiveQuestion || step.interactive_question;
    return {
      id: step.id,
      stepNumber: step.stepNumber ?? step.step_number ?? index + 1,
      type: step.type,
      title: step.title,
      subtitle: step.subtitle,
      content: step.content,
      highlightNotes: step.highlightNotes || step.highlight_notes,
      formulaData: step.formulaData || step.formula_data,
      visualModelData: step.visualModelData || step.visual_model_data,
      interactiveQuestion: rawQuestion
        ? sanitizeQuestion(rawQuestion, courseId, skillId)
        : (step.type === 'interactive_question' || index === steps.length - 1) ? fallbackQuestion : undefined,
    };
  });
};

/** Maps safe views without inventing unscorable synthetic question ids. */
export function mapLearnerLesson(row: any): Lesson {
  const firstQuestion = Array.isArray(row.questions) && row.questions.length > 0
    ? sanitizeQuestion(row.questions[0], row.course_id, row.skill_id) : undefined;
  const steps = sanitizeSteps(row.steps, row.course_id, row.skill_id, firstQuestion);
  const reinforcementExercise = row.reinforcement_exercise
    ? sanitizeQuestion(row.reinforcement_exercise, row.course_id, row.skill_id)
    : firstQuestion || steps.find((step) => step.interactiveQuestion)?.interactiveQuestion;
  if (!reinforcementExercise?.id || reinforcementExercise.options.length < 2) {
    throw new Error('Darsning serverda baholanadigan savoli topilmadi.');
  }
  return {
    id: row.id,
    courseId: row.course_id,
    skillId: row.skill_id,
    title: row.title,
    estimatedMinutes: row.estimated_minutes || 15,
    summary: row.summary || '',
    steps,
    reinforcementExercise,
    isAiGenerated: Boolean(row.generation_model && row.generation_model !== 'deterministic-fallback'),
    isDeterministicFallback: row.generation_model === 'deterministic-fallback',
  };
}

export class SupabaseLessonRepository implements ILessonRepository {
  private fallback = inMemoryLessonRepository;

  private async requireAuthenticatedUser(): Promise<void> {
    const { data, error } = await supabase.auth.getUser();
    if (error) throw error;
    if (!data.user) throw new Error('Autentifikatsiyadan o‘tilmagan.');
  }

  async getLessonById(lessonId: string): Promise<Lesson | null> {
    if (!isSupabaseConfigured) {
      return this.fallback.getLessonById(lessonId);
    }

    try {
      await this.requireAuthenticatedUser();
      // 1. Check the learner-safe curated lesson view. The raw lessons table
      // contains answer keys in JSONB and is never queried by learners.
      const { data: lessonRow, error: lessonError } = await supabase
        .from('learner_lessons')
        .select('*')
        .eq('id', lessonId)
        .maybeSingle();
      if (lessonError) throw lessonError;

      if (lessonRow) {
        return mapLearnerLesson(lessonRow);
      }

      // 2. Check generated_lessons cache table
      const { data: genRow, error: generatedError } = await supabase
        .from('learner_generated_lessons')
        .select('*')
        .eq('id', lessonId)
        .maybeSingle();
      if (generatedError) throw generatedError;

      if (genRow) {
        return mapLearnerLesson(genRow);
      }

      return null;
    } catch (error) {
      console.warn('Error fetching Supabase lesson:', error);
      throw error;
    }
  }

  async getLessonByCourseAndSkill(courseId: string, skillId: string): Promise<Lesson | null> {
    if (!isSupabaseConfigured) {
      return this.fallback.getLessonByCourseAndSkill(courseId, skillId);
    }

    try {
      await this.requireAuthenticatedUser();
      const { data, error } = await supabase
        .from('learner_lessons')
        .select('*')
        .eq('course_id', courseId)
        .eq('skill_id', skillId)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (error) throw error;
      if (!data) return null;

      return mapLearnerLesson(data);
    } catch (error) {
      console.warn('Error fetching Supabase lesson by course and skill:', error);
      throw error;
    }
  }

  async getBaseRoadmapNodes(courseId: string): Promise<LearningPathNode[]> {
    if (!isSupabaseConfigured) {
      return this.fallback.getBaseRoadmapNodes(courseId);
    }

    try {
      await this.requireAuthenticatedUser();
      const { data, error } = await supabase
        .from('roadmap_nodes')
        .select('*')
        .eq('course_id', courseId)
        .eq('is_active', true)
        .order('order_index', { ascending: true });

      if (error) throw error;
      if (!data) return [];

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
    } catch (error) {
      console.warn('Error fetching Supabase roadmap nodes:', error);
      throw error;
    }
  }

  async saveLesson(lesson: Lesson): Promise<void> {
    // Local cache only. Persisting AI-generated lessons to the global
    // `generated_lessons` table is exclusively the Edge Function's
    // responsibility (service_role) — clients must never write the shared
    // cache, otherwise one learner could poison content for everyone.
    await this.fallback.saveLesson(lesson);
  }
}

export const supabaseLessonRepository = new SupabaseLessonRepository();
