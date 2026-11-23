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
import { DemoAITutorService } from './DemoAITutorService';
import { isDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { LocalizedError } from '@/core/locales/LocalizedError';
import type { MessageKey } from '@/core/locales/messages';
import { publishQuestionWithRegisteredKey } from '@/core/runtime/questionAnswerKeys';
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
  private fallbackService = new DemoAITutorService();

  async explainMistake(request: AIExplanationRequest): Promise<AIExplanationResponse> {
    const questionId = request.questionId?.trim() || undefined;
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      const fb = await this.fallbackService.explainMistake({
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
        tutorName: data.tutorName || 'Yölçi AI',
        title: data.title || 'Xatoni tahlil qiliş',
        explanation: data.explanation || `Siz ${request.selectedOption} ni tanladingiz.`,
        remediationStep: data.remediationStep || 'Mavzuni qadamma-qadam takrorlaş tavsiya etiladi.',
        suggestedAction: data.suggestedAction || 'Keling, uşbu mavzuni qisqa maşq bilan mustahkamlaymiz.',
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
      return this.getFallbackQuestion(request, request.difficulty);
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
      return this.getFallbackQuestion(request, 'easy');
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
      return this.fallbackService.generateLesson(request);
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
        tutorName: 'Yölçi AI',
        answer: request.language === 'ru' ? 'Пожалуйста, напишите ваш вопрос.' : 'Iltimos, savolingizni yozing.',
        isAiGenerated: false,
        isDeterministicFallback: true,
      };
    }

    if (typeof navigator !== 'undefined' && navigator.onLine === false) {
      throw new GeminiAIServiceError('tutor.networkError');
    }

    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return this.fallbackService.askTutor({ ...request, questionId });
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
        tutorName: data.tutorName || 'Yölçi AI',
        answer: data.answer,
        isAiGenerated: Boolean(data.isAiGenerated),
        isDeterministicFallback: Boolean(data.isDeterministicFallback),
      };
    } catch (err) {
      if (err instanceof GeminiAIServiceError) throw err;
      throw new GeminiAIServiceError(describeEdgeError(extractStatus(err)));
    }
  }

  private getFallbackQuestion(
    request: { courseId: string; skillId: string },
    difficulty: 'easy' | 'medium' | 'hard'
  ): GeneratedQuestionResponse {
    const base = {
      id: `q_fallback_${request.skillId}_${difficulty}`,
      courseId: request.courseId,
      skillId: request.skillId,
      difficulty,
      isAiGenerated: false,
      isDeterministicFallback: true,
    } as const;

    // Subject-scoped deterministic fallbacks — a math question must never be
    // served for English / IT / logic courses (and vice versa). The answer key
    // is registered server-side (demo) and stripped from the client payload.
    switch (request.courseId) {
      case 'course_eng_01':
        return publishQuestionWithRegisteredKey({
          ...base,
          text: 'Mustahkamlaş: “She is reading a book” gapida fe’l qaysi zamonida işlatilgan?',
          options: ['Present Continuous', 'Past Simple', 'Future Simple', 'Present Perfect'],
          correctIndex: 0,
          explanation: '“is reading” — hozirgi davomiy zamon (Present Continuous).',
        });
      case 'course_it':
        return publishQuestionWithRegisteredKey({
          ...base,
          text: 'Mustahkamlaş: `for` sikli qaysi şart bajarilganda töxtaydi?',
          options: ['Şart bajarilganda', 'Birinçi qadamda', 'Doim 10 marta', 'Faqat xato bölganda'],
          correctIndex: 0,
          explanation: '`for` sikli berilgan şart (şartli ifoda) yolğon bölganda töxtaydi.',
        });
      case 'course_logic':
        return publishQuestionWithRegisteredKey({
          ...base,
          text: 'Mustahkamlaş: 2, 4, 8, 16, ... ketma-ketligidagi keyingi son qaysi?',
          options: ['24', '30', '32', '34'],
          correctIndex: 2,
          explanation: 'Har bir had 2 baravar oşadi: 16 × 2 = 32.',
        });
      case 'course_math_01':
        return publishQuestionWithRegisteredKey({
          ...base,
          text: 'Mustahkamlaş: f(x) = 3x + 2 funksiya berilgan. Agar x = 2 bölsa, f(2) neçaga teng?',
          formulaLatex: 'f(2) = 3(2) + 2',
          options: ['8', '6', '7', '5'],
          correctIndex: 0,
          explanation: 'f(2) = 3×2 + 2 = 6 + 2 = 8.',
        });
      default:
        return publishQuestionWithRegisteredKey({
          ...base,
          text: 'Mustahkamlaş: uşbu mavzuni qayta körib çiqiş va misollar yeçiş tavsiya etiladi.',
          options: ['Tuşundim', 'Qayta köriş kerak', 'Savollarim bor', 'Yana maşq qilaman'],
          correctIndex: 0,
          explanation: 'Mavzuni mustahkamlaş uçun qöşimça misollar yeçib köring.',
        });
    }
  }
}
