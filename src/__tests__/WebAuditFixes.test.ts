import { describe, expect, it, beforeEach } from 'vitest';
import { getPlacementQuestionCount, usePlacementStore } from '../app/store/usePlacementStore';
import { shouldCompleteLesson } from '../app/store/useLessonStore';
import { resolveRoadmapNodeLessonId } from '../app/router/lessonResolution';
import { useCourseStore } from '../app/store/useCourseStore';
import { useLearnerStore } from '../app/store/useLearnerStore';
import { useRoadmapStore } from '../app/store/useRoadmapStore';
import { Question } from '../domain/entities/Question';

const question = (id: string, skillId: string): Question => ({
  id,
  courseId: 'course_math_01',
  skillId,
  text: id,
  options: ['A', 'B'],
  correctIndex: 0,
  difficulty: 'easy',
  explanation: 'test',
});

describe('approved web audit regressions', () => {
  beforeEach(() => {
    usePlacementStore.getState().resetPlacement();
    useCourseStore.getState().clearSession();
    useLearnerStore.getState().clearSession();
    useRoadmapStore.getState().clearSession();
  });

  it('derives placement copy count from the configured skill coverage', () => {
    const bank = [
      question('q1', 'skill_a'),
      question('q2', 'skill_a'),
      question('q3', 'skill_a'),
      question('q4', 'skill_b'),
    ];

    expect(getPlacementQuestionCount(bank, ['skill_a', 'skill_b'])).toBe(3);
    expect(getPlacementQuestionCount([], ['skill_a', 'skill_b'])).toBe(0);
  });

  it('terminates an empty placement load with an actionable error state', async () => {
    // A course id with no placement bank — exercises the honest empty path.
    await usePlacementStore.getState().initPlacement('course_nonexistent_99');
    const state = usePlacementStore.getState();

    expect(state.isLoading).toBe(false);
    expect(state.currentQuestion).toBeNull();
    expect(state.totalQuestionsToAsk).toBe(0);
    expect(state.error).toContain('savollar');
  });

  it('only completes a lesson on its final step', () => {
    expect(shouldCompleteLesson(0, 3)).toBe(false);
    expect(shouldCompleteLesson(1, 3)).toBe(false);
    expect(shouldCompleteLesson(2, 3)).toBe(true);
  });

  it('never assigns a generic lesson to completed nodes without a target', () => {
    expect(resolveRoadmapNodeLessonId({ status: 'completed' }, 'lesson_generic')).toBeNull();
    expect(resolveRoadmapNodeLessonId({ status: 'available' }, 'lesson_generic')).toBe('lesson_generic');
    expect(resolveRoadmapNodeLessonId({ status: 'completed', targetLessonId: 'lesson_exact' }, 'lesson_generic')).toBe('lesson_exact');
  });
});
