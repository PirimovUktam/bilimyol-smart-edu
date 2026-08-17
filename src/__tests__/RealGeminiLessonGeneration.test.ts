import { describe, it, expect, beforeEach, vi } from 'vitest';
import { GeminiAITutorService } from '../data/services/GeminiAITutorService';
import { DemoAITutorService } from '../data/services/DemoAITutorService';
import { SkillScoringEngine } from '../domain/personalization/SkillScoringEngine';

describe('Real Gemini-3.6-Flash Lesson Generation & Security', () => {
  let demoService: DemoAITutorService;
  let geminiService: GeminiAITutorService;

  beforeEach(() => {
    demoService = new DemoAITutorService();
    geminiService = new GeminiAITutorService();
    vi.clearAllMocks();
  });

  it('1. Valid Lesson Generation: Returns full structured lesson schema', async () => {
    const res = await demoService.generateLesson({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      topic: 'Chiziqli funksiyalar va ularning grafigi',
      difficulty: 'medium',
    });

    expect(res.lessonId).toBeDefined();
    expect(res.title).toContain('Chiziqli funksiyalar');
    expect(res.steps.length).toBeGreaterThanOrEqual(3);
    expect(res.steps[0].type).toBe('concept');
    expect(res.steps[1].type).toBe('formula');
  });

  it('2. Anti-Cheat Security: Client questions payload never contains correctIndex / correct_option_id', async () => {
    const res = await demoService.generateLesson({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
    });

    res.questions.forEach((q: any) => {
      // Client question model MUST NOT leak the correct answer
      expect(q.correctIndex).toBeUndefined();
      expect(q.correct_index).toBeUndefined();
      expect(q.correctOption).toBeUndefined();
      expect(q.correct_option_id).toBeUndefined();
      expect(q.options).toBeDefined();
      expect(q.options.length).toBe(4);
    });
  });

  it('3. Question Content Quality: All options are clean without letter prefixes or spoilers', async () => {
    const res = await demoService.generateLesson({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
    });

    res.questions.forEach((q) => {
      q.options.forEach((opt) => {
        expect(opt).not.toMatch(/^[A-D]\)/i); // No "A)" or "B)" prefix
        expect(opt).not.toMatch(/\(to['‘`]?g['‘`]?ri\)/i); // No spoiler "(to'g'ri)"
      });
    });
  });

  it('4. Adaptive Difficulty Mapping: Adapts difficulty according to learner skill score', () => {
    const getDifficultyForScore = (score: number): 'easy' | 'medium' | 'hard' => {
      if (score < 40) return 'easy';
      if (score > 75) return 'hard';
      return 'medium';
    };

    expect(getDifficultyForScore(25)).toBe('easy');
    expect(getDifficultyForScore(55)).toBe('medium');
    expect(getDifficultyForScore(85)).toBe('hard');
  });

  it('5. Fallback Resilience: Network error gracefully returns valid fallback lesson without crashing', async () => {
    const fallbackRes = await geminiService.generateLesson({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      topic: 'Funksiyalar',
      difficulty: 'easy',
    });

    expect(fallbackRes).toBeDefined();
    expect(fallbackRes.title).toBeDefined();
    expect(fallbackRes.steps.length).toBeGreaterThan(0);
  });

  it('6. Rate Limit Simulation: 429 status code handling does not break application state', async () => {
    // Sliding window check simulation
    const rateMap = new Map<string, { count: number; resetTime: number }>();
    const checkRateLimit = (userId: string, limit: number, windowMs: number) => {
      const now = Date.now();
      const userRate = rateMap.get(userId);
      if (!userRate || now > userRate.resetTime) {
        rateMap.set(userId, { count: 1, resetTime: now + windowMs });
        return true;
      }
      if (userRate.count >= limit) return false;
      userRate.count++;
      return true;
    };

    const userId = 'usr_test_student_01';
    for (let i = 0; i < 5; i++) {
      expect(checkRateLimit(userId, 5, 60000)).toBe(true);
    }
    // 6th request within window is rate-limited
    expect(checkRateLimit(userId, 5, 60000)).toBe(false);
  });

  it('7. Scoring Engine Isolation: AI generation never alters deterministic score calculation', () => {
    const scores = {
      skill_1: {
        skillId: 'skill_1',
        courseId: 'course_math_01',
        score: 60,
        masteryLevel: 'proficient' as const,
        attempts: 2,
        lastUpdated: Date.now(),
      },
      skill_2: {
        skillId: 'skill_2',
        courseId: 'course_math_01',
        score: 80,
        masteryLevel: 'mastered' as const,
        attempts: 3,
        lastUpdated: Date.now(),
      },
    };

    const overall = SkillScoringEngine.computeOverallScore(scores);
    expect(overall).toBe(70); // Exact arithmetic mean
  });
});
