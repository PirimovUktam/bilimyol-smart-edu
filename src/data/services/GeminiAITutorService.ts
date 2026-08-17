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
      return this.getFallbackQuestion(request.skillId, request.difficulty);
    }

    try {
      const { data, error } = await supabase.functions.invoke('yolchi-tutor', {
        body: {
          action: 'generate_question',
          ...request,
        },
      });

      if (error || !data || !data.text) {
        return this.getFallbackQuestion(request.skillId, request.difficulty);
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
      return this.getFallbackQuestion(request.skillId, request.difficulty);
    }
  }

  async generateReinforcement(request: GenerateReinforcementRequest): Promise<GeneratedQuestionResponse> {
    if (!isSupabaseConfigured) {
      return this.getFallbackQuestion(request.skillId, 'easy');
    }

    try {
      const { data, error } = await supabase.functions.invoke('yolchi-tutor', {
        body: {
          action: 'generate_reinforcement',
          ...request,
        },
      });

      if (error || !data || !data.text) {
        return this.getFallbackQuestion(request.skillId, 'easy');
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
      return this.getFallbackQuestion(request.skillId, 'easy');
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

      if (error || !data || !data.title || !Array.isArray(data.steps)) {
        console.warn('[Gemini AI] Edge Function returned error for generate_lesson, using fallback:', error);
        return this.fallbackService.generateLesson(request);
      }

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
        isDeterministicFallback: false,
      };
    } catch (err) {
      console.warn('[Gemini AI] Network error during generate_lesson, using fallback:', err);
      return this.fallbackService.generateLesson(request);
    }
  }

  private getFallbackQuestion(skillId: string, difficulty: 'easy' | 'medium' | 'hard'): GeneratedQuestionResponse {
    return {
      id: `q_fallback_${skillId}_${difficulty}`,
      courseId: 'course_math_01',
      skillId,
      text: 'Mustahkamlash: f(x) = 3x + 2 funksiya berilgan. Agar x = 2 bo‘lsa, f(2) nechaga teng?',
      formulaLatex: 'f(2) = 3(2) + 2',
      options: ['8', '6', '7', '5'],
      difficulty,
      isAiGenerated: false,
      isDeterministicFallback: true,
    };
  }
}
