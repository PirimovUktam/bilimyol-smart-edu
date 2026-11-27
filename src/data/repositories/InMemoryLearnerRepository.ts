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
import { STARTER_LESSONS } from '@/data/datasources/starterLessons';
import { getQuestionAnswerKey } from '@/core/runtime/questionAnswerKeys';
import { learningDate } from '@/core/utils/learningDate';
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

interface DailyBonusEvent {
  timestamp: number;
  xpEarned: number;
  lessonsCompleted: number;
}

interface SkillBaselineEntry {
  score: number;
  attemptCountAtBaseline: number;
}

export class InMemoryLearnerRepository implements ILearnerRepository {
  readonly supportsNodeCompletion = true;
  private profile: LearnerProfile = createDefaultProfile();
  private answerAttempts: AnswerAttemptRecord[] = [];
  private dailyBonusEvents: DailyBonusEvent[] = [];
  private processedActionKeys: Set<string> = new Set();
  private recordedActivityDates: Set<string> = new Set();
  private skillBaselines: Record<string, Record<string, SkillBaselineEntry>> = {};

  constructor(private readonly tabStorage?: () => Storage) {
    try {
      const stored = JSON.parse(this.tabStorage?.().getItem(DEMO_PROGRESS_KEY) ?? 'null');
      if (stored?.profile?.id !== DEFAULT_PROFILE.id || !Array.isArray(stored.answerAttempts) ||
        !Array.isArray(stored.processedActionKeys) || !Array.isArray(stored.recordedActivityDates)) return;
      this.profile = normalizeStoredProfile(stored.profile);
      this.answerAttempts = stored.answerAttempts.filter(
        (attempt: unknown): attempt is AnswerAttemptRecord => isPlainRecord(attempt),
      );
      this.dailyBonusEvents = Array.isArray(stored.dailyBonusEvents)
        ? stored.dailyBonusEvents
            .filter((ev: unknown): ev is Record<string, unknown> => isPlainRecord(ev) && typeof ev.timestamp === 'number')
            .map((ev: Record<string, unknown>) => ({
              timestamp: ev.timestamp as number,
              xpEarned: typeof ev.xpEarned === 'number' ? ev.xpEarned : 0,
              lessonsCompleted: typeof ev.lessonsCompleted === 'number' ? ev.lessonsCompleted : 0,
            }))
        : [];
      this.processedActionKeys = new Set(normalizeStringArray(stored.processedActionKeys));
      this.recordedActivityDates = new Set(normalizeStringArray(stored.recordedActivityDates));
      if (isPlainRecord(stored.skillBaselines)) {
        const parsedBaselines: Record<string, Record<string, SkillBaselineEntry>> = {};
        for (const [courseId, rawCourseMap] of Object.entries(stored.skillBaselines)) {
          if (!isPlainRecord(rawCourseMap)) continue;
          const skillMap: Record<string, SkillBaselineEntry> = {};
          for (const [skillId, rawBase] of Object.entries(rawCourseMap)) {
            if (isPlainRecord(rawBase) && typeof rawBase.score === 'number' && typeof rawBase.attemptCountAtBaseline === 'number') {
              skillMap[skillId] = {
                score: SkillScoringEngine.clampScore(rawBase.score),
                attemptCountAtBaseline: Math.max(0, Math.trunc(rawBase.attemptCountAtBaseline)),
              };
            }
          }
          if (Object.keys(skillMap).length > 0) {
            parsedBaselines[courseId] = skillMap;
          }
        }
        this.skillBaselines = parsedBaselines;
      }
    } catch { /* A malformed snapshot starts a fresh demo. */ }
  }

  private saveTabProgress() {
    try {
      this.tabStorage?.().setItem(DEMO_PROGRESS_KEY, JSON.stringify({
        profile: this.profile,
        answerAttempts: this.answerAttempts,
        dailyBonusEvents: this.dailyBonusEvents,
        processedActionKeys: [...this.processedActionKeys],
        recordedActivityDates: [...this.recordedActivityDates],
        skillBaselines: this.skillBaselines,
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
   * Calibrates skill mastery over UNIQUE non-placement questions (latest attempt wins),
   * blending prior diagnostic baseline (`priorWeight = 4`), enforcing `starterOnlyMaxScore = 55`
   * on starter/foundation lessons, discounting spoiled choice retries (`0.75`), and requiring
   * `attemptCount >= 4` for `'mastered'` (`FIX-P1-09`, `FIX-P2-09`).
   */
  private computeUniqueSkillScore(courseId: string, skillId: string): {
    score: number;
    total: number;
    correct: number;
    masteryLevel: SkillScore['masteryLevel'];
    confidence: NonNullable<SkillScore['confidence']>;
  } {
    const nonPlacementAttempts = this.answerAttempts.filter(
      (a) => a.courseId === courseId && a.skillId === skillId && a.lessonId !== 'placement_test'
    );
    const baseline = this.skillBaselines[courseId]?.[skillId];
    const postBaselineAttempts =
      baseline && baseline.attemptCountAtBaseline <= nonPlacementAttempts.length
        ? nonPlacementAttempts.slice(baseline.attemptCountAtBaseline)
        : nonPlacementAttempts;

    const placementPrior = this.profile.placementSkillScoresByCourse?.[courseId]?.[skillId]?.score;
    const deduplicateByQuestion = courseId === 'course_eng_01' && !baseline;

    const latestByQuestion = new Map<string, { isCorrect: boolean; firstIsCorrect: boolean; lessonId?: string }>();
    for (const a of postBaselineAttempts) {
      const prev = latestByQuestion.get(a.questionId);
      latestByQuestion.set(a.questionId, {
        isCorrect: a.isCorrect,
        firstIsCorrect: prev ? prev.firstIsCorrect : a.isCorrect,
        lessonId: a.lessonId,
      });
    }

    let correct = 0;
    let weightedCorrect = 0;
    let weightedTotal = 0;
    let unadjustedEarned = 0;
    let hasNonStarterAttempt = false;

    if (deduplicateByQuestion) {
      latestByQuestion.forEach((entry, qid) => {
        const isStarter = Boolean(entry.lessonId && STARTER_LESSONS[entry.lessonId]);
        const weight = isStarter ? 0.5 : 1.0;
        if (!isStarter) {
          hasNonStarterAttempt = true;
        }
        weightedTotal += weight;
        if (entry.isCorrect) {
          correct += 1;
          const matchedQ = this.findQuestionById(qid);
          const qType = matchedQ?.questionType ?? 'multiple_choice';
          const isChoiceMode =
            qType === 'multiple_choice' || qType === 'error_correction' || qType === 'conversation_completion';
          const retryFactor = !entry.firstIsCorrect && isChoiceMode ? 0.75 : 1.0;
          weightedCorrect += weight * retryFactor;
          unadjustedEarned += retryFactor;
        }
      });
    } else {
      latestByQuestion.forEach((entry) => {
        if (entry.isCorrect) correct += 1;
      });
      for (const a of postBaselineAttempts) {
        const isStarter = Boolean(a.lessonId && STARTER_LESSONS[a.lessonId]);
        const weight = isStarter ? 0.5 : 1.0;
        if (!isStarter) {
          hasNonStarterAttempt = true;
        }
        weightedTotal += weight;
        if (a.isCorrect) {
          weightedCorrect += weight;
        }
      }
    }

    const total = latestByQuestion.size;
    const priorScore =
      courseId !== 'course_eng_01'
        ? (baseline?.score ?? placementPrior ?? null)
        : (baseline?.score ?? (!hasNonStarterAttempt ? (placementPrior ?? null) : null));

    let score: number;
    if (postBaselineAttempts.length === 0) {
      score = priorScore ?? 0;
    } else if (courseId === 'course_eng_01' && priorScore === null && hasNonStarterAttempt) {
      score = SkillScoringEngine.clampScore((unadjustedEarned / Math.max(1, total)) * 100);
    } else {
      score = SkillScoringEngine.computeCalibratedSkillScore({
        weightedCorrect,
        weightedTotal,
        priorScore,
        starterOnly: priorScore === null && !hasNonStarterAttempt,
        hasNonStarterAttempt,
      });
    }

    const effectiveCount = Math.max(total, priorScore !== null ? 2 : 0);
    return {
      score,
      total,
      correct,
      masteryLevel: SkillScoringEngine.getMasteryLevel(score, total > 0 ? total : (priorScore !== null ? 4 : undefined)),
      confidence: SkillScoringEngine.computeConfidence(effectiveCount),
    };
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
    const courseBaselines = { ...(this.skillBaselines[courseId] ?? {}) };
    for (const [skillId, entry] of Object.entries(scores)) {
      const existingNonPlacementCount = this.answerAttempts.filter(
        (a) => a.courseId === courseId && a.skillId === skillId && a.lessonId !== 'placement_test'
      ).length;
      courseBaselines[skillId] = {
        score: entry.score,
        attemptCountAtBaseline: existingNonPlacementCount,
      };
    }
    this.skillBaselines[courseId] = courseBaselines;
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
      const prevXp = this.profile.xp || 0;
      const nextXp = await this.addXp(20, `lesson_completed_${lessonId}`);
      this.dailyBonusEvents.push({
        timestamp: Date.now(),
        xpEarned: Math.max(0, nextXp - prevXp),
        lessonsCompleted: 1,
      });
      this.saveTabProgress();
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
      const prevXp = this.profile.xp || 0;
      const nextXp = await this.addXp(15, `reinforcement_completed_${reinforcementId}`);
      this.dailyBonusEvents.push({
        timestamp: Date.now(),
        xpEarned: Math.max(0, nextXp - prevXp),
        lessonsCompleted: 0,
      });
      this.saveTabProgress();
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
    if (request.idempotencyKey !== undefined) {
      if (!request.idempotencyKey.trim()) {
        throw new Error('Idempotency kaliti bo‘sh satr bo‘lishi mumkin emas.');
      }
      if (request.idempotencyKey.length > 128) {
        throw new Error('Idempotency kaliti uzunligi 128 belgidan oshmasligi shart.');
      }
    }
    if ((request.selectedAnswer ?? '').length > 4000) {
      throw new Error('Javob matni 4000 belgidan oshmasligi shart.');
    }

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

    const explicitKey = request.idempotencyKey?.trim() || undefined;
    let existingAttempt: AnswerAttemptRecord | undefined;

    if (explicitKey) {
      if (this.processedActionKeys.has(explicitKey)) {
        existingAttempt = this.answerAttempts.find((a) => a.idempotencyKey === explicitKey);
        if (
          existingAttempt &&
          (existingAttempt.courseId !== request.courseId ||
            existingAttempt.skillId !== request.skillId ||
            (existingAttempt.lessonId ?? '') !== request.lessonId ||
            existingAttempt.questionId !== request.questionId ||
            existingAttempt.selectedIndex !== request.selectedIndex ||
            existingAttempt.selectedAnswer !== request.selectedAnswer)
        ) {
          throw new Error('Idempotency kaliti boshqa javob uchun ishlatilgan.');
        }
      }
    } else {
      // Legacy direct repository calls omitting idempotencyKey deduplicate only
      // against the immediately latest attempt on the same (lessonId, questionId).
      for (let i = this.answerAttempts.length - 1; i >= 0; i--) {
        const candidate = this.answerAttempts[i];
        if ((candidate.lessonId ?? '') === request.lessonId && candidate.questionId === request.questionId) {
          const samePayload = isPayloadKeyedType
            ? isTextRequest
              ? normalizeFreeTextAnswer(candidate.selectedAnswer) === normalizedPayload
              : resolvedType === 'word_match'
              ? canonicalizeWordMatchJson(candidate.selectedAnswer) === normalizedPayload
              : candidate.selectedAnswer.trim() === normalizedPayload
            : candidate.selectedIndex === request.selectedIndex;
          if (samePayload) {
            existingAttempt = candidate;
          }
          break;
        }
      }
    }

    if ((explicitKey && this.processedActionKeys.has(explicitKey)) || existingAttempt) {
      const isCorrectExisting = existingAttempt ? existingAttempt.isCorrect : false;
      const repeatedExplanation =
        isPayloadKeyedType && matchedQuestion && !isCorrectExisting
          ? (isTextRequest
              ? buildFreeTextWrongFeedback(request.selectedAnswer, matchedQuestion, lang)
              : getLocalizedMistakeFeedback(matchedQuestion, request.selectedAnswer, lang))
          : isCorrectExisting && matchedQuestion
            ? getLocalizedQuestionExplanation(matchedQuestion, lang)
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

    if (explicitKey) {
      this.processedActionKeys.add(explicitKey);
    }

    let xpAwarded = 0;
    if (isCorrect) {
      const xpKey = `xp_question_${request.questionId}`;
      if (!this.processedActionKeys.has(xpKey)) {
        this.processedActionKeys.add(xpKey);
        xpAwarded = 2;
        this.profile.xp = (this.profile.xp || 0) + 2;
      }
    }

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
      xpAwarded,
      idempotencyKey: explicitKey,
      timestamp: Date.now(),
    };
    this.answerAttempts.push(record);

    await this.recordDailyActivity();

    // Recalculate skill score over unique questions (latest attempt each) for non-placement attempts only.
    const {
      score: newScoreVal,
      total: uniqueTotal,
      correct: uniqueCorrect,
      masteryLevel,
      confidence,
    } = this.computeUniqueSkillScore(request.courseId, request.skillId);

    if (request.lessonId !== 'placement_test') {
      if (!this.profile.scoresByCourse[request.courseId]) {
        this.profile.scoresByCourse[request.courseId] = {};
      }

      this.profile.scoresByCourse[request.courseId][request.skillId] = {
        skillId: request.skillId,
        courseId: request.courseId,
        score: newScoreVal,
        lastUpdated: Date.now(),
        masteryLevel,
        attemptCount: uniqueTotal,
        confidence,
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
    const explicitKey = attempt.idempotencyKey?.trim() || undefined;
    if (attempt.idempotencyKey !== undefined && !explicitKey) {
      throw new Error('Idempotency kaliti bo‘sh satr bo‘lishi mumkin emas.');
    }
    if (explicitKey && explicitKey.length > 128) {
      throw new Error('Idempotency kaliti uzunligi 128 belgidan oshmasligi shart.');
    }
    if ((attempt.selectedAnswer ?? '').length > 4000) {
      throw new Error('Javob matni 4000 belgidan oshmasligi shart.');
    }
    if (explicitKey && this.processedActionKeys.has(explicitKey)) {
      const existing = this.answerAttempts.find((a) => a.idempotencyKey === explicitKey);
      if (existing) {
        if (
          existing.courseId !== attempt.courseId ||
          existing.skillId !== attempt.skillId ||
          (existing.lessonId ?? '') !== (attempt.lessonId ?? '') ||
          existing.questionId !== attempt.questionId ||
          existing.selectedIndex !== attempt.selectedIndex ||
          existing.selectedAnswer !== attempt.selectedAnswer
        ) {
          throw new Error('Idempotency kaliti boshqa javob uchun ishlatilgan.');
        }
        return { ...existing, xpAwarded: 0 };
      }
    }
    if (explicitKey) {
      this.processedActionKeys.add(explicitKey);
    }

    let xpAwarded = 0;
    if (attempt.isCorrect) {
      const xpKey = `xp_question_${attempt.questionId}`;
      if (!this.processedActionKeys.has(xpKey)) {
        this.processedActionKeys.add(xpKey);
        xpAwarded = 2;
        this.profile.xp = (this.profile.xp || 0) + 2;
      }
    }

    const record: AnswerAttemptRecord = {
      ...attempt,
      xpAwarded,
      idempotencyKey: explicitKey,
      id: 'att_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5),
      timestamp: Date.now(),
    };
    this.answerAttempts.push(record);
    await this.recordDailyActivity();

    // Recalculate cumulative unique-question skill score for independent lesson/reinforcement attempts only.
    if (attempt.lessonId !== 'placement_test') {
      const {
        score: newScoreVal,
        total: uniqueTotal,
        masteryLevel,
        confidence,
      } = this.computeUniqueSkillScore(attempt.courseId, attempt.skillId);

      if (!this.profile.scoresByCourse[attempt.courseId]) {
        this.profile.scoresByCourse[attempt.courseId] = {};
      }

      this.profile.scoresByCourse[attempt.courseId][attempt.skillId] = {
        skillId: attempt.skillId,
        courseId: attempt.courseId,
        score: newScoreVal,
        lastUpdated: Date.now(),
        masteryLevel,
        attemptCount: uniqueTotal,
        confidence,
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
    const now = Date.now();

    for (let i = days - 1; i >= 0; i--) {
      const dateStr = learningDate(i, now);
      const dayAttempts = this.answerAttempts.filter(
        (a) => learningDate(0, a.timestamp) === dateStr
      );
      // Deduplicate by (activity_date, question_id) using each question's latest outcome on that day.
      const latestByQuestion = new Map<string, AnswerAttemptRecord>();
      let xpEarned = 0;
      for (const a of dayAttempts) {
        latestByQuestion.set(a.questionId, a);
        xpEarned += typeof a.xpAwarded === 'number' ? a.xpAwarded : 0;
      }
      let lessonsCompleted = 0;
      for (const ev of this.dailyBonusEvents) {
        if (learningDate(0, ev.timestamp) === dateStr) {
          xpEarned += ev.xpEarned;
          lessonsCompleted += ev.lessonsCompleted;
        }
      }
      const questionsAnswered = latestByQuestion.size;
      let correctAnswers = 0;
      latestByQuestion.forEach((a) => {
        if (a.isCorrect) correctAnswers += 1;
      });
      const accuracyPercent =
        questionsAnswered > 0 ? Math.round((correctAnswers * 100) / questionsAnswered) : 0;

      result.push({
        date: dateStr,
        activeMinutes: 0,
        xpEarned,
        lessonsCompleted,
        questionsAnswered,
        correctAnswers,
        accuracyPercent,
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
    this.dailyBonusEvents = [];
    this.processedActionKeys.clear();
    this.recordedActivityDates.clear();
    this.skillBaselines = {};
    this.saveTabProgress();
    return this.getProfile();
  }
}

export const inMemoryLearnerRepository = new InMemoryLearnerRepository();
