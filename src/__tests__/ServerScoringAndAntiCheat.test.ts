import { describe, it, expect, beforeEach } from 'vitest';
import { SubmitLessonAnswerUseCase } from '../domain/usecases/SubmitLessonAnswerUseCase';
import { InMemoryLearnerRepository } from '../data/repositories/InMemoryLearnerRepository';
import { DemoAITutorService } from '../data/services/DemoAITutorService';
import { Question } from '../domain/entities/Question';
import { PLACEMENT_QUESTIONS } from '../data/datasources/questions';

describe('Server-Side Scoring & Anti-Cheat Protection (Bosqich 2)', () => {
  let learnerRepo: InMemoryLearnerRepository;
  let aiService: DemoAITutorService;
  let useCase: SubmitLessonAnswerUseCase;

  const mathBank = PLACEMENT_QUESTIONS['course_math_01'];
  const serverCorrectIndex = (id: string): number => {
    const question = mathBank.find((item) => item.id === id);
    if (!question || question.correctIndex === undefined) throw new Error(`Missing bank question ${id}`);
    return question.correctIndex;
  };
  const serverCorrectOption = (id: string): string => {
    const question = mathBank.find((item) => item.id === id);
    if (!question || question.correctIndex === undefined) throw new Error(`Missing bank question ${id}`);
    return question.options[question.correctIndex];
  };
  const serverWrongIndex = (id: string): number => {
    const question = mathBank.find((item) => item.id === id);
    if (!question || question.correctIndex === undefined) throw new Error(`Missing bank question ${id}`);
    return (question.correctIndex + 1) % question.options.length;
  };

  beforeEach(() => {
    learnerRepo = new InMemoryLearnerRepository();
    aiService = new DemoAITutorService();
    useCase = new SubmitLessonAnswerUseCase(aiService, learnerRepo);
  });

  it('1. Anti-Cheat: Savol obyektida correctIndex bo‘lmaganda ham server to‘g‘ri baholaydi', async () => {
    // Sanitized question without correctIndex
    const sanitizedQuestion: Question = {
      id: 'q_math_alg_01',
      courseId: 'course_math_01',
      skillId: 'skill_math_algebra',
      text: 'Hisoblang: (a + 3)² ifodani ochganda qaysi natija hosil bo‘ladi?',
      options: ['a² + 6a + 9', 'a² + 9', 'a² + 3a + 9', '2a + 6'],
      difficulty: 'easy',
      explanation: 'Formula yechimi.',
    };

    // Client has no idea what correctIndex is
    expect(sanitizedQuestion.correctIndex).toBeUndefined();

    // Selecting the server-side correct option (the answer key lives only in the bank)
    const result = await useCase.execute(sanitizedQuestion, serverCorrectIndex('q_math_alg_01'), 'Ali', 'lesson_01');
    expect(result.isCorrect).toBe(true);
    expect(result.correctOption).toBe(serverCorrectOption('q_math_alg_01'));
    expect(result.xpAwarded).toBe(2);
    expect(result.newSkillScore).toBeDefined();

    // Profile XP should be incremented
    const profile = await learnerRepo.getProfile();
    expect(profile.xp).toBe(2);
  });

  it('2. Anti-Cheat: Noto‘g‘ri variant tanlanganda server xatoni qaytaradi va Yo‘lchi AI tushuntiradi', async () => {
    const sanitizedQuestion: Question = {
      id: 'q_math_alg_01',
      courseId: 'course_math_01',
      skillId: 'skill_math_algebra',
      text: 'Hisoblang: (a + 3)² ifodani ochganda qaysi natija hosil bo‘ladi?',
      options: ['a² + 6a + 9', 'a² + 9', 'a² + 3a + 9', '2a + 6'],
      difficulty: 'easy',
      explanation: 'Formula yechimi.',
    };

    // Student selects a wrong option
    const result = await useCase.execute(sanitizedQuestion, serverWrongIndex('q_math_alg_01'), 'Ali', 'lesson_01');
    expect(result.isCorrect).toBe(false);
    expect(result.correctOption).toBe(serverCorrectOption('q_math_alg_01'));
    expect(result.xpAwarded).toBe(0);
    expect(result.aiExplanation).toBeDefined();
    expect(result.aiExplanation?.explanation).toBeDefined();
    expect(result.aiExplanation?.tutorName).toBe('Yo‘lchi AI');
  });

  it('3. Anti-Cheat: Notanish savol ID bo‘lsa, index 0 avtomatik to‘g‘ri deb qabul qilinmaydi', async () => {
    const fakeQuestion: Question = {
      id: 'q_fake_hacked_999',
      courseId: 'course_math_01',
      skillId: 'skill_math_algebra',
      text: 'Soxtalashtirilgan savol?',
      options: ['Hacked 1', 'Hacked 2', 'Hacked 3', 'Hacked 4'],
      difficulty: 'hard',
      explanation: '',
    };

    // Student attempts to pick option 0 hoping for the old default-0 cheat
    const result = await useCase.execute(fakeQuestion, 0, 'Hacker', 'lesson_cheat');
    // Must be false because question is unknown in trusted DB
    expect(result.isCorrect).toBe(false);
  });

  it('4. Idempotency: Bir xil savol va variant qayta yuborilganda XP ikki marta berilmaydi', async () => {
    const question: Question = {
      id: 'q_math_alg_02',
      courseId: 'course_math_01',
      skillId: 'skill_math_algebra',
      text: 'Ko‘paytuvchilarga ajrating: x² - 25',
      options: ['(x - 5)(x + 5)', '(x - 5)²', '(x + 5)²', 'x(x - 25)'],
      difficulty: 'easy',
      explanation: '',
    };

    // First attempt
    const res1 = await useCase.execute(question, serverCorrectIndex('q_math_alg_02'), 'Ali', 'lesson_02');
    expect(res1.isCorrect).toBe(true);
    expect(res1.xpAwarded).toBe(2);

    const profile1 = await learnerRepo.getProfile();
    expect(profile1.xp).toBe(2);

    // Replay attempt with same parameters
    const res2 = await useCase.execute(question, serverCorrectIndex('q_math_alg_02'), 'Ali', 'lesson_02');
    expect(res2.isCorrect).toBe(true);
    expect(res2.xpAwarded).toBe(0); // No double XP awarded!

    const profile2 = await learnerRepo.getProfile();
    expect(profile2.xp).toBe(2); // XP remains exactly 2
  });

  it('5. Server Skill Score: To‘g‘ri javoblar o‘zlashtirish foizini serverda hisoblaydi', async () => {
    const q1: Question = {
      id: 'q_math_alg_01',
      courseId: 'course_math_01',
      skillId: 'skill_math_algebra',
      text: 'Savol 1',
      options: ['a² + 6a + 9', 'a² + 9', 'a² + 3a + 9', '2a + 6'],
      difficulty: 'easy',
      explanation: '',
    };

    await useCase.execute(q1, serverCorrectIndex('q_math_alg_01'), 'Ali', 'lesson_stat');
    const profile = await learnerRepo.getProfile();
    const algScore = profile.scoresByCourse['course_math_01']?.['skill_math_algebra'];

    expect(algScore).toBeDefined();
    expect(algScore?.score).toBe(100);
    expect(algScore?.masteryLevel).toBe('mastered');
  });
});
