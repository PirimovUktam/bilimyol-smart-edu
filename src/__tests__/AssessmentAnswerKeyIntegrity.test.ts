import { describe, it, expect } from 'vitest';
import { PLACEMENT_QUESTIONS } from '@/data/datasources/questions';
import { SEED_LESSONS } from '@/data/datasources/lessons';
import { InMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';
import { DemoAITutorService } from '@/data/services/DemoAITutorService';
import { GeminiAITutorService } from '@/data/services/GeminiAITutorService';
import { SubmitLessonAnswerUseCase } from '@/domain/usecases/SubmitLessonAnswerUseCase';
import { Question } from '@/domain/entities/Question';

const collectSeedQuestions = (): Question[] => {
  const list: Question[] = [];
  Object.values(PLACEMENT_QUESTIONS).forEach((questions) => list.push(...questions));
  Object.values(SEED_LESSONS).forEach((lesson) => {
    lesson.steps.forEach((step) => {
      if (step.interactiveQuestion) list.push(step.interactiveQuestion);
    });
    if (lesson.reinforcementExercise) list.push(lesson.reinforcementExercise);
  });
  return list;
};

const toClientQuestion = (question: Question): Question => {
  const { correctIndex: _correctIndex, ...clientQuestion } = question;
  return clientQuestion as Question;
};

describe('Curriculum answer-key integrity & scorable AI content', () => {
  const seedQuestions = collectSeedQuestions();

  it('every authored question has a valid correctIndex and a real explanation', () => {
    expect(seedQuestions.length).toBeGreaterThan(20);
    seedQuestions.forEach((question) => {
      expect(question.options.length).toBeGreaterThanOrEqual(3);
      expect(Number.isInteger(question.correctIndex)).toBe(true);
      expect(question.correctIndex!).toBeGreaterThanOrEqual(0);
      expect(question.correctIndex!).toBeLessThan(question.options.length);
      expect((question.explanation || '').trim().length).toBeGreaterThan(4);
    });
  });

  it('question ids are globally unique across placement and lesson banks', () => {
    const ids = seedQuestions.map((question) => question.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('correct answers are distributed across option positions (regression: all were index 0)', () => {
    const distinctPositions = new Set(seedQuestions.map((question) => question.correctIndex));
    expect(distinctPositions.size).toBeGreaterThanOrEqual(3);

    const zeroCount = seedQuestions.filter((question) => question.correctIndex === 0).length;
    expect(zeroCount).toBeLessThan(seedQuestions.length);
  });

  it('seeded questions are scored by the server and reveal the correct option on mistakes', async () => {
    const lesson = SEED_LESSONS['lesson_math_functions_01'];
    const authored = lesson.steps.find((step) => step.interactiveQuestion)!.interactiveQuestion!;
    const correctIndex = authored.correctIndex!;
    const clientQuestion = toClientQuestion(authored);

    const repo = new InMemoryLearnerRepository();
    const useCase = new SubmitLessonAnswerUseCase(new DemoAITutorService(), repo);

    const correct = await useCase.execute(clientQuestion, correctIndex, 'Ali', lesson.id);
    expect(correct.isCorrect).toBe(true);
    expect(correct.correctOption).toBe(authored.options[correctIndex]);

    const wrongIndex = (correctIndex + 1) % authored.options.length;
    const wrong = await useCase.execute(clientQuestion, wrongIndex, 'Ali', lesson.id);
    expect(wrong.isCorrect).toBe(false);
    expect(wrong.correctOption).toBe(authored.options[correctIndex]);
    expect(wrong.aiExplanation).toBeDefined();
  });

  it('AI-generated lesson questions are scorable and never leak the answer key', async () => {
    const service = new DemoAITutorService();
    const lesson = await service.generateLesson({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
    });
    const generated = lesson.questions[0];

    expect((generated as Record<string, unknown>).correctIndex).toBeUndefined();
    expect((generated as Record<string, unknown>).explanation).toBeUndefined();

    const clientQuestion: Question = {
      id: generated.id,
      courseId: generated.courseId,
      skillId: generated.skillId,
      text: generated.text,
      options: generated.options,
      difficulty: generated.difficulty,
      explanation: '',
    };

    const useCase = new SubmitLessonAnswerUseCase(service, new InMemoryLearnerRepository());
    const results = [];
    for (let index = 0; index < generated.options.length; index++) {
      results.push(await useCase.execute(clientQuestion, index, 'Ali', lesson.lessonId));
    }

    const correctResults = results.filter((result) => result.isCorrect);
    expect(correctResults).toHaveLength(1);
    const correctOption = correctResults[0].correctOption;
    expect(correctOption).toBeDefined();

    results
      .filter((result) => !result.isCorrect)
      .forEach((result) => expect(result.correctOption).toBe(correctOption));
  });

  it('subject-scoped deterministic fallback questions are also scorable', async () => {
    const service = new GeminiAITutorService();
    const fallback = await service.generateQuestion({
      courseId: 'course_logic',
      skillId: 'skill_logic_patterns',
      difficulty: 'medium',
    });
    expect((fallback as Record<string, unknown>).correctIndex).toBeUndefined();

    const clientQuestion: Question = {
      id: fallback.id,
      courseId: fallback.courseId,
      skillId: fallback.skillId,
      text: fallback.text,
      options: fallback.options,
      difficulty: fallback.difficulty,
      explanation: '',
    };

    const useCase = new SubmitLessonAnswerUseCase(service, new InMemoryLearnerRepository());
    const results = [];
    for (let index = 0; index < fallback.options.length; index++) {
      results.push(await useCase.execute(clientQuestion, index, 'Ali', 'lesson_fallback'));
    }
    expect(results.filter((result) => result.isCorrect)).toHaveLength(1);
    results
      .filter((result) => !result.isCorrect)
      .forEach((result) => expect(result.correctOption).toBeDefined());
  });
});