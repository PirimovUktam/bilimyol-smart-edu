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
    try {
      handler();
    } catch (error) {
      console.warn('Session reset handler failed:', error);
    }
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
    try {
      handler();
    } catch (error) {
      console.warn('Course invalidation handler failed:', error);
    }
  }
}
