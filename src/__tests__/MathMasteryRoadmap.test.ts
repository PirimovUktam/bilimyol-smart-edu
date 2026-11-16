import { describe, expect, it } from 'vitest';
import { RouteEngine } from '@/domain/personalization/RouteEngine';
import { resolveContinuationLessonId } from '@/app/router/lessonResolution';
import type { Course } from '@/domain/entities/Course';
import type { LearningPathNode } from '@/domain/entities/LearningPathNode';

const course = { id: 'course_math_01', lessons: ['advanced'] } as Course;
const foundation: LearningPathNode = {
  id: 'addition', courseId: course.id, skillId: 'addition', title: 'Qo‘shish',
  prerequisites: [], requiredScore: 80, isReinforcement: false, targetLessonId: 'foundation',
  estimatedMinutes: 8, order: 10, status: 'reinforcement',
  mastery: { state: 'needs_review', answered: 2, correct: 0, requiredItems: 5,
    passedCheckpoints: 0, requiredCheckpoints: 2, reviewDue: false },
};
const advanced: LearningPathNode = {
  ...foundation, id: 'advanced', skillId: 'advanced', status: 'locked',
  prerequisites: [foundation.id], targetLessonId: 'advanced', order: 20,
};

describe('authoritative mathematics roadmap', () => {
  it('keeps server gates despite historical diagnostic scores and lesson completions', () => {
    const path = RouteEngine.adaptRoadmap(course.id, [foundation, advanced], {}, [foundation.id, advanced.id], []);
    expect(path.nodes).toEqual([foundation, advanced]);
    expect(path.activeNodeId).toBe(foundation.id);
    expect(resolveContinuationLessonId(course, path)).toBe('foundation');
  });

  it('leaves square expansion as a separate optional challenge', () => {
    const done = { ...foundation, status: 'completed' as const };
    const challenge = { ...advanced, status: 'available' as const, isOptional: true };
    const path = RouteEngine.adaptRoadmap(course.id, [done, challenge], {}, [], []);
    expect(resolveContinuationLessonId(course, path)).toBeNull();
  });
});
