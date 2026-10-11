import { Course } from '@/domain/entities/Course';
import { LearningPath } from '@/domain/entities/LearningPathNode';

/**
 * Resolves which lesson "Continue" should open for the ACTIVE course only.
 * Never derives a lesson from another course: a stale roadmap (different
 * courseId) or a course without lessons yields null so callers can route to
 * an honest empty state instead of foreign content.
 */
export function resolveContinuationLessonId(
  activeCourse: Course | null | undefined,
  roadmap: LearningPath | null | undefined
): string | null {
  if (!activeCourse) return null;

  if (roadmap && roadmap.courseId === activeCourse.id) {
    const preferred =
      roadmap.nodes.find((n) => n.targetLessonId && (n.status === 'available' || n.status === 'reinforcement')) ||
      roadmap.nodes.find((n) => n.targetLessonId && n.status === 'completed') ||
      roadmap.nodes.find((n) => Boolean(n.targetLessonId));
    if (preferred?.targetLessonId) return preferred.targetLessonId;
  }

  if (activeCourse.lessons && activeCourse.lessons.length > 0) {
    return activeCourse.lessons[0];
  }

  return null;
}

/**
 * True when a loaded lesson belongs to a different course than the one the
 * learner selected — the lesson UI must refuse to render it.
 */
export function isLessonCourseMismatch(
  lesson: { courseId: string } | null | undefined,
  activeCourse: Course | null | undefined
): boolean {
  if (!lesson || !activeCourse) return false;
  return lesson.courseId !== activeCourse.id;
}
