import { IAITutorService, AIExplanationRequest, AIExplanationResponse } from './IAITutorService';
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
        body: request,
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
        isDeterministicFallback: Boolean(data.isDeterministicFallback),
      };
    } catch (err) {
      console.warn('Gemini AI service network error, using fallback:', err);
      return this.fallbackService.explainMistake(request);
    }
  }
}
