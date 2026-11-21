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
    if (lesson.alternateExercise) list.push(lesson.alternateExercise);
  });
  return list;
};

const toClientQuestion = (question: Question): Question => {
  const { correctIndex: _correctIndex, ...clientQuestion } = question;
  return clientQuestion as Question;
};

const isChoiceMode = (q: Question): boolean => {
  const qType = q.questionType ?? 'multiple_choice';
  return qType === 'multiple_choice' || qType === 'error_correction' || qType === 'conversation_completion';
};

describe('Curriculum answer-key integrity & scorable AI content', () => {
  const seedQuestions = collectSeedQuestions();
  const mcqQuestions = seedQuestions.filter(isChoiceMode);
  const textQuestions = seedQuestions.filter(
    (question) => question.questionType === 'text_input' || question.questionType === 'fill_blank'
  );
  const wordMatchQuestions = seedQuestions.filter((q) => q.questionType === 'word_match');
  const sentenceOrderQuestions = seedQuestions.filter((q) => q.questionType === 'sentence_order');
  const selfAssessedQuestions = seedQuestions.filter(
    (q) => q.questionType === 'speaking_prompt' || q.questionType === 'writing_prompt'
  );

  it('every authored question has a valid answer key and a real explanation', () => {
    expect(seedQuestions.length).toBeGreaterThan(20);
    mcqQuestions.forEach((question) => {
      expect(question.options.length).toBeGreaterThanOrEqual(3);
      expect(Number.isInteger(question.correctIndex)).toBe(true);
      expect(question.correctIndex!).toBeGreaterThanOrEqual(0);
      expect(question.correctIndex!).toBeLessThan(question.options.length);
      expect((question.explanation || '').trim().length).toBeGreaterThan(4);
    });
    expect(textQuestions.length).toBeGreaterThanOrEqual(1);
    textQuestions.forEach((question) => {
      expect(Array.isArray(question.acceptedAnswers)).toBe(true);
      expect(question.acceptedAnswers!.length).toBeGreaterThanOrEqual(1);
      expect((question.explanation || '').trim().length).toBeGreaterThan(4);
      expect((question.wrongFeedback || '').trim().length).toBeGreaterThan(4);
    });
    expect(wordMatchQuestions.length).toBeGreaterThanOrEqual(1);
    wordMatchQuestions.forEach((question) => {
      expect(Array.isArray(question.matchPairs)).toBe(true);
      expect(question.matchPairs!.length).toBeGreaterThanOrEqual(3);
      expect((question.explanation || '').trim().length).toBeGreaterThan(4);
    });
    expect(sentenceOrderQuestions.length).toBeGreaterThanOrEqual(1);
    sentenceOrderQuestions.forEach((question) => {
      expect(Array.isArray(question.orderedTokens)).toBe(true);
      expect(question.orderedTokens!.length).toBeGreaterThanOrEqual(3);
      expect((question.explanation || '').trim().length).toBeGreaterThan(4);
    });
    expect(selfAssessedQuestions.length).toBeGreaterThanOrEqual(2);
    selfAssessedQuestions.forEach((question) => {
      expect(question.evaluationMode).toBe('self_assessed');
      expect((question.sampleResponse || '').trim().length).toBeGreaterThan(5);
      expect(Array.isArray(question.rubricCriteria)).toBe(true);
      expect(question.rubricCriteria!.length).toBeGreaterThanOrEqual(3);
    });
  });

  it('question ids are globally unique across placement and lesson banks', () => {
    const ids = seedQuestions.map((question) => question.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('correct answers are distributed across option positions (regression: all were index 0)', () => {
    const distinctPositions = new Set(mcqQuestions.map((question) => question.correctIndex));
    expect(distinctPositions.size).toBeGreaterThanOrEqual(3);

    const zeroCount = mcqQuestions.filter((question) => question.correctIndex === 0).length;
    expect(zeroCount).toBeLessThan(mcqQuestions.length);
  });

  it('free-text English starter question accepts valid variants and withholds spoilers on mistakes', async () => {
    const starter = SEED_LESSONS['lesson_eng_starter'];
    const authored = starter.steps.find((step) => step.interactiveQuestion)!.interactiveQuestion!;
    const { acceptedAnswers: _accepted, ...clientQuestion } = authored;
    const repo = new InMemoryLearnerRepository();
    const useCase = new SubmitLessonAnswerUseCase(repo);

    const wrongNameOnly = await useCase.executeText(clientQuestion as Question, 'Sam', starter.id);
    expect(wrongNameOnly.isCorrect).toBe(false);
    expect(wrongNameOnly.correctOption).toBe('');
    expect(wrongNameOnly.explanation).toContain('I\'m');

    const wrongGoodbye = await useCase.executeText(clientQuestion as Question, 'Goodbye', starter.id);
    expect(wrongGoodbye.isCorrect).toBe(false);
    expect(wrongGoodbye.correctOption).toBe('');
    expect(wrongGoodbye.explanation).toContain('Goodbye');

    const validShort = await useCase.executeText(clientQuestion as Question, "I'm Sam", starter.id);
    expect(validShort.isCorrect).toBe(true);

    const validFull = await useCase.executeText(clientQuestion as Question, 'My name is Sam.', starter.id);
    expect(validFull.isCorrect).toBe(true);
  });

  it('seeded questions are scored by the server and reveal the correct option on mistakes', async () => {
    const lesson = SEED_LESSONS['lesson_math_functions_01'];
    const authored = lesson.steps.find((step) => step.interactiveQuestion)!.interactiveQuestion!;
    const correctIndex = authored.correctIndex!;
    const clientQuestion = toClientQuestion(authored);

    const repo = new InMemoryLearnerRepository();
    const useCase = new SubmitLessonAnswerUseCase(repo);

    const correct = await useCase.execute(clientQuestion, correctIndex, lesson.id);
    expect(correct.isCorrect).toBe(true);
    expect(correct.correctOption).toBe(authored.options[correctIndex]);

    const wrongIndex = (correctIndex + 1) % authored.options.length;
    const wrong = await useCase.execute(clientQuestion, wrongIndex, lesson.id);
    expect(wrong.isCorrect).toBe(false);
    expect(wrong.correctOption).toBe(authored.options[correctIndex]);
    expect(wrong.explanation).toBe(authored.explanation);
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

    const useCase = new SubmitLessonAnswerUseCase(new InMemoryLearnerRepository());
    const results = [];
    for (let index = 0; index < generated.options.length; index++) {
      results.push(await useCase.execute(clientQuestion, index, lesson.lessonId));
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

    const useCase = new SubmitLessonAnswerUseCase(new InMemoryLearnerRepository());
    const results = [];
    for (let index = 0; index < fallback.options.length; index++) {
      results.push(await useCase.execute(clientQuestion, index, 'lesson_fallback'));
    }
    expect(results.filter((result) => result.isCorrect)).toHaveLength(1);
    results
      .filter((result) => !result.isCorrect)
      .forEach((result) => expect(result.correctOption).toBeDefined());
  });
});
