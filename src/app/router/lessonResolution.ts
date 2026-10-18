import { Course } from '@/domain/entities/Course';
import { LearningPath, LearningPathNode } from '@/domain/entities/LearningPathNode';

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

/**
 * A completed roadmap node can only be reviewed through its own lesson.
 * Generic continuation lessons are valid for active nodes, never for review.
 */
export function resolveRoadmapNodeLessonId(
  node: Pick<LearningPathNode, 'status' | 'targetLessonId'>,
  continuationLessonId: string | null
): string | null {
  if (node.targetLessonId) return node.targetLessonId;
  return node.status === 'completed' ? null : continuationLessonId;
}

export interface CourseReconciliationDecision {
  shouldReconcile: boolean;
  nextLastSeenId: string | null;
}

/**
 * One-way reconciliation decision between the learner profile's selected
 * course and the active course store.
 *
 * The first profile value is a real server preference, not merely a baseline:
 * it must be allowed to replace a local-storage restore during startup. The
 * caller records the value before selecting it, so the profile write-back of
 * that same value cannot trigger another reconciliation (or a ping-pong loop).
 */
export function decideCourseReconciliation(
  lastSeenId: string | null,
  selectedCourseId: string | null | undefined,
  coursesCount: number
): CourseReconciliationDecision {
  if (!selectedCourseId) {
    return { shouldReconcile: false, nextLastSeenId: lastSeenId };
  }
  if (coursesCount === 0) {
    // Courses not loaded yet: keep waiting until the id can be validated.
    return { shouldReconcile: false, nextLastSeenId: lastSeenId };
  }
  if (lastSeenId === null) {
    return { shouldReconcile: true, nextLastSeenId: selectedCourseId };
  }
  if (lastSeenId === selectedCourseId) {
    return { shouldReconcile: false, nextLastSeenId: lastSeenId };
  }
  return { shouldReconcile: true, nextLastSeenId: selectedCourseId };
}
