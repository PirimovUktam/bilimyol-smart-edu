import {
  IAITutorService,
  AIExplanationRequest,
  AIExplanationResponse,
  GenerateLessonRequest,
  GeneratedLessonResponse,
} from './IAITutorService';
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

  async generateLesson(request: GenerateLessonRequest): Promise<GeneratedLessonResponse> {
    const topic = request.topic || request.skillId || 'Matematika';
    const difficulty = request.difficulty || 'medium';
    return {
      lessonId: `lesson_fallback_${request.skillId}`,
      courseId: request.courseId,
      skillId: request.skillId,
      topic,
      level: request.level || 'intermediate',
      difficulty: typeof difficulty === 'number' ? (difficulty <= 2 ? 'easy' : difficulty >= 4 ? 'hard' : 'medium') : difficulty,
      title: `${topic} bo‘yicha interaktiv dars`,
      summary: 'Asosiy nazariy qoidalar va amaliy namunalar jamlanmasi.',
      objective: 'Mavzu bo‘yicha tushunchalarni mustahkamlash.',
      estimatedMinutes: 15,
      steps: [
        {
          id: 'step_1',
          stepNumber: 1,
          type: 'concept',
          title: 'Asosiy tushuncha',
          content: 'Chiziqli funksiya f(x) = kx + b ko‘rinishida ifodalanadi.',
          highlightNotes: ['k — burchak koeffitsiyenti', 'b — ozod had'],
        },
        {
          id: 'step_2',
          stepNumber: 2,
          type: 'formula',
          title: 'Hisoblash qoidasi',
          content: 'x ning berilgan qiymatini formulaga qo‘yib hisoblash.',
          formulaData: {
            latex: 'f(x) = 2x + 3',
            description: 'Chiziqli funksiya formulasi',
            variables: [
              { symbol: 'x', meaning: 'Argument' },
              { symbol: 'f(x)', meaning: 'Funksiya qiymati' },
            ],
          },
        },
        {
          id: 'step_3',
          stepNumber: 3,
          type: 'concept',
          title: 'Misol tahlili',
          content: 'Agar x = 4 bo‘lsa, f(4) = 2(4) + 3 = 11 bo‘ladi.',
        },
        {
          id: 'step_4',
          stepNumber: 4,
          type: 'interactive_question',
          title: 'Mustahkamlash',
          content: 'O‘rganganlaringizni sinab ko‘ring.',
        },
      ],
      questions: [
        {
          id: 'q_demo_1',
          courseId: request.courseId,
          skillId: request.skillId,
          text: 'f(x) = 2x + 3 funksiya berilgan. x = 4 bo‘lganda f(4) nechaga teng?',
          formulaLatex: 'f(4) = 2(4) + 3',
          options: ['11', '8', '14', '9'],
          difficulty: 'medium',
          isAiGenerated: false,
          isDeterministicFallback: true,
        },
        {
          id: 'q_demo_2',
          courseId: request.courseId,
          skillId: request.skillId,
          text: 'f(x) = 3x - 1 funksiya berilgan. x = 3 bo‘lganda f(3) nechaga teng?',
          formulaLatex: 'f(3) = 3(3) - 1',
          options: ['8', '10', '6', '9'],
          difficulty: 'medium',
          isAiGenerated: false,
          isDeterministicFallback: true,
        },
      ],
      isAiGenerated: false,
      isDeterministicFallback: true,
    };
  }
}

export const demoAITutorService = new DemoAITutorService();
