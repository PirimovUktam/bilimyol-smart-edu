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
import {
  DEMO_AI_RESPONSES,
  buildEnglishMistakeExplanation,
  buildEnglishTutorReply,
} from '../datasources/demoAiResponses';
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
      if (request.questionId === 'q_eng_lesson_interactive' && request.language === 'ru') {
        return {
          tutorName: 'Yölçi AI',
          title: 'Не учтено отрицание во времени',
          explanation:
            'Вы верно услышали слово «four», но не обратили внимания на оборот «quarter to four» (без 15 минут четыре) и отрицание «not at four o\'clock».',
          remediationStep: 'Выражение «quarter to [hour]» всегда обозначает время на 15 минут раньше названного часа.',
          suggestedAction: 'Давайте закрепим эту тему коротким упражнением.',
          isDeterministicFallback: true,
        };
      }
      return {
        tutorName: 'Yölçi AI',
        title: matched.misconceptionTitle,
        explanation: matched.explanation,
        remediationStep: matched.remediationStep,
        suggestedAction: matched.suggestedAction,
        isDeterministicFallback: true,
      };
    }

    if (request.courseId === 'course_eng_01') {
      return buildEnglishMistakeExplanation(request);
    }

    // Generic pedagogical fallback for any other question
    if (request.language === 'ru') {
      const correctLineRu = request.correctOption
        ? `Правильный ответ: ${request.correctOption}.`
        : '';
      return {
        tutorName: 'Yölçi AI',
        title: 'Разбор ошибки',
        explanation: `Выбранный ответ (${request.selectedOption}) неверный. ${correctLineRu}`.trim(),
        remediationStep: 'Проверьте решение шаг за шагом, чтобы закрепить тему.',
        suggestedAction: 'Давайте закрепим этот навык коротким упражнением.',
        isDeterministicFallback: true,
      };
    }
    const correctLine = request.correctOption
      ? `Töğri javob: ${request.correctOption}.`
      : '';
    return {
      tutorName: 'Yölçi AI',
      title: 'Xatoni tahlil qiliş',
      explanation: `Siz tanlagan javob (${request.selectedOption}) töğri emas. ${correctLine}`.trim(),
      remediationStep: 'Mavzuni töliq özlaştiriş uçun yeçimni qadamma-qadam tekşirib çiqing.',
      suggestedAction: 'Keling, uşbu könikmani mustahkamlaş maşqi bilan tekşiramiz.',
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
        title: `${topic} böyiça ingliz tili darsi`,
        summary: 'Ingliz tili könikmalarini mustahkamlaş: kalit iboralar, talaffuz va amaliy maşqlar.',
        objective: 'Tinglab tuşuniş, yangi sözlar va grammatika böyiça bilimni oşiriş.',
        estimatedMinutes: 12,
        steps: [
          {
            id: 'step_1',
            stepNumber: 1,
            type: 'concept',
            title: '1. Asosiy Qoida va Luğat',
            content: 'Ingliz tilida mazmunni töliq tuşuniş uçun kalit sözlarga va kontekstga e’tibor beriş lozim.',
            highlightNotes: ['Kalit sözlarni ajratib oling', 'Gapdagi asosiy fe’l va ot munosabatiga qarang'],
          },
          {
            id: 'step_2',
            stepNumber: 2,
            type: 'visual_example',
            title: '2. Audio Xabar Tahlili',
            content: 'Quyidagi audio tölqin va talaffuz ifodasini tinglang:',
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
            title: '3. Amaliy Qöllaniş',
            content: 'Mavzuni kundalik suhbat va yozuvda mustahkamlaş qoidalari.',
          },
          {
            id: 'step_4',
            stepNumber: 4,
            type: 'interactive_question',
            title: '4. Sinov Savoli',
            content: 'Örgangan könikmangizni quyidagi savol bilan sinab köring.',
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
            explanation: 'Darsga köra, doimiy maşq söz boyligini mukammal egallaşga olib keladi.',
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
            explanation: 'Otdan oldin sifat keladi: "deep understanding" — "juda çuqur tuşunça".',
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
        title: `${topic} böyiça IT va dasturlaş darsi`,
        summary: 'Dasturlaş asoslari, özgaruvçilar va algoritmlaş mantiqi.',
        objective: 'Kod yoziş va kompyuter fanlari tuşunçalarini özlaştiriş.',
        estimatedMinutes: 15,
        steps: [
          {
            id: 'step_1',
            stepNumber: 1,
            type: 'concept',
            title: '1. Algoritm nima?',
            content: 'Algoritm — bu belgilangan maqsadga erişiş uçun kompyuter bajarişi kerak bölgan qadamma-qadam körsatmalar ketma-ketligidir.',
            highlightNotes: ['Ketma-ketlik buzilmasligi şart', 'Har bir qadam aniq va tuşunarli bölişi lozim'],
          },
          {
            id: 'step_2',
            stepNumber: 2,
            type: 'concept',
            title: '2. Özgaruvçilar va ma’lumot turlari',
            content: 'Dasturda ma’lumotlarni saqlaş uçun özgaruvçilardan (variables) foydalaniladi: sonlar, matnlar va mantiqiy qiymatlar.',
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
            text: 'Python tilida matnli qiymat (string) qaysi belgilar içida yoziladi?',
            options: ['Qöştirnoq yoki bittalik tirnoq', 'Kvadrat qavslar', 'Katta-kiçik belgilari', 'Heç qanday belgisiz'],
            correctIndex: 0,
            explanation: 'Python’da satr (string) qöştirnoq ("...") yoki bittalik tirnoq (\'...\') içida yoziladi.',
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
        title: `${topic} böyiça mantiqiy fikrlaş darsi`,
        summary: 'Deduktiv mantiq, naqşlar va tahliliy xulosalar çiqariş.',
        objective: 'Mantiqiy ketma-ketliklarni töğri topiş va qaror qabul qiliş.',
        estimatedMinutes: 12,
        steps: [
          {
            id: 'step_1',
            stepNumber: 1,
            type: 'concept',
            title: '1. Mantiqiy Qonuniyat',
            content: 'Ketma-ketlikdagi har bir keyingi son oldingi hadlarning özaro qonuniyati asosida şakllanadi.',
            highlightNotes: ['Farqlar orasidagi oraliqni örganing', 'Köpaytiriş yoki qöşiş mantiqini tekşiring'],
          },
          {
            id: 'step_2',
            stepNumber: 2,
            type: 'interactive_question',
            title: '2. Mantiqiy Boşqotirma',
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
      title: `${topic} böyiça interaktiv dars`,
      summary: 'Asosiy nazariy qoidalar va amaliy namunalar jamlanmasi.',
      objective: 'Mavzu böyiça tuşunçalarni mustahkamlaş.',
      estimatedMinutes: 15,
      steps: [
        {
          id: 'step_1',
          stepNumber: 1,
          type: 'concept',
          title: 'Asosiy tuşunça',
          content: 'Çiziqli funksiya f(x) = kx + b körinişida ifodalanadi.',
          highlightNotes: ['k — burçak koeffitsiyenti', 'b — ozod had'],
        },
        {
          id: 'step_2',
          stepNumber: 2,
          type: 'formula',
          title: 'Hisoblaş qoidasi',
          content: 'x ning berilgan qiymatini formulaga qöyib hisoblaş.',
          formulaData: {
            latex: 'f(x) = 2x + 3',
            description: 'Çiziqli funksiya formulasi',
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
          content: 'Agar x = 4 bölsa, f(4) = 2(4) + 3 = 11 böladi.',
        },
        {
          id: 'step_4',
          stepNumber: 4,
          type: 'interactive_question',
          title: 'Mustahkamlaş',
          content: 'Örganganlaringizni sinab köring.',
        },
      ],
      questions: publishAll([
        {
          id: 'q_demo_1',
          courseId: request.courseId,
          skillId: request.skillId,
          text: 'f(x) = 2x + 3 funksiya berilgan. x = 4 bölganda f(4) neçaga teng?',
          formulaLatex: 'f(4) = 2(4) + 3',
          options: ['11', '8', '14', '9'],
          correctIndex: 0,
          explanation: 'Argument örniga qöyamiz: f(4) = 2×4 + 3 = 8 + 3 = 11.',
          difficulty: 'medium',
          isAiGenerated: false,
          isDeterministicFallback: true,
        },
        {
          id: 'q_demo_2',
          courseId: request.courseId,
          skillId: request.skillId,
          text: 'f(x) = 3x - 1 funksiya berilgan. x = 3 bölganda f(3) neçaga teng?',
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
    if (request.courseId === 'course_eng_01') {
      return buildEnglishTutorReply(request);
    }
    const topic = request.topic || 'bu mavzu';
    return {
      tutorName: 'Yölçi AI',
      answer: request.language === 'ru'
        ? 'Давайте разберём вопрос по шагам. Какое правило здесь подходит? Попробуйте применить его к простому примеру.'
        : `${topic} böyiça savolingiz juda yaxşi! Keling, birgalikda qadam-baqadam körib çiqamiz: avval asosiy qoidani eslaysizmi? Uni birgalikda misolda qöllab köramiz.`,
      isAiGenerated: false,
      isDeterministicFallback: true,
    };
  }
}

export const demoAITutorService = new DemoAITutorService();
