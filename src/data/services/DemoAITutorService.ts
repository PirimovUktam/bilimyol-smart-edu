import { IAITutorService, AIExplanationRequest, AIExplanationResponse } from './IAITutorService';
import { DEMO_AI_RESPONSES } from '../datasources/demoAiResponses';

export class DemoAITutorService implements IAITutorService {
  /**
   * Deterministic, zero-network offline explanation provider
   */
  async explainMistake(request: AIExplanationRequest): Promise<AIExplanationResponse> {
    // Artificial minimal latency (150ms) to feel natural without slowing down testing
    await new Promise((resolve) => setTimeout(resolve, 150));

    const matched = DEMO_AI_RESPONSES[request.questionId];

    if (matched) {
      return {
        tutorName: 'Yo‘lchi AI',
        title: matched.misconceptionTitle,
        explanation: matched.explanation,
        remediationStep: matched.remediationStep,
        suggestedAction: matched.suggestedAction,
        isDeterministicFallback: true,
      };
    }

    // Generic pedagogical fallback for any other question
    return {
      tutorName: 'Yo‘lchi AI',
      title: 'Xatoni tahlil qilish',
      explanation: `Siz tanlagan javob (${request.selectedOption}) to‘g‘ri emas. To‘g‘ri javob: ${request.correctOption}.`,
      remediationStep: 'Mavzuni to‘liq o‘zlashtirish uchun formulani qadamma-qadam tekshirib chiqing.',
      suggestedAction: 'Keling, ushbu ko‘nikmani mustahkamlash mashqi bilan tekshiramiz.',
      isDeterministicFallback: true,
    };
  }
}

export const demoAITutorService = new DemoAITutorService();
