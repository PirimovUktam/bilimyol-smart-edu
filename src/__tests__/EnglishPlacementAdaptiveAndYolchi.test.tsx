import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
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

import { AuthProvider } from '@/core/context/AuthContext';
import { loadRussian } from '@/core/locales/messages';
import { usePreferences } from '@/core/preferences/preferences';
import { setDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { PLACEMENT_QUESTIONS } from '@/data/datasources/questions';
import { SEED_COURSES } from '@/data/datasources/courses';
import { SEED_ROADMAP_NODES } from '@/data/datasources/roadmaps';
import { SEED_SKILLS } from '@/data/datasources/skills';
import { ENGLISH_ALL_LESSONS, ENGLISH_ALL_QUESTIONS } from '@/data/datasources/english';
import { InMemoryCourseRepository } from '@/data/repositories/InMemoryCourseRepository';
import { InMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { DemoAITutorService } from '@/data/services/DemoAITutorService';
import { GeminiAIServiceError, GeminiAITutorService } from '@/data/services/GeminiAITutorService';
import { readApprovedLessonMedia } from '@/domain/entities/LessonMedia';
import type { LearnerProfile } from '@/domain/entities/LearnerProfile';
import type { QuestionAnswerSubmission } from '@/domain/entities/Question';
import { AdaptiveCycleEngine } from '@/domain/personalization/AdaptiveCycleEngine';
import { AdaptiveQuestionSelector } from '@/domain/personalization/AdaptiveQuestionSelector';
import {
  computeEnglishPlacementCefr,
  getEnglishPlacementEntryNodeId,
} from '@/domain/personalization/EnglishCefrPlacement';
import { hasStartedCourse, pendingFoundationLesson, usesMathMastery } from '@/domain/personalization/learningStart';
import { RecommendationEngine } from '@/domain/personalization/RecommendationEngine';
import { RouteEngine } from '@/domain/personalization/RouteEngine';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import { SubmitPlacementTestUseCase } from '@/domain/usecases/SubmitPlacementTestUseCase';
import { resolveContinuationLessonId } from '@/app/router/lessonResolution';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useLessonStore } from '@/app/store/useLessonStore';
import { usePlacementStore } from '@/app/store/usePlacementStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { InteractiveLessonView } from '@/features/lesson/InteractiveLessonView';
import { PlacementTestView } from '@/features/placement/PlacementTestView';
import { ReinforcementModal } from '@/features/reinforcement/ReinforcementModal';
import { RoadmapView } from '@/features/roadmap/RoadmapView';
import { Badge } from '@/presentation/components/Badge';

describe('M5.1 English Placement, Adaptive/SRS, Deferred B2-C2 & Yolchi AI', () => {
  beforeEach(() => {
    setDemoRuntimeActive(true);
    usePreferences.setState({ language: 'uz', theme: 'light' });
    usePlacementStore.getState().resetPlacement();
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

  it('provides 12 calibrated A1-B1 placement items with approved en WAV media and zero Audio context leaks', () => {
    const bank = PLACEMENT_QUESTIONS['course_eng_01'];
    expect(bank).toHaveLength(12);

    const skills = ['skill_eng_vocab', 'skill_eng_grammar', 'skill_eng_listening', 'skill_eng_reading'];
    for (const skillId of skills) {
      const skillItems = bank.filter((q) => q.skillId === skillId);
      expect(skillItems).toHaveLength(3);
      expect(skillItems.map((q) => `${q.difficulty}:${q.cefrLevel}`).sort()).toEqual([
        'easy:A1',
        'hard:B1',
        'medium:A2',
      ]);
    }

    for (const q of bank) {
      expect(q.isPlacement).toBe(true);
      expect(q.text).not.toContain('Audio context:');
      expect(q.textRu).toBeTruthy();
      expect(q.textRu).not.toContain('Audio context:');
      expect(['A1', 'A2', 'B1']).toContain(q.cefrLevel);
      expect(q.options).toHaveLength(4);
      expect(q.mistakeFeedbackByOption).toBeDefined();
      for (const opt of q.options) {
        expect(q.mistakeFeedbackByOption?.[opt]?.uz).toBeTruthy();
        expect(q.mistakeFeedbackByOption?.[opt]?.ru).toBeTruthy();
      }
    }

    const listeningItems = bank.filter((q) => q.skillId === 'skill_eng_listening');
    expect(listeningItems).toHaveLength(3);
    for (const item of listeningItems) {
      const approved = readApprovedLessonMedia(item.media);
      expect(approved).toBeDefined();
      expect(approved?.kind).toBe('audio');
      expect(approved?.language).toBe('en');
      expect(approved?.provenance).toBe('local-system-speech');
      expect(approved?.durationSeconds).toBeGreaterThan(0);
      const publicPath = resolve(process.cwd(), 'public', approved!.source.replace(/^\//, ''));
      expect(existsSync(publicPath)).toBe(true);
    }
  });

  it('starts English placement at easy (A1), prevents miss jumps to hard, and computes scores strictly over answered items', () => {
    const engBank = PLACEMENT_QUESTIONS['course_eng_01'];
    const skills = ['skill_eng_vocab', 'skill_eng_grammar', 'skill_eng_listening', 'skill_eng_reading'];

    const first = AdaptiveQuestionSelector.getNextQuestion(engBank, skills, [], 2);
    expect(first?.difficulty).toBe('easy');
    expect(first?.cefrLevel).toBe('A1');

    // Miss on easy A1 vocab -> next vocab question should stay medium (never hard if easy exhausted)
    const afterMiss = AdaptiveQuestionSelector.getNextQuestion(
      engBank,
      skills,
      [
        { questionId: first!.id, skillId: 'skill_eng_vocab', difficulty: 'easy', isCorrect: false },
        { questionId: 'q_eng_place_grammar_a1', skillId: 'skill_eng_grammar', difficulty: 'easy', isCorrect: true },
        { questionId: 'q_eng_place_listening_a1', skillId: 'skill_eng_listening', difficulty: 'easy', isCorrect: true },
        { questionId: 'q_eng_place_reading_a1', skillId: 'skill_eng_reading', difficulty: 'easy', isCorrect: true },
      ],
      2,
    );
    expect(afterMiss?.skillId).toBe('skill_eng_vocab');
    expect(afterMiss?.difficulty).toBe('medium');

    // 8 answered items out of 12-item bank -> 8/8 = 100%, 0/8 = 0% (never 67% from unasked 4)
    const asked8 = engBank.filter((q) => q.difficulty !== 'hard');
    expect(asked8).toHaveLength(8);
    const allRight = SkillScoringEngine.computePlacementScores(
      'course_eng_01',
      engBank,
      asked8.map((q) => ({ questionId: q.id, selectedIndex: q.correctIndex ?? 0, isCorrect: true, timeSpentSeconds: 5 })),
    );
    for (const s of Object.values(allRight)) {
      expect(s.score).toBe(100);
    }

    const allWrong = SkillScoringEngine.computePlacementScores(
      'course_eng_01',
      engBank,
      asked8.map((q) => ({ questionId: q.id, selectedIndex: ((q.correctIndex ?? 0) + 1) % 4, isCorrect: false, timeSpentSeconds: 5 })),
    );
    for (const s of Object.values(allWrong)) {
      expect(s.score).toBe(0);
      expect(s.masteryLevel).toBe('needs_remediation');
    }
  });

  it('isolates placement scores from independent mastery and caps CEFR tier at B1 without fabricating completions', async () => {
    const courseRepo = new InMemoryCourseRepository();
    const learnerRepo = new InMemoryLearnerRepository();
    await learnerRepo.resetAll();
    const useCase = new SubmitPlacementTestUseCase(courseRepo, learnerRepo);

    const bank = await courseRepo.getPlacementQuestions('course_eng_01');
    const asked8 = bank.filter((q) => q.difficulty !== 'hard');
    const perfectSubs: QuestionAnswerSubmission[] = asked8.map((q) => ({
      questionId: q.id,
      selectedIndex: q.correctIndex ?? 0,
      isCorrect: false, // verify server-side evaluation ignores client flag
      timeSpentSeconds: 6,
    }));

    const result = await useCase.execute('course_eng_01', perfectSubs);
    expect(result.overallScore).toBe(100);
    expect(result.placementCefr).toBe('B1');
    expect(result.recommendedNodeId).toBe('node_eng_b1_m1_travel');

    const profile = await learnerRepo.getProfile();
    expect(profile.placementScoreByCourse?.['course_eng_01']).toBe(100);
    expect(profile.placementCefrByCourse?.['course_eng_01']).toBe('B1');
    expect(profile.scoresByCourse['course_eng_01']).toBeUndefined();
    expect(profile.completedLessonIds).toEqual([]);
    expect(profile.completedNodeIds).toEqual([]);

    // Subsequent wrong lesson attempt should calculate mastery strictly from independent lesson attempts (not placement)
    await learnerRepo.recordAnswerAttempt({
      courseId: 'course_eng_01',
      skillId: 'skill_eng_vocab',
      lessonId: 'lesson_eng_vocab_01',
      questionId: 'q_eng_vocab_1',
      selectedIndex: 1,
      selectedAnswer: 'wrong',
      isCorrect: false,
    });
    const afterLessonAttempt = await learnerRepo.getProfile();
    expect(afterLessonAttempt.scoresByCourse['course_eng_01']?.['skill_eng_vocab']?.score).toBe(0);

    // CEFR tier capping & foundation routing
    expect(computeEnglishPlacementCefr(bank, [], ['node_eng_a2_exit'])).toBe('B1');
    expect(
      computeEnglishPlacementCefr(
        bank,
        asked8.map((q) => ({ questionId: q.id, selectedIndex: 0, isCorrect: false, timeSpentSeconds: 5 })),
      ),
    ).toBe('Pre-A1');
    expect(getEnglishPlacementEntryNodeId('B2')).toBe('node_eng_b1_m1_travel');

    const engCourse = SEED_COURSES.find((c) => c.id === 'course_eng_01')!;
    expect(hasStartedCourse(engCourse, profile)).toBe(true);
    expect(
      pendingFoundationLesson(engCourse, {
        ...profile,
        courseLevels: { course_eng_01: 'beginner' },
        placementCefrByCourse: { course_eng_01: 'A2' },
      }),
    ).toBeNull();
    expect(
      pendingFoundationLesson(engCourse, {
        ...profile,
        courseLevels: { course_eng_01: 'beginner' },
        placementCefrByCourse: { course_eng_01: 'Pre-A1' },
      }),
    ).toBe('lesson_eng_starter');
  });

  it('renders PlacementTestView with real WAV audio player, Russian localization, and calibrated CEFR result', async () => {
    await loadRussian();
    const listeningQ = PLACEMENT_QUESTIONS['course_eng_01'].find(
      (q) => q.id === 'q_eng_place_listening_a1',
    )!;
    const engCourse = SEED_COURSES.find((c) => c.id === 'course_eng_01')!;
    useCourseStore.setState({
      courses: SEED_COURSES,
      activeCourse: engCourse,
      activeCourseSkills: SEED_SKILLS.filter((s) => s.courseId === 'course_eng_01'),
    });
    usePlacementStore.setState({
      currentQuestion: listeningQ,
      questionNumber: 1,
      totalQuestionsToAsk: 8,
      isLoading: false,
      hasFinished: false,
      assessmentResult: null,
    });

    const htmlUz = renderToStaticMarkup(
      <AuthProvider>
        <PlacementTestView onComplete={() => {}} onChooseCourse={() => {}} onStartLearning={() => {}} />
      </AuthProvider>,
    );
    expect(htmlUz).toContain('<audio');
    expect(htmlUz).toContain('src="/lesson-media/english/placement/q_eng_place_listening_a1.wav"');
    expect(htmlUz).toContain('Matnli bayon');
    expect(htmlUz).not.toContain('<details open');

    usePreferences.setState({ language: 'ru' });
    const htmlRu = renderToStaticMarkup(
      <AuthProvider>
        <PlacementTestView onComplete={() => {}} onChooseCourse={() => {}} onStartLearning={() => {}} />
      </AuthProvider>,
    );
    expect(htmlRu).toContain(listeningQ.textRu!);

    usePlacementStore.setState({
      currentQuestion: null,
      hasFinished: true,
      assessmentResult: {
        assessmentId: 'plc_test',
        courseId: 'course_eng_01',
        submissions: [{ questionId: listeningQ.id, selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 }],
        computedScores: {
          skill_eng_listening: {
            skillId: 'skill_eng_listening',
            courseId: 'course_eng_01',
            score: 100,
            lastUpdated: Date.now(),
            masteryLevel: 'mastered',
          },
        },
        overallScore: 100,
        placementCefr: 'B1',
        recommendedNodeId: 'node_eng_b1_m1_travel',
        weakestSkillId: 'skill_eng_listening',
        timestamp: Date.now(),
      },
    });
    usePreferences.setState({ language: 'uz' });
    const resultHtml = renderToStaticMarkup(
      <AuthProvider>
        <PlacementTestView onComplete={() => {}} onChooseCourse={() => {}} onStartLearning={() => {}} />
      </AuthProvider>,
    );
    expect(resultHtml).toContain('CEFR daraja: B1');
    expect(resultHtml).toContain('DEFERRED');
  });

  it('supports placement-aware A2/B1 entry, 50-69 targeted practice, 2x-mistake remedial UI, and Deferred B2-C2 display', async () => {
    expect(usesMathMastery('course_eng_01')).toBe(false);

    const engCourse = SEED_COURSES.find((c) => c.id === 'course_eng_01')!;
    const engNodes = SEED_ROADMAP_NODES['course_eng_01'];
    const engSkills = SEED_SKILLS.filter((s) => s.courseId === 'course_eng_01');

    const a2Path = RouteEngine.adaptRoadmap('course_eng_01', engNodes, {}, [], [], { placementCefr: 'A2' });
    expect(a2Path.activeNodeId).toBe('node_eng_a2_m1_directions');
    expect(a2Path.nodes.find((n) => n.id === 'node_eng_a2_m1_directions')?.status).toBe('available');
    expect(a2Path.nodes.find((n) => n.id === 'node_eng_a2_m1_directions')?.isPlacementRecommended).toBe(true);
    expect(resolveContinuationLessonId(engCourse, a2Path)).toBe('lesson_eng_a2_m1_directions');

    const targetedScores = {
      skill_eng_vocab: {
        skillId: 'skill_eng_vocab',
        courseId: 'course_eng_01',
        score: 62,
        lastUpdated: Date.now(),
        masteryLevel: 'proficient' as const,
      },
    };
    const targetedPath = RouteEngine.adaptRoadmap('course_eng_01', engNodes, targetedScores, [], []);
    expect(targetedPath.nodes.find((n) => n.id === 'node_eng_a1_m1_greetings')?.routeStrategy).toBe('targeted_practice');
    expect(targetedPath.nodes.find((n) => n.id === 'node_eng_a1_m1_greetings')?.status).toBe('available');

    const microTasks = AdaptiveCycleEngine.buildDailyMicroTasks({
      course: engCourse,
      skills: engSkills,
      skillScores: targetedScores,
      roadmap: targetedPath,
    });
    expect(microTasks.some((task) => task.id === 'micro_targeted')).toBe(true);
    const rec = RecommendationEngine.generateRecommendation('course_eng_01', engSkills, targetedScores, targetedPath);
    expect(rec.title).toContain('Maqsadli mashq');

    // Consecutive mistake tracking (>= 2) across clearAnswerResult retries
    const starter = ENGLISH_ALL_LESSONS['lesson_eng_starter'];
    useCourseStore.setState({ courses: SEED_COURSES, activeCourse: engCourse, activeCourseSkills: engSkills });
    useLessonStore.setState({
      currentLesson: starter,
      currentStepIndex: starter.steps.length - 1,
      isLoading: false,
      lastAnswerResult: null,
      consecutiveMistakes: 0,
      consecutiveMistakeSkillId: null,
    });
    await useLessonStore.getState().submitTextAnswer('Sam');
    expect(useLessonStore.getState().consecutiveMistakes).toBe(1);
    useLessonStore.getState().clearAnswerResult();
    expect(useLessonStore.getState().consecutiveMistakes).toBe(1);
    await useLessonStore.getState().submitTextAnswer('Goodbye');
    expect(useLessonStore.getState().consecutiveMistakes).toBe(2);

    const lessonHtml = renderToStaticMarkup(
      <AuthProvider>
        <InteractiveLessonView lessonId="lesson_eng_starter" onFinish={() => {}} onBackToRoadmap={() => {}} />
      </AuthProvider>,
    );
    expect(lessonHtml).toContain('Takroriy xato aniqlandi');
    expect(lessonHtml).toContain('Qo‘shimcha mashq');

    // RoadmapView B2-C2 DEFERRED display without raw internal IDs
    const b1PlacedPath = RouteEngine.adaptRoadmap('course_eng_01', engNodes, {}, [], [], { placementCefr: 'B1' });
    const profile: LearnerProfile = {
      id: 'learner_default_01',
      name: 'Test',
      selectedCourseId: 'course_eng_01',
      goal: 'mastery',
      dailyMinutes: 15,
      initialLevel: 'advanced',
      courseLevels: { course_eng_01: 'advanced' },
      xp: 20,
      streakDays: 1,
      lastActiveDate: '2026-11-19',
      scoresByCourse: {},
      placementScoreByCourse: { course_eng_01: 100 },
      placementCefrByCourse: { course_eng_01: 'B1' },
      completedLessonIds: [],
      completedNodeIds: [],
      completedReinforcementIds: [],
      createdAt: Date.now(),
    };
    useLearnerStore.setState({ profile, isLoading: false });
    useRoadmapStore.setState({ roadmap: b1PlacedPath, isLoading: false, error: null });

    const roadmapHtml = renderToStaticMarkup(
      <AuthProvider>
        <RoadmapView
          onStartLesson={() => {}}
          onOpenKnowledgeMap={() => {}}
          onChooseCourse={() => {}}
          onConfigure={() => {}}
          onStartPlacement={() => {}}
        />
      </AuthProvider>,
    );
    expect(roadmapHtml).toContain('CEFR darajalari · A1–B1');
    expect(roadmapHtml).toContain('Keyingi bosqich (DEFERRED)');
    expect(roadmapHtml).toContain('text-[#FCD34D]');
    expect(roadmapHtml).not.toContain('text-[#92400E]');
    expect(roadmapHtml).not.toContain('text-[#047857]');
    expect(roadmapHtml).not.toContain('text-[#9F1239]');
    expect(roadmapHtml).not.toContain('text-[#0369A1]');
    expect(roadmapHtml).not.toContain('text-[#5b21b6]');
    const visibleRoadmapText = roadmapHtml.replace(/<[^>]+>/g, ' ');
    expect(visibleRoadmapText).not.toContain('node_eng_b1_exit');
    const b2Slice = roadmapHtml.slice(roadmapHtml.indexOf('data-cefr-level="B2"'));
    expect(b2Slice).not.toContain('node_eng_b1_exit');

    await loadRussian();
    usePreferences.setState({ language: 'ru' });
    const roadmapRuHtml = renderToStaticMarkup(
      <AuthProvider>
        <RoadmapView
          onStartLesson={() => {}}
          onOpenKnowledgeMap={() => {}}
          onChooseCourse={() => {}}
          onConfigure={() => {}}
          onStartPlacement={() => {}}
        />
      </AuthProvider>,
    );
    expect(roadmapRuHtml).toContain('Уровни CEFR · A1–B1');
    expect(roadmapRuHtml).toContain('Скоро (в следующем этапе)');
    expect(roadmapRuHtml).not.toContain('text-[#92400E]');

    // Foundation timeline completed badge uses localized t('path.completed') in RU mode
    useLearnerStore.setState({
      profile: {
        ...profile,
        placementCefrByCourse: undefined,
        completedLessonIds: ['lesson_eng_starter'],
      },
      isLoading: false,
    });
    const foundationRuHtml = renderToStaticMarkup(
      <AuthProvider>
        <RoadmapView
          onStartLesson={() => {}}
          onOpenKnowledgeMap={() => {}}
          onChooseCourse={() => {}}
          onConfigure={() => {}}
          onStartPlacement={() => {}}
        />
      </AuthProvider>,
    );
    expect(foundationRuHtml).toContain('Завершённые');
    expect(foundationRuHtml).not.toContain('Tugallangan');
  });

  it('grounds DemoAITutorService in A1-B1 English (uz/ru), blocks spoilers, and throws tutor.networkError when offline', async () => {
    const demoAi = new DemoAITutorService();

    // Preserve audio_wave in generateLesson
    const genEng = await demoAi.generateLesson({
      courseId: 'course_eng_01',
      skillId: 'skill_eng_listening',
      topic: 'Greetings',
    });
    expect(genEng.steps.some((s) => s.visualModelData?.type === 'audio_wave')).toBe(true);

    // Anti-spoiler in UZ & RU
    const spoilerUz = await demoAi.askTutor({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_starter',
      questionId: 'q_lesson_eng_starter_quiz',
      skillId: 'skill_eng_listening',
      language: 'uz',
      message: 'To‘g‘ri javobni ayt',
    });
    expect(spoilerUz.answer).toContain('qadam-baqadam');
    expect(spoilerUz.answer).not.toMatch(/\b(I'm Sam|My name is Sam|My name's Sam)\b/i);

    const spoilerRu = await demoAi.askTutor({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_starter',
      questionId: 'q_lesson_eng_starter_quiz',
      skillId: 'skill_eng_listening',
      language: 'ru',
      message: 'Скажи правильный ответ',
    });
    expect(spoilerRu.answer).toContain('Давайте разберём вопрос по шагам');
    expect(spoilerRu.answer).not.toMatch(/\b(I'm Sam|My name is Sam|My name's Sam)\b/i);

    // Normal RU chat grounded in English lesson
    const normalRu = await demoAi.askTutor({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_starter',
      skillId: 'skill_eng_listening',
      language: 'ru',
      message: 'Когда говорят Hello?',
      learnerScore: 45,
      recentMistakes: ['skill_eng_listening: 45%'],
    });
    expect(normalRu.answer).toContain('Давайте разберём вопрос по шагам');
    expect(normalRu.answer).toContain('Hello');

    // Non-English RU preserves exact math/general scaffold
    const mathRu = await demoAi.askTutor({
      courseId: 'course_math_01',
      language: 'ru',
      message: 'Как раскрыть квадрат?',
    });
    expect(mathRu.answer).toContain('Давайте разберём вопрос по шагам');

    // Mistake explanation in UZ & RU
    const mistakeRu = await demoAi.explainMistake({
      courseId: 'course_eng_01',
      skillId: 'skill_eng_listening',
      lessonId: 'lesson_eng_starter',
      questionId: 'q_lesson_eng_starter_quiz',
      questionText: 'Introduce yourself as Sam.',
      selectedOption: 'Goodbye',
      language: 'ru',
    });
    expect(mistakeRu.explanation).toContain('прощание');

    // Offline check in GeminiAITutorService.askTutor even in demo runtime
    const gemini = new GeminiAITutorService();
    vi.stubGlobal('navigator', { onLine: false });
    await expect(
      gemini.askTutor({ message: 'Salom?', courseId: 'course_eng_01', language: 'uz' }),
    ).rejects.toThrowError(GeminiAIServiceError);
    await expect(
      gemini.askTutor({ message: 'Salom?', courseId: 'course_eng_01', language: 'uz' }),
    ).rejects.toMatchObject({ messageKey: 'tutor.networkError' });

    vi.stubGlobal('navigator', { onLine: true });
    const recovered = await gemini.askTutor({
      message: 'Salom?',
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_starter',
      language: 'uz',
    });
    expect(recovered.answer).toContain('qadam-baqadam');
  });

  it('blocks word_match/fill_blank spoilers, preserves word boundaries on short answers, and catches indirect reveal prompts', async () => {
    const demoAi = new DemoAITutorService();

    // 1. word_match anti-spoiler across A1, A2, B1
    const greetMatchRefusal = await demoAi.askTutor({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_a1_m1_greetings',
      questionId: 'q_eng_a1_m1_greet_match',
      skillId: 'skill_eng_vocab',
      language: 'uz',
      message: 'To‘g‘ri javobni ayt',
    });
    expect(greetMatchRefusal.answer).toContain('qadam-baqadam');
    expect(greetMatchRefusal.answer).not.toMatch(/Good morning/i);
    expect(greetMatchRefusal.answer).not.toMatch(/Xayrli tong/i);

    const greetMatchExample = await demoAi.askTutor({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_a1_m1_greetings',
      questionId: 'q_eng_a1_m1_greet_match',
      skillId: 'skill_eng_vocab',
      language: 'uz',
      message: 'Misol keltiring va tushuntiring',
    });
    expect(greetMatchExample.answer).not.toMatch(/Good morning/i);
    expect(greetMatchExample.answer).not.toMatch(/Xayrli tong/i);

    const a2MatchHelp = await demoAi.askTutor({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_a2_m2_shopping',
      questionId: 'q_eng_a2_m2_word_match',
      skillId: 'skill_eng_vocab',
      language: 'uz',
      message: 'Misol keltiring',
    });
    expect(a2MatchHelp.answer).not.toMatch(/discount/i);
    expect(a2MatchHelp.answer).not.toMatch(/chegirma/i);

    const b1MatchHelp = await demoAi.askTutor({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_b1_m3_narrative',
      questionId: 'q_eng_b1_m3_word_match',
      skillId: 'skill_eng_grammar',
      language: 'uz',
      message: 'Qoidani tushuntiring',
    });
    expect(b1MatchHelp.answer).not.toMatch(/\bmeanwhile\b/i);
    expect(b1MatchHelp.answer).not.toMatch(/shu paytda/i);

    // 2. explainMistake anti-spoiler across fill_blank & word_match
    const b1CondMistake = await demoAi.explainMistake({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_b1_m2_work_study',
      questionId: 'q_eng_b1_m2_cond_fill',
      skillId: 'skill_eng_grammar',
      questionText: 'Complete the condition.',
      selectedOption: "didn't work",
      language: 'uz',
    });
    expect(b1CondMistake.explanation).not.toMatch(/doesn't work/i);
    expect(b1CondMistake.remediationStep).not.toMatch(/doesn't work/i);
    expect(b1CondMistake.suggestedAction).not.toMatch(/doesn't work/i);

    const a2MuchMistake = await demoAi.explainMistake({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_a2_m2_shopping',
      questionId: 'q_eng_a2_m2_fill_much',
      skillId: 'skill_eng_grammar',
      questionText: 'How ___ does it cost?',
      selectedOption: 'many',
      language: 'ru',
    });
    expect(a2MuchMistake.explanation).not.toMatch(/\bmuch\b/i);
    expect(a2MuchMistake.remediationStep).not.toMatch(/\bmuch\b/i);
    expect(a2MuchMistake.suggestedAction).not.toMatch(/\bmuch\b/i);

    const a1MatchMistake = await demoAi.explainMistake({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_a1_m1_greetings',
      questionId: 'q_eng_a1_m1_greet_match',
      skillId: 'skill_eng_vocab',
      questionText: 'Match greetings.',
      selectedOption: '{}',
      language: 'uz',
    });
    expect(a1MatchMistake.explanation).not.toMatch(/Good morning/i);
    expect(a1MatchMistake.remediationStep).not.toMatch(/Good morning/i);
    expect(a1MatchMistake.remediationStep).not.toMatch(/Xayrli tong/i);

    // 3. Short-word boundary sanitization ("am" never corrupts "qadam-baqadam" or "Grammar")
    const foundationRefusal = await demoAi.askTutor({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_foundation_02',
      questionId: 'q_lesson_eng_foundation_02',
      skillId: 'skill_eng_grammar',
      language: 'uz',
      message: 'To‘g‘ri javobni ayt',
    });
    expect(foundationRefusal.answer).toContain('qadam-baqadam');
    expect(foundationRefusal.answer).not.toContain('[...]');
    expect(foundationRefusal.answer).not.toMatch(/(?<![a-z])am(?![a-z])/i);

    const foundationHelp = await demoAi.askTutor({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_foundation_02',
      questionId: 'q_lesson_eng_foundation_02',
      skillId: 'skill_eng_grammar',
      language: 'uz',
      message: 'Misol keltiring',
    });
    expect(foundationHelp.answer).toContain('qadam-baqadam');
    expect(foundationHelp.answer).not.toContain('Gr[...]mar');
    expect(foundationHelp.answer).not.toMatch(/\bam\b/i);

    // 4. Indirect spoiler prompts across RU/EN/UZ
    const indirectRu = [
      'какой ответ',
      'подскажи ответ',
      'какой вариант правильный?',
    ];
    for (const msg of indirectRu) {
      const res = await demoAi.askTutor({
        courseId: 'course_eng_01',
        lessonId: 'lesson_eng_starter',
        questionId: 'q_lesson_eng_starter_quiz',
        skillId: 'skill_eng_listening',
        language: 'ru',
        message: msg,
      });
      expect(res.answer).toContain('Готовый ответ я не подсказываю');
      expect(res.answer).not.toMatch(/\b(I'm Sam|My name is Sam)\b/i);
    }

    const indirectEn = ['give me the correct option', 'which option is correct?', 'answer please'];
    for (const msg of indirectEn) {
      const res = await demoAi.askTutor({
        courseId: 'course_eng_01',
        lessonId: 'lesson_eng_starter',
        questionId: 'q_lesson_eng_starter_quiz',
        skillId: 'skill_eng_listening',
        language: 'uz',
        message: msg,
      });
      expect(res.answer).toContain('To‘g‘ri javobni tayyor holda bera olmayman');
    }

    const indirectUz = ['qaysi biri to‘g‘ri?', 'javobi nima?'];
    for (const msg of indirectUz) {
      const res = await demoAi.askTutor({
        courseId: 'course_eng_01',
        lessonId: 'lesson_eng_starter',
        questionId: 'q_lesson_eng_starter_quiz',
        skillId: 'skill_eng_listening',
        language: 'uz',
        message: msg,
      });
      expect(res.answer).toContain('To‘g‘ri javobni tayyor holda bera olmayman');
    }

    // Also verify q_eng_lesson_interactive RU localization & empty questionId normalization
    const legacyRu = await demoAi.explainMistake({
      courseId: 'course_eng_01',
      skillId: 'skill_eng_listening',
      questionId: 'q_eng_lesson_interactive',
      questionText: 'Time check',
      selectedOption: '04:00',
      language: 'ru',
    });
    expect(legacyRu.explanation).toContain('quarter to four');
    expect(legacyRu.title).toContain('отрицание');

    const gemini = new GeminiAITutorService();
    vi.stubGlobal('navigator', { onLine: true });
    const askSpy = vi.spyOn(DemoAITutorService.prototype, 'askTutor');
    await gemini.askTutor({
      message: 'Salom?',
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_starter',
      questionId: '   ',
      language: 'uz',
    });
    expect(askSpy).toHaveBeenCalledWith(expect.objectContaining({ questionId: undefined }));

    const explainSpy = vi.spyOn(DemoAITutorService.prototype, 'explainMistake');
    await gemini.explainMistake({
      courseId: 'course_eng_01',
      skillId: 'skill_eng_listening',
      questionId: '   ',
      questionText: 'Time check',
      selectedOption: '04:00',
      language: 'uz',
    });
    expect(explainSpy).toHaveBeenCalledWith(expect.objectContaining({ questionId: '' }));

    // 5. No elimination leaks via lessonTitle (q_eng_vocab_reinf_01) or asksHello (q_lesson_eng_foundation_02_practice)
    for (const lang of ['uz', 'ru'] as const) {
      const vocabRefusal = await demoAi.askTutor({
        courseId: 'course_eng_01',
        lessonId: 'lesson_eng_vocab_01',
        questionId: 'q_eng_vocab_reinf_01',
        skillId: 'skill_eng_vocab',
        language: lang,
        message: lang === 'ru' ? 'правильный ответ?' : 'to‘g‘risi nima?',
      });
      expect(vocabRefusal.answer).not.toContain('(beside, between');
      expect(vocabRefusal.answer).not.toContain('[...]');
      expect(vocabRefusal.answer).not.toMatch(/\bbehind\b/i);

      const vocabMistake = await demoAi.explainMistake({
        courseId: 'course_eng_01',
        lessonId: 'lesson_eng_vocab_01',
        questionId: 'q_eng_vocab_reinf_01',
        skillId: 'skill_eng_vocab',
        questionText: 'Where is the cat?',
        selectedOption: 'beside',
        language: lang,
      });
      expect(vocabMistake.suggestedAction).not.toContain('(beside, between');
      expect(vocabMistake.suggestedAction).not.toContain('[...]');
      expect(vocabMistake.explanation).not.toMatch(/\bbehind\b/i);

      const foundationHello = await demoAi.askTutor({
        courseId: 'course_eng_01',
        lessonId: 'lesson_eng_foundation_02',
        questionId: 'q_lesson_eng_foundation_02_practice',
        skillId: 'skill_eng_grammar',
        language: lang,
        message: 'Salom',
      });
      expect(foundationHello.answer).not.toContain('My name [...]');
      expect(foundationHello.answer).not.toContain('[...]');
      expect(foundationHello.answer).not.toMatch(/\bis\b/i);
    }

    // 6. Edge reveal phrasings in RU & UZ
    for (const msg of ['правильный ответ?', 'что выбрать?', 'ответ скажи']) {
      const res = await demoAi.askTutor({
        courseId: 'course_eng_01',
        lessonId: 'lesson_eng_starter',
        questionId: 'q_lesson_eng_starter_quiz',
        skillId: 'skill_eng_listening',
        language: 'ru',
        message: msg,
      });
      expect(res.answer, `Missed RU reveal phrasing "${msg}"`).toContain('Готовый ответ я не подсказываю');
    }
    for (const msg of ['to‘g‘risi nima?', 'qaysi birini tanlay?']) {
      const res = await demoAi.askTutor({
        courseId: 'course_eng_01',
        lessonId: 'lesson_eng_starter',
        questionId: 'q_lesson_eng_starter_quiz',
        skillId: 'skill_eng_listening',
        language: 'uz',
        message: msg,
      });
      expect(res.answer, `Missed UZ reveal phrasing "${msg}"`).toContain('To‘g‘ri javobni tayyor holda bera olmayman');
    }

    // 7. Apostrophe symmetry in sanitizeNoSpoilers (curly ’ vs straight ')
    const curlyApostropheCheck = await demoAi.askTutor({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_b1_m2_work_study',
      questionId: 'q_eng_b1_m2_cond_fill',
      skillId: 'skill_eng_grammar',
      language: 'uz',
      message: 'Qoidani tushuntiring',
      recentMistakes: ['doesn’t work'],
    });
    expect(curlyApostropheCheck.answer).not.toMatch(/doesn[’']t work/i);
    expect(curlyApostropheCheck.answer).toContain('[...]');
  });

  it('recomputes CEFR on Supabase retake, completes word_match in ReinforcementModal, isolates submitAnswerAttempt, and fixes light contrast', async () => {
    // 1. Live Supabase placement retake recomputes 'B1' over stale 'A1'
    const engBank = PLACEMENT_QUESTIONS['course_eng_01'];
    const asked8 = engBank.filter((q) => q.difficulty !== 'hard');
    const staleProfile: LearnerProfile = {
      id: 'learner_sb_01',
      name: 'Retaker',
      selectedCourseId: 'course_eng_01',
      goal: 'mastery',
      dailyMinutes: 15,
      initialLevel: 'beginner',
      xp: 0,
      streakDays: 0,
      lastActiveDate: '',
      scoresByCourse: {},
      placementScoreByCourse: { course_eng_01: 38 },
      placementCefrByCourse: { course_eng_01: 'A1' },
      completedLessonIds: [],
      completedNodeIds: [],
      completedReinforcementIds: [],
      createdAt: Date.now(),
    };
    useLearnerStore.setState({ profile: staleProfile, isLoading: false });
    vi.spyOn(useLearnerStore.getState(), 'loadProfile').mockResolvedValue(undefined);
    const updateProfileSpy = vi.spyOn(supabaseLearnerRepository, 'updateProfile').mockResolvedValue({
      ...staleProfile,
      placementScoreByCourse: { course_eng_01: 100 },
      placementCefrByCourse: { course_eng_01: 'B1' },
    });
    vi.spyOn(supabaseLearnerRepository, 'supportsServerPlacementPersistence', 'get').mockReturnValue(true);
    vi.spyOn(supabaseLearnerRepository, 'advancePlacement').mockResolvedValue({
      id: 'sess_retake_1',
      question: null,
      number: 8,
      total: 8,
      canRetake: true,
      wasReset: false,
      result: {
        assessmentId: 'plc_retake_1',
        courseId: 'course_eng_01',
        submissions: asked8.map((q) => ({
          questionId: q.id,
          selectedIndex: q.correctIndex ?? 0,
          isCorrect: true,
          timeSpentSeconds: 5,
        })),
        computedScores: {},
        overallScore: 100,
        weakestSkillId: 'skill_eng_vocab',
        timestamp: Date.now(),
      },
    });

    await usePlacementStore.getState().initPlacement('course_eng_01', true);
    expect(usePlacementStore.getState().assessmentResult?.placementCefr).toBe('B1');
    expect(updateProfileSpy).toHaveBeenCalledWith(
      expect.objectContaining({
        placementCefrByCourse: expect.objectContaining({ course_eng_01: 'B1' }),
      }),
    );

    // 2. CEFR calibration check: 4/4 A1 + 1/4 A2 stays A1; 4/4 A1 + 2/4 A2 -> A2
    const a1Items = engBank.filter((q) => q.difficulty === 'easy');
    const a2Items = engBank.filter((q) => q.difficulty === 'medium');
    expect(
      computeEnglishPlacementCefr(engBank, [
        ...a1Items.map((q) => ({ questionId: q.id, selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 })),
        ...a2Items.map((q, idx) => ({ questionId: q.id, selectedIndex: 0, isCorrect: idx === 0, timeSpentSeconds: 5 })),
      ]),
    ).toBe('A1');
    expect(
      computeEnglishPlacementCefr(engBank, [
        ...a1Items.map((q) => ({ questionId: q.id, selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 })),
        ...a2Items.map((q, idx) => ({ questionId: q.id, selectedIndex: 0, isCorrect: idx < 2, timeSpentSeconds: 5 })),
      ]),
    ).toBe('A2');

    // 3. ReinforcementModal renders interactive word_match controls & evaluates completion
    const a2Checkpoint = ENGLISH_ALL_LESSONS['lesson_eng_a2_u1_checkpoint'];
    const reinfMatchQ = a2Checkpoint.reinforcementExercise;
    expect(reinfMatchQ.questionType).toBe('word_match');
    const modalHtml = renderToStaticMarkup(
      <ReinforcementModal
        isOpen
        question={reinfMatchQ}
        courseId="course_eng_01"
        skillId={reinfMatchQ.skillId}
        onSuccess={() => {}}
        onClose={() => {}}
      />,
    );
    expect(modalHtml).toContain('data-match-side="left"');
    expect(modalHtml).toContain('data-match-side="right"');
    expect(modalHtml).toContain('get off');
    expect(modalHtml).toContain('tushmoq');

    const memRepo = new InMemoryLearnerRepository();
    await memRepo.resetAll();
    // Verify submitAnswerAttempt placement isolation
    await memRepo.submitAnswerAttempt({
      courseId: 'course_eng_01',
      skillId: 'skill_eng_grammar',
      lessonId: 'placement_test',
      questionId: 'q_eng_place_grammar_a1',
      selectedIndex: 0,
      selectedAnswer: 'is',
      isCorrect: true,
    });
    const afterPlacementAttempt = await memRepo.getProfile();
    expect(afterPlacementAttempt.scoresByCourse['course_eng_01']).toBeUndefined();

    // Verify completeReinforcement evaluates word_match JSON payload via useRoadmapStore
    vi.restoreAllMocks();
    await supabaseLearnerRepository.resetAll();
    await useRoadmapStore.getState().loadRoadmap('course_eng_01');
    const validPairsJson = JSON.stringify(
      Object.fromEntries((reinfMatchQ.matchPairs ?? []).map((p) => [p.id, p.id])),
    );
    const reinfResult = await useRoadmapStore.getState().completeReinforcement(
      'course_eng_01',
      reinfMatchQ.skillId,
      `reinf_${reinfMatchQ.skillId}`,
      reinfMatchQ,
      0,
      validPairsJson,
      'uz',
    );
    expect(reinfResult.isCorrect).toBe(true);

    // 4. Default 'light' theme contrast classes & deduplicated 2x mistake CTA + RU grammar
    usePreferences.setState({ language: 'uz', theme: 'light' });
    const badgeHtml = renderToStaticMarkup(
      <div>
        <Badge variant="amber">Amber</Badge>
        <Badge variant="emerald">Emerald</Badge>
        <Badge variant="rose">Rose</Badge>
        <Badge variant="teal">Teal</Badge>
        <Badge variant="purple">Purple</Badge>
      </div>,
    );
    expect(badgeHtml).toContain('text-[#FCD34D]');
    expect(badgeHtml).toContain('text-[#6EE7B7]');
    expect(badgeHtml).toContain('text-[#FDA4AF]');
    expect(badgeHtml).toContain('text-[#67E8F9]');
    expect(badgeHtml).toContain('text-[#C4B5FD]');
    expect(badgeHtml).not.toContain('text-[#92400E]');
    expect(badgeHtml).not.toContain('text-[#047857]');
    expect(badgeHtml).not.toContain('text-[#9F1239]');

    const starter = ENGLISH_ALL_LESSONS['lesson_eng_starter'];
    const engCourse = SEED_COURSES.find((c) => c.id === 'course_eng_01')!;
    useCourseStore.setState({
      courses: SEED_COURSES,
      activeCourse: engCourse,
      activeCourseSkills: SEED_SKILLS.filter((s) => s.courseId === 'course_eng_01'),
    });
    useLessonStore.setState({
      currentLesson: starter,
      currentStepIndex: starter.steps.length - 1,
      isLoading: false,
      lastAnswerResult: {
        isCorrect: false,
        selectedOption: 'Sam',
        explanation: 'Write a full sentence.',
      },
      consecutiveMistakes: 2,
      consecutiveMistakeSkillId: 'skill_eng_listening',
    });

    const lessonLightHtml = renderToStaticMarkup(
      <AuthProvider>
        <InteractiveLessonView lessonId="lesson_eng_starter" onFinish={() => {}} onBackToRoadmap={() => {}} />
      </AuthProvider>,
    );
    expect(lessonLightHtml).toContain('text-[#FCD34D]');
    expect(lessonLightHtml).not.toContain('text-[#92400E]');
    expect(lessonLightHtml).toContain('Qo‘shimcha mashq');
    expect(lessonLightHtml).not.toContain('Mustahkamlash mashqi');

    await loadRussian();
    usePreferences.setState({ language: 'ru', theme: 'light' });
    const lessonRuHtml = renderToStaticMarkup(
      <AuthProvider>
        <InteractiveLessonView lessonId="lesson_eng_starter" onFinish={() => {}} onBackToRoadmap={() => {}} />
      </AuthProvider>,
    );
    expect(lessonRuHtml).toContain('Повторных ошибок подряд: 2');
  });

  it('audits all 110 English questions for zero anti-spoiler leaks and zero word-fragment corruption', async () => {
    const demoAi = new DemoAITutorService();
    const allEnglishQuestions = [...ENGLISH_ALL_QUESTIONS, ...PLACEMENT_QUESTIONS['course_eng_01']];
    expect(allEnglishQuestions).toHaveLength(110);

    for (const q of allEnglishQuestions) {
      const refusalUz = await demoAi.askTutor({
        courseId: 'course_eng_01',
        questionId: q.id,
        skillId: q.skillId,
        language: 'uz',
        message: 'To‘g‘ri javobni ayt',
      });
      expect(refusalUz.answer, `Refusal UZ missing qadam-baqadam for ${q.id}`).toContain('qadam-baqadam');
      expect(refusalUz.answer, `Corrupted mask inside word for ${q.id}`).not.toMatch(/[\p{L}\p{N}]\[\.\.\.\]|\[\.\.\.\][\p{L}\p{N}]/u);

      const refusalRu = await demoAi.askTutor({
        courseId: 'course_eng_01',
        questionId: q.id,
        skillId: q.skillId,
        language: 'ru',
        message: 'какой ответ',
      });
      expect(refusalRu.answer, `Refusal RU missing step scaffold for ${q.id}`).toContain('Давайте разберём вопрос по шагам');
      expect(refusalRu.answer, `Corrupted RU mask inside word for ${q.id}`).not.toMatch(/[\p{L}\p{N}]\[\.\.\.\]|\[\.\.\.\][\p{L}\p{N}]/u);

      const helpUz = await demoAi.askTutor({
        courseId: 'course_eng_01',
        questionId: q.id,
        skillId: q.skillId,
        language: 'uz',
        message: 'Misol keltiring va tushuntiring',
      });
      expect(helpUz.answer, `Corrupted help mask inside word for ${q.id}`).not.toMatch(/[\p{L}\p{N}]\[\.\.\.\]|\[\.\.\.\][\p{L}\p{N}]/u);
      if (q.id === 'q_eng_vocab_reinf_01' || q.id === 'q_lesson_eng_foundation_02_practice') {
        expect(refusalUz.answer, `Elimination clue [...] for ${q.id}`).not.toContain('[...]');
        expect(refusalRu.answer, `Elimination clue [...] for ${q.id}`).not.toContain('[...]');
        expect(helpUz.answer, `Elimination clue [...] for ${q.id}`).not.toContain('[...]');
      }

      const qType = q.questionType ?? 'multiple_choice';
      if (qType === 'word_match' || qType === 'fill_blank' || qType === 'text_input' || qType === 'sentence_order') {
        const secrets: string[] = [
          ...(q.acceptedAnswers ?? []),
          ...(q.matchPairs ?? []).flatMap((p) => [p.left, p.right]),
          ...(q.orderedTokens?.length ? [q.orderedTokens.join(' ')] : []),
        ]
          .map((s) => s.trim())
          .filter((s) => s.length >= 2);

        const [mistakeUz, mistakeRu] = await Promise.all([
          demoAi.explainMistake({
            courseId: 'course_eng_01',
            questionId: q.id,
            skillId: q.skillId,
            questionText: q.text,
            selectedOption: 'wrong_attempt',
            language: 'uz',
          }),
          demoAi.explainMistake({
            courseId: 'course_eng_01',
            questionId: q.id,
            skillId: q.skillId,
            questionText: q.text,
            selectedOption: 'wrong_attempt',
            language: 'ru',
          }),
        ]);

        const surfaces = [
          refusalUz.answer,
          refusalRu.answer,
          helpUz.answer,
          mistakeUz.explanation,
          mistakeUz.remediationStep,
          mistakeUz.suggestedAction,
          mistakeRu.explanation,
          mistakeRu.remediationStep,
          mistakeRu.suggestedAction,
        ];

        for (const secret of secrets) {
          const escaped = secret.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
          const rx = new RegExp(`(?<![\\p{L}\\p{N}_'])${escaped}(?![\\p{L}\\p{N}_'])`, 'iu');
          for (const surface of surfaces) {
            expect(surface, `Secret "${secret}" leaked for ${q.id} in: ${surface}`).not.toMatch(rx);
          }
        }
      }
    }
  }, 30000);
});
