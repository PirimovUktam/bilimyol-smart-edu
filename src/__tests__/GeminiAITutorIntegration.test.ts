import { describe, it, expect } from 'vitest';
import { GeminiAITutorService } from '@/data/services/GeminiAITutorService';

describe('Gemini AI Tutor Integration Tests', () => {
  it('correctly provides pedagogical error diagnosis with clean structured fields', async () => {
    const aiService = new GeminiAITutorService();

    const diagnosis = await aiService.explainMistake({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      questionId: 'q_math_func_01',
      questionText: 'f(x) = 2x + 3 funksiyasida x = 4 bo‘lsa, f(4) ni toping:',
      selectedOption: '8',
      correctOption: '11',
      learnerName: 'Ali',
    });

    expect(diagnosis.tutorName).toBe('Yo‘lchi AI');
    expect(diagnosis.title.length).toBeGreaterThan(0);
    expect(diagnosis.explanation.length).toBeGreaterThan(10);
    expect(diagnosis.remediationStep.length).toBeGreaterThan(5);
    expect(diagnosis.suggestedAction.length).toBeGreaterThan(5);
    expect(diagnosis.isDeterministicFallback).toBeDefined();
  });

  it('generates structured questions with 4 options and hides correct answer from client payload', async () => {
    const aiService = new GeminiAITutorService();

    const genQuestion = await aiService.generateQuestion({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      difficulty: 'medium',
      learnerScore: 45,
    });

    expect(genQuestion.id).toBeDefined();
    expect(genQuestion.courseId).toBe('course_math_01');
    expect(genQuestion.skillId).toBe('skill_math_functions');
    expect(genQuestion.options.length).toBe(4);
    expect(genQuestion.difficulty).toBe('medium');

    // SECURITY INVARIANT: correctIndex and correctOptionId MUST NOT exist in client payload
    expect((genQuestion as any).correctIndex).toBeUndefined();
    expect((genQuestion as any).correctOptionId).toBeUndefined();
  });

  it('generates targeted reinforcement exercise on demand', async () => {
    const aiService = new GeminiAITutorService();

    const reinfQuestion = await aiService.generateReinforcement({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      misconceptionTitle: 'Ozod son (+3) unutilgan',
      previousQuestionText: 'f(x) = 2x + 3, x = 4',
    });

    expect(reinfQuestion.id).toBeDefined();
    expect(reinfQuestion.options.length).toBe(4);
    expect(reinfQuestion.difficulty).toBe('easy');
    expect((reinfQuestion as any).correctIndex).toBeUndefined();
  });

  it('gracefully handles offline/network failures without crashing user flow', async () => {
    const aiService = new GeminiAITutorService();

    const result = await aiService.explainMistake({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      questionId: 'unknown_q',
      questionText: 'Test question',
      selectedOption: 'Wrong Option',
      correctOption: 'Correct Option',
    });

    expect(result.tutorName).toBe('Yo‘lchi AI');
    expect(result.explanation).toContain('to‘g‘ri emas');
    expect(result.isDeterministicFallback).toBe(true);
  });
});
