import {
  IAITutorService,
  AIExplanationRequest,
  AIExplanationResponse,
  GenerateQuestionRequest,
  GeneratedQuestionResponse,
  GenerateReinforcementRequest,
  GenerateLessonRequest,
  GeneratedLessonResponse,
} from './IAITutorService';
import { DemoAITutorService } from './DemoAITutorService';
import { supabase, isSupabaseConfigured } from '../../core/config/supabase';

/**
 * Thrown when the AI edge function is reachable but refuses the request
 * (auth / rate-limit / server errors). Must surface to the UI as a clear,
 * recoverable Uzbek error — never silently replaced by demo content.
 */
export class GeminiAIServiceError extends Error {}

const extractStatus = (err: unknown): number | null => {
  if (!err || typeof err !== 'object') return null;
  const e = err as { context?: { status?: unknown } | Response; status?: unknown };
  const fromContext =
    e.context && typeof e.context === 'object' ? (e.context as { status?: unknown }).status : undefined;
  const raw = fromContext ?? e.status;
  return typeof raw === 'number' ? raw : null;
};

const describeEdgeError = (status: number): string => {
  if (status === 401 || status === 403) return 'AI xizmatiga ruxsat etilmadi (autifikatsiya xatosi)';
  if (status === 429) return 'AI xizmatiga so‘rovlar limiti tugadi';
  if (status >= 500) return 'AI xizmati vaqtincha ishlamayapti';
  return `AI xizmati so‘rovni qabul qilmadi (xatolik kodi: ${status})`;
};

export class GeminiAITutorService implements IAITutorService {
  private fallbackService = new DemoAITutorService();

  async explainMistake(request: AIExplanationRequest): Promise<AIExplanationResponse> {
    if (!isSupabaseConfigured) {
      return this.fallbackService.explainMistake(request);
    }

    try {
      // Invoke Supabase Edge Function: yolchi-tutor
      const { data, error } = await supabase.functions.invoke('yolchi-tutor', {
        body: {
          action: 'diagnose_mistake',
          ...request,
        },
      });

      if (error || !data) {
        console.warn('Edge function returned error, using reliable fallback:', error);
        return this.fallbackService.explainMistake(request);
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
      };
    } catch (err) {
      console.warn('Gemini AI service network error, using fallback:', err);
      return this.fallbackService.explainMistake(request);
    }
  }

  async generateQuestion(request: GenerateQuestionRequest): Promise<GeneratedQuestionResponse> {
    if (!isSupabaseConfigured) {
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
        return this.getFallbackQuestion(request, request.difficulty);
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
    } catch {
      return this.getFallbackQuestion(request, request.difficulty);
    }
  }

  async generateReinforcement(request: GenerateReinforcementRequest): Promise<GeneratedQuestionResponse> {
    if (!isSupabaseConfigured) {
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
        return this.getFallbackQuestion(request, 'easy');
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
    } catch {
      return this.getFallbackQuestion(request, 'easy');
    }
  }

  async generateLesson(request: GenerateLessonRequest): Promise<GeneratedLessonResponse> {
    if (!isSupabaseConfigured) {
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
        console.warn('[Gemini AI] Edge Function network error for generate_lesson, using fallback:', error);
        return this.fallbackService.generateLesson(request);
      }

      if (!data || !data.title || !Array.isArray(data.steps)) {
        console.warn('[Gemini AI] Edge Function returned invalid generate_lesson payload, using fallback');
        return this.fallbackService.generateLesson(request);
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
      console.warn('[Gemini AI] Network error during generate_lesson, using fallback:', err);
      return this.fallbackService.generateLesson(request);
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
    // served for English / IT / logic courses (and vice versa).
    switch (request.courseId) {
      case 'course_eng_01':
        return {
          ...base,
          text: 'Mustahkamlash: “She is reading a book” gapida fe’l qaysi zamonida ishlatilgan?',
          options: ['Present Continuous', 'Past Simple', 'Future Simple', 'Present Perfect'],
        };
      case 'course_it':
        return {
          ...base,
          text: 'Mustahkamlash: `for` sikli qaysi shart bajarilganda to‘xtaydi?',
          options: ['Shart bajarilganda', 'Birinchi qadamda', 'Doim 10 marta', 'Faqat xato bo‘lganda'],
        };
      case 'course_logic':
        return {
          ...base,
          text: 'Mustahkamlash: 2, 4, 8, 16, ... ketma-ketligidagi keyingi son qaysi?',
          options: ['24', '30', '32', '34'],
        };
      case 'course_math_01':
        return {
          ...base,
          text: 'Mustahkamlash: f(x) = 3x + 2 funksiya berilgan. Agar x = 2 bo‘lsa, f(2) nechaga teng?',
          formulaLatex: 'f(2) = 3(2) + 2',
          options: ['8', '6', '7', '5'],
        };
      default:
        return {
          ...base,
          text: 'Mustahkamlash: ushbu mavzuni qayta ko‘rib chiqish va misollar yechish tavsiya etiladi.',
          options: ['Tushundim', 'Qayta ko‘rish kerak', 'Savollarim bor', 'Yana mashq qilaman'],
        };
    }
  }
}
