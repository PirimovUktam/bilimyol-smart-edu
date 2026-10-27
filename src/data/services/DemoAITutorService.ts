import {
  IAITutorService,
  AIExplanationRequest,
  AIExplanationResponse,
  GenerateLessonRequest,
  GeneratedLessonResponse,
  GeneratedQuestionResponse,
  AskTutorRequest,
  AskTutorResponse,
} from './IAITutorService';
import { DEMO_AI_RESPONSES } from '../datasources/demoAiResponses';
import { publishQuestionWithRegisteredKey } from '@/core/runtime/questionAnswerKeys';

/** An authored AI question: the answer key is registered server-side, then stripped. */
type AuthoredQuestion = GeneratedQuestionResponse & { correctIndex: number; explanation: string };

const publishAll = (questions: AuthoredQuestion[]): GeneratedQuestionResponse[] =>
  questions.map((question) => publishQuestionWithRegisteredKey(question));

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
    const correctLine = request.correctOption
      ? `To‘g‘ri javob: ${request.correctOption}.`
      : '';
    return {
      tutorName: 'Yo‘lchi AI',
      title: 'Xatoni tahlil qilish',
      explanation: `Siz tanlagan javob (${request.selectedOption}) to‘g‘ri emas. ${correctLine}`.trim(),
      remediationStep: 'Mavzuni to‘liq o‘zlashtirish uchun yechimni qadamma-qadam tekshirib chiqing.',
      suggestedAction: 'Keling, ushbu ko‘nikmani mustahkamlash mashqi bilan tekshiramiz.',
      isDeterministicFallback: true,
    };
  }

  async generateLesson(request: GenerateLessonRequest): Promise<GeneratedLessonResponse> {
    const topic = request.topic || request.skillId || 'Mavzu';
    const difficulty = request.difficulty || 'medium';
    const normalizedDifficulty = typeof difficulty === 'number'
      ? (difficulty <= 2 ? 'easy' : difficulty >= 4 ? 'hard' : 'medium')
      : difficulty;

    if (request.courseId === 'course_eng_01') {
      return {
        lessonId: `lesson_fallback_${request.skillId}_eng`,
        courseId: request.courseId,
        skillId: request.skillId,
        topic,
        level: request.level || 'intermediate',
        difficulty: normalizedDifficulty,
        title: `${topic} bo‘yicha ingliz tili darsi`,
        summary: 'Ingliz tili ko‘nikmalarini mustahkamlash: kalit iboralar, talaffuz va amaliy mashqlar.',
        objective: 'Tinglab tushunish, yangi so‘zlar va grammatika bo‘yicha bilimni oshirish.',
        estimatedMinutes: 12,
        steps: [
          {
            id: 'step_1',
            stepNumber: 1,
            type: 'concept',
            title: '1. Asosiy Qoida va Lug‘at',
            content: 'Ingliz tilida mazmunni to‘liq tushunish uchun kalit so‘zlarga va kontekstga e’tibor berish lozim.',
            highlightNotes: ['Kalit so‘zlarni ajratib oling', 'Gapdagi asosiy fe’l va ot munosabatiga qarang'],
          },
          {
            id: 'step_2',
            stepNumber: 2,
            type: 'visual_example',
            title: '2. Audio Xabar Tahlili',
            content: 'Quyidagi audio to‘lqin va talaffuz ifodasini tinglang:',
            visualModelData: {
              type: 'audio_wave',
              speakerName: 'Sarah (Speaker)',
              audioTranscript: 'Consistent daily practice is the key to mastering English vocabulary.',
            },
          },
          {
            id: 'step_3',
            stepNumber: 3,
            type: 'concept',
            title: '3. Amaliy Qo‘llanish',
            content: 'Mavzuni kundalik suhbat va yozuvda mustahkamlash qoidalari.',
          },
          {
            id: 'step_4',
            stepNumber: 4,
            type: 'interactive_question',
            title: '4. Sinov Savoli',
            content: 'O‘rgangan ko‘nikmangizni quyidagi savol bilan sinab ko‘ring.',
          },
        ],
        questions: publishAll([
          {
            id: 'q_demo_eng_1',
            courseId: request.courseId,
            skillId: request.skillId,
            text: 'What does "consistent daily practice" lead to according to the lesson?',
            options: ['Mastering vocabulary', 'Forgetting words', 'Reducing fluency', 'Changing grammar rules'],
            correctIndex: 0,
            explanation: 'Darsga ko‘ra, doimiy mashq so‘z boyligini mukammal egallashga olib keladi.',
            difficulty: 'medium',
            isAiGenerated: false,
            isDeterministicFallback: true,
          },
          {
            id: 'q_demo_eng_2',
            courseId: request.courseId,
            skillId: request.skillId,
            text: 'Choose the correct word: "She has a very ___ understanding of the topic."',
            options: ['deep', 'deeply', 'depth', 'deepness'],
            correctIndex: 0,
            explanation: 'Otdan oldin sifat keladi: "deep understanding" — "juda chuqur tushuncha".',
            difficulty: 'medium',
            isAiGenerated: false,
            isDeterministicFallback: true,
          },
        ]),
        isAiGenerated: false,
        isDeterministicFallback: true,
      };
    }

    if (request.courseId === 'course_it') {
      return {
        lessonId: `lesson_fallback_${request.skillId}_it`,
        courseId: request.courseId,
        skillId: request.skillId,
        topic,
        level: request.level || 'intermediate',
        difficulty: normalizedDifficulty,
        title: `${topic} bo‘yicha IT va dasturlash darsi`,
        summary: 'Dasturlash asoslari, o‘zgaruvchilar va algoritmlash mantiqi.',
        objective: 'Kod yozish va kompyuter fanlari tushunchalarini o‘zlashtirish.',
        estimatedMinutes: 15,
        steps: [
          {
            id: 'step_1',
            stepNumber: 1,
            type: 'concept',
            title: '1. Algoritm nima?',
            content: 'Algoritm — bu belgilangan maqsadga erishish uchun kompyuter bajarishi kerak bo‘lgan qadamma-qadam ko‘rsatmalar ketma-ketligidir.',
            highlightNotes: ['Ketma-ketlik buzilmasligi shart', 'Har bir qadam aniq va tushunarli bo‘lishi lozim'],
          },
          {
            id: 'step_2',
            stepNumber: 2,
            type: 'concept',
            title: '2. O‘zgaruvchilar va ma’lumot turlari',
            content: 'Dasturda ma’lumotlarni saqlash uchun o‘zgaruvchilardan (variables) foydalaniladi: sonlar, matnlar va mantiqiy qiymatlar.',
          },
          {
            id: 'step_3',
            stepNumber: 3,
            type: 'interactive_question',
            title: '3. Amaliy Test',
            content: 'Quyidagi kod natijasini aniqlang.',
          },
        ],
        questions: publishAll([
          {
            id: 'q_demo_it_1',
            courseId: request.courseId,
            skillId: request.skillId,
            text: 'Python tilida matnli qiymat (string) qaysi belgilar ichida yoziladi?',
            options: ['Qo‘shtirnoq yoki bittalik tirnoq', 'Kvadrat qavslar', 'Katta-kichik belgilari', 'Hech qanday belgisiz'],
            correctIndex: 0,
            explanation: 'Python’da satr (string) qo‘shtirnoq ("...") yoki bittalik tirnoq (\'...\') ichida yoziladi.',
            difficulty: 'easy',
            isAiGenerated: false,
            isDeterministicFallback: true,
          },
        ]),
        isAiGenerated: false,
        isDeterministicFallback: true,
      };
    }

    if (request.courseId === 'course_logic') {
      return {
        lessonId: `lesson_fallback_${request.skillId}_logic`,
        courseId: request.courseId,
        skillId: request.skillId,
        topic,
        level: request.level || 'intermediate',
        difficulty: normalizedDifficulty,
        title: `${topic} bo‘yicha mantiqiy fikrlash darsi`,
        summary: 'Deduktiv mantiq, naqshlar va tahliliy xulosalar chiqarish.',
        objective: 'Mantiqiy ketma-ketliklarni to‘g‘ri topish va qaror qabul qilish.',
        estimatedMinutes: 12,
        steps: [
          {
            id: 'step_1',
            stepNumber: 1,
            type: 'concept',
            title: '1. Mantiqiy Qonuniyat',
            content: 'Ketma-ketlikdagi har bir keyingi son oldingi hadlarning o‘zaro qonuniyati asosida shakllanadi.',
            highlightNotes: ['Farqlar orasidagi oraliqni o‘rganing', 'Ko‘paytirish yoki qo‘shish mantiqini tekshiring'],
          },
          {
            id: 'step_2',
            stepNumber: 2,
            type: 'interactive_question',
            title: '2. Mantiqiy Boshqotirma',
            content: 'Ketma-ketlikdagi keyingi sonni toping.',
          },
        ],
        questions: publishAll([
          {
            id: 'q_demo_logic_1',
            courseId: request.courseId,
            skillId: request.skillId,
            text: 'Ketma-ketlikni davom ettiring: 2, 4, 8, 16, ?',
            options: ['32', '24', '30', '64'],
            correctIndex: 0,
            explanation: 'Har bir had oldingisidan 2 baravar katta: 16 × 2 = 32.',
            difficulty: 'medium',
            isAiGenerated: false,
            isDeterministicFallback: true,
          },
        ]),
        isAiGenerated: false,
        isDeterministicFallback: true,
      };
    }

    // Default: Mathematics
    return {
      lessonId: `lesson_fallback_${request.skillId}`,
      courseId: request.courseId,
      skillId: request.skillId,
      topic,
      level: request.level || 'intermediate',
      difficulty: normalizedDifficulty,
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
      questions: publishAll([
        {
          id: 'q_demo_1',
          courseId: request.courseId,
          skillId: request.skillId,
          text: 'f(x) = 2x + 3 funksiya berilgan. x = 4 bo‘lganda f(4) nechaga teng?',
          formulaLatex: 'f(4) = 2(4) + 3',
          options: ['11', '8', '14', '9'],
          correctIndex: 0,
          explanation: 'Argument o‘rniga qo‘yamiz: f(4) = 2×4 + 3 = 8 + 3 = 11.',
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
          correctIndex: 0,
          explanation: 'f(3) = 3×3 − 1 = 9 − 1 = 8.',
          difficulty: 'medium',
          isAiGenerated: false,
          isDeterministicFallback: true,
        },
      ]),
      isAiGenerated: false,
      isDeterministicFallback: true,
    };
  }

  async askTutor(request: AskTutorRequest): Promise<AskTutorResponse> {
    const topic = request.topic || 'bu mavzu';
    return {
      tutorName: 'Yo‘lchi AI',
      answer: `${topic} bo‘yicha savolingiz juda yaxshi! Keling, birgalikda qadam-baqadam ko‘rib chiqamiz: avval asosiy qoidani eslaysizmi? Uni birgalikda misolda qo‘llab ko‘ramiz.`,
      isAiGenerated: false,
      isDeterministicFallback: true,
    };
  }
}

export const demoAITutorService = new DemoAITutorService();
