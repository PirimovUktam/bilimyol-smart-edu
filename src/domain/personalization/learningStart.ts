import type { Course } from '@/domain/entities/Course';
import type { LearnerProfile } from '@/domain/entities/LearnerProfile';
import { isSupabaseConfigured } from '@/core/config/supabase';
import { isDemoRuntimeActive } from '@/core/runtime/demoRuntime';

export const MATH_MASTERY_COURSE = 'course_math_01';

export function usesMathMastery(courseId: string | undefined): boolean {
  return courseId === MATH_MASTERY_COURSE && isSupabaseConfigured && !isDemoRuntimeActive();
}

export function hasStartedCourse(course: Course, profile: LearnerProfile | null): boolean {
  if (!profile) return false;
  return Boolean(profile.courseLevels?.[course.id]) ||
    profile.placementScoreByCourse?.[course.id] !== undefined ||
    Boolean(profile.placementCefrByCourse?.[course.id]) ||
    Object.keys(profile.scoresByCourse[course.id] ?? {}).length > 0 ||
    course.lessons.some((id) => profile.completedLessonIds.includes(id));
}

export function foundationLessons(course: Course): string[] {
  if (course.foundationLessonIds?.length) return course.foundationLessonIds;
  return course.starterLessonId ? [course.starterLessonId] : [];
}

export function pendingFoundationLesson(course: Course | null, profile: LearnerProfile | null): string | null {
  if (!course || usesMathMastery(course.id) || profile?.courseLevels?.[course.id] !== 'beginner') return null;
  const placedCefr = profile?.placementCefrByCourse?.[course.id];
  if (placedCefr === 'A1' || placedCefr === 'A2' || placedCefr === 'B1') return null;
  return foundationLessons(course).find((id) => !profile.completedLessonIds.includes(id)) ?? null;
}
