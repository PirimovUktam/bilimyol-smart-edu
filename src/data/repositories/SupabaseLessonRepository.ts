import { ILessonRepository } from '@/domain/repositories/ILessonRepository';
import { Lesson, LessonFlashcard } from '@/domain/entities/Lesson';
import {
  isSafeLessonAudioSource,
  isSafeLessonImageSource,
  readApprovedLessonMedia,
} from '@/domain/entities/LessonMedia';
import { Question, QuestionType } from '@/domain/entities/Question';
import { LearningPathNode } from '@/domain/entities/LearningPathNode';
import { isDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { supabase, isSupabaseConfigured } from '@/core/config/supabase';
import { updatedUzbekSpelling, updatedCourseText } from '@/core/locales/uzbekAlphabet';
import { LocalizedError } from '@/core/locales/LocalizedError';
import { MATH_MASTERY_COURSE } from '@/domain/personalization/learningStart';
import { inMemoryLessonRepository } from './InMemoryLessonRepository';

interface MathProgressionRow {
  id: string;
  course_id: string;
  skill_id: string;
  title: string;
  description: string;
  prerequisites: string[];
  required_score: number;
  target_lesson_id: string;
  estimated_minutes: number;
  order_index: number;
  status: LearningPathNode['status'];
  mastery_state: NonNullable<LearningPathNode['mastery']>['state'];
  answered: number;
  correct: number;
  required_items: number;
  passed_checkpoints: number;
  required_checkpoints: number;
  review_due: boolean;
  is_optional: boolean;
}

const ALLOWED_QUESTION_TYPES = new Set<QuestionType>([
  'multiple_choice',
  'text_input',
  'fill_blank',
  'word_match',
  'sentence_order',
  'error_correction',
  'conversation_completion',
  'speaking_prompt',
  'writing_prompt',
]);

const normalizeQuestionType = (rawType: unknown): QuestionType | undefined =>
  typeof rawType === 'string' && ALLOWED_QUESTION_TYPES.has(rawType as QuestionType)
    ? (rawType as QuestionType)
    : undefined;

const sanitizeQuestion = (raw: any, courseId: string, skillId: string): Question => {
  const questionType = normalizeQuestionType(raw.questionType || raw.question_type);
  const evaluationMode =
    (raw.evaluationMode || raw.evaluation_mode) === 'self_assessed' ||
    questionType === 'speaking_prompt' ||
    questionType === 'writing_prompt'
      ? 'self_assessed'
      : (raw.evaluationMode || raw.evaluation_mode) === 'deterministic'
      ? 'deterministic'
      : undefined;
  const media = readApprovedLessonMedia(raw.media);
  const matchPairs = Array.isArray(raw.matchPairs || raw.match_pairs)
    ? (raw.matchPairs || raw.match_pairs).filter(
        (pair: any) => pair && typeof pair.id === 'string' && typeof pair.left === 'string' && typeof pair.right === 'string'
      )
    : undefined;
  const orderedTokens = Array.isArray(raw.orderedTokens || raw.ordered_tokens)
    ? (raw.orderedTokens || raw.ordered_tokens).filter((token: unknown): token is string => typeof token === 'string')
    : undefined;
  const rubricCriteria = Array.isArray(raw.rubricCriteria || raw.rubric_criteria)
    ? (raw.rubricCriteria || raw.rubric_criteria).filter(
        (crit: any) => crit && typeof crit.id === 'string' && typeof crit.labelUz === 'string' && typeof crit.labelRu === 'string'
      )
    : undefined;
  const dialogueContext = Array.isArray(raw.dialogueContext || raw.dialogue_context)
    ? (raw.dialogueContext || raw.dialogue_context).filter((line: unknown): line is string => typeof line === 'string')
    : undefined;

  return {
    id: raw.id,
    courseId,
    skillId,
    ...(typeof (raw.skillDomain || raw.skill_domain) === 'string'
      ? { skillDomain: raw.skillDomain || raw.skill_domain }
      : {}),
    ...(typeof (raw.cefrLevel || raw.cefr_level) === 'string'
      ? { cefrLevel: raw.cefrLevel || raw.cefr_level }
      : {}),
    ...(typeof raw.topic === 'string' ? { topic: raw.topic } : {}),
    text: updatedCourseText(raw.text, courseId),
    ...(typeof (raw.textRu || raw.text_ru) === 'string' ? { textRu: raw.textRu || raw.text_ru } : {}),
    contextSnippet: raw.contextSnippet || raw.context_snippet || undefined,
    questionType,
    ...(evaluationMode ? { evaluationMode } : {}),
    formulaLatex: raw.formulaLatex || raw.formula_latex || undefined,
    audioSimText: raw.audioSimText || raw.audio_sim_text || undefined,
    audioSimSpeaker: raw.audioSimSpeaker || raw.audio_sim_speaker || undefined,
    options: Array.isArray(raw.options) ? raw.options.map((text: string) => updatedCourseText(text, courseId)) : [],
    ...(typeof (raw.blankTemplate || raw.blank_template) === 'string'
      ? { blankTemplate: raw.blankTemplate || raw.blank_template }
      : {}),
    ...(typeof (raw.sentenceWithError || raw.sentence_with_error) === 'string'
      ? { sentenceWithError: raw.sentenceWithError || raw.sentence_with_error }
      : {}),
    ...(dialogueContext && dialogueContext.length > 0 ? { dialogueContext } : {}),
    ...(matchPairs && matchPairs.length > 0 ? { matchPairs } : {}),
    ...(orderedTokens && orderedTokens.length > 0 ? { orderedTokens } : {}),
    ...(typeof (raw.sampleResponse || raw.sample_response) === 'string'
      ? { sampleResponse: raw.sampleResponse || raw.sample_response }
      : {}),
    ...(rubricCriteria && rubricCriteria.length > 0 ? { rubricCriteria } : {}),
    ...(typeof (raw.selfAssessmentNoticeUz || raw.self_assessment_notice_uz) === 'string'
      ? { selfAssessmentNoticeUz: raw.selfAssessmentNoticeUz || raw.self_assessment_notice_uz }
      : {}),
    ...(typeof (raw.selfAssessmentNoticeRu || raw.self_assessment_notice_ru) === 'string'
      ? { selfAssessmentNoticeRu: raw.selfAssessmentNoticeRu || raw.self_assessment_notice_ru }
      : {}),
    difficulty: raw.difficulty || 'medium',
    explanation: '',
    wrongFeedback: typeof (raw.wrongFeedback || raw.wrong_feedback) === 'string'
      ? updatedCourseText(raw.wrongFeedback || raw.wrong_feedback, courseId)
      : undefined,
    wrongFeedbackRu: typeof (raw.wrongFeedbackRu || raw.wrong_feedback_ru) === 'string'
      ? (raw.wrongFeedbackRu || raw.wrong_feedback_ru)
      : undefined,
    ...(media ? { media } : {}),
  };
};

const isValidReinforcementShape = (q: Question | undefined): q is Question => {
  if (!q?.id) return false;
  const qType = q.questionType ?? 'multiple_choice';
  if (qType === 'text_input' || qType === 'fill_blank') return true;
  if (qType === 'word_match') return Array.isArray(q.matchPairs) && q.matchPairs.length >= 2;
  if (qType === 'sentence_order') return Array.isArray(q.orderedTokens) && q.orderedTokens.length >= 2;
  if (qType === 'speaking_prompt' || qType === 'writing_prompt') {
    return typeof q.sampleResponse === 'string' && q.sampleResponse.trim().length > 0;
  }
  return Array.isArray(q.options) && q.options.length >= 2;
};

const sanitizeFlashcards = (raw: unknown): LessonFlashcard[] | undefined => {
  if (!Array.isArray(raw)) return undefined;
  const valid: LessonFlashcard[] = [];
  for (const item of raw) {
    if (
      !item ||
      typeof item !== 'object' ||
      typeof (item as LessonFlashcard).id !== 'string' ||
      typeof (item as LessonFlashcard).front !== 'string' ||
      typeof (item as LessonFlashcard).backUz !== 'string' ||
      typeof (item as LessonFlashcard).backRu !== 'string' ||
      typeof (item as LessonFlashcard).example !== 'string' ||
      typeof (item as LessonFlashcard).exampleUz !== 'string' ||
      typeof (item as LessonFlashcard).exampleRu !== 'string'
    ) {
      continue;
    }
    const card = item as LessonFlashcard;
    const audioSrc = isSafeLessonAudioSource(card.audioSrc) ? card.audioSrc : undefined;
    const imageSrc = isSafeLessonImageSource(card.imageSrc) ? card.imageSrc : undefined;
    valid.push({
      id: card.id,
      front: card.front,
      backUz: updatedUzbekSpelling(card.backUz),
      backRu: card.backRu,
      ...(typeof card.ipa === 'string' ? { ipa: card.ipa } : {}),
      ...(typeof card.ipaAmE === 'string' ? { ipaAmE: card.ipaAmE } : {}),
      ...(typeof card.partOfSpeech === 'string' ? { partOfSpeech: card.partOfSpeech } : {}),
      ...(typeof card.cefrLevel === 'string' ? { cefrLevel: card.cefrLevel } : {}),
      example: card.example,
      exampleUz: updatedUzbekSpelling(card.exampleUz),
      exampleRu: card.exampleRu,
      ...(audioSrc ? { audioSrc } : {}),
      ...(imageSrc ? { imageSrc } : {}),
      ...(imageSrc && typeof card.alt === 'string' && card.alt.trim()
        ? { alt: card.alt.trim() }
        : {}),
      ...(imageSrc && typeof card.altRu === 'string' && card.altRu.trim()
        ? { altRu: card.altRu.trim() }
        : {}),
      ...(card.srsDefaults ? { srsDefaults: card.srsDefaults } : {}),
    });
  }
  return valid.length > 0 ? valid : undefined;
};

const sanitizeSteps = (steps: unknown, courseId: string, skillId: string, fallbackQuestion?: Question): Lesson['steps'] => {
  if (!Array.isArray(steps)) return [];
  return steps.map((step: any, index) => {
    const rawQuestion = step.interactiveQuestion || step.interactive_question;
    return {
      id: step.id,
      stepNumber: step.stepNumber ?? step.step_number ?? index + 1,
      type: step.type,
      title: updatedCourseText(step.title, courseId),
      ...(typeof (step.titleRu || step.title_ru) === 'string' ? { titleRu: step.titleRu || step.title_ru } : {}),
      subtitle: step.subtitle && updatedCourseText(step.subtitle, courseId),
      ...(typeof (step.subtitleRu || step.subtitle_ru) === 'string' ? { subtitleRu: step.subtitleRu || step.subtitle_ru } : {}),
      content: step.content && updatedCourseText(step.content, courseId),
      ...(typeof (step.contentRu || step.content_ru) === 'string' ? { contentRu: step.contentRu || step.content_ru } : {}),
      highlightNotes: (step.highlightNotes || step.highlight_notes)?.map((text: string) => updatedCourseText(text, courseId)),
      ...(Array.isArray(step.highlightNotesRu || step.highlight_notes_ru)
        ? { highlightNotesRu: step.highlightNotesRu || step.highlight_notes_ru }
        : {}),
      formulaData: step.formulaData || step.formula_data,
      visualModelData: step.visualModelData || step.visual_model_data,
      flashcards: sanitizeFlashcards(step.flashcards),
      masteryCheckpoint: step.masteryCheckpoint === 'application' || step.masteryCheckpoint === 'retrieval'
        ? step.masteryCheckpoint : undefined,
      media: readApprovedLessonMedia(step.media),
      interactiveQuestion: rawQuestion
        ? sanitizeQuestion(rawQuestion, courseId, skillId)
        : (step.type === 'interactive_question' || index === steps.length - 1) ? fallbackQuestion : undefined,
    };
  });
};

/** Maps safe views without inventing unscorable synthetic question ids. */
export function mapLearnerLesson(row: any): Lesson {
  if (row.is_locked === true) throw new LocalizedError('lesson.prerequisites');
  const firstQuestion = Array.isArray(row.questions) && row.questions.length > 0
    ? sanitizeQuestion(row.questions[0], row.course_id, row.skill_id) : undefined;
  const steps = sanitizeSteps(row.steps, row.course_id, row.skill_id, firstQuestion);
  const rawReinf = row.reinforcement_exercise || row.reinforcementExercise;
  const reinforcementExercise = rawReinf
    ? sanitizeQuestion(rawReinf, row.course_id, row.skill_id)
    : firstQuestion || steps.find((step) => step.interactiveQuestion)?.interactiveQuestion;
  if (!isValidReinforcementShape(reinforcementExercise)) {
    throw new Error('Darsning serverda baholanadigan savoli topilmadi.');
  }
  const rawAlt = row.alternate_exercise || row.alternateExercise;
  const alternateExercise = rawAlt ? sanitizeQuestion(rawAlt, row.course_id, row.skill_id) : undefined;
  return {
    id: row.id,
    courseId: row.course_id,
    skillId: row.skill_id,
    ...(typeof (row.skill_domain || row.skillDomain) === 'string' ? { skillDomain: row.skill_domain || row.skillDomain } : {}),
    ...(typeof (row.communicative_focus || row.communicativeFocus) === 'string'
      ? { communicativeFocus: row.communicative_focus || row.communicativeFocus }
      : {}),
    ...(typeof (row.cefr_level || row.cefrLevel) === 'string' ? { cefrLevel: row.cefr_level || row.cefrLevel } : {}),
    ...(typeof (row.module_id || row.moduleId) === 'string' ? { moduleId: row.module_id || row.moduleId } : {}),
    ...(typeof (row.unit_id || row.unitId) === 'string' ? { unitId: row.unit_id || row.unitId } : {}),
    ...(typeof (row.can_do_objective || row.canDoObjective) === 'string'
      ? { canDoObjective: row.can_do_objective || row.canDoObjective }
      : {}),
    ...(typeof (row.can_do_objective_ru || row.canDoObjectiveRu) === 'string'
      ? { canDoObjectiveRu: row.can_do_objective_ru || row.canDoObjectiveRu }
      : {}),
    ...(Array.isArray(row.prerequisites) ? { prerequisites: row.prerequisites } : {}),
    title: updatedUzbekSpelling(row.title),
    ...(typeof (row.title_ru || row.titleRu) === 'string' ? { titleRu: row.title_ru || row.titleRu } : {}),
    estimatedMinutes: row.estimated_minutes || 15,
    summary: updatedCourseText(row.summary || '', row.course_id),
    ...(typeof (row.summary_ru || row.summaryRu) === 'string' ? { summaryRu: row.summary_ru || row.summaryRu } : {}),
    steps,
    requiresMastery: steps.some((step) => step.masteryCheckpoint),
    reinforcementExercise,
    ...(alternateExercise ? { alternateExercise } : {}),
    isAiGenerated: Boolean(row.generation_model && row.generation_model !== 'deterministic-fallback'),
    isDeterministicFallback: row.generation_model === 'deterministic-fallback',
  };
}

export class SupabaseLessonRepository implements ILessonRepository {
  private async demoRepository() {
    return inMemoryLessonRepository;
  }

  private async requireAuthenticatedUser(): Promise<void> {
    const { data, error } = await supabase.auth.getUser();
    if (error) throw error;
    if (!data.user) throw new Error('Autentifikatsiyadan ötilmagan.');
  }

  getCachedDemoLessonSync(lessonId: string): Lesson | null {
    if (!isDemoRuntimeActive() && isSupabaseConfigured) {
      return null;
    }
    return inMemoryLessonRepository.getLessonByIdSync(lessonId);
  }

  async getLessonById(lessonId: string): Promise<Lesson | null> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return (await this.demoRepository()).getLessonById(lessonId);
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
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return (await this.demoRepository()).getLessonByCourseAndSkill(courseId, skillId);
    }

    try {
      await this.requireAuthenticatedUser();
      const query = supabase
        .from('learner_lessons')
        .select('*')
        .eq('course_id', courseId)
        .eq('skill_id', skillId);
      if (courseId === MATH_MASTERY_COURSE) query.eq('is_locked', false);
      const { data, error } = await query
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
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return (await this.demoRepository()).getBaseRoadmapNodes(courseId);
    }

    try {
      await this.requireAuthenticatedUser();
      if (courseId === MATH_MASTERY_COURSE) {
        const { data, error } = await supabase.rpc('get_math_progression');
        if (error) throw error;
        if (!Array.isArray(data) || !data.length) throw new LocalizedError('path.failed');
        return (data as MathProgressionRow[]).map((n) => ({
          id: n.id, courseId: n.course_id, skillId: n.skill_id, title: updatedUzbekSpelling(n.title),
          description: updatedUzbekSpelling(n.description), prerequisites: n.prerequisites, requiredScore: n.required_score,
          targetLessonId: n.target_lesson_id, estimatedMinutes: n.estimated_minutes, order: Number(n.order_index),
          status: n.status, isReinforcement: false, isOptional: n.is_optional,
          mastery: {
            state: n.mastery_state, answered: n.answered, correct: n.correct, requiredItems: n.required_items,
            passedCheckpoints: n.passed_checkpoints, requiredCheckpoints: n.required_checkpoints, reviewDue: n.review_due,
          },
        }));
      }
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
        ...(typeof (n.skill_domain || n.skillDomain) === 'string' ? { skillDomain: n.skill_domain || n.skillDomain } : {}),
        ...(typeof (n.cefr_level || n.cefrLevel) === 'string' ? { cefrLevel: n.cefr_level || n.cefrLevel } : {}),
        ...(typeof (n.module_id || n.moduleId) === 'string' ? { moduleId: n.module_id || n.moduleId } : {}),
        ...(typeof (n.module_title || n.moduleTitle) === 'string' ? { moduleTitle: n.module_title || n.moduleTitle } : {}),
        ...(typeof (n.module_title_ru || n.moduleTitleRu) === 'string' ? { moduleTitleRu: n.module_title_ru || n.moduleTitleRu } : {}),
        ...(typeof (n.unit_id || n.unitId) === 'string' ? { unitId: n.unit_id || n.unitId } : {}),
        ...(typeof (n.can_do_objective || n.canDoObjective) === 'string' ? { canDoObjective: n.can_do_objective || n.canDoObjective } : {}),
        ...(typeof (n.can_do_objective_ru || n.canDoObjectiveRu) === 'string' ? { canDoObjectiveRu: n.can_do_objective_ru || n.canDoObjectiveRu } : {}),
        ...(typeof (n.node_kind || n.nodeKind) === 'string' ? { nodeKind: n.node_kind || n.nodeKind } : {}),
        ...(typeof (n.is_checkpoint ?? n.isCheckpoint) === 'boolean' ? { isCheckpoint: n.is_checkpoint ?? n.isCheckpoint } : {}),
        ...(typeof (n.has_rich_exercise ?? n.hasRichExercise) === 'boolean' ? { hasRichExercise: n.has_rich_exercise ?? n.hasRichExercise } : {}),
        ...(typeof (n.task_kind || n.taskKind) === 'string' ? { taskKind: n.task_kind || n.taskKind } : {}),
        title: updatedUzbekSpelling(n.title),
        ...(typeof (n.title_ru || n.titleRu) === 'string' ? { titleRu: n.title_ru || n.titleRu } : {}),
        description: updatedUzbekSpelling(n.description || ''),
        ...(typeof (n.description_ru || n.descriptionRu) === 'string' ? { descriptionRu: n.description_ru || n.descriptionRu } : {}),
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
    await (await this.demoRepository()).saveLesson(lesson);
  }
}

export const supabaseLessonRepository = new SupabaseLessonRepository();
