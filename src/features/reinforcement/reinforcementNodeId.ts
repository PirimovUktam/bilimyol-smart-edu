import { LearningPath } from '@/domain/entities/LearningPathNode';

/**
 * Resolves a course-scoped reinforcement node id.
 *
 * Priority:
 * 1. The reinforcement node in the ACTIVE course's roadmap matching the skill
 *    (preserves RouteEngine-generated ids like `reinf_node_math_func` so
 *    XP idempotency keeps working).
 * 2. A deterministic course-scoped fallback — never a hardcoded node from
 *    another course (the old `isMath ? math : eng` pair leaked English ids
 *    for IT/logic learners).
 */
export function deriveReinforcementNodeId(
  roadmap: LearningPath | null | undefined,
  courseId: string,
  skillId: string
): string {
  if (roadmap && roadmap.courseId === courseId) {
    const node = roadmap.nodes.find((n) => n.isReinforcement && n.skillId === skillId);
    if (node) return node.id;
  }
  return `reinf_${courseId}_${skillId}`;
}
