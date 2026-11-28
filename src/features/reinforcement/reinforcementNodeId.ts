import { LearningPath, LearningPathNode } from '@/domain/entities/LearningPathNode';

/**
 * Resolves the underlying base roadmap node for a roadmap practice click.
 *
 * `RouteEngine.adaptRoadmap` creates `reinf_<base.id>` cards with
 * `targetLessonId` omitted, so stripping the `reinf_` prefix and matching by
 * id/prerequisite (and searching optional nodes too) must happen before falling
 * back to `skillId` — otherwise courses where many nodes share one skill
 * (e.g. `skill_math_algebra` or English CEFR skills) misroute to the first node.
 */
export function resolveRoadmapPracticeBaseNode(
  nodes: LearningPathNode[],
  node: LearningPathNode
): LearningPathNode | undefined {
  if (!node.isReinforcement) return node;
  const baseNodes = nodes.filter((n) => !n.isReinforcement);
  const strippedId = node.id.startsWith('reinf_') ? node.id.slice(6) : node.id;

  return (
    baseNodes.find((n) => n.id === strippedId) ??
    (node.targetLessonId
      ? baseNodes.find((n) => n.targetLessonId === node.targetLessonId)
      : undefined) ??
    baseNodes.find((n) => node.prerequisites.includes(n.id)) ??
    baseNodes.find((n) => n.skillId === node.skillId)
  );
}

/**
 * Resolves a canonical course- and lesson-scoped reinforcement node id.
 *
 * Priority when `lessonId` is supplied:
 * 1. Exact `isReinforcement` node matching `targetLessonId === lessonId` or
 *    `reinf_<baseByLesson.id>`.
 * 2. Matching base roadmap node (`!isReinforcement`) with
 *    `targetLessonId === lessonId`, mapped to `reinf_<node.id>`.
 * 3. `reinf_lesson_<lessonId>` (covers starter/foundation/AI lessons not on
 *    `roadmap.nodes` and calls before roadmap hydration completes, without
 *    misrouting to an unrelated node that happens to share `skillId`).
 *
 * Priority when `lessonId` is omitted:
 * 4. Explicit `isReinforcement` or base node matching `skillId`, else
 *    legacy `reinf_<courseId>_<skillId>`.
 */
export function deriveReinforcementNodeId(
  roadmap: LearningPath | null | undefined,
  courseId: string,
  skillId: string,
  lessonId?: string
): string {
  const cleanLessonId = lessonId?.trim();
  if (roadmap && roadmap.courseId === courseId) {
    if (cleanLessonId) {
      const baseByLesson = roadmap.nodes.find(
        (n) => !n.isReinforcement && n.targetLessonId === cleanLessonId
      );
      const explicitByLesson = roadmap.nodes.find(
        (n) =>
          n.isReinforcement &&
          (n.targetLessonId === cleanLessonId ||
            (baseByLesson !== undefined && n.id === `reinf_${baseByLesson.id}`))
      );
      if (explicitByLesson) return explicitByLesson.id;
      if (baseByLesson) {
        return baseByLesson.id.startsWith('reinf_')
          ? baseByLesson.id
          : `reinf_${baseByLesson.id}`;
      }
      return cleanLessonId.startsWith('reinf_')
        ? cleanLessonId
        : `reinf_lesson_${cleanLessonId}`;
    }

    const explicitBySkill = roadmap.nodes.find(
      (n) => n.isReinforcement && n.skillId === skillId
    );
    if (explicitBySkill) return explicitBySkill.id;

    const baseBySkill = roadmap.nodes.find(
      (n) => !n.isReinforcement && n.skillId === skillId
    );
    if (baseBySkill) {
      return baseBySkill.id.startsWith('reinf_')
        ? baseBySkill.id
        : `reinf_${baseBySkill.id}`;
    }
  }

  if (cleanLessonId) {
    return cleanLessonId.startsWith('reinf_') ? cleanLessonId : `reinf_lesson_${cleanLessonId}`;
  }
  return `reinf_${courseId}_${skillId}`;
}
