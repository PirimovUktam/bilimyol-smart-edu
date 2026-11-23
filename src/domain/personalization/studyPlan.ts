import type { DailyTimeCommitment, OnboardingGoal } from '@/core/types/common';
import type { LearningPath, LearningPathNode } from '@/domain/entities/LearningPathNode';
import type { Lesson } from '@/domain/entities/Lesson';

export type PlanLesson = Pick<Lesson, 'id' | 'title' | 'titleRu' | 'estimatedMinutes'>;
type PlanItem = PlanLesson & { kind: 'lesson' | 'review' | 'checkpoint' | 'practice'; ready: boolean };
export type StudySession = { minutes: number; items: PlanItem[] };

export function buildStudyPlan(
  courseId: string, path: LearningPath | null, foundation: PlanLesson[],
  completedLessonIds: readonly string[], goal: OnboardingGoal, budget: DailyTimeCommitment,
): StudySession[] {
  const nodes = (path?.courseId === courseId ? path.nodes : []).filter((node) => node.courseId === courseId);
  const completed = new Set(nodes.filter((node) => node.status === 'completed').map((node) => node.id));
  const planned = new Set<string>();
  const usedLessons = new Set<string>();
  const placementEntry = nodes.find((node) => node.isPlacementRecommended);
  const sessions: StudySession[] = [];
  const append = (item: PlanItem) => {
    let session = sessions.at(-1);
    if (!session || session.minutes + item.estimatedMinutes > budget) {
      if (sessions.length === 3) return false;
      session = { minutes: 0, items: [] };
      sessions.push(session);
    }
    session.items.push(item);
    session.minutes += item.estimatedMinutes;
    usedLessons.add(item.id);
    return true;
  };

  for (const [index, lesson] of foundation.entries()) {
    if (!append({ ...lesson, kind: 'lesson', ready: index === 0 })) return sessions;
    nodes.filter((node) => node.targetLessonId === lesson.id).forEach((node) => planned.add(node.id));
  }

  const kind = (node: LearningPathNode): PlanItem['kind'] => {
    if (node.mastery?.reviewDue || node.mastery?.state === 'needs_review') return 'review';
    if (node.isCheckpoint || node.nodeKind === 'unit_checkpoint' || node.nodeKind === 'level_assessment') return 'checkpoint';
    if (node.status === 'reinforcement' || node.routeStrategy === 'targeted_practice') return 'practice';
    return 'lesson';
  };
  const ready = (node: LearningPathNode) => node.status !== 'locked';
  const priority = (node: LearningPathNode) => {
    if (!ready(node)) return 4;
    if (kind(node) === 'review') return 0;
    if (goal === 'exam_prep' && kind(node) === 'checkpoint') return 1;
    if (goal === 'skills_boost' && kind(node) === 'practice') return 1;
    return node.id === path?.activeNodeId ? 2 : 3;
  };
  const candidates = nodes.flatMap((node) => {
    const id = node.targetLessonId;
    if (!id || node.isReinforcement || (node.isOptional && !node.mastery?.reviewDue) || !(node.estimatedMinutes > 0)) return [];
    if (node.status === 'completed' || completedLessonIds.includes(id)) {
      if (!node.mastery?.reviewDue) return [];
    }
    if (placementEntry && node.order < placementEntry.order && kind(node) !== 'review') return [];
    return [{ node, id, kind: kind(node), priority: priority(node) }];
  }).sort((a, b) => a.priority - b.priority || a.node.order - b.node.order);

  for (;;) {
    const next = candidates.find(({ node, id }) => !usedLessons.has(id) && (
      ready(node) || (planned.size > 0 && node.prerequisites.length > 0 && node.prerequisites.every((id) => completed.has(id) || planned.has(id)))
    ));
    if (!next || !append({
      id: next.id, title: next.node.title, titleRu: next.node.titleRu, estimatedMinutes: next.node.estimatedMinutes,
      kind: next.kind, ready: foundation.length === 0 && ready(next.node),
    })) return sessions;
    planned.add(next.node.id);
  }
}
