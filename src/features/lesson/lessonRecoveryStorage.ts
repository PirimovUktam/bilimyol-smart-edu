import type { LessonAnswerResult } from '@/domain/usecases/SubmitLessonAnswerUseCase';
import type { SubmitAnswerAttemptResult } from '@/domain/repositories/ILearnerRepository';
import { isDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { registerSessionResetHandler } from '@/core/runtime/sessionReset';
import { generateAttemptUuid } from '@/core/utils/attemptUuid';

const PENDING_ATTEMPT_PREFIX = 'bilimyol-pending-attempt:';
const LESSON_PROGRESS_PREFIX = 'bilimyol-lesson-progress:';

export interface DurablePendingAttempt {
  attemptId: string;
  accountId: string;
  courseId: string;
  lessonId: string;
  questionId: string;
  payloadSignature: string;
  selectedIndex?: number;
  selectedText?: string;
  status: 'submitting' | 'graded';
  cachedLessonResult?: LessonAnswerResult;
  cachedServerResult?: SubmitAnswerAttemptResult;
  updatedAt: number;
}

interface StoredLessonProgress {
  answeredQuestionIds: string[];
  updatedAt: number;
}

const memoryFallback = new Map<string, string>();

function readRaw(storageKey: string): string | null {
  try {
    const fromLocal = globalThis.localStorage?.getItem(storageKey);
    if (fromLocal !== null && fromLocal !== undefined) return fromLocal;
  } catch { /* fallback */ }
  try {
    const fromSession = globalThis.sessionStorage?.getItem(storageKey);
    if (fromSession !== null && fromSession !== undefined) return fromSession;
  } catch { /* fallback */ }
  return memoryFallback.get(storageKey) ?? null;
}

function writeRaw(storageKey: string, value: string): void {
  memoryFallback.set(storageKey, value);
  try {
    globalThis.localStorage?.setItem(storageKey, value);
    return;
  } catch { /* fallback */ }
  try {
    globalThis.sessionStorage?.setItem(storageKey, value);
  } catch { /* memory fallback remains active */ }
}

function removeRaw(storageKey: string): void {
  memoryFallback.delete(storageKey);
  try {
    globalThis.localStorage?.removeItem(storageKey);
  } catch { /* ignore */ }
  try {
    globalThis.sessionStorage?.removeItem(storageKey);
  } catch { /* ignore */ }
}

export function resolveRecoveryAccountScope(profileId?: string | null): string {
  if (isDemoRuntimeActive()) return 'demo';
  const clean = typeof profileId === 'string' ? profileId.trim() : '';
  return clean || 'anonymous';
}

function pendingAttemptKey(
  accountId: string,
  courseId: string,
  lessonId: string,
  questionId: string,
): string {
  return PENDING_ATTEMPT_PREFIX + JSON.stringify([accountId, courseId, lessonId, questionId]);
}

function lessonProgressKey(accountId: string, courseId: string, lessonId: string): string {
  return LESSON_PROGRESS_PREFIX + JSON.stringify([accountId, courseId, lessonId]);
}

export function readPendingAttempt(
  accountId: string,
  courseId: string,
  lessonId: string,
  questionId: string,
): DurablePendingAttempt | null {
  const raw = readRaw(pendingAttemptKey(accountId, courseId, lessonId, questionId));
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as Partial<DurablePendingAttempt>;
    if (
      !parsed ||
      typeof parsed !== 'object' ||
      typeof parsed.attemptId !== 'string' ||
      !parsed.attemptId.trim() ||
      parsed.accountId !== accountId ||
      parsed.courseId !== courseId ||
      parsed.lessonId !== lessonId ||
      parsed.questionId !== questionId ||
      typeof parsed.payloadSignature !== 'string' ||
      (parsed.status !== 'submitting' && parsed.status !== 'graded')
    ) {
      return null;
    }
    return {
      attemptId: parsed.attemptId,
      accountId: parsed.accountId,
      courseId: parsed.courseId,
      lessonId: parsed.lessonId,
      questionId: parsed.questionId,
      payloadSignature: parsed.payloadSignature,
      selectedIndex: typeof parsed.selectedIndex === 'number' ? parsed.selectedIndex : undefined,
      selectedText: typeof parsed.selectedText === 'string' ? parsed.selectedText : undefined,
      status: parsed.status,
      cachedLessonResult: parsed.cachedLessonResult,
      cachedServerResult: parsed.cachedServerResult,
      updatedAt: typeof parsed.updatedAt === 'number' ? parsed.updatedAt : Date.now(),
    };
  } catch {
    return null;
  }
}

export function getOrCreatePendingAttempt(params: {
  accountId: string;
  courseId: string;
  lessonId: string;
  questionId: string;
  payloadSignature: string;
  selectedIndex?: number;
  selectedText?: string;
}): DurablePendingAttempt {
  const existing = readPendingAttempt(
    params.accountId,
    params.courseId,
    params.lessonId,
    params.questionId,
  );
  if (existing && existing.payloadSignature === params.payloadSignature) {
    return existing;
  }
  const created: DurablePendingAttempt = {
    attemptId: generateAttemptUuid(),
    accountId: params.accountId,
    courseId: params.courseId,
    lessonId: params.lessonId,
    questionId: params.questionId,
    payloadSignature: params.payloadSignature,
    selectedIndex: params.selectedIndex,
    selectedText: params.selectedText,
    status: 'submitting',
    updatedAt: Date.now(),
  };
  writeRaw(
    pendingAttemptKey(params.accountId, params.courseId, params.lessonId, params.questionId),
    JSON.stringify(created),
  );
  return created;
}

export function markPendingAttemptGraded(
  attempt: DurablePendingAttempt,
  options: {
    lessonResult?: LessonAnswerResult;
    serverResult?: SubmitAnswerAttemptResult;
  },
): DurablePendingAttempt {
  const updated: DurablePendingAttempt = {
    ...attempt,
    status: 'graded',
    cachedLessonResult: options.lessonResult ?? attempt.cachedLessonResult,
    cachedServerResult: options.serverResult ?? attempt.cachedServerResult,
    updatedAt: Date.now(),
  };
  writeRaw(
    pendingAttemptKey(attempt.accountId, attempt.courseId, attempt.lessonId, attempt.questionId),
    JSON.stringify(updated),
  );
  return updated;
}

export function clearPendingAttempt(
  accountId: string,
  courseId: string,
  lessonId: string,
  questionId: string,
): void {
  removeRaw(pendingAttemptKey(accountId, courseId, lessonId, questionId));
}

export function readPersistedAnsweredQuestionIds(
  accountId: string,
  courseId: string,
  lessonId: string,
  validQuestionIds?: ReadonlySet<string>,
): string[] {
  const raw = readRaw(lessonProgressKey(accountId, courseId, lessonId));
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw) as Partial<StoredLessonProgress>;
    if (!parsed || !Array.isArray(parsed.answeredQuestionIds)) return [];
    const unique = new Set<string>();
    for (const id of parsed.answeredQuestionIds) {
      if (typeof id === 'string' && id.trim() && (!validQuestionIds || validQuestionIds.has(id))) {
        unique.add(id);
      }
    }
    return [...unique];
  } catch {
    return [];
  }
}

export function writePersistedAnsweredQuestionIds(
  accountId: string,
  courseId: string,
  lessonId: string,
  answeredQuestionIds: readonly string[],
): void {
  const unique = [...new Set(answeredQuestionIds.filter((id) => typeof id === 'string' && id.trim()))];
  if (unique.length === 0) {
    removeRaw(lessonProgressKey(accountId, courseId, lessonId));
    return;
  }
  const payload: StoredLessonProgress = {
    answeredQuestionIds: unique,
    updatedAt: Date.now(),
  };
  writeRaw(lessonProgressKey(accountId, courseId, lessonId), JSON.stringify(payload));
}

export function clearPersistedLessonProgress(
  accountId: string,
  courseId: string,
  lessonId: string,
  questionIds: readonly string[] = [],
): void {
  removeRaw(lessonProgressKey(accountId, courseId, lessonId));
  for (const qId of questionIds) {
    removeRaw(pendingAttemptKey(accountId, courseId, lessonId, qId));
  }
}

export function clearNodeTestRecoveryMemoryIfHeadless(): void {
  if (typeof window === 'undefined') {
    memoryFallback.clear();
  }
}

function purgeVolatileAndDemoRecoveryState(): void {
  for (const k of [...memoryFallback.keys()]) {
    if (k.includes('["demo",') || k.includes('["anonymous",')) {
      memoryFallback.delete(k);
    }
  }
  const purgeStorage = (store: Storage | undefined) => {
    if (!store) return;
    try {
      const toDelete: string[] = [];
      for (let i = 0; i < store.length; i++) {
        const k = store.key(i);
        if (
          k &&
          (k.startsWith(PENDING_ATTEMPT_PREFIX) || k.startsWith(LESSON_PROGRESS_PREFIX)) &&
          (k.includes('["demo",') || k.includes('["anonymous",'))
        ) {
          toDelete.push(k);
        }
      }
      for (const k of toDelete) {
        store.removeItem(k);
      }
    } catch { /* ignore */ }
  };
  purgeStorage(globalThis.localStorage);
  purgeStorage(globalThis.sessionStorage);
}

registerSessionResetHandler(() => {
  purgeVolatileAndDemoRecoveryState();
});
