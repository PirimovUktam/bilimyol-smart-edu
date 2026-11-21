import { renderToStaticMarkup } from 'react-dom/server';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('zustand', async (importOriginal) => {
  const actual = await importOriginal<typeof import('zustand')>();
  const React = await import('react');
  return {
    ...actual,
    create: ((createState: Parameters<typeof actual.create>[0]) => {
      if (!createState) return actual.create;
      const api = actual.create(createState);
      return Object.assign(
        (selector: (state: unknown) => unknown = (state) => state) =>
          React.useSyncExternalStore(
            api.subscribe,
            () => selector(api.getState()),
            () => selector(api.getState()),
          ),
        api,
      );
    }) as typeof actual.create,
  };
});

vi.mock('@/core/config/supabase', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/core/config/supabase')>();
  return {
    ...actual,
    isSupabaseConfigured: true,
  };
});

import { AuthProvider } from '@/core/context/AuthContext';
import { supabase } from '@/core/config/supabase';
import { usePreferences } from '@/core/preferences/preferences';
import { setDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { SEED_COURSES } from '@/data/datasources/courses';
import { isAnswerRevealRequest } from '@/data/datasources/demoAiResponses';
import { SEED_LESSONS } from '@/data/datasources/lessons';
import { SEED_SKILLS } from '@/data/datasources/skills';
import { InMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';
import { SupabaseLearnerRepository, supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { DemoAITutorService } from '@/data/services/DemoAITutorService';
import type { LearnerProfile } from '@/domain/entities/LearnerProfile';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useLessonStore } from '@/app/store/useLessonStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { InteractiveLessonView } from '@/features/lesson/InteractiveLessonView';
import { RoadmapView } from '@/features/roadmap/RoadmapView';

function createMemoryStorage(): Storage {
  const store = new Map<string, string>();
  return {
    getItem: (k: string) => store.get(k) ?? null,
    setItem: (k: string, v: string) => {
      store.set(k, v);
    },
    removeItem: (k: string) => {
      store.delete(k);
    },
    clear: () => {
      store.clear();
    },
    key: (i: number) => [...store.keys()][i] ?? null,
    get length() {
      return store.size;
    },
  } as Storage;
}

describe('Tier 5 Adversarial Web Hardening', () => {
  beforeEach(() => {
    setDemoRuntimeActive(true);
    usePreferences.setState({ language: 'uz', theme: 'light' });
    useLessonStore.getState().clearSession();
    useRoadmapStore.getState().clearSession();
    useLearnerStore.getState().clearSession();
    useCourseStore.getState().clearSession();
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
    setDemoRuntimeActive(false);
    usePreferences.setState({ language: 'uz', theme: 'light' });
  });

  it('serializes concurrent online SupabaseLearnerRepository.recordFlashcardSrs calls without dropping earlier cards', async () => {
    setDemoRuntimeActive(false);
    const localStorageMock = createMemoryStorage();
    vi.stubGlobal('window', { localStorage: localStorageMock });
    vi.spyOn(supabase.auth, 'getUser').mockResolvedValue({
      data: { user: { id: 'online_user_01' } as never },
      error: null,
    });

    const repo = new SupabaseLearnerRepository();
    const baseProfile = (cardMap: Record<string, unknown>): LearnerProfile => ({
      id: 'online_user_01',
      name: 'Online Learner',
      selectedCourseId: 'course_eng_01',
      goal: 'mastery',
      dailyMinutes: 15,
      initialLevel: 'beginner',
      xp: 0,
      streakDays: 0,
      lastActiveDate: '',
      scoresByCourse: {},
      completedLessonIds: [],
      completedNodeIds: [],
      completedReinforcementIds: [],
      flashcardSrsByCourse: cardMap as LearnerProfile['flashcardSrsByCourse'],
      createdAt: 1000,
    });

    const getProfileSpy = vi.spyOn(repo, 'getProfile').mockImplementation(async () => {
      await new Promise((r) => setTimeout(r, 15));
      const raw = localStorageMock.getItem('bilimyol_srs:online_user_01');
      const parsed = raw ? (JSON.parse(raw) as Record<string, unknown>) : {};
      return baseProfile(parsed);
    });

    const [resA, resB] = await Promise.all([
      repo.recordFlashcardSrs('course_eng_01', 'fc_concurrent_1', 'remembered'),
      repo.recordFlashcardSrs('course_eng_01', 'fc_concurrent_2', 'need_practice'),
    ]);

    expect(getProfileSpy).toHaveBeenCalledTimes(2);
    expect(resA.flashcardSrsByCourse?.['course_eng_01']?.['fc_concurrent_1']?.status).toBe('remembered');
    expect(resB.flashcardSrsByCourse?.['course_eng_01']?.['fc_concurrent_1']?.status).toBe('remembered');
    expect(resB.flashcardSrsByCourse?.['course_eng_01']?.['fc_concurrent_2']?.status).toBe('need_practice');
    const persisted = JSON.parse(localStorageMock.getItem('bilimyol_srs:online_user_01') ?? '{}') as Record<
      string,
      Record<string, { status?: string }>
    >;
    expect(persisted['course_eng_01']?.['fc_concurrent_1']?.status).toBe('remembered');
    expect(persisted['course_eng_01']?.['fc_concurrent_2']?.status).toBe('need_practice');
  });

  it('serializes concurrent useLearnerStore.recordFlashcardSrs saves and discards stale saves after clearSession', async () => {
    const initial: LearnerProfile = {
      id: 'learner_srs_store',
      name: 'SRS Learner',
      selectedCourseId: 'course_eng_01',
      goal: 'mastery',
      dailyMinutes: 15,
      initialLevel: 'beginner',
      xp: 10,
      streakDays: 0,
      lastActiveDate: '',
      scoresByCourse: {},
      completedLessonIds: [],
      completedNodeIds: [],
      completedReinforcementIds: [],
      flashcardSrsByCourse: {},
      createdAt: 1000,
    };
    useLearnerStore.setState({ profile: initial, isLoading: false });

    const spy = vi
      .spyOn(supabaseLearnerRepository, 'recordFlashcardSrs')
      .mockImplementationOnce(async (_courseId, cardId) => {
        await new Promise((r) => setTimeout(r, 20));
        return {
          ...initial,
          flashcardSrsByCourse: {
            course_eng_01: {
              [cardId]: {
                cardId,
                status: 'remembered',
                bucket: 'learning',
                reviewCount: 1,
                intervalDays: 1,
                lastReviewedAt: '2026-11-20T00:00:00.000Z',
                nextReviewAt: '2026-11-21T00:00:00.000Z',
              },
            },
          },
        };
      })
      .mockImplementationOnce(async (_courseId, cardId) => {
        return {
          ...initial,
          flashcardSrsByCourse: {
            course_eng_01: {
              [cardId]: {
                cardId,
                status: 'need_practice',
                bucket: 'need_practice',
                reviewCount: 1,
                intervalDays: 0,
                lastReviewedAt: '2026-11-20T00:00:00.000Z',
                nextReviewAt: '2026-11-20T00:00:00.000Z',
              },
            },
          },
        };
      });

    await Promise.all([
      useLearnerStore.getState().recordFlashcardSrs('course_eng_01', 'fc_store_1', 'remembered'),
      useLearnerStore.getState().recordFlashcardSrs('course_eng_01', 'fc_store_2', 'need_practice'),
    ]);

    expect(spy).toHaveBeenCalledTimes(2);
    const savedDeck = useLearnerStore.getState().profile?.flashcardSrsByCourse?.['course_eng_01'];
    expect(savedDeck?.['fc_store_1']?.status).toBe('remembered');
    expect(savedDeck?.['fc_store_2']?.status).toBe('need_practice');

    // In-flight SRS save must not repopulate profile after clearSession()
    spy.mockImplementationOnce(async () => {
      await new Promise((r) => setTimeout(r, 20));
      return initial;
    });
    const pendingSave = useLearnerStore.getState().recordFlashcardSrs('course_eng_01', 'fc_store_3', 'remembered');
    useLearnerStore.getState().clearSession();
    await pendingSave;
    expect(useLearnerStore.getState().profile).toBeNull();
  });

  it('blocks empty word_match and sentence_order submissions in both store and InteractiveLessonView while keeping >=1 partial enabled', async () => {
    const attemptSpy = vi.spyOn(supabaseLearnerRepository, 'submitAnswerAttempt');
    await useCourseStore.getState().loadCourses();
    await useCourseStore.getState().selectCourseById('course_eng_01');

    // 1. word_match empty guard in store and rendered disabled TEKSHIRISH
    await useLessonStore.getState().loadLesson('lesson_eng_a1_m1_greetings');
    const greetLesson = useLessonStore.getState().currentLesson!;
    const matchStepIdx = greetLesson.steps.findIndex((s) => s.interactiveQuestion?.questionType === 'word_match');
    expect(matchStepIdx).toBeGreaterThanOrEqual(0);
    useLessonStore.getState().goToStep(matchStepIdx);

    expect(await useLessonStore.getState().submitStructuredAnswer({ matchPairs: {} })).toBeNull();
    expect(attemptSpy).not.toHaveBeenCalled();
    expect(useLessonStore.getState().lastAnswerResult).toBeNull();
    expect(useLessonStore.getState().consecutiveMistakes).toBe(0);

    const matchHtml = renderToStaticMarkup(
      <AuthProvider>
        <InteractiveLessonView
          lessonId="lesson_eng_a1_m1_greetings"
          onFinish={() => {}}
          onBackToRoadmap={() => {}}
        />
      </AuthProvider>,
    );
    expect(matchHtml).toMatch(/<button[^>]*disabled=""[^>]*>.*?TEKSHIRISH/is);

    // Partial (>=1 matched pair) stays permitted for T2-F5-05
    const firstPair = greetLesson.steps[matchStepIdx].interactiveQuestion!.matchPairs![0];
    const partialMatchRes = await useLessonStore.getState().submitStructuredAnswer({
      matchPairs: { [firstPair.id]: firstPair.id },
    });
    expect(partialMatchRes?.isCorrect).toBe(false);

    // 2. sentence_order empty guard in store and rendered disabled TEKSHIRISH
    useLessonStore.getState().clearSession();
    attemptSpy.mockClear();
    await useLessonStore.getState().loadLesson('lesson_eng_a1_m2_sentence_builder');
    const orderLesson = useLessonStore.getState().currentLesson!;
    const orderStepIdx = orderLesson.steps.findIndex((s) => s.interactiveQuestion?.questionType === 'sentence_order');
    expect(orderStepIdx).toBeGreaterThanOrEqual(0);
    useLessonStore.getState().goToStep(orderStepIdx);

    expect(await useLessonStore.getState().submitStructuredAnswer({ orderedTokens: [] })).toBeNull();
    expect(await useLessonStore.getState().submitStructuredAnswer({ orderedTokens: ['   '] })).toBeNull();
    expect(attemptSpy).not.toHaveBeenCalled();

    const orderHtml = renderToStaticMarkup(
      <AuthProvider>
        <InteractiveLessonView
          lessonId="lesson_eng_a1_m2_sentence_builder"
          onFinish={() => {}}
          onBackToRoadmap={() => {}}
        />
      </AuthProvider>,
    );
    expect(orderHtml).toMatch(/<button[^>]*disabled=""[^>]*>.*?TEKSHIRISH/is);

    // Partial (>=1 ordered token) stays permitted for T2-F5-05
    const firstToken = orderLesson.steps[orderStepIdx].interactiveQuestion!.orderedTokens![0];
    const partialOrderRes = await useLessonStore.getState().submitStructuredAnswer({
      orderedTokens: [firstToken],
    });
    expect(partialOrderRes?.isCorrect).toBe(false);

    // Verify minutes spacing in InteractiveLessonView ("5 daqiqa", not "5daqiqa")
    expect(orderHtml).toContain(`${orderLesson.estimatedMinutes} daqiqa`);
    expect(orderHtml).not.toContain(`${orderLesson.estimatedMinutes}daqiqa`);
  });

  it('keeps lessonSessionId invariant on switchToAlternateExercise on step > first exercise (lesson_eng_a1_exit)', async () => {
    await useLessonStore.getState().loadLesson('lesson_eng_a1_exit');
    const exitLesson = useLessonStore.getState().currentLesson!;
    const initialSessionId = useLessonStore.getState().lessonSessionId;
    expect(initialSessionId).toBeGreaterThan(0);

    const firstQIdx = exitLesson.steps.findIndex((s) => Boolean(s.interactiveQuestion));
    const secondQIdx = exitLesson.steps.findIndex((s, i) => i > firstQIdx && Boolean(s.interactiveQuestion));
    expect(secondQIdx).toBeGreaterThan(firstQIdx);

    useLessonStore.getState().goToStep(secondQIdx);
    expect(useLessonStore.getState().switchToAlternateExercise()).toBe(true);
    expect(useLessonStore.getState().lessonSessionId).toBe(initialSessionId);
    expect(useLessonStore.getState().currentStepIndex).toBe(secondQIdx);
    expect(useLessonStore.getState().currentLesson?.steps[secondQIdx].interactiveQuestion?.id).toBe(
      exitLesson.alternateExercise?.id,
    );
  });

  it('normalizes corrupt/partial sessionStorage profile fields safely without crashing .includes() or map reads', async () => {
    const storage = createMemoryStorage();
    storage.setItem(
      'bilimyol_demo_progress',
      JSON.stringify({
        profile: {
          id: 'learner_default_01',
          name: 123,
          selectedCourseId: '',
          dailyMinutes: 999,
          xp: -15,
          scoresByCourse: null,
          placementScoreByCourse: 'invalid',
          placementCefrByCourse: [],
          placementSkillScoresByCourse: null,
          completedLessonIds: null,
          completedNodeIds: 'not-an-array',
          completedReinforcementIds: [42, null, 'reinf_valid'],
          flashcardSrsByCourse: null,
        },
        answerAttempts: [null, 'bad-attempt'],
        processedActionKeys: [123, 'key_ok'],
        recordedActivityDates: [null, '2026-11-20'],
      }),
    );

    const repo = new InMemoryLearnerRepository(() => storage);
    const loaded = await repo.getProfile();
    expect(loaded.completedLessonIds).toEqual([]);
    expect(loaded.completedNodeIds).toEqual([]);
    expect(loaded.completedReinforcementIds).toEqual(['reinf_valid']);
    expect(loaded.scoresByCourse).toEqual({});
    expect(loaded.placementScoreByCourse).toEqual({});
    expect(loaded.placementCefrByCourse).toEqual({});
    expect(loaded.flashcardSrsByCourse).toEqual({});
    expect(loaded.xp).toBe(0);
    expect(loaded.dailyMinutes).toBe(15);
    expect(loaded.selectedCourseId).toBe('course_math_01');

    // Subsequent profile operations must work cleanly without throwing
    await repo.markLessonCompleted('lesson_eng_starter', 'course_eng_01');
    const afterComplete = await repo.getProfile();
    expect(afterComplete.completedLessonIds).toContain('lesson_eng_starter');
  });

  it('refuses UZ/RU/EN answer-reveal and solution paraphrases in Yolchi AI while allowing conceptual questions', async () => {
    const revealParaphrases = {
      en: [
        'which one should i choose',
        'which one should i pick?',
        'just give me the solution',
        'what is the solution?',
        'which option do i select',
      ],
      uz: [
        'qaysi javobni bosay',
        'qaysi variantni bosay?',
        "to'g'risini ayt",
        'yechimini ber',
        'qaysinisini tanlay?',
      ],
      ru: [
        'подскажи правильный вариант пожалуйста',
        'подскажите правильный вариант',
        'дай готовое решение',
        'какой из них выбрать?',
        'просто скажи решение',
      ],
    } as const;

    const demoAi = new DemoAITutorService();
    const starterQ = SEED_LESSONS['lesson_eng_starter'].steps.find((s) => s.interactiveQuestion)!.interactiveQuestion!;

    for (const [lang, phrases] of Object.entries(revealParaphrases)) {
      for (const phrase of phrases) {
        expect(isAnswerRevealRequest(phrase), `Expected spoiler refusal for "${phrase}"`).toBe(true);
        const reply = await demoAi.askTutor({
          courseId: 'course_eng_01',
          lessonId: 'lesson_eng_starter',
          questionId: starterQ.id,
          skillId: starterQ.skillId,
          language: lang as 'uz' | 'ru',
          message: phrase,
        });
        expect(reply.answer).not.toMatch(/I'm Sam|My name is Sam/i);
      }
    }

    for (const safePrompt of [
      'Hello qachon ishlatiladi?',
      'Когда используется Hello?',
      'How do I form Past Simple?',
      'Misol keltiring va tushuntiring',
    ]) {
      expect(isAnswerRevealRequest(safePrompt), `Unexpected refusal on safe prompt "${safePrompt}"`).toBe(false);
    }
  });

  it('renders RoadmapView locked Qulf sharti button without aria-disabled="true" so it stays clickable', async () => {
    await useCourseStore.getState().loadCourses();
    await useCourseStore.getState().selectCourseById('course_eng_01');
    const engCourse = SEED_COURSES.find((c) => c.id === 'course_eng_01')!;
    useCourseStore.setState({
      courses: SEED_COURSES,
      activeCourse: engCourse,
      activeCourseSkills: SEED_SKILLS.filter((s) => s.courseId === 'course_eng_01'),
    });
    useLearnerStore.setState({
      profile: {
        id: 'guest_user_01',
        name: 'Test',
        selectedCourseId: 'course_eng_01',
        goal: 'mastery',
        dailyMinutes: 15,
        initialLevel: 'intermediate',
        courseLevels: { course_eng_01: 'intermediate' },
        xp: 0,
        streakDays: 0,
        lastActiveDate: '',
        scoresByCourse: {},
        completedLessonIds: [],
        completedNodeIds: [],
        completedReinforcementIds: [],
        createdAt: 1000,
      },
      isLoading: false,
    });
    await useRoadmapStore.getState().loadRoadmap('course_eng_01');

    const roadmapHtml = renderToStaticMarkup(
      <AuthProvider>
        <RoadmapView
          onStartLesson={() => {}}
          onOpenKnowledgeMap={() => {}}
          onChooseCourse={() => {}}
          onConfigure={() => {}}
        />
      </AuthProvider>,
    );
    expect(roadmapHtml).toContain('Qulf sharti');
    expect(roadmapHtml).not.toContain('aria-disabled="true"');
    expect(roadmapHtml).toContain('aria-expanded="false"');
  });
});
