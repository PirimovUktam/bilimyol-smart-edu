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
    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      const fb = await this.fallbackService.explainMistake(request);
      return { ...fb, isFallback: true };
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
        throw new GeminiAIServiceError(
          error ? describeEdgeError(extractStatus(error) || 500) : 'Yo‘lchi AI hozircha javob bera olmadi.'
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
      throw new GeminiAIServiceError('Yo‘lchi AI xizmatiga ulanib bo‘lmadi. Internetni tekshirib qayta urinib ko‘ring.');
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
          error ? describeEdgeError(extractStatus(error) || 500) : 'Savol generatsiya qilinmadi.'
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
      throw new GeminiAIServiceError('Savol generatsiyasi xizmatiga ulanib bo‘lmadi.');
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
          error ? describeEdgeError(extractStatus(error) || 500) : 'Mustahkamlash savoli generatsiya qilinmadi.'
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
      throw new GeminiAIServiceError('Mustahkamlash savoli xizmatiga ulanib bo‘lmadi.');
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
        throw new GeminiAIServiceError(describeEdgeError(status || 500));
      }

      if (!data || !data.title || !Array.isArray(data.steps)) {
        throw new GeminiAIServiceError('Dars kontenti noto‘g‘ri formatda qaytdi. Qayta urinib ko‘ring.');
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
      throw new GeminiAIServiceError('Dars generatsiyasi xizmatiga ulanib bo‘lmadi.');
    }
  }

  async askTutor(request: AskTutorRequest): Promise<AskTutorResponse> {
    const message = request.message.trim();
    if (!message) {
      return {
        tutorName: 'Yo‘lchi AI',
        answer: 'Iltimos, savolingizni yozing.',
        isAiGenerated: false,
        isDeterministicFallback: true,
      };
    }

    if (isDemoRuntimeActive() || !isSupabaseConfigured) {
      return this.fallbackService.askTutor(request);
    }

    try {
      const { data, error } = await supabase.functions.invoke('yolchi-tutor', {
        body: {
          action: 'askTutor',
          ...request,
          message,
        },
      });

      if (error || !data || typeof data.answer !== 'string') {
        throw new GeminiAIServiceError(
          'Yo‘lchi AI hozircha javob bera olmadi. Iltimos, qayta urinib ko‘ring.'
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
      const status = extractStatus(err);
      if (status !== null && status >= 400) {
        throw new GeminiAIServiceError(describeEdgeError(status));
      }
      throw new GeminiAIServiceError(
        'Yo‘lchi AI xizmatiga ulanib bo‘lmadi. Internet aloqasini tekshirib qayta urinib ko‘ring.'
      );
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
