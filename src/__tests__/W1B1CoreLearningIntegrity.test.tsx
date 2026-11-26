// @vitest-environment jsdom
import React from 'react';
import { act, render, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { LearnerProfile } from '@/domain/entities/LearnerProfile';
import type { Lesson } from '@/domain/entities/Lesson';
import type { Question } from '@/domain/entities/Question';
import { SubmitLessonAnswerUseCase } from '@/domain/usecases/SubmitLessonAnswerUseCase';
import { SubmitReinforcementUseCase } from '@/domain/usecases/SubmitReinforcementUseCase';
import { InMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';
import { InMemoryLessonRepository } from '@/data/repositories/InMemoryLessonRepository';
import { registerQuestionAnswerKey, clearQuestionAnswerKeys } from '@/core/runtime/questionAnswerKeys';
import { readLessonPosition, saveLessonPosition } from '@/features/lesson/readingPosition';

const UUID_V4_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const sampleQuestion = (id = 'q_w1b1_mcq', skillId = 'skill_eng_vocab'): Question => ({
  id,
  courseId: 'course_eng_01',
  skillId,
  text: 'Choose Hello',
  options: ['Bye', 'Hello'],
  correctIndex: 1,
  difficulty: 'easy',
  explanation: 'Hello is a greeting.',
});

const multiStepLesson = (id = 'lesson_w1b1_multi', requiresMastery = false): Lesson => ({
  id,
  courseId: 'course_eng_01',
  skillId: 'skill_eng_vocab',
  title: 'Multi-step Lesson',
  summary: 'Summary',
  estimatedMinutes: 10,
  requiresMastery,
  reinforcementExercise: sampleQuestion('q_w1b1_reinf'),
  steps: [
    {
      id: 'step_0',
      stepNumber: 1,
      type: 'concept',
      title: 'Intro',
      content: 'Read carefully',
    },
    {
      id: 'step_1',
      stepNumber: 2,
      type: 'interactive_question',
      title: 'Checkpoint 1',
      content: 'First check',
      interactiveQuestion: sampleQuestion('q_w1b1_step_1'),
    },
    {
      id: 'step_2',
      stepNumber: 3,
      type: 'visual_example',
      title: 'Worked Example',
      content: 'Review example',
    },
    {
      id: 'step_3',
      stepNumber: 4,
      type: 'interactive_question',
      title: 'Checkpoint 2',
      content: 'Final check',
      interactiveQuestion: sampleQuestion('q_w1b1_step_2'),
    },
  ],
});

describe('W1-B1 Core Learning Integrity (FIX-P0-24, FIX-P1-55, FIX-P2-23)', () => {
  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
    vi.restoreAllMocks();
  });

  afterEach(() => {
    clearQuestionAnswerKeys();
    localStorage.clear();
    sessionStorage.clear();
  });

  it('1. FIX-P0-24: SubmitLessonAnswerUseCase and SubmitReinforcementUseCase mint fresh per-attempt UUIDs even for identical answers (unblocking Correct -> Wrong -> Correct)', async () => {
    const repo = new InMemoryLearnerRepository();
    const lessonRepo = new InMemoryLessonRepository();
    const spy = vi.spyOn(repo, 'submitAnswerAttempt');
    const lessonUseCase = new SubmitLessonAnswerUseCase(repo);

    const q = sampleQuestion('q_w1b1_mcq_seq');
    registerQuestionAnswerKey({
      id: q.id,
      options: q.options,
      correctIndex: 1,
      explanation: q.explanation,
    });

    const r1 = await lessonUseCase.execute(q, 1, 'lesson_eng_starter');
    const r2 = await lessonUseCase.execute(q, 0, 'lesson_eng_starter');
    const r3 = await lessonUseCase.execute(q, 1, 'lesson_eng_starter');

    expect(spy).toHaveBeenCalledTimes(3);
    const key1 = spy.mock.calls[0][0].idempotencyKey!;
    const key2 = spy.mock.calls[1][0].idempotencyKey!;
    const key3 = spy.mock.calls[2][0].idempotencyKey!;

    expect(key1).toMatch(UUID_V4_RE);
    expect(key2).toMatch(UUID_V4_RE);
    expect(key3).toMatch(UUID_V4_RE);
    expect(new Set([key1, key2, key3]).size).toBe(3);

    expect(r1.isCorrect).toBe(true);
    expect(r1.xpAwarded).toBe(2);
    expect(r2.isCorrect).toBe(false);
    expect(r3.isCorrect).toBe(true);
    expect(r3.xpAwarded).toBe(0);
    expect(r3.newSkillScore).toBeGreaterThan(r2.newSkillScore!);

    // Same UUID sent twice (transport retry) is deduplicated with alreadyProcessed: true
    const replay = await repo.submitAnswerAttempt({
      courseId: q.courseId,
      skillId: q.skillId,
      lessonId: 'lesson_eng_starter',
      questionId: q.id,
      selectedIndex: 1,
      selectedAnswer: q.options[1],
      idempotencyKey: key1,
    });
    expect(replay.alreadyProcessed).toBe(true);
    expect(replay.xpAwarded).toBe(0);

    // Free-text starter question Correct -> Wrong -> Correct also mints fresh UUIDs per click
    const starterLesson = await lessonRepo.getLessonById('lesson_eng_starter');
    const starterQuiz = starterLesson!.steps.find((s) => s.interactiveQuestion?.id === 'q_lesson_eng_starter_quiz')!.interactiveQuestion!;
    const t1 = await lessonUseCase.executeText(starterQuiz, "I'm Sam", 'lesson_eng_starter');
    const t2 = await lessonUseCase.executeText(starterQuiz, 'Goodbye', 'lesson_eng_starter');
    const t3 = await lessonUseCase.executeText(starterQuiz, "I'm Sam", 'lesson_eng_starter');
    expect(t1.isCorrect).toBe(true);
    expect(t2.isCorrect).toBe(false);
    expect(t3.isCorrect).toBe(true);

    // Reinforcement Correct -> Wrong -> Correct also mints fresh UUIDs per click
    const reinfUseCase = new SubmitReinforcementUseCase(repo, lessonRepo);
    const reinfQ = sampleQuestion('q_w1b1_reinf_seq');
    registerQuestionAnswerKey({
      id: reinfQ.id,
      options: reinfQ.options,
      correctIndex: 1,
      explanation: reinfQ.explanation,
    });

    const callOffset = spy.mock.calls.length;
    await reinfUseCase.execute('course_eng_01', 'skill_eng_vocab', 'reinf_node_eng_vocab', reinfQ, 1);
    const reinfKey1 = spy.mock.calls[callOffset][0].idempotencyKey!;
    await reinfUseCase.execute('course_eng_01', 'skill_eng_vocab', 'reinf_node_eng_vocab', reinfQ, 0);
    const reinfKey2 = spy.mock.calls[callOffset + 1][0].idempotencyKey!;
    await reinfUseCase.execute('course_eng_01', 'skill_eng_vocab', 'reinf_node_eng_vocab', reinfQ, 1);
    const reinfKey3 = spy.mock.calls[callOffset + 2][0].idempotencyKey!;

    expect(reinfKey1).toMatch(UUID_V4_RE);
    expect(reinfKey2).toMatch(UUID_V4_RE);
    expect(reinfKey3).toMatch(UUID_V4_RE);
    expect(new Set([reinfKey1, reinfKey2, reinfKey3]).size).toBe(3);
  });

  it('2. FIX-P0-24 & FIX-P1-55: useLessonStore reuses pending UUID across transport timeouts & F5 reloads, skips duplicate submitAnswerAttempt when complete_lesson fails, and restores answeredQuestionIds', async () => {
    vi.resetModules();
    const completedSet = new Set<string>();
    const makeProfile = (): LearnerProfile => ({
      id: 'user-w1b1-web',
      name: 'Sardor',
      selectedCourseId: 'course_eng_01',
      goal: 'mastery',
      dailyMinutes: 15,
      initialLevel: 'beginner',
      xp: 10,
      streakDays: 1,
      lastActiveDate: '2026-11-26',
      scoresByCourse: {},
      completedLessonIds: [...completedSet],
      completedNodeIds: [],
      completedReinforcementIds: [],
      createdAt: 1,
    });

    const lessonFixture = multiStepLesson('lesson_w1b1_recovery', false);
    const submitSpy = vi.fn();
    const completeSpy = vi.fn(async (id: string) => {
      completedSet.add(id);
    });
    const getProfileSpy = vi.fn(async () => makeProfile());

    vi.doMock('@/data/repositories/SupabaseLessonRepository', () => ({
      supabaseLessonRepository: {
        getLessonById: vi.fn(async () => lessonFixture),
        saveLesson: vi.fn(),
      },
    }));
    vi.doMock('@/data/repositories/SupabaseLearnerRepository', () => ({
      supabaseLearnerRepository: {
        submitAnswerAttempt: submitSpy,
        markLessonCompleted: completeSpy,
        getProfile: getProfileSpy,
      },
    }));

    const { useLearnerStore } = await import('@/app/store/useLearnerStore');
    const { useLessonStore } = await import('@/app/store/useLessonStore');

    useLearnerStore.setState({ profile: makeProfile(), isLoading: false });
    await useLessonStore.getState().loadLesson(lessonFixture.id);

    // Step 1 (Checkpoint 1): first call times out -> F5 reload -> retry reuses exact same UUID!
    useLessonStore.getState().goToStep(1);
    submitSpy.mockRejectedValueOnce(new Error('Network timeout'));
    const failedRes = await useLessonStore.getState().submitAnswer(1);
    expect(failedRes).toBeNull();
    expect(submitSpy).toHaveBeenCalledTimes(1);
    const firstAttemptUuid = submitSpy.mock.calls[0][0].idempotencyKey as string;
    expect(firstAttemptUuid).toMatch(UUID_V4_RE);

    // Simulate F5 page reload: clear in-memory store, re-hydrate profile & reload lesson
    saveLessonPosition('user-w1b1-web', lessonFixture, 1);
    useLessonStore.getState().clearSession();
    useLearnerStore.setState({ profile: makeProfile(), isLoading: false });
    await useLessonStore.getState().loadLesson(lessonFixture.id);
    useLessonStore.getState().goToStep(1);

    submitSpy.mockResolvedValueOnce({
      isCorrect: true,
      explanation: 'Correct!',
      newSkillScore: 100,
      overallScore: 100,
      xpAwarded: 2,
    });
    const recoveredRes = await useLessonStore.getState().submitAnswer(1);
    expect(recoveredRes?.isCorrect).toBe(true);
    expect(submitSpy).toHaveBeenCalledTimes(2);
    expect(submitSpy.mock.calls[1][0].idempotencyKey).toBe(firstAttemptUuid);
    expect(useLessonStore.getState().answeredQuestionIds).toContain('q_w1b1_step_1');

    // Advance to Step 3 (Checkpoint 2), save position, and simulate mid-lesson F5 reload!
    useLessonStore.getState().goToStep(3);
    saveLessonPosition('user-w1b1-web', lessonFixture, 3, useLessonStore.getState().answeredQuestionIds);
    useLessonStore.getState().clearSession();
    useLearnerStore.setState({ profile: makeProfile(), isLoading: false });
    await useLessonStore.getState().loadLesson(lessonFixture.id);

    // answeredQuestionIds AND safe position past Checkpoint 1 must survive F5!
    expect(useLessonStore.getState().answeredQuestionIds).toEqual(['q_w1b1_step_1']);
    expect(
      readLessonPosition('user-w1b1-web', lessonFixture, useLessonStore.getState().answeredQuestionIds),
    ).toBe(3);

    // Final Step 3: submitAnswerAttempt succeeds, but complete_lesson drops offline!
    useLessonStore.getState().goToStep(3);
    submitSpy.mockResolvedValueOnce({
      isCorrect: true,
      explanation: 'Final step correct!',
      newSkillScore: 100,
      overallScore: 100,
      xpAwarded: 2,
    });
    completeSpy.mockRejectedValueOnce(new Error('complete_lesson network drop'));

    const partialFail = await useLessonStore.getState().submitAnswer(1);
    expect(partialFail).toBeNull();
    expect(useLessonStore.getState().isCompleted).toBe(false);
    expect(submitSpy).toHaveBeenCalledTimes(3);

    // Retry on Step 3 MUST NOT call submitAnswerAttempt a 4th time — only complete_lesson + getProfile!
    const retryFinal = await useLessonStore.getState().submitAnswer(1);
    expect(retryFinal?.isCorrect).toBe(true);
    expect(submitSpy).toHaveBeenCalledTimes(3);
    expect(completeSpy).toHaveBeenCalledTimes(2);
    expect(useLessonStore.getState().isCompleted).toBe(true);
  });

  it('3. FIX-P2-23: InMemoryLearnerRepository deduplicates daily question statistics by (date, questionId) and caps per-question XP in recordAnswerAttempt', async () => {
    const repo = new InMemoryLearnerRepository();
    const q1 = sampleQuestion('q_w1b1_stats_wrong');
    const q2 = sampleQuestion('q_w1b1_stats_correct');
    registerQuestionAnswerKey({ id: q1.id, options: q1.options, correctIndex: 1, explanation: q1.explanation });
    registerQuestionAnswerKey({ id: q2.id, options: q2.options, correctIndex: 1, explanation: q2.explanation });

    // Q1 wrong
    await repo.submitAnswerAttempt({
      courseId: q1.courseId,
      skillId: q1.skillId,
      lessonId: 'lesson_eng_starter',
      questionId: q1.id,
      selectedIndex: 0,
      selectedAnswer: q1.options[0],
      idempotencyKey: crypto.randomUUID(),
    });

    // Q2 spammed 10 times with 10 distinct UUIDs
    for (let i = 0; i < 10; i++) {
      await repo.submitAnswerAttempt({
        courseId: q2.courseId,
        skillId: q2.skillId,
        lessonId: 'lesson_eng_starter',
        questionId: q2.id,
        selectedIndex: 1,
        selectedAnswer: q2.options[1],
        idempotencyKey: crypto.randomUUID(),
      });
    }

    const [todayStats] = await repo.getDailyActivity(1);
    expect(todayStats.questionsAnswered).toBe(2);
    expect(todayStats.correctAnswers).toBe(1);
    expect(todayStats.accuracyPercent).toBe(50);
    expect(todayStats.xpEarned).toBe(2);

    // recordAnswerAttempt also awards +2 XP only once per questionId
    await repo.recordAnswerAttempt({
      courseId: q1.courseId,
      skillId: q1.skillId,
      lessonId: 'lesson_eng_starter',
      questionId: 'q_record_dedup',
      selectedIndex: 1,
      selectedAnswer: 'Hello',
      isCorrect: true,
    });
    const xpAfterFirstRecord = (await repo.getProfile()).xp;
    await repo.recordAnswerAttempt({
      courseId: q1.courseId,
      skillId: q1.skillId,
      lessonId: 'lesson_eng_starter',
      questionId: 'q_record_dedup',
      selectedIndex: 1,
      selectedAnswer: 'Hello',
      isCorrect: true,
    });
    expect((await repo.getProfile()).xp).toBe(xpAfterFirstRecord);
  });

  it('4. FIX-P1-55: AuthProvider signUp recovers half-signed-up session without 422 and signOut("global") always clears local auth state when offline', async () => {
    vi.resetModules();
    const userObj = { id: 'user-signup-1', email: 'newlearner@example.invalid' };
    const sessionObj = { access_token: 'tok-1', user: userObj };
    let currentSession: typeof sessionObj | null = null;
    let failProfileRead = true;

    const signUpMock = vi.fn(async () => {
      if (currentSession) {
        return {
          data: { user: null, session: null },
          error: { status: 422, message: 'User already registered' },
        };
      }
      currentSession = sessionObj;
      return { data: { user: userObj, session: sessionObj }, error: null };
    });
    const getSessionMock = vi.fn(async () => ({ data: { session: currentSession }, error: null }));
    const signOutMock = vi.fn(async ({ scope }: { scope?: 'local' | 'global' } = {}) => {
      if (scope === 'global') {
        return { error: { message: 'Failed to fetch (offline)' } };
      }
      currentSession = null;
      return { error: null };
    });
    const maybeSingleMock = vi.fn(async () => {
      if (failProfileRead) {
        return { data: null, error: { message: 'Temporary network error' } };
      }
      return {
        data: {
          id: userObj.id,
          first_name: 'Ali',
          last_name: 'Valiyev',
          display_name: 'Ali Valiyev',
          email: userObj.email,
          avatar_url: '',
          role: 'student',
        },
        error: null,
      };
    });

    vi.doMock('@/core/config/supabase', () => ({
      isSupabaseConfigured: true,
      supabase: {
        from: vi.fn(() => ({
          select: vi.fn(() => ({
            eq: vi.fn(() => ({ maybeSingle: maybeSingleMock })),
          })),
          insert: vi.fn(async () => ({ error: null })),
        })),
        auth: {
          getSession: getSessionMock,
          getUser: vi.fn(async () => ({ data: { user: currentSession?.user ?? null }, error: null })),
          onAuthStateChange: vi.fn(() => ({ data: { subscription: { unsubscribe: vi.fn() } } })),
          signUp: signUpMock,
          signInWithPassword: vi.fn(),
          signOut: signOutMock,
          resetPasswordForEmail: vi.fn(),
          resend: vi.fn(),
          updateUser: vi.fn(),
        },
      },
    }));

    const { AuthProvider, useAuth } = await import('@/core/context/AuthContext');
    let captured!: ReturnType<typeof useAuth>;
    function Probe() {
      captured = useAuth();
      return null;
    }

    render(
      <AuthProvider>
        <Probe />
      </AuthProvider>,
    );
    await waitFor(() => expect(captured.isLoading).toBe(false));

    // Attempt 1: signUp creates session, but profile read fails transiently
    let firstAttempt!: Awaited<ReturnType<typeof captured.signUp>>;
    await act(async () => {
      firstAttempt = await captured.signUp(userObj.email, 'ValidPass123', 'Ali', 'Valiyev');
    });
    expect(firstAttempt.error).toBeInstanceOf(Error);
    expect(signUpMock).toHaveBeenCalledTimes(1);

    // Attempt 2: user clicks Register again -> recovers profile on existing session WITHOUT hitting 422!
    failProfileRead = false;
    let secondAttempt!: Awaited<ReturnType<typeof captured.signUp>>;
    await act(async () => {
      secondAttempt = await captured.signUp(userObj.email, 'ValidPass123', 'Ali', 'Valiyev');
    });
    expect(secondAttempt.error).toBeNull();
    expect(signUpMock).toHaveBeenCalledTimes(1);
    expect(captured.profile?.id).toBe(userObj.id);

    // Offline global signOut MUST still wipe local session & profile without throwing
    await act(async () => {
      await captured.signOut('global');
    });
    expect(signOutMock).toHaveBeenCalledWith({ scope: 'global' });
    expect(signOutMock).toHaveBeenCalledWith({ scope: 'local' });
    expect(captured.user).toBeNull();
    expect(captured.session).toBeNull();
    expect(captured.profile).toBeNull();
  });
});
