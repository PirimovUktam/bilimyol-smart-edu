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
 * The FIRST observed profile value (once courses are loaded) is only recorded
 * as a baseline — never reconciled — so the localStorage-restored course is
 * not stomped by a still-default profile during startup. Afterwards only a
 * genuine profile VALUE change may reconcile, and the caller must react by
 * selecting that same course (which writes back the SAME value), so the
 * effect's trigger can never change again: no math⇄english ping-pong loop.
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
    // Courses not loaded yet: keep waiting for a proper baseline.
    return { shouldReconcile: false, nextLastSeenId: lastSeenId };
  }
  if (lastSeenId === null) {
    return { shouldReconcile: false, nextLastSeenId: selectedCourseId };
  }
  if (lastSeenId === selectedCourseId) {
    return { shouldReconcile: false, nextLastSeenId: lastSeenId };
  }
  return { shouldReconcile: true, nextLastSeenId: selectedCourseId };
}
