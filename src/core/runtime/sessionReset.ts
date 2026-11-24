export const ACTIVE_COURSE_STORAGE_KEY = 'bilimyol_active_course_id';

const sessionResetHandlers = new Set<() => void>();
const courseInvalidationHandlers = new Set<() => void>();

export function registerSessionResetHandler(handler: () => void): () => void {
  sessionResetHandlers.add(handler);
  return () => {
    sessionResetHandlers.delete(handler);
  };
}

export function resetAllSessionStores(): void {
  for (const handler of sessionResetHandlers) {
    handler();
  }
}

export function registerCourseInvalidationHandler(handler: () => void): () => void {
  courseInvalidationHandlers.add(handler);
  return () => {
    courseInvalidationHandlers.delete(handler);
  };
}

export function invalidateCourseScopedStores(): void {
  for (const handler of courseInvalidationHandlers) {
    handler();
  }
}
