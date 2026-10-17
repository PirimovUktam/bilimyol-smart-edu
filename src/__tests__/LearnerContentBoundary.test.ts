import { describe, expect, it } from 'vitest';
import { stripAnswerKeys, scopeFallbackQuestionId } from '../../supabase/functions/yolchi-tutor/learner-content';
import { mapLearnerLesson } from '../data/repositories/SupabaseLessonRepository';

describe('learner content boundary', () => {
  it('recursively strips camel/snake answer metadata without mutating the cached row', () => {
    const raw = {
      steps: [{ interactive_question: { id: 'q', options: ['a', 'b'], correct_index: 1, explanation: 'secret', nested: [{ correctOptionId: 'b', keep: true }] } }],
      reinforcement: { correctIndex: 0, answer: 'a' },
    };
    expect(stripAnswerKeys(raw)).toEqual({
      steps: [{ interactive_question: { id: 'q', options: ['a', 'b'], nested: [{ keep: true }] } }], reinforcement: {},
    });
    expect(raw.steps[0].interactive_question.correct_index).toBe(1);
    expect(stripAnswerKeys([null, 'text', 12])).toEqual([null, 'text', 12]);
  });

  it('scopes deterministic template question ids so different skills cannot overwrite one key', () => {
    const first = scopeFallbackQuestionId('q_fallback_eng_1', 'course_eng_01', 'skill_eng_vocab');
    expect(first).not.toBe(scopeFallbackQuestionId('q_fallback_eng_1', 'course_eng_01', 'skill_eng_grammar'));
    expect(first).toBe(scopeFallbackQuestionId('q_fallback_eng_1', 'course_eng_01', 'skill_eng_vocab'));
  });

  const row = {
    id: 'lesson_generated', course_id: 'course_math_01', skill_id: 'skill_math_functions', title: 'Lesson',
    steps: [{ id: 'step', stepNumber: 1, type: 'interactive_question', title: 'Check', content: '' }],
    questions: [{ id: 'q_server', text: 'Question?', options: ['a', 'b'], difficulty: 'easy', correct_index: 1 }],
  };

  it('restores generated interactive steps with the real server question id and context', () => {
    const lesson = mapLearnerLesson(row);
    expect(lesson.steps[0].interactiveQuestion).toMatchObject({ id: 'q_server', courseId: row.course_id, skillId: row.skill_id });
    expect(lesson.steps[0].interactiveQuestion).not.toHaveProperty('correctIndex');
    expect(lesson.steps[0].interactiveQuestion).not.toHaveProperty('correct_index');
    expect(lesson.reinforcementExercise.id).toBe('q_server');
  });

  it('normalizes curated snake_case embedded questions without leaking a raw alias', () => {
    const { questions: _questions, ...curated } = row;
    const lesson = mapLearnerLesson({ ...curated, steps: [{ ...row.steps[0], interactive_question: row.questions[0] }] });
    expect(lesson.steps[0].interactiveQuestion?.courseId).toBe(row.course_id);
    expect(lesson.steps[0]).not.toHaveProperty('interactive_question');
  });

  it('rejects missing assessments instead of inventing an unscorable success question', () => {
    expect(() => mapLearnerLesson({ ...row, questions: [] })).toThrow();
  });
});
