import type { Lesson } from '@/domain/entities/Lesson';

function key(accountId: string, lesson: Lesson) {
  return 'bilimyol-reading:' + JSON.stringify([accountId, lesson.courseId, lesson.id]);
}

function safePosition(lesson: Lesson, index: number) {
  const exercise = lesson.steps.findIndex((step) => step.interactiveQuestion || step.type === 'interactive_question');
  const last = exercise === -1 ? lesson.steps.length - 1 : exercise;
  return Number.isInteger(index) && index >= 0 ? Math.max(0, Math.min(last, index)) : 0;
}

export function readLessonPosition(accountId: string, lesson: Lesson) {
  try { return safePosition(lesson, Number(sessionStorage.getItem(key(accountId, lesson)))); }
  catch { return 0; }
}

export function saveLessonPosition(accountId: string, lesson: Lesson, step: number) {
  // A browser checkpoint can restore reading. Only the assessment service can confirm answers.
  try { sessionStorage.setItem(key(accountId, lesson), String(safePosition(lesson, step))); }
  catch { /* Reading remains available without browser storage. */ }
}

export function clearLessonPosition(accountId: string, lesson: Lesson) {
  try { sessionStorage.removeItem(key(accountId, lesson)); }
  catch { /* Optional browser storage. */ }
}
