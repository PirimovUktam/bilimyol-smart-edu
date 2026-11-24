import { LearningPath } from '@/domain/entities/LearningPathNode';

/**
 * Resolves a canonical course- and lesson-scoped reinforcement node id.
 *
 * Priority:
 * 1. An explicit `isReinforcement` node on the active course roadmap
 *    (preferring an exact `targetLessonId` match when provided, then `skillId`).
 * 2. A matching base roadmap node (`!isReinforcement`) via `targetLessonId` or
 *    `skillId`, mapped to `reinf_<node.id>` (covers Live Math Pilot and
 *    mid-lesson modals when `score >= 50%` so no `isReinforcement` node was
 *    injected).
 * 3. `reinf_lesson_<lessonId>` when `lessonId` is supplied without a matching
 *    roadmap node (for example, before roadmap hydration completes).
 * 4. Legacy `reinf_<courseId>_<skillId>` fallback only when neither roadmap
 *    node nor `lessonId` is known.
 */
export function deriveReinforcementNodeId(
  roadmap: LearningPath | null | undefined,
  courseId: string,
  skillId: string,
  lessonId?: string
): string {
  const cleanLessonId = lessonId?.trim();
  if (roadmap && roadmap.courseId === courseId) {
    const baseByLesson = cleanLessonId
      ? roadmap.nodes.find((n) => !n.isReinforcement && n.targetLessonId === cleanLessonId)
      : undefined;

    const explicitReinf =
      (cleanLessonId
        ? roadmap.nodes.find(
            (n) =>
              n.isReinforcement &&
              (n.targetLessonId === cleanLessonId ||
                (baseByLesson !== undefined && n.id === `reinf_${baseByLesson.id}`))
          )
        : undefined) ??
      roadmap.nodes.find((n) => n.isReinforcement && n.skillId === skillId);
    if (explicitReinf) return explicitReinf.id;

    const baseNode =
      baseByLesson ?? roadmap.nodes.find((n) => !n.isReinforcement && n.skillId === skillId);
    if (baseNode) {
      return baseNode.id.startsWith('reinf_') ? baseNode.id : `reinf_${baseNode.id}`;
    }
  }

  if (cleanLessonId) {
    return cleanLessonId.startsWith('reinf_') ? cleanLessonId : `reinf_lesson_${cleanLessonId}`;
  }
  return `reinf_${courseId}_${skillId}`;
}
