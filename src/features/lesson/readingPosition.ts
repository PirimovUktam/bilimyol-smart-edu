import type { Lesson } from '@/domain/entities/Lesson';
import { readPersistedAnsweredQuestionIds } from './lessonRecoveryStorage';

function key(accountId: string, lesson: Lesson) {
  return 'bilimyol-reading:' + JSON.stringify([accountId, lesson.courseId, lesson.id]);
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
  const resolvedAnswered =
    answeredQuestionIds ??
    readPersistedAnsweredQuestionIds(accountId, lesson.courseId, lesson.id);
  try {
    const storageKey = key(accountId, lesson);
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
  const resolvedAnswered =
    answeredQuestionIds ??
    readPersistedAnsweredQuestionIds(accountId, lesson.courseId, lesson.id);
  const clamped = String(safePosition(lesson, step, resolvedAnswered));
  const storageKey = key(accountId, lesson);
  try {
    globalThis.sessionStorage?.setItem(storageKey, clamped);
  } catch { /* Optional browser storage. */ }
  try {
    globalThis.localStorage?.setItem(storageKey, clamped);
  } catch { /* Optional browser storage. */ }
}

export function clearLessonPosition(accountId: string | undefined | null, lesson: Lesson) {
  const resolvedAccount = typeof accountId === 'string' && accountId.trim() ? accountId : 'demo';
  const storageKey = key(resolvedAccount, lesson);
  try {
    globalThis.sessionStorage?.removeItem(storageKey);
  } catch { /* Optional browser storage. */ }
  try {
    globalThis.localStorage?.removeItem(storageKey);
  } catch { /* Optional browser storage. */ }
}
