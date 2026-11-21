import {
  ILearnerRepository,
  AnswerAttemptRecord,
  PlacementAttemptData,
  ReinforcementCompletionContext,
  SubmitAnswerAttemptRequest,
  SubmitAnswerAttemptResult,
  DailyActivitySummary,
} from '@/domain/repositories/ILearnerRepository';
import { LearnerProfile } from '@/domain/entities/LearnerProfile';
import { SkillScore } from '@/domain/entities/SkillScore';
import { computeNextFlashcardSrs } from '@/domain/personalization/FlashcardSrsEngine';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import { PLACEMENT_QUESTIONS } from '@/data/datasources/questions';
import { SEED_LESSONS } from '@/data/datasources/lessons';
import { SEED_ROADMAP_NODES } from '@/data/datasources/roadmaps';
import { getQuestionAnswerKey } from '@/core/runtime/questionAnswerKeys';
import {
  Question,
  evaluateSentenceOrder,
  evaluateWordMatch,
  getLocalizedMistakeFeedback,
  getLocalizedQuestionExplanation,
  matchesAcceptedAnswer,
  normalizeFreeTextAnswer,
} from '@/domain/entities/Question';

function buildFreeTextWrongFeedback(
  rawAnswer: string,
  question: Question,
  language: 'uz' | 'ru' = 'uz'
): string {
  const normalized = normalizeFreeTextAnswer(rawAnswer);
  if (question.id === 'q_lesson_eng_starter_quiz') {
    if (!normalized) {
      return language === 'ru'
        ? 'Поле ответа пустое. Напишите полную фразу знакомства на английском.'
        : 'Javob maydoni bo‘sh. Ingliz tilida to‘liq tanishuv gapini yozing.';
    }
    if (normalized === 'sam') {
      return language === 'ru'
        ? 'Одного имени недостаточно. Чтобы представиться по-английски, напишите полную фразу с «I\'m ...» или «My name is ...».'
        : 'Faqat ismning o‘zi yetarli emas. Ingliz tilida o‘zingizni tanishtirish uchun «I\'m ...» yoki «My name is ...» shaklida to‘liq gap yozing.';
    }
    if (normalized === 'goodbye' || normalized === 'bye' || normalized === 'good bye') {
      return language === 'ru'
        ? '«Goodbye» означает «до свидания». Собеседник спросил ваше имя («What\'s your name?»), поэтому ответьте фразой «I\'m ...» или «My name is ...».'
        : '«Goodbye» — xayrlashuv so‘zi. Suhbatdosh «What\'s your name?» deb ismingizni so‘radi, shuning uchun «I\'m ...» yoki «My name is ...» deb o‘zingizni tanishtiring.';
    }
    if (normalized === 'hello' || normalized === 'hi') {
      return language === 'ru'
        ? 'Приветствие верное, но нужно также назвать своё имя с помощью «I\'m ...» или «My name is ...».'
        : 'Salomlashish yaxshi, lekin ismingizni ham aytishingiz kerak. «I\'m ...» yoki «My name is ...» shaklida to‘liq gap yozing.';
    }
  } else if (!normalized) {
    return language === 'ru'
      ? 'Поле ответа пустое. Напишите ответ на английском.'
      : 'Javob maydoni bo‘sh. Ingliz tilida javob yozing.';
  }
  return getLocalizedMistakeFeedback(question, rawAnswer, language);
}

function parseWordMatchSubmission(rawAnswer: string): Record<string, string> {
  try {
    const parsed = JSON.parse(rawAnswer) as unknown;
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed as Record<string, string>;
    }
  } catch { /* fallback empty */ }
  return {};
}

function canonicalizeWordMatchJson(rawAnswer: string): string {
  const parsed = parseWordMatchSubmission(rawAnswer);
  const sortedEntries = Object.entries(parsed).sort(([a], [b]) => a.localeCompare(b));
  return JSON.stringify(Object.fromEntries(sortedEntries));
}

function parseSentenceOrderSubmission(rawAnswer: string): string[] {
  try {
    const parsed = JSON.parse(rawAnswer) as unknown;
    if (Array.isArray(parsed)) {
      return parsed.filter((item): item is string => typeof item === 'string');
    }
  } catch { /* fallback split */ }
  return rawAnswer.trim() ? rawAnswer.trim().split(/\s+/) : [];
}

function parseSelfAssessedSubmission(rawAnswer: string): { response: string; criteria: string[] } {
  try {
    const parsed = JSON.parse(rawAnswer) as unknown;
    if (parsed && typeof parsed === 'object' && 'response' in parsed) {
      const obj = parsed as { response?: unknown; criteria?: unknown };
      return {
        response: typeof obj.response === 'string' ? obj.response.trim() : '',
        criteria: Array.isArray(obj.criteria)
          ? obj.criteria.filter((c): c is string => typeof c === 'string')
          : [],
      };
    }
  } catch { /* raw string fallback */ }
  return { response: rawAnswer.trim(), criteria: [] };
}

const DEFAULT_PROFILE: LearnerProfile = {
  id: 'learner_default_01',
  name: 'Foydalanuvchi',
  firstName: 'Foydalanuvchi',
  lastName: '',
  email: '',
  selectedCourseId: 'course_math_01',
  goal: 'mastery',
  dailyMinutes: 15,
  initialLevel: 'intermediate',
  xp: 0,
  streakDays: 0,
  lastActiveDate: '',
  scoresByCourse: {},
  placementScoreByCourse: {},
  placementCefrByCourse: {},
  placementSkillScoresByCourse: {},
  completedLessonIds: [],
  completedNodeIds: [],
  completedReinforcementIds: [],
  flashcardSrsByCourse: {},
  createdAt: Date.now(),
};

// Deep clone: DEFAULT_PROFILE's nested objects/arrays must NEVER be shared
// between repository instances (shallow spreads leaked completed-node and
// score state across instances — a cross-profile data leak).
const createDefaultProfile = (): LearnerProfile =>
  JSON.parse(JSON.stringify(DEFAULT_PROFILE)) as LearnerProfile;
const DEMO_PROGRESS_KEY = 'bilimyol_demo_progress';

const isPlainRecord = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === 'object' && !Array.isArray(value);

const normalizeStringArray = (value: unknown): string[] =>
  Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : [];

const normalizeNestedRecordMap = <T,>(value: unknown): Record<string, Record<string, T>> => {
  if (!isPlainRecord(value)) return {};
  const result: Record<string, Record<string, T>> = {};
  for (const [courseId, inner] of Object.entries(value)) {
    if (isPlainRecord(inner)) {
      result[courseId] = inner as Record<string, T>;
    }
  }
  return result;
};

const normalizeStoredProfile = (raw: unknown): LearnerProfile => {
  const defaults = createDefaultProfile();
  if (!isPlainRecord(raw)) return defaults;

  const dailyMinutes =
    raw.dailyMinutes === 15 || raw.dailyMinutes === 30 || raw.dailyMinutes === 60
      ? raw.dailyMinutes
      : defaults.dailyMinutes;
  const goal =
    raw.goal === 'mastery' || raw.goal === 'exam_prep' || raw.goal === 'skills_boost'
      ? raw.goal
      : defaults.goal;
  const initialLevel =
    raw.initialLevel === 'beginner' || raw.initialLevel === 'intermediate' || raw.initialLevel === 'advanced'
      ? raw.initialLevel
      : defaults.initialLevel;

  return {
    ...defaults,
    id: typeof raw.id === 'string' && raw.id ? raw.id : defaults.id,
    name: typeof raw.name === 'string' ? raw.name : defaults.name,
    firstName: typeof raw.firstName === 'string' ? raw.firstName : defaults.firstName,
    lastName: typeof raw.lastName === 'string' ? raw.lastName : defaults.lastName,
    email: typeof raw.email === 'string' ? raw.email : defaults.email,
    avatarUrl: typeof raw.avatarUrl === 'string' ? raw.avatarUrl : undefined,
    selectedCourseId:
      typeof raw.selectedCourseId === 'string' && raw.selectedCourseId.trim()
        ? raw.selectedCourseId
        : defaults.selectedCourseId,
    goal,
    dailyMinutes,
    initialLevel,
    courseLevels: isPlainRecord(raw.courseLevels) ? (raw.courseLevels as LearnerProfile['courseLevels']) : undefined,
    xp: typeof raw.xp === 'number' && Number.isFinite(raw.xp) && raw.xp >= 0 ? raw.xp : defaults.xp,
    streakDays:
      typeof raw.streakDays === 'number' && Number.isFinite(raw.streakDays) && raw.streakDays >= 0
        ? raw.streakDays
        : defaults.streakDays,
    lastActiveDate: typeof raw.lastActiveDate === 'string' ? raw.lastActiveDate : defaults.lastActiveDate,
    scoresByCourse: normalizeNestedRecordMap(raw.scoresByCourse),
    placementScoreByCourse: isPlainRecord(raw.placementScoreByCourse)
      ? (raw.placementScoreByCourse as Record<string, number>)
      : {},
    placementCefrByCourse: isPlainRecord(raw.placementCefrByCourse)
      ? (raw.placementCefrByCourse as LearnerProfile['placementCefrByCourse'])
      : {},
    placementSkillScoresByCourse: normalizeNestedRecordMap(raw.placementSkillScoresByCourse),
    completedLessonIds: normalizeStringArray(raw.completedLessonIds),
    completedNodeIds: normalizeStringArray(raw.completedNodeIds),
    completedReinforcementIds: normalizeStringArray(raw.completedReinforcementIds),
    flashcardSrsByCourse: normalizeNestedRecordMap(raw.flashcardSrsByCourse),
    createdAt:
      typeof raw.createdAt === 'number' && Number.isFinite(raw.createdAt)
        ? raw.createdAt
        : defaults.createdAt,
    updatedAt:
      typeof raw.updatedAt === 'number' && Number.isFinite(raw.updatedAt) ? raw.updatedAt : undefined,
  };
};

export class InMemoryLearnerRepository implements ILearnerRepository {
  readonly supportsNodeCompletion = true;
  private profile: LearnerProfile = createDefaultProfile();
  private answerAttempts: AnswerAttemptRecord[] = [];
  private processedActionKeys: Set<string> = new Set();
  private recordedActivityDates: Set<string> = new Set();

  constructor(private readonly tabStorage?: () => Storage) {
    try {
      const stored = JSON.parse(this.tabStorage?.().getItem(DEMO_PROGRESS_KEY) ?? 'null');
      if (stored?.profile?.id !== DEFAULT_PROFILE.id || !Array.isArray(stored.answerAttempts) ||
        !Array.isArray(stored.processedActionKeys) || !Array.isArray(stored.recordedActivityDates)) return;
      this.profile = normalizeStoredProfile(stored.profile);
      this.answerAttempts = stored.answerAttempts.filter(
        (attempt: unknown): attempt is AnswerAttemptRecord => isPlainRecord(attempt),
      );
      this.processedActionKeys = new Set(normalizeStringArray(stored.processedActionKeys));
      this.recordedActivityDates = new Set(normalizeStringArray(stored.recordedActivityDates));
    } catch { /* A malformed snapshot starts a fresh demo. */ }
  }

  private saveTabProgress() {
    try {
      this.tabStorage?.().setItem(DEMO_PROGRESS_KEY, JSON.stringify({
        profile: this.profile,
        answerAttempts: this.answerAttempts,
        processedActionKeys: [...this.processedActionKeys],
        recordedActivityDates: [...this.recordedActivityDates],
      }));
    } catch { /* The demo still works when browser storage is unavailable. */ }
  }

  async getCurrentProfile(): Promise<LearnerProfile> {
    return this.getProfile();
  }

  async getProfile(): Promise<LearnerProfile> {
    return JSON.parse(JSON.stringify(this.profile));
  }

  /**
   * Mirrors the server-side anti-cheat scoring: a skill score is computed over
   * UNIQUE questions only, using each question's LATEST attempt. Re-solving or
   * deliberately failing the same question can no longer inflate/deflate the
   * score, keeping the client cache consistent with `submit_answer_attempt`.
   */
  private computeUniqueSkillScore(courseId: string, skillId: string): { score: number; total: number; correct: number } {
    const latestByQuestion = new Map<string, boolean>();
    for (const a of this.answerAttempts) {
      if (a.courseId === courseId && a.skillId === skillId && a.lessonId !== 'placement_test') {
        latestByQuestion.set(a.questionId, a.isCorrect);
      }
    }
    let correct = 0;
    latestByQuestion.forEach((isCorrect) => {
      if (isCorrect) correct += 1;
    });
    const total = latestByQuestion.size;
    return { score: SkillScoringEngine.computeSkillScore(correct, total), total, correct };
  }

  async updateProfile(updates: Partial<LearnerProfile>): Promise<LearnerProfile> {
    this.profile = {
      ...this.profile,
      ...updates,
      scoresByCourse: updates.scoresByCourse || this.profile.scoresByCourse,
      placementScoreByCourse: updates.placementScoreByCourse || this.profile.placementScoreByCourse || {},
      placementCefrByCourse: updates.placementCefrByCourse || this.profile.placementCefrByCourse || {},
      placementSkillScoresByCourse: updates.placementSkillScoresByCourse || this.profile.placementSkillScoresByCourse || {},
      flashcardSrsByCourse: updates.flashcardSrsByCourse || this.profile.flashcardSrsByCourse || {},
    };
    this.saveTabProgress();
    return this.getProfile();
  }

  async recordFlashcardSrs(
    courseId: string,
    cardId: string,
    rating: 'need_practice' | 'remembered',
    intervalsDays?: readonly number[],
  ): Promise<LearnerProfile> {
    const currentByCourse = this.profile.flashcardSrsByCourse ?? {};
    const courseDeck = currentByCourse[courseId] ?? {};
    const nextEntry = computeNextFlashcardSrs(courseDeck[cardId], cardId, rating, new Date(), intervalsDays);
    this.profile = {
      ...this.profile,
      flashcardSrsByCourse: {
        ...currentByCourse,
        [courseId]: {
          ...courseDeck,
          [cardId]: nextEntry,
        },
      },
    };
    this.saveTabProgress();
    return this.getProfile();
  }

  async saveSkillScores(courseId: string, scores: Record<string, SkillScore>): Promise<void> {
    if (!this.profile.scoresByCourse) {
      this.profile.scoresByCourse = {};
    }
    this.profile.scoresByCourse[courseId] = {
      ...(this.profile.scoresByCourse[courseId] || {}),
      ...scores,
    };
    this.saveTabProgress();
  }

  async savePlacementAttempt(_data: PlacementAttemptData): Promise<string> {
    const attemptId = 'plc_att_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5);
    return attemptId;
  }

  async evaluatePlacementAnswer(
    courseId: string,
    questionId: string,
    selectedIndex: number
  ): Promise<{ isCorrect: boolean }> {
    const question = PLACEMENT_QUESTIONS[courseId]?.find((item) => item.id === questionId);
    return { isCorrect: question?.correctIndex === selectedIndex };
  }

  async markLessonCompleted(lessonId: string, courseId?: string | null): Promise<void> {
    if (!this.profile.completedLessonIds.includes(lessonId)) {
      this.profile.completedLessonIds.push(lessonId);
      const roadmapNodes = courseId
        ? SEED_ROADMAP_NODES[courseId] || []
        : Object.values(SEED_ROADMAP_NODES).flat();
      const targetNodeIds = roadmapNodes
        .filter((node) => node.targetLessonId === lessonId)
        .map((node) => node.id);
      this.profile.completedNodeIds = [
        ...new Set([...this.profile.completedNodeIds, ...targetNodeIds]),
      ];
      await this.addXp(20, `lesson_completed_${lessonId}`);
      await this.recordDailyActivity();
    }
  }

  async markNodeCompleted(nodeId: string): Promise<void> {
    if (!this.profile.completedNodeIds.includes(nodeId)) {
      this.profile.completedNodeIds.push(nodeId);
      this.saveTabProgress();
    }
  }

  async markReinforcementCompleted(reinforcementId: string, _context?: ReinforcementCompletionContext): Promise<void> {
    if (!this.profile.completedReinforcementIds.includes(reinforcementId)) {
      this.profile.completedReinforcementIds.push(reinforcementId);
      this.saveTabProgress();
      await this.addXp(15, `reinforcement_completed_${reinforcementId}`);
      await this.recordDailyActivity();
    }
  }

  private findQuestionById(questionId: string): Question | undefined {
    for (const qList of Object.values(PLACEMENT_QUESTIONS)) {
      const found = qList.find((q) => q.id === questionId);
      if (found) return found;
    }
    for (const lesson of Object.values(SEED_LESSONS)) {
      if (lesson.reinforcementExercise && lesson.reinforcementExercise.id === questionId) {
        return lesson.reinforcementExercise;
      }
      if (lesson.alternateExercise && lesson.alternateExercise.id === questionId) {
        return lesson.alternateExercise;
      }
      for (const step of lesson.steps) {
        if (step.interactiveQuestion && step.interactiveQuestion.id === questionId) {
          return step.interactiveQuestion;
        }
      }
    }
    return undefined;
  }

  async submitAnswerAttempt(request: SubmitAnswerAttemptRequest): Promise<SubmitAnswerAttemptResult> {
    // Server-side lookup of the authoritative question before computing idempotency key
    // so direct callers omitting questionType still get payload-keyed idempotency.
    const matchedQuestion = this.findQuestionById(request.questionId);
    const resolvedType = matchedQuestion?.questionType ?? request.questionType ?? 'multiple_choice';
    const lang = request.language ?? 'uz';
    const isPayloadKeyedType =
      resolvedType === 'text_input' ||
      resolvedType === 'fill_blank' ||
      resolvedType === 'word_match' ||
      resolvedType === 'sentence_order' ||
      resolvedType === 'speaking_prompt' ||
      resolvedType === 'writing_prompt';
    const isTextRequest = resolvedType === 'text_input' || resolvedType === 'fill_blank';
    const normalizedPayload = isTextRequest
      ? normalizeFreeTextAnswer(request.selectedAnswer)
      : resolvedType === 'word_match'
      ? canonicalizeWordMatchJson(request.selectedAnswer)
      : request.selectedAnswer.trim();
    const idempotencyKey =
      request.idempotencyKey ||
      (isPayloadKeyedType
        ? `${request.lessonId}:${request.questionId}:${resolvedType}:${normalizedPayload}`
        : `${request.lessonId}:${request.questionId}:${request.selectedIndex}`);
    if (this.processedActionKeys.has(idempotencyKey)) {
      const existing = this.answerAttempts.find((a) =>
        isPayloadKeyedType
          ? a.questionId === request.questionId &&
            (isTextRequest
              ? normalizeFreeTextAnswer(a.selectedAnswer) === normalizedPayload
              : resolvedType === 'word_match'
              ? canonicalizeWordMatchJson(a.selectedAnswer) === normalizedPayload
              : a.selectedAnswer.trim() === normalizedPayload)
          : a.questionId === request.questionId && a.selectedIndex === request.selectedIndex
      );
      const isCorrectExisting = existing ? existing.isCorrect : false;
      const repeatedExplanation =
        isPayloadKeyedType && matchedQuestion && !isCorrectExisting
          ? (isTextRequest
              ? buildFreeTextWrongFeedback(request.selectedAnswer, matchedQuestion, lang)
              : getLocalizedMistakeFeedback(matchedQuestion, request.selectedAnswer, lang))
          : lang === 'ru'
            ? 'Ответ уже был сохранён ранее.'
            : 'Javob avval qayd etilgan.';
      const skillScore = this.profile.scoresByCourse[request.courseId]?.[request.skillId]?.score ?? 50;
      const overall = SkillScoringEngine.computeOverallScore(this.profile.scoresByCourse[request.courseId] || {});
      return {
        isCorrect: isCorrectExisting,
        explanation: repeatedExplanation,
        newSkillScore: skillScore,
        overallScore: overall,
        xpAwarded: 0,
        totalXp: this.profile.xp,
        alreadyProcessed: true,
      };
    }

    let correctIndex: number | undefined;
    let correctOption: string | undefined;
    let explanation = lang === 'ru'
      ? 'Верное решение и педагогическое объяснение.'
      : 'To‘g‘ri yechim va pedagogik tushuntirish.';

    let isCorrect = false;
    if (matchedQuestion && (resolvedType === 'text_input' || resolvedType === 'fill_blank')) {
      isCorrect = matchesAcceptedAnswer(request.selectedAnswer, matchedQuestion.acceptedAnswers ?? []);
      correctIndex = 0;
      correctOption = undefined;
      explanation = isCorrect
        ? getLocalizedQuestionExplanation(matchedQuestion, lang)
        : buildFreeTextWrongFeedback(request.selectedAnswer, matchedQuestion, lang);
    } else if (matchedQuestion && resolvedType === 'word_match') {
      const submittedPairs = parseWordMatchSubmission(request.selectedAnswer);
      isCorrect = evaluateWordMatch(submittedPairs, matchedQuestion.matchPairs ?? []);
      correctIndex = 0;
      correctOption = undefined;
      explanation = isCorrect
        ? getLocalizedQuestionExplanation(matchedQuestion, lang)
        : getLocalizedMistakeFeedback(matchedQuestion, request.selectedAnswer, lang);
    } else if (matchedQuestion && resolvedType === 'sentence_order') {
      const tokens = parseSentenceOrderSubmission(request.selectedAnswer);
      isCorrect = evaluateSentenceOrder(
        tokens,
        matchedQuestion.orderedTokens ?? [],
        matchedQuestion.acceptedAnswers ?? [],
      );
      correctIndex = 0;
      correctOption = undefined;
      explanation = isCorrect
        ? getLocalizedQuestionExplanation(matchedQuestion, lang)
        : getLocalizedMistakeFeedback(matchedQuestion, tokens.join(' '), lang);
    } else if (matchedQuestion && (resolvedType === 'speaking_prompt' || resolvedType === 'writing_prompt')) {
      const submission = parseSelfAssessedSubmission(request.selectedAnswer);
      isCorrect = submission.response.length > 0;
      correctIndex = 0;
      correctOption = undefined;
      explanation = isCorrect
        ? getLocalizedQuestionExplanation(matchedQuestion, lang)
        : (lang === 'ru'
            ? 'Пожалуйста, сначала напишите свой ответ.'
            : 'Iltimos, avval javobingizni yozing.');
    } else if (matchedQuestion) {
      correctIndex = matchedQuestion.correctIndex;
      const selectedOption = matchedQuestion.options[request.selectedIndex] ?? request.selectedAnswer;
      if (correctIndex !== undefined && matchedQuestion.options[correctIndex]) {
        correctOption = matchedQuestion.options[correctIndex];
      }
      isCorrect = correctIndex !== undefined ? request.selectedIndex === correctIndex : false;
      explanation = isCorrect
        ? getLocalizedQuestionExplanation(matchedQuestion, lang)
        : getLocalizedMistakeFeedback(matchedQuestion, selectedOption, lang);
    } else {
      // 3. Check runtime-registered answer keys (AI / deterministic-fallback
      // questions that are not part of the static seed banks).
      const runtimeKey = getQuestionAnswerKey(request.questionId);
      if (runtimeKey) {
        correctIndex = runtimeKey.correctIndex;
        if (runtimeKey.explanation) explanation = runtimeKey.explanation;
        correctOption = runtimeKey.options[correctIndex];
      }
      // Anti-cheat verification: If question is unknown, do NOT assume 0
      isCorrect = correctIndex !== undefined ? request.selectedIndex === correctIndex : false;
    }

    this.processedActionKeys.add(idempotencyKey);

    const record: AnswerAttemptRecord = {
      id: 'att_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5),
      userId: this.profile.id,
      courseId: request.courseId,
      skillId: request.skillId,
      lessonId: request.lessonId,
      questionId: request.questionId,
      selectedIndex: request.selectedIndex,
      selectedAnswer: request.selectedAnswer,
      isCorrect,
      timestamp: Date.now(),
    };
    this.answerAttempts.push(record);

    let xpAwarded = 0;
    if (isCorrect) {
      const xpKey = `xp_question_${request.questionId}`;
      if (!this.processedActionKeys.has(xpKey)) {
        this.processedActionKeys.add(xpKey);
        xpAwarded = 2;
        this.profile.xp = (this.profile.xp || 0) + 2;
      }
    }
    await this.recordDailyActivity();

    // Recalculate skill score over unique questions (latest attempt each) for non-placement attempts only.
    const { score: newScoreVal, total: uniqueTotal, correct: uniqueCorrect } =
      this.computeUniqueSkillScore(request.courseId, request.skillId);

    if (request.lessonId !== 'placement_test') {
      if (!this.profile.scoresByCourse[request.courseId]) {
        this.profile.scoresByCourse[request.courseId] = {};
      }

      this.profile.scoresByCourse[request.courseId][request.skillId] = {
        skillId: request.skillId,
        courseId: request.courseId,
        score: newScoreVal,
        lastUpdated: Date.now(),
        masteryLevel: SkillScoringEngine.getMasteryLevel(newScoreVal),
      };
    }

    const overallScore = SkillScoringEngine.computeOverallScore(this.profile.scoresByCourse[request.courseId] || {});
    this.saveTabProgress();

    return {
      isCorrect,
      correctIndex,
      correctOption,
      explanation,
      newSkillScore: newScoreVal,
      overallScore,
      xpAwarded,
      totalXp: this.profile.xp,
      totalAttempts: uniqueTotal,
      correctAttempts: uniqueCorrect,
      alreadyProcessed: false,
    };
  }

  async recordAnswerAttempt(attempt: Omit<AnswerAttemptRecord, 'id' | 'timestamp'>): Promise<AnswerAttemptRecord> {
    const record: AnswerAttemptRecord = {
      ...attempt,
      id: 'att_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5),
      timestamp: Date.now(),
    };
    this.answerAttempts.push(record);

    // If answer is correct, award +2 XP idempotently
    if (attempt.isCorrect) {
      await this.addXp(2, `answer_${attempt.questionId}_${record.id}`);
    }
    await this.recordDailyActivity();

    // Recalculate cumulative unique-question skill score for independent lesson/reinforcement attempts only.
    if (attempt.lessonId !== 'placement_test') {
      const { score: newScoreVal } = this.computeUniqueSkillScore(attempt.courseId, attempt.skillId);

      if (!this.profile.scoresByCourse[attempt.courseId]) {
        this.profile.scoresByCourse[attempt.courseId] = {};
      }

      this.profile.scoresByCourse[attempt.courseId][attempt.skillId] = {
        skillId: attempt.skillId,
        courseId: attempt.courseId,
        score: newScoreVal,
        lastUpdated: Date.now(),
        masteryLevel: SkillScoringEngine.getMasteryLevel(newScoreVal),
      };
    }

    this.saveTabProgress();
    return record;
  }

  async getAnswerAttempts(limit: number = 10): Promise<AnswerAttemptRecord[]> {
    return [...this.answerAttempts].slice(-limit);
  }

  async getDailyActivity(days: number = 7): Promise<DailyActivitySummary[]> {
    const result: DailyActivitySummary[] = [];
    const dayMs = 1000 * 60 * 60 * 24;
    const now = Date.now();

    for (let i = days - 1; i >= 0; i--) {
      const dateStr = new Date(now - i * dayMs).toISOString().split('T')[0];
      const dayAttempts = this.answerAttempts.filter(
        (a) => new Date(a.timestamp).toISOString().split('T')[0] === dateStr
      );
      const correct = dayAttempts.filter((a) => a.isCorrect).length;
      result.push({
        date: dateStr,
        activeMinutes: 0,
        xpEarned: correct * 2,
        lessonsCompleted: 0,
        questionsAnswered: dayAttempts.length,
        correctAnswers: correct,
      });
    }

    return result;
  }

  async addXp(amount: number, actionIdempotencyKey?: string): Promise<number> {
    if (actionIdempotencyKey) {
      if (this.processedActionKeys.has(actionIdempotencyKey)) {
        return this.profile.xp;
      }
      this.processedActionKeys.add(actionIdempotencyKey);
    }
    this.profile.xp = (this.profile.xp || 0) + amount;
    this.saveTabProgress();
    return this.profile.xp;
  }

  async recordDailyActivity(dateStr?: string): Promise<number> {
    const today = dateStr || new Date().toISOString().split('T')[0];

    if (this.recordedActivityDates.has(today)) {
      return this.profile.streakDays;
    }

    this.recordedActivityDates.add(today);

    const lastDate = this.profile.lastActiveDate;
    if (!lastDate) {
      this.profile.streakDays = 1;
    } else if (lastDate === today) {
      // Same day, streak unchanged
    } else {
      const prevMs = new Date(lastDate).getTime();
      const currMs = new Date(today).getTime();
      const diffDays = Math.round((currMs - prevMs) / (1000 * 60 * 60 * 24));

      if (diffDays === 1) {
        this.profile.streakDays = (this.profile.streakDays || 0) + 1;
      } else {
        this.profile.streakDays = 1;
      }
    }

    this.profile.lastActiveDate = today;
    this.saveTabProgress();
    return this.profile.streakDays;
  }

  async resetAll(): Promise<LearnerProfile> {
    this.profile = createDefaultProfile();
    this.answerAttempts = [];
    this.processedActionKeys.clear();
    this.recordedActivityDates.clear();
    this.saveTabProgress();
    return this.getProfile();
  }
}

export const inMemoryLearnerRepository = new InMemoryLearnerRepository();
