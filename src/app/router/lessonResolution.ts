import { Course } from '@/domain/entities/Course';
import { LearningPath, LearningPathNode } from '@/domain/entities/LearningPathNode';
import type { LearnerProfile } from '@/domain/entities/LearnerProfile';
import { hasStartedCourse, pendingFoundationLesson } from '@/domain/personalization/learningStart';

export function resolveNextLearningLesson(course: Course | null, profile: LearnerProfile | null, roadmap: LearningPath | null): string | null {
  if (!course || !hasStartedCourse(course, profile)) return null;
  return pendingFoundationLesson(course, profile) ?? (roadmap?.courseId === course.id ? resolveContinuationLessonId(course, roadmap) : null);
}

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
    const topics = roadmap.nodes.filter((node) => !node.isReinforcement);
    const preferred = topics.find((node) => node.status === 'available' || node.status === 'reinforcement' || node.status === 'in_progress');
    if (preferred) return preferred.targetLessonId ?? null;
    if (topics.length > 0) return topics.every((node) => node.status === 'completed')
      ? topics.find((node) => node.targetLessonId)?.targetLessonId ?? null
      : null;
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
 * Each roadmap node can only start or review its own lesson.
 */
export function resolveRoadmapNodeLessonId(node: Pick<LearningPathNode, 'status' | 'targetLessonId'>): string | null {
  return node.status === 'locked' ? null : node.targetLessonId ?? null;
}
