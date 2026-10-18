import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const backend = vi.hoisted(() => ({
  configured: true,
  getUser: vi.fn(),
  from: vi.fn(),
  rpc: vi.fn(),
  invoke: vi.fn(),
}));

vi.mock('../core/config/supabase', () => ({
  get isSupabaseConfigured() {
    return backend.configured;
  },
  supabase: {
    auth: { getUser: backend.getUser },
    from: backend.from,
    rpc: backend.rpc,
    functions: { invoke: backend.invoke },
  },
}));

import { setDemoRuntimeActive } from '../core/runtime/demoRuntime';
import { SupabaseCourseRepository, supabaseCourseRepository } from '../data/repositories/SupabaseCourseRepository';
import { SupabaseLessonRepository } from '../data/repositories/SupabaseLessonRepository';
import { SupabaseLearnerRepository } from '../data/repositories/SupabaseLearnerRepository';
import { GeminiAITutorService } from '../data/services/GeminiAITutorService';
import { usePlacementStore } from '../app/store/usePlacementStore';

const makeQuery = (result: { data: unknown; error: unknown }) => ({
  select: vi.fn().mockReturnThis(),
  eq: vi.fn().mockReturnThis(),
  in: vi.fn().mockReturnThis(),
  gte: vi.fn().mockReturnThis(),
  order: vi.fn().mockResolvedValue(result),
  limit: vi.fn().mockReturnThis(),
  maybeSingle: vi.fn().mockResolvedValue(result),
  single: vi.fn().mockResolvedValue(result),
  update: vi.fn().mockReturnThis(),
  upsert: vi.fn().mockResolvedValue(result),
});

describe('hosted demo data plane', () => {
  beforeEach(() => {
    backend.configured = true;
    vi.clearAllMocks();
    setDemoRuntimeActive(true);
    usePlacementStore.getState().resetPlacement();
  });

  afterEach(() => {
    setDemoRuntimeActive(false);
    usePlacementStore.getState().resetPlacement();
    vi.restoreAllMocks();
  });

  it('uses bundled repositories and deterministic AI without any Supabase call when active', async () => {
    const courseRepository = new SupabaseCourseRepository();
    const lessonRepository = new SupabaseLessonRepository();
    const learnerRepository = new SupabaseLearnerRepository();

    const courses = await courseRepository.getAllCourses();
    expect(courses.length).toBeGreaterThan(0);
    expect(await courseRepository.getCourseById('course_math_01')).toBeTruthy();
    expect(await courseRepository.getSkillsByCourseId('course_math_01')).toHaveLength(4);
    const [placementQuestion] = await courseRepository.getPlacementQuestions('course_math_01');
    expect(placementQuestion).toBeTruthy();

    const lesson = await lessonRepository.getLessonById('lesson_math_functions_01');
    expect(lesson).toBeTruthy();
    expect(await lessonRepository.getLessonByCourseAndSkill('course_math_01', 'skill_math_functions')).toBeTruthy();
    expect(await lessonRepository.getBaseRoadmapNodes('course_math_01')).toHaveLength(4);
    await lessonRepository.saveLesson({ ...lesson!, id: 'demo_runtime_lesson' });
    expect(await lessonRepository.getLessonById('demo_runtime_lesson')).toMatchObject({ id: 'demo_runtime_lesson' });

    expect(learnerRepository.supportsNodeCompletion).toBe(true);
    expect(learnerRepository.supportsServerPlacementPersistence).toBe(false);
    expect(learnerRepository.supportsServerReinforcementPersistence).toBe(false);
    expect((await learnerRepository.getProfile()).id).toBe('learner_default_01');
    await learnerRepository.updateProfile({ dailyMinutes: 30 });
    await learnerRepository.saveSkillScores('course_math_01', {});
    expect(await learnerRepository.savePlacementAttempt({
      courseId: 'course_math_01',
      score: 50,
      submissions: [],
    })).toMatch(/^plc_att_/);
    expect(await learnerRepository.evaluatePlacementAnswer(
      'course_math_01',
      placementQuestion.id,
      placementQuestion.correctIndex ?? 0,
    )).toEqual({ isCorrect: true });
    await learnerRepository.markLessonCompleted('lesson_math_functions_01', 'course_math_01');
    await learnerRepository.markNodeCompleted('demo_node');
    await learnerRepository.markReinforcementCompleted('demo_reinforcement');
    await learnerRepository.submitAnswerAttempt({
      courseId: placementQuestion.courseId,
      skillId: placementQuestion.skillId,
      lessonId: 'demo_lesson',
      questionId: placementQuestion.id,
      selectedIndex: placementQuestion.correctIndex ?? 0,
      selectedAnswer: placementQuestion.options[placementQuestion.correctIndex ?? 0],
    });
    await learnerRepository.recordAnswerAttempt({
      courseId: placementQuestion.courseId,
      skillId: placementQuestion.skillId,
      lessonId: 'demo_lesson',
      questionId: placementQuestion.id,
      selectedIndex: 0,
      selectedAnswer: placementQuestion.options[0],
      isCorrect: false,
    });
    expect(await learnerRepository.getAnswerAttempts()).toBeInstanceOf(Array);
    expect(await learnerRepository.getDailyActivity(1)).toHaveLength(1);
    expect(await learnerRepository.addXp(1)).toBeGreaterThan(0);
    expect(await learnerRepository.recordDailyActivity()).toBeGreaterThan(0);
    await learnerRepository.resetAll();

    const tutor = new GeminiAITutorService();
    const explanation = await tutor.explainMistake({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      questionId: 'q_demo_1',
      questionText: 'Savol',
      selectedOption: '8',
      correctOption: '11',
    });
    const generatedQuestion = await tutor.generateQuestion({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      difficulty: 'medium',
    });
    const reinforcement = await tutor.generateReinforcement({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
    });
    const generatedLesson = await tutor.generateLesson({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      topic: 'Funksiya',
    });
    const tutorAnswer = await tutor.askTutor({ message: 'Funksiya nima?' });

    expect(explanation.isDeterministicFallback).toBe(true);
    expect(generatedQuestion.isDeterministicFallback).toBe(true);
    expect(reinforcement.isDeterministicFallback).toBe(true);
    expect(generatedLesson.isDeterministicFallback).toBe(true);
    expect(tutorAnswer.isDeterministicFallback).toBe(true);
    expect(backend.getUser).not.toHaveBeenCalled();
    expect(backend.from).not.toHaveBeenCalled();
    expect(backend.rpc).not.toHaveBeenCalled();
    expect(backend.invoke).not.toHaveBeenCalled();
  });

  it('makes placement choose the bundled question bank even when Supabase is configured', async () => {
    const supabasePlacementSpy = vi.spyOn(supabaseCourseRepository, 'getPlacementQuestions');

    await usePlacementStore.getState().initPlacement('course_math_01');

    expect(usePlacementStore.getState().currentQuestion).toBeTruthy();
    expect(supabasePlacementSpy).not.toHaveBeenCalled();
    expect(backend.getUser).not.toHaveBeenCalled();
    expect(backend.from).not.toHaveBeenCalled();
    expect(backend.rpc).not.toHaveBeenCalled();
  });

  it('keeps authenticated configured behavior when demo runtime is inactive', async () => {
    setDemoRuntimeActive(false);
    backend.getUser.mockResolvedValue({ data: { user: { id: 'configured-user' } }, error: null });

    const courseQuery = makeQuery({
      data: [{
        id: 'course_math_01',
        title: 'Matematika',
        subject: 'mathematics',
        description: '',
        is_active: true,
      }],
      error: null,
    });
    const activityQuery = makeQuery({ data: [], error: null });
    backend.from.mockReturnValueOnce(courseQuery).mockReturnValueOnce(activityQuery);

    const courses = await new SupabaseCourseRepository().getAllCourses();
    const activity = await new SupabaseLearnerRepository().getDailyActivity(1);

    expect(courses).toHaveLength(1);
    expect(activity).toHaveLength(1);
    expect(backend.getUser).toHaveBeenCalledTimes(2);
    expect(backend.from).toHaveBeenNthCalledWith(1, 'courses');
    expect(backend.from).toHaveBeenNthCalledWith(2, 'daily_learning_stats');
  });

  it('keeps the configured edge-function AI path when demo runtime is inactive', async () => {
    setDemoRuntimeActive(false);
    backend.invoke.mockResolvedValue({
      data: {
        tutorName: 'Yo‘lchi AI',
        answer: 'Server javobi',
        isAiGenerated: true,
        isDeterministicFallback: false,
      },
      error: null,
    });

    const response = await new GeminiAITutorService().askTutor({ message: 'Savol' });

    expect(response.answer).toBe('Server javobi');
    expect(backend.invoke).toHaveBeenCalledExactlyOnceWith('yolchi-tutor', expect.objectContaining({
      body: expect.objectContaining({ action: 'askTutor', message: 'Savol' }),
    }));
  });
});
