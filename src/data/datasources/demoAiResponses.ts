import type {
  AIExplanationRequest,
  AIExplanationResponse,
  AskTutorRequest,
  AskTutorResponse,
} from '@/data/services/IAITutorService';
import type { Lesson, LessonFlashcard } from '@/domain/entities/Lesson';
import type { Question } from '@/domain/entities/Question';
import { getLocalizedMistakeFeedback, getLocalizedQuestionExplanation } from '@/domain/entities/Question';
interface EnglishDemoData {
  ENGLISH_ALL_LESSONS: typeof import('./english').ENGLISH_ALL_LESSONS;
  ENGLISH_ALL_LESSONS_LIST: typeof import('./english').ENGLISH_ALL_LESSONS_LIST;
  ENGLISH_ALL_QUESTIONS: typeof import('./english').ENGLISH_ALL_QUESTIONS;
  ENGLISH_FLASHCARDS_BY_LESSON: typeof import('./english/flashcards').ENGLISH_FLASHCARDS_BY_LESSON;
  PLACEMENT_QUESTIONS: typeof import('./questions').PLACEMENT_QUESTIONS;
  SEED_SKILLS: typeof import('./skills').SEED_SKILLS;
}

let englishDemoDataPromise: Promise<EnglishDemoData> | null = null;

function loadEnglishDemoData(): Promise<EnglishDemoData> {
  englishDemoDataPromise ??= Promise.all([
    import('./english'),
    import('./english/flashcards'),
    import('./questions'),
    import('./skills'),
  ]).then(([eng, fc, q, s]) => ({
    ENGLISH_ALL_LESSONS: eng.ENGLISH_ALL_LESSONS,
    ENGLISH_ALL_LESSONS_LIST: eng.ENGLISH_ALL_LESSONS_LIST,
    ENGLISH_ALL_QUESTIONS: eng.ENGLISH_ALL_QUESTIONS,
    ENGLISH_FLASHCARDS_BY_LESSON: fc.ENGLISH_FLASHCARDS_BY_LESSON,
    PLACEMENT_QUESTIONS: q.PLACEMENT_QUESTIONS,
    SEED_SKILLS: s.SEED_SKILLS,
  })).catch((err) => {
    englishDemoDataPromise = null;
    throw err;
  });
  return englishDemoDataPromise;
}

export interface AIDemoFeedback {
  courseId: string;
  questionId: string;
  misconceptionTitle: string;
  explanation: string;
  remediationStep: string;
  suggestedAction: string;
}

export const DEMO_AI_RESPONSES: Record<string, AIDemoFeedback> = {
  // Math Lesson Mistake: Chosen '8' instead of '11'
  q_math_lesson_interactive: {
    courseId: 'course_math_01',
    questionId: 'q_math_lesson_interactive',
    misconceptionTitle: 'Ozod son (+3) unutilgan',
    explanation:
      'Siz bu misolda 2 × 4 ni to‘g‘ri hisoblagansiz, lekin formuladagi +3 ozod hadini hisobga olmadingiz. To‘g‘ri natija 11 bo‘ladi.',
    remediationStep: 'Chiziqli funksiyada f(x) = ax + b tartibida har doim avval ko‘paytirish, so‘ng qo‘shish bajariladi.',
    suggestedAction: 'Keling, shu qadamni bitta qisqa mustahkamlash mashqi bilan mustahkamlaymiz.',
  },

  // English Lesson Mistake: Chosen '04:00' instead of '03:45'
  q_eng_lesson_interactive: {
    courseId: 'course_eng_01',
    questionId: 'q_eng_lesson_interactive',
    misconceptionTitle: 'Vaqt inkor iborasi e’tibordan chetda qolgan',
    explanation:
      'Siz asosiy "four" so‘zini to‘g‘ri eshitdingiz, ammo "quarter to four" (to‘rtga 15 daqiqa qoldi) va "not at four o\'clock" degan inkor iborasini noto‘g‘ri talqin qildingiz.',
    remediationStep: '"quarter to [hour]" har doim aytilgan soatdan 15 daqiqa oldingi vaqtni bildiradi.',
    suggestedAction: 'Keling, yana bitta qisqa mustahkamlash mashqini bajaramiz.',
  },
};

const SKILL_COACHING_NOTES: Record<string, { uz: string; ru: string }> = {
  skill_eng_vocab: {
    uz: 'Yangi so‘zlarni kontekstli gap va talaffuz (IPA) bilan bog‘lab eslab qoling.',
    ru: 'Запоминайте новые слова в контексте предложения и вместе с произношением (IPA).',
  },
  skill_eng_grammar: {
    uz: 'Gapdagi ega-kesim mosligi, zamon ko‘rsatkichi (time marker) va so‘z tartibini tekshiring.',
    ru: 'Проверяйте согласование подлежащего и сказуемого, маркеры времени и порядок слов.',
  },
  skill_eng_listening: {
    uz: 'Audioni tinglayotganda raqam, vaqt iborasi (in the morning/afternoon) va inkor so‘zlarga e’tibor bering.',
    ru: 'При аудировании обращайте внимание на числа, уточнения времени (in the morning/afternoon) и отрицания.',
  },
  skill_eng_reading: {
    uz: 'Matndagi kalit dalilni topib, javob variantini aynan o‘sha jumla bilan solishtiring.',
    ru: 'Найдите ключевое подтверждение в тексте и сверьте вариант ответа именно с ним.',
  },
};

function findEnglishQuestion(data: EnglishDemoData, questionId?: string): Question | undefined {
  if (!questionId) return undefined;
  return (
    data.ENGLISH_ALL_QUESTIONS.find((q) => q.id === questionId) ||
    (data.PLACEMENT_QUESTIONS['course_eng_01'] ?? []).find((q) => q.id === questionId)
  );
}

function findEnglishLesson(
  data: EnglishDemoData,
  lessonId?: string,
  questionId?: string,
  skillId?: string,
): Lesson | undefined {
  if (lessonId && data.ENGLISH_ALL_LESSONS[lessonId]) {
    return data.ENGLISH_ALL_LESSONS[lessonId];
  }
  if (questionId) {
    const byQuestion = data.ENGLISH_ALL_LESSONS_LIST.find(
      (lesson) =>
        lesson.reinforcementExercise?.id === questionId ||
        lesson.alternateExercise?.id === questionId ||
        lesson.steps.some((step) => step.interactiveQuestion?.id === questionId)
    );
    if (byQuestion) return byQuestion;
  }
  if (skillId) {
    return data.ENGLISH_ALL_LESSONS_LIST.find((lesson) => lesson.skillId === skillId);
  }
  return undefined;
}

function collectSecretAnswers(question?: Question): string[] {
  if (!question) return [];
  const secrets = new Set<string>();
  const addSecret = (raw?: string) => {
    const trimmed = raw?.trim();
    if (!trimmed) return;
    if (trimmed.length >= 2) secrets.add(trimmed);
    const withoutTrailingPunct = trimmed.replace(/[.!?]+$/g, '').trim();
    if (withoutTrailingPunct.length >= 2) secrets.add(withoutTrailingPunct);
  };

  if (
    question.correctIndex !== undefined &&
    question.options[question.correctIndex]
  ) {
    addSecret(question.options[question.correctIndex]);
  }
  for (const ans of question.acceptedAnswers ?? []) {
    addSecret(ans);
  }
  for (const pair of question.matchPairs ?? []) {
    addSecret(pair.left);
    addSecret(pair.right);
  }
  if (question.orderedTokens?.length) {
    addSecret(question.orderedTokens.join(' '));
  }
  if (question.sampleResponse?.trim()) {
    addSecret(question.sampleResponse);
  }
  return Array.from(secrets).sort((a, b) => b.length - a.length);
}

const APOSTROPHE_PATTERN = "['’‘`´\\u02BB\\u02BC]";

function buildSecretBoundaryRegex(secret: string): RegExp {
  const normalizedSecret = secret.replace(/[’‘`´\u02BB\u02BC]/g, "'");
  const escaped = normalizedSecret
    .replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    .replace(/'/g, APOSTROPHE_PATTERN);
  return new RegExp(
    `(?<![\\p{L}\\p{N}_'’‘\`´\\u02BB\\u02BC])${escaped}(?![\\p{L}\\p{N}_'’‘\`´\\u02BB\\u02BC])`,
    'giu',
  );
}

function normalizeTokenComparison(value: string): string {
  return value
    .toLowerCase()
    .replace(/[’‘`´\u02BB\u02BC]/g, "'")
    .replace(/\s+/g, ' ')
    .replace(/[.!?]+$/g, '')
    .trim();
}

function containsSecretToken(text: string, question?: Question): boolean {
  if (!question || !text.trim()) return false;
  const secrets = collectSecretAnswers(question);
  if (secrets.length === 0) return false;
  return secrets.some((secret) => buildSecretBoundaryRegex(secret).test(text));
}

function sanitizeNoSpoilers(text: string, question?: Question): string {
  if (!question) return text;
  const secrets = collectSecretAnswers(question);
  let output = text;
  for (const secret of secrets) {
    output = output.replace(buildSecretBoundaryRegex(secret), '[...]');
  }
  return output;
}

function pickSafeFlashcard(cards: LessonFlashcard[], question?: Question): LessonFlashcard | undefined {
  if (!question) return cards[0];
  const secrets = collectSecretAnswers(question).map(normalizeTokenComparison);
  return cards.find((card) => {
    const fields = [
      card.front,
      card.backUz,
      card.backRu,
      card.example,
      card.exampleUz,
      card.exampleRu,
    ].filter((f): f is string => Boolean(f && f.trim()));
    return !fields.some((field) => {
      if (containsSecretToken(field, question)) return true;
      const normField = normalizeTokenComparison(field);
      return secrets.some((secret) => normField === secret);
    });
  });
}

function selectSafeRuleCue(
  lesson: Lesson | undefined,
  question: Question | undefined,
  skillId: string | undefined,
  lang: 'uz' | 'ru',
): string {
  if (lesson) {
    for (const step of lesson.steps) {
      const notes = lang === 'ru' ? step.highlightNotesRu : step.highlightNotes;
      for (const note of notes ?? []) {
        if (note.trim() && !containsSecretToken(note, question)) {
          return note;
        }
      }
    }
  }
  return (skillId ? SKILL_COACHING_NOTES[skillId]?.[lang] : undefined) || '';
}

function selectSafeCanDo(
  lesson: Lesson | undefined,
  question: Question | undefined,
  lang: 'uz' | 'ru',
): string {
  if (!lesson) return '';
  const raw = lang === 'ru' && lesson.canDoObjectiveRu ? lesson.canDoObjectiveRu : lesson.canDoObjective || '';
  if (!raw.trim()) return '';
  return containsSecretToken(raw, question) ? '' : raw;
}

function selectSafeLessonTitle(
  lesson: Lesson | undefined,
  question: Question | undefined,
  lang: 'uz' | 'ru',
  fallback = '',
): string {
  const rawTitle = lesson
    ? (lang === 'ru' && lesson.titleRu ? lesson.titleRu : lesson.title)
    : fallback;
  if (!rawTitle.trim()) return '';
  if (!question || !containsSecretToken(rawTitle, question)) {
    return rawTitle;
  }
  const stripped = rawTitle.replace(/\s*\([^)]*\)/g, '').trim();
  const candidate = stripped || fallback;
  if (!candidate.trim()) return '';
  return containsSecretToken(candidate, question)
    ? sanitizeNoSpoilers(candidate, question)
    : candidate;
}

function selectSafeHelloMessage(question: Question | undefined, lang: 'uz' | 'ru'): string {
  const candidates =
    lang === 'ru'
      ? [
          '«Hello» используется как универсальное приветствие в любое время дня, затем можно представиться: «I\'m ...» или «My name is ...».',
          'Привет! В начале диалога обычно используют нейтральное приветствие «Hi!» или «Hello!».',
          'Привет! Разберём задание шаг за шагом — обратите внимание на контекст вопроса.',
        ]
      : [
          '«Hello» — istalgan vaqtda ishlatiladigan neytral salomlashuv. Salomlashgach, o‘zingizni «I\'m ...» yoki «My name is ...» deb tanishtirasiz.',
          'Salom! Suhbat boshida «Hi!» yoki «Hello!» kabi neytral salomlashuvdan foydalanishingiz mumkin.',
          'Salom! Qadam-baqadam davom etamiz — savoldagi kontekstga e’tibor bering.',
        ];
  return candidates.find((text) => !containsSecretToken(text, question)) ?? candidates[candidates.length - 1];
}

export function isAnswerRevealRequest(message: string): boolean {
  const normalized = message
    .toLowerCase()
    .replace(/[’‘`´\u02BB\u02BC]/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
  return [
    /to'g'ri\s+(?:javob|variant|yechim)/i,
    /\bto'g'risini\b/i,
    /(?:^|[^\p{L}\p{N}_])to'g'risi\s+(?:nima|qaysi)(?:$|[^\p{L}\p{N}_])/iu,
    /(?:javob|javobi|javobini|javobni|yechim|yechimi|yechimini)\s+(?:nima|qaysi|ayt|aytib|ber|ko'rsat|yoz)/i,
    /(?:ayt|aytib ber|ko'rsat|yoz|ber)(?:ing)?\s+(?:javob|javobni|yechim|yechimni|to'g'risini)/i,
    /tayyor\s+(?:javob|yechim)/i,
    /qaysi\s+(?:javob|variant|biri|birini|qaysinisini)\s+(?:to'g'ri|tanlay|belgilay|bosay)/i,
    /(?:^|[^\p{L}\p{N}_])qaysi\s+(?:birini\s+|biri\s+|javobni\s+|variantni\s+)?(?:tanlay|belgilay|bosay)(?:$|[^\p{L}\p{N}_])/iu,
    /qaysinisini\s+(?:tanlay|belgilay|bosay)/i,
    /qaysi\s+(?:javob|variant|biri)\s*\??$/i,
    /(?:скажи|скажите|дай|дайте|покажи|покажите|подскажи|подскажите|назови|назовите)(?:\s+мне)?(?:\s+пожалуйста)?(?:\s+(?:правильный|верный|точный|готовый|правильное|верное|готовое))?\s+(?:ответ|вариант|решение)/iu,
    /(?:^|[^\p{L}\p{N}_])(?:ответ|вариант|решение)\s+(?:скажи|скажите|дай|дайте|подскажи|подскажите|назови|назовите|покажи|покажите)(?:$|[^\p{L}\p{N}_])/iu,
    /(?:^|[^\p{L}\p{N}_])(?:правильный|верный|точный)\s+(?:ответ|вариант)\s*\?/iu,
    /^(?:правильный|верный|точный)\s+(?:ответ|вариант)\s*[.!?]*$/iu,
    /(?:^|[^\p{L}\p{N}_])что\s+(?:мне\s+|тут\s+|здесь\s+)?(?:выбрать|ответить|нажать|указать)(?:$|[^\p{L}\p{N}_])/iu,
    /(?:какой|какое)\s+(?:правильный\s+|верный\s+|точный\s+)?(?:ответ|вариант|решение)/iu,
    /какой\s+(?:вариант|из\s+них)\s+(?:правильный|верный|выбрать|нажать)/iu,
    /готовый\s+ответ|готовое\s+решение/iu,
    /(?:tell|give|show|reveal)(?:\s+me)?(?:\s+just)?(?:\s+the)?(?:\s+(?:correct|right|exact))?\s+(?:answer|option|solution)\b/i,
    /\bjust\s+(?:tell|give|show)\s+(?:me\s+)?(?:the\s+)?(?:answer|option|solution)\b/i,
    /\bwhat(?:'s|\s+is)\s+the\s+(?:correct|right|exact\s+)?(?:answer|option|solution)\b/i,
    /\bwhich\s+(?:answer|option|one)\s+(?:is\s+(?:correct|right)|(?:should|do)\s+i\s+(?:choose|pick|select|click|press))\b/i,
    /\bwhat\s+(?:should|do)\s+i\s+(?:choose|pick|select|answer)\b/i,
    /^(?:answer|solution)\s+please\b|\b(?:correct|right)\s+(?:answer|option|solution)\s+please\b/i,
  ].some((pattern) => pattern.test(normalized));
}

export async function buildEnglishMistakeExplanation(
  request: AIExplanationRequest,
): Promise<AIExplanationResponse> {
  const data = await loadEnglishDemoData();
  const lang: 'uz' | 'ru' = request.language === 'ru' ? 'ru' : 'uz';
  const question = findEnglishQuestion(data, request.questionId);
  const resolvedSkillId = question?.skillId || request.skillId;
  const lesson = findEnglishLesson(data, request.lessonId, request.questionId, resolvedSkillId);
  const skill = data.SEED_SKILLS.find((s) => s.id === resolvedSkillId);
  const lessonTitle = selectSafeLessonTitle(lesson, question, lang, '');
  const canDo = selectSafeCanDo(lesson, question, lang);
  const ruleCue = selectSafeRuleCue(lesson, question, resolvedSkillId, lang);

  const normalizedSelection = request.selectedOption
    .trim()
    .toLowerCase()
    .replace(/[’‘`´\u02BB\u02BC]/g, "'")
    .replace(/[.,!?]+$/g, '');

  let explanationText = '';
  if (request.questionId === 'q_lesson_eng_starter_quiz') {
    if (normalizedSelection === 'sam') {
      explanationText =
        lang === 'ru'
          ? 'Одного имени недостаточно. Чтобы представиться по-английски, используйте полную конструкцию «I\'m [имя]» или «My name is [имя]».'
          : 'Faqat ismning o‘zi yetarli emas. Ingliz tilida o‘zingizni tanishtirish uchun «I\'m [ism]» yoki «My name is [ism]» shaklida to‘liq gap tuzing.';
    } else if (normalizedSelection === 'goodbye' || normalizedSelection === 'bye') {
      explanationText =
        lang === 'ru'
          ? '«Goodbye» означает прощание. На вопрос «What\'s your name?» отвечают представлением: «I\'m ...» или «My name is ...».'
          : '«Goodbye» xayrlashuv so‘zi. «What\'s your name?» savoliga «I\'m ...» yoki «My name is ...» deb javob beriladi.';
    } else if (normalizedSelection === 'hello' || normalizedSelection === 'hi') {
      explanationText =
        lang === 'ru'
          ? 'Приветствие верное, но собеседник спросил имя. Добавьте «I\'m ...» или «My name is ...».'
          : 'Salomlashish to‘g‘ri, lekin ismingizni ham aytishingiz kerak: «I\'m ...» yoki «My name is ...» shaklida davom ettiring.';
    }
  }

  if (!explanationText && question) {
    const qType = question.questionType ?? 'multiple_choice';
    if (
      qType === 'text_input' ||
      qType === 'fill_blank' ||
      qType === 'word_match' ||
      qType === 'sentence_order' ||
      qType === 'speaking_prompt' ||
      qType === 'writing_prompt'
    ) {
      explanationText =
        (lang === 'ru' ? question.wrongFeedbackRu : undefined) ||
        question.wrongFeedback ||
        getLocalizedQuestionExplanation(question, lang);
      explanationText = sanitizeNoSpoilers(explanationText, question);
    } else {
      explanationText = getLocalizedMistakeFeedback(question, request.selectedOption, lang);
    }
  }

  if (!explanationText) {
    explanationText =
      lang === 'ru'
        ? `Выбранный вариант (${request.selectedOption}) не подходит по смыслу или грамматике. Проверьте подсказку правила.`
        : `Tanlangan javob (${request.selectedOption}) ushbu kontekst yoki qoida bilan mos kelmadi. Qoidani qadam-baqadam tekshiring.`;
  }

  const cefrPrefix = lesson?.cefrLevel ? `[${lesson.cefrLevel}] ` : '';
  const title =
    lang === 'ru'
      ? `${cefrPrefix}${skill?.name ?? 'English'}: разбор ошибки`
      : `${cefrPrefix}${skill?.name ?? 'Ingliz tili'}: xato tahlili`;

  const rawRemediationStep =
    [canDo, ruleCue].filter(Boolean).join(' — ') ||
    (lang === 'ru'
      ? 'Повторите правило урока и сравните вариант с примером.'
      : 'Dars qoidasini va misolni qayta ko‘rib, variantni solishtiring.');
  const remediationStep = sanitizeNoSpoilers(rawRemediationStep, question);

  const scoreHint =
    typeof request.learnerScore === 'number' && request.learnerScore < 70
      ? lang === 'ru'
        ? ` Текущий уровень по навыку: ${request.learnerScore}% — закрепите тему дополнительным упражнением.`
        : ` Joriy ko‘nikma natijasi: ${request.learnerScore}% — qo‘shimcha mashq bilan 70%+ ga chiqaring.`
      : '';
  const mistakeHint =
    request.recentMistakes?.length
      ? lang === 'ru'
        ? ` Учтены недавние ошибки (${request.recentMistakes[0]}).`
        : ` So‘nggi xatolar (${request.recentMistakes[0]}) ham inobatga olindi.`
      : '';

  const rawSuggestedAction =
    (lang === 'ru'
      ? `Откройте закрепляющее упражнение${lessonTitle ? ` по теме «${lessonTitle}»` : ''}.${scoreHint}${mistakeHint}`
      : `${lessonTitle ? `«${lessonTitle}» mavzusi bo‘yicha ` : ''}mustahkamlash mashqini bajarib ko‘ring.${scoreHint}${mistakeHint}`).trim();
  const suggestedAction = sanitizeNoSpoilers(rawSuggestedAction, question);

  return {
    tutorName: 'Yo‘lchi AI',
    title,
    explanation: sanitizeNoSpoilers(explanationText, question),
    remediationStep,
    suggestedAction,
    reinforcementNeeded: true,
    isDeterministicFallback: true,
  };
}

export async function buildEnglishTutorReply(request: AskTutorRequest): Promise<AskTutorResponse> {
  const data = await loadEnglishDemoData();
  const lang: 'uz' | 'ru' = request.language === 'ru' ? 'ru' : 'uz';
  const question = findEnglishQuestion(data, request.questionId);
  const resolvedSkillId = request.questionSkillId || question?.skillId || request.skillId;
  const lesson = findEnglishLesson(data, request.lessonId, request.questionId, resolvedSkillId);
  const skill = data.SEED_SKILLS.find((s) => s.id === resolvedSkillId);
  const flashcards = lesson ? (data.ENGLISH_FLASHCARDS_BY_LESSON[lesson.id] ?? []) : [];
  const safeCard = pickSafeFlashcard(flashcards, question);

  const lessonTitle = selectSafeLessonTitle(
    lesson,
    question,
    lang,
    request.topic || (lang === 'ru' ? 'Английский язык' : 'Ingliz tili'),
  );
  const cefrTag = lesson?.cefrLevel ?? question?.cefrLevel ?? 'A1–B1';
  const canDo = selectSafeCanDo(lesson, question, lang) || undefined;
  const ruleCue = selectSafeRuleCue(lesson, question, resolvedSkillId, lang) || undefined;

  const answerReveal = isAnswerRevealRequest(request.message);

  if (answerReveal) {
    const qType = question?.questionType ?? 'multiple_choice';
    let strategyHint = '';
    if (qType === 'text_input' || qType === 'fill_blank') {
      strategyHint =
        lang === 'ru'
          ? 'Проверьте структуру фразы (подлежащее + глагол + недостающее слово) и обратите внимание на подсказку в вопросе.'
          : 'Gap tuzilishini tekshiring (ega + fe’l + kerakli so‘z) va savoldagi shaklga qarab o‘zingiz yozib ko‘ring.';
    } else if (qType === 'word_match') {
      strategyHint =
        lang === 'ru'
          ? 'Сначала соедините самые очевидные пары слов, затем проверьте оставшиеся по части речи.'
          : 'Avval aniq biladigan so‘z juftliklarini moslang, so‘ng qolganlarini so‘z turkumi bo‘yicha tekshiring.';
    } else if (qType === 'sentence_order') {
      strategyHint =
        lang === 'ru'
          ? 'Соберите сначала основу предложения (подлежащее + глагол), а затем добавьте дополнение и время.'
          : 'Avval gap asosini (ega + kesim) qo‘ying, keyin to‘ldiruvchi va vaqt ko‘rsatkichini joylashtiring.';
    } else {
      strategyHint =
        lang === 'ru'
          ? 'Исключите варианты, которые не совпадают по времени, числу или контексту, и выберите оставшийся.'
          : 'Zamon, birlik/ko‘plik yoki suhbat kontekstiga zid variantlarni chiqarib tashlang va mosini tekshiring.';
    }

    const scaffold =
      lang === 'ru'
        ? `Готовый ответ я не подсказываю. Давайте разберём вопрос по шагам (${cefrTag} · ${lessonTitle}): 1) ${ruleCue || 'Вспомните главное правило урока.'} 2) ${strategyHint}${canDo ? ` Цель: ${canDo}` : ''}`
        : `To‘g‘ri javobni tayyor holda bera olmayman — keling, uni qadam-baqadam birga topamiz (${cefrTag} · ${lessonTitle}): 1) ${ruleCue || 'Darsdagi asosiy qoidani eslang.'} 2) ${strategyHint}${canDo ? ` Maqsad: ${canDo}` : ''}`;

    return {
      tutorName: 'Yo‘lchi AI',
      answer: sanitizeNoSpoilers(scaffold, question),
      isAiGenerated: false,
      isDeterministicFallback: true,
    };
  }

  const msgLower = request.message.toLowerCase();
  const asksExample = /misol|example|пример/i.test(msgLower);
  const asksHello = /\bhello\b|\bhi\b|salom|привет/i.test(msgLower);

  const parts: string[] = [];
  if (lang === 'ru') {
    parts.push(`Давайте разберём вопрос по шагам (${cefrTag} · ${lessonTitle}${skill ? ` · ${skill.name}` : ''}).`);
    if (canDo) parts.push(`Цель урока: ${canDo}`);
    if (ruleCue) parts.push(`Ключевое правило: ${ruleCue}`);
    if (asksHello) {
      parts.push(selectSafeHelloMessage(question, 'ru'));
    } else if (asksExample && safeCard) {
      parts.push(`Пример с карточки: «${safeCard.front}» (${safeCard.backRu}) — «${safeCard.example}».`);
    } else if (safeCard) {
      parts.push(`Полезное слово урока: «${safeCard.front}»${safeCard.ipa ? ` [${safeCard.ipa}]` : ''} — ${safeCard.backRu}.`);
    }
    if (typeof request.learnerScore === 'number' && request.learnerScore < 70) {
      parts.push(`Ваш текущий показатель по навыку (${request.learnerScore}%) требует практики — попробуйте выполнить задание ещё раз без подсказки ответа.`);
    }
    if (request.recentMistakes?.length) {
      parts.push(`Обратите внимание на прошлую сложность: ${request.recentMistakes[0]}.`);
    }
  } else {
    parts.push(`Keling, «${lessonTitle}» (${cefrTag}${skill ? ` · ${skill.name}` : ''}) mavzusini qadam-baqadam ko‘rib chiqamiz.`);
    if (canDo) parts.push(`Dars maqsadi: ${canDo}`);
    if (ruleCue) parts.push(`Asosiy qoida: ${ruleCue}`);
    if (asksHello) {
      parts.push(selectSafeHelloMessage(question, 'uz'));
    } else if (asksExample && safeCard) {
      parts.push(`Namuna: «${safeCard.front}» (${safeCard.backUz}) — «${safeCard.example}».`);
    } else if (safeCard) {
      parts.push(`Kalit so‘z: «${safeCard.front}»${safeCard.ipa ? ` [${safeCard.ipa}]` : ''} — ${safeCard.backUz}.`);
    }
    if (typeof request.learnerScore === 'number' && request.learnerScore < 70) {
      parts.push(`Joriy ko‘nikma natijangiz ${request.learnerScore}% — 70%+ ga chiqish uchun qoidani misolda qo‘llab ko‘ring.`);
    }
    if (request.recentMistakes?.length) {
      parts.push(`So‘nggi xato eslatmasi: ${request.recentMistakes[0]}.`);
    }
  }

  return {
    tutorName: 'Yo‘lchi AI',
    answer: sanitizeNoSpoilers(parts.join(' '), question),
    isAiGenerated: false,
    isDeterministicFallback: true,
  };
}
