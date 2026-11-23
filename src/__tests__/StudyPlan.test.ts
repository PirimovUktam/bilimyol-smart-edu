import { describe, expect, it } from 'vitest';
import type { LearningPath, LearningPathNode } from '@/domain/entities/LearningPathNode';
import { buildStudyPlan } from '@/domain/personalization/studyPlan';
import { resolveNextLearningLesson } from '@/app/router/lessonResolution';
import { InMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';
import { SEED_COURSES } from '@/data/datasources/courses';

const courseId = 'course_logic';
const node = (id: string, order: number, overrides: Partial<LearningPathNode> = {}): LearningPathNode => ({
  id, courseId, order, status: 'available', title: id, targetLessonId: id,
  skillId: 'logic', isReinforcement: false, estimatedMinutes: 7, requiredScore: 70, prerequisites: [],
  ...overrides,
});
const path = (nodes: LearningPathNode[], activeNodeId = 'one'): LearningPath => ({
  id: courseId, courseId, title: courseId, activeNodeId, updatedAt: 0, nodes,
});

describe('study plan', () => {
  it('opens the lesson shown for the saved goal and rejects stale course links', async () => {
    const course = SEED_COURSES.find((item) => item.id === courseId)!;
    const profile = await new InMemoryLearnerRepository().getProfile();
    profile.courseLevels = { [courseId]: 'intermediate' };
    profile.goal = 'exam_prep';
    const topics = path([node('one', 1), node('exam', 2, { isCheckpoint: true })]);
    expect(resolveNextLearningLesson(course, profile, topics)).toBe('exam');
    expect(resolveNextLearningLesson(course, profile, { ...topics, courseId: 'other' })).toBeNull();
    expect(resolveNextLearningLesson(course, profile, path([node('one', 1, { courseId: 'other' })]))).toBeNull();
  });
  it('groups projected lessons by real duration without granting prerequisite access', () => {
    const topics = path([
      node('one', 1),
      node('two', 2, { status: 'locked', prerequisites: ['one'] }),
      node('three', 3, { status: 'locked', prerequisites: ['two'] }),
      node('blocked', 4, { status: 'locked', prerequisites: ['missing'] }),
    ]);
    const first = { id: 'one', title: 'Foundation', estimatedMinutes: 7 };
    const plan = buildStudyPlan(courseId, topics, [first], [], 'mastery', 15);
    expect(plan.map((session) => session.minutes)).toEqual([14, 7]);
    expect(plan.flatMap((session) => session.items.map(({ id, ready }) => [id, ready]))).toEqual([
      ['one', true], ['two', false], ['three', false],
    ]);
    expect(buildStudyPlan(courseId, topics, [first], [], 'mastery', 30)).toHaveLength(1);
  });

  it('uses actual open checkpoints and practice for goals, and keeps due review first', () => {
    const topics = path([
      node('one', 1),
      node('two', 2, { nodeKind: 'unit_checkpoint' }),
      node('three', 3, { routeStrategy: 'targeted_practice' }),
      node('four', 4, { status: 'locked', isCheckpoint: true, prerequisites: ['missing'] }),
    ]);
    const first = (goal: 'mastery' | 'exam_prep' | 'skills_boost') =>
      buildStudyPlan(courseId, topics, [], [], goal, 15)[0].items[0].id;
    expect([first('mastery'), first('exam_prep'), first('skills_boost')]).toEqual(['one', 'two', 'three']);
    topics.nodes.push(node('review', 0, { status: 'completed', mastery: {
      state: 'mastered', answered: 5, correct: 5, requiredItems: 5, passedCheckpoints: 2, requiredCheckpoints: 2, reviewDue: true,
    } }));
    expect(first('exam_prep')).toBe('review');
  });

  it('skips completed and foreign lessons and displays the full time for a long lesson', () => {
    const topics = path([
      node('one', 1), node('foreign', 2, { courseId: 'course_math_01' }),
      node('long', 3, { estimatedMinutes: 23 }), node('next', 4),
    ]);
    expect(buildStudyPlan(courseId, topics, [], ['one'], 'mastery', 15).map(({ minutes }) => minutes)).toEqual([23, 7]);
    expect(buildStudyPlan('course_eng_01', topics, [], [], 'mastery', 15)).toEqual([]);
  });
});
