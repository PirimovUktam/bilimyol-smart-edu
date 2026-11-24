import {
  IAITutorService,
  AIExplanationRequest,
  AIExplanationResponse,
  GenerateQuestionRequest,
  GeneratedQuestionResponse,
  GenerateReinforcementRequest,
  GenerateLessonRequest,
  GeneratedLessonResponse,
  AskTutorRequest,
  AskTutorResponse,
} from './IAITutorService';
import type { DemoAITutorService } from './DemoAITutorService';
import { isDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { LocalizedError } from '@/core/locales/LocalizedError';
import type { MessageKey } from '@/core/locales/messages';
import { supabase, isSupabaseConfigured } from '../../core/config/supabase';

/**
 * Thrown when the AI edge function is reachable but refuses the request
 * (auth / rate-limit / server errors). The UI translates safe message keys.
 */
export class GeminiAIServiceError extends LocalizedError {}

const extractStatus = (err: unknown): number | null => {
  if (!err || typeof err !== 'object') return null;
  const e = err as { context?: { status?: unknown } | Response; status?: unknown };
  const fromContext =
    e.context && typeof e.context === 'object' ? (e.context as { status?: unknown }).status : undefined;
  const raw = fromContext ?? e.status;
  return typeof raw === 'number' ? raw : null;
};

const describeEdgeError = (status: number | null): MessageKey => {
  if (status === null) return 'tutor.networkError';
  if (status === 401) return 'tutor.unauthorized';
  if (status === 403) return 'tutor.forbidden';
  if (status === 429) return 'tutor.rateLimit';
  if (status >= 500) return 'tutor.unavailable';
  return 'tutor.invalidRequest';
};

export class GeminiAITutorService implements IAITutorService {
  private fallbackServicePromise?: Promise<DemoAITutorService>;

  private getFallbackService(): Promise<DemoAITutorService> {
    this.fallbackServicePromise ??= import('./DemoAITutorService')
      .then((m) => new m.DemoAITutorService())
      .catch((err) => {
        this.fallbackServicePromise = undefined;
        throw err;
      });
    return this.fallbackServicePromise;
  }

  async explainMistake(request: AIExplanationRequest): Promise<AIExplanationResponse> {
    const questionId = request.questionId?.trim() || undefined;
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      const fb = await (await this.getFallbackService()).explainMistake({
        ...request,
        questionId: questionId ?? '',
      });
      return { ...fb, isFallback: true };
    }

    try {
      // Invoke Supabase Edge Function: yolchi-tutor
      const { data, error } = await supabase.functions.invoke('yolchi-tutor', {
        body: {
          action: 'diagnose_mistake',
          ...request,
          questionId,
        },
      });

      if (error || !data) {
        throw new GeminiAIServiceError(
          error ? describeEdgeError(extractStatus(error)) : 'tutor.noResponse'
        );
      }

      return {
        tutorName: data.tutorName || 'Yo‘lchi AI',
        title: data.title || 'Xatoni tahlil qilish',
        explanation: data.explanation || `Siz ${request.selectedOption} ni tanladingiz.`,
        remediationStep: data.remediationStep || 'Mavzuni qadamma-qadam takrorlash tavsiya etiladi.',
        suggestedAction: data.suggestedAction || 'Keling, ushbu mavzuni qisqa mashq bilan mustahkamlaymiz.',
        motivation: data.motivation,
        reinforcementNeeded: data.reinforcementNeeded ?? true,
        isDeterministicFallback: Boolean(data.isDeterministicFallback),
        isFallback: Boolean(data.isDeterministicFallback),
      };
    } catch (err) {
      if (err instanceof GeminiAIServiceError) throw err;
      throw new GeminiAIServiceError('tutor.networkError');
    }
  }

  async generateQuestion(request: GenerateQuestionRequest): Promise<GeneratedQuestionResponse> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return (await this.getFallbackService()).generateQuestion(request);
    }

    try {
      const { data, error } = await supabase.functions.invoke('yolchi-tutor', {
        body: {
          action: 'generate_question',
          ...request,
        },
      });

      if (error || !data || !data.text) {
        throw new GeminiAIServiceError(
          error ? describeEdgeError(extractStatus(error)) : 'tutor.noResponse'
        );
      }

      return {
        id: data.id,
        courseId: request.courseId,
        skillId: request.skillId,
        text: data.text,
        formulaLatex: data.formulaLatex,
        options: data.options,
        difficulty: request.difficulty,
        isAiGenerated: Boolean(data.isAiGenerated),
      };
    } catch (err) {
      if (err instanceof GeminiAIServiceError) throw err;
      throw new GeminiAIServiceError('tutor.networkError');
    }
  }

  async generateReinforcement(request: GenerateReinforcementRequest): Promise<GeneratedQuestionResponse> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return (await this.getFallbackService()).generateReinforcement(request);
    }

    try {
      const { data, error } = await supabase.functions.invoke('yolchi-tutor', {
        body: {
          action: 'generate_reinforcement',
          ...request,
        },
      });

      if (error || !data || !data.text) {
        throw new GeminiAIServiceError(
          error ? describeEdgeError(extractStatus(error)) : 'tutor.noResponse'
        );
      }

      return {
        id: data.id,
        courseId: request.courseId,
        skillId: request.skillId,
        text: data.text,
        formulaLatex: data.formulaLatex,
        options: data.options,
        difficulty: 'easy',
        isAiGenerated: Boolean(data.isAiGenerated),
      };
    } catch (err) {
      if (err instanceof GeminiAIServiceError) throw err;
      throw new GeminiAIServiceError('tutor.networkError');
    }
  }

  async generateLesson(request: GenerateLessonRequest): Promise<GeneratedLessonResponse> {
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return (await this.getFallbackService()).generateLesson(request);
    }

    try {
      const { data, error } = await supabase.functions.invoke('yolchi-tutor', {
        body: {
          action: 'generate_lesson',
          ...request,
        },
      });

      if (error) {
        const status = extractStatus(error);
        if (status !== null && status >= 400) {
          // Auth / rate-limit / server failures: surface a clear Uzbek error
          // so the UI can offer retry instead of showing fake AI success.
          throw new GeminiAIServiceError(describeEdgeError(status));
        }
        throw new GeminiAIServiceError(describeEdgeError(status ?? (error ? null : 503)));
      }

      if (!data || !data.title || !Array.isArray(data.steps)) {
        throw new GeminiAIServiceError('tutor.noResponse');
      }

      // Edge returns a deterministic fallback (isDeterministicFallback: true,
      // isAiGenerated: false) when GEMINI_API_KEY is missing or Gemini output
      // fails validation — never mislabel it as a real AI result.
      return {
        lessonId: data.lessonId,
        courseId: data.courseId,
        skillId: data.skillId,
        topic: data.topic,
        level: data.level,
        difficulty: data.difficulty,
        title: data.title,
        summary: data.summary,
        objective: data.objective,
        estimatedMinutes: data.estimatedMinutes || 15,
        steps: data.steps,
        questions: data.questions || [],
        isAiGenerated: Boolean(data.isAiGenerated),
        model: data.model || 'gemini-3.6-flash',
        isDeterministicFallback: Boolean(data.isDeterministicFallback),
      };
    } catch (err) {
      if (err instanceof GeminiAIServiceError) throw err;
      throw new GeminiAIServiceError('tutor.networkError');
    }
  }

  async askTutor(request: AskTutorRequest): Promise<AskTutorResponse> {
    const message = request.message.trim();
    const questionId = request.questionId?.trim() || undefined;
    if (!message) {
      return {
        tutorName: 'Yo‘lchi AI',
        answer: request.language === 'ru' ? 'Пожалуйста, напишите ваш вопрос.' : 'Iltimos, savolingizni yozing.',
        isAiGenerated: false,
        isDeterministicFallback: true,
      };
    }

    if (typeof navigator !== 'undefined' && navigator.onLine === false) {
      throw new GeminiAIServiceError('tutor.networkError');
    }

    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return (await this.getFallbackService()).askTutor({ ...request, questionId });
    }

    try {
      const { data, error } = await supabase.functions.invoke('yolchi-tutor', {
        body: {
          action: 'askTutor',
          ...request,
          questionId,
          message,
        },
      });

      if (error || !data || typeof data.answer !== 'string' || !data.answer.trim()) {
        throw new GeminiAIServiceError(
          error ? describeEdgeError(extractStatus(error)) : 'tutor.noResponse'
        );
      }

      return {
        tutorName: data.tutorName || 'Yo‘lchi AI',
        answer: data.answer,
        isAiGenerated: Boolean(data.isAiGenerated),
        isDeterministicFallback: Boolean(data.isDeterministicFallback),
      };
    } catch (err) {
      if (err instanceof GeminiAIServiceError) throw err;
      throw new GeminiAIServiceError(describeEdgeError(extractStatus(err)));
    }
  }
}
