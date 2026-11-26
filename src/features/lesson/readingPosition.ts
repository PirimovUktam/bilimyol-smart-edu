import type { Lesson } from '@/domain/entities/Lesson';
import { isDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { registerSessionResetHandler } from '@/core/runtime/sessionReset';
import { readPersistedAnsweredQuestionIds } from './lessonRecoveryStorage';

const READING_PREFIX = 'bilimyol-reading:';
const DEMO_ACCOUNT_ALIASES = new Set(['demo', 'guest_user_01', 'learner_default_01']);

function resolveReadingAccountScope(accountId?: string | null): string {
  if (isDemoRuntimeActive()) return 'demo';
  const clean = typeof accountId === 'string' ? accountId.trim() : '';
  if (!clean || DEMO_ACCOUNT_ALIASES.has(clean)) return 'demo';
  return clean;
}

function key(accountId: string, lesson: Lesson) {
  return READING_PREFIX + JSON.stringify([accountId, lesson.courseId, lesson.id]);
}

export function maxSafeLessonPosition(
  lesson: Lesson,
  answeredQuestionIds: readonly string[] = [],
): number {
  if (!Array.isArray(lesson.steps) || lesson.steps.length === 0) return 0;
  const passed = new Set(answeredQuestionIds);
  const firstUnpassedExercise = lesson.steps.findIndex((step) => {
    const qId = step.interactiveQuestion?.id;
    if (qId) {
      return !passed.has(qId);
    }
    return step.type === 'interactive_question';
  });
  return firstUnpassedExercise === -1 ? lesson.steps.length - 1 : firstUnpassedExercise;
}

function safePosition(
  lesson: Lesson,
  index: number,
  answeredQuestionIds: readonly string[] = [],
) {
  const last = maxSafeLessonPosition(lesson, answeredQuestionIds);
  return Number.isInteger(index) && index >= 0 ? Math.max(0, Math.min(last, index)) : 0;
}

export function readLessonPosition(
  accountId: string,
  lesson: Lesson,
  answeredQuestionIds?: readonly string[],
) {
  const scope = resolveReadingAccountScope(accountId);
  const resolvedAnswered =
    answeredQuestionIds ??
    readPersistedAnsweredQuestionIds(scope, lesson.courseId, lesson.id);
  try {
    const storageKey = key(scope, lesson);
    const raw =
      globalThis.sessionStorage?.getItem(storageKey) ??
      globalThis.localStorage?.getItem(storageKey);
    if (raw === null || raw === undefined) return 0;
    return safePosition(lesson, Number(raw), resolvedAnswered);
  } catch {
    return 0;
  }
}

export function saveLessonPosition(
  accountId: string,
  lesson: Lesson,
  step: number,
  answeredQuestionIds?: readonly string[],
) {
  // A browser checkpoint can restore reading up to the next unconfirmed interactive question.
  const scope = resolveReadingAccountScope(accountId);
  const resolvedAnswered =
    answeredQuestionIds ??
    readPersistedAnsweredQuestionIds(scope, lesson.courseId, lesson.id);
  const clamped = String(safePosition(lesson, step, resolvedAnswered));
  const storageKey = key(scope, lesson);
  try {
    globalThis.sessionStorage?.setItem(storageKey, clamped);
  } catch { /* Optional browser storage. */ }
  try {
    globalThis.localStorage?.setItem(storageKey, clamped);
  } catch { /* Optional browser storage. */ }
}

export function clearLessonPosition(accountId: string | undefined | null, lesson: Lesson) {
  const scope = resolveReadingAccountScope(accountId);
  const storageKey = key(scope, lesson);
  try {
    globalThis.sessionStorage?.removeItem(storageKey);
  } catch { /* Optional browser storage. */ }
  try {
    globalThis.localStorage?.removeItem(storageKey);
  } catch { /* Optional browser storage. */ }
}

function purgeDemoReadingPositions(): void {
  const purge = (store: Storage | undefined) => {
    if (!store) return;
    try {
      const toDelete: string[] = [];
      for (let i = 0; i < store.length; i++) {
        const k = store.key(i);
        if (
          k &&
          k.startsWith(READING_PREFIX) &&
          (k.includes('["demo",') ||
            k.includes('["anonymous",') ||
            k.includes('["guest_user_01",') ||
            k.includes('["learner_default_01",'))
        ) {
          toDelete.push(k);
        }
      }
      for (const k of toDelete) {
        store.removeItem(k);
      }
    } catch { /* Optional browser storage. */ }
  };
  purge(globalThis.localStorage);
  purge(globalThis.sessionStorage);
}

registerSessionResetHandler(() => {
  purgeDemoReadingPositions();
});
