import type { Course } from '@/domain/entities/Course';
import type { LearnerProfile } from '@/domain/entities/LearnerProfile';

export function hasStartedCourse(course: Course, profile: LearnerProfile | null): boolean {
  if (!profile) return false;
  return Boolean(profile.courseLevels?.[course.id]) ||
    Object.keys(profile.scoresByCourse[course.id] ?? {}).length > 0 ||
    course.lessons.some((id) => profile.completedLessonIds.includes(id));
}

export function foundationLessons(course: Course): string[] {
  if (course.foundationLessonIds?.length) return course.foundationLessonIds;
  return course.starterLessonId ? [course.starterLessonId] : [];
}

export function pendingFoundationLesson(course: Course | null, profile: LearnerProfile | null): string | null {
  if (!course || profile?.courseLevels?.[course.id] !== 'beginner') return null;
  return foundationLessons(course).find((id) => !profile.completedLessonIds.includes(id)) ?? null;
}
