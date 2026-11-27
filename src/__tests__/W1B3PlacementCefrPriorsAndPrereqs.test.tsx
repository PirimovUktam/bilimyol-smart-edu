// @vitest-environment jsdom
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { PLACEMENT_QUESTIONS } from '@/data/datasources/questions';
import { SEED_COURSES } from '@/data/datasources/courses';
import { SEED_SKILLS } from '@/data/datasources/skills';
import { SEED_ROADMAP_NODES } from '@/data/datasources/roadmaps';
import { AdaptiveQuestionSelector } from '@/domain/personalization/AdaptiveQuestionSelector';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';
import {
  computeEnglishPlacementCefr,
  evaluateEnglishPlacementCefr,
} from '@/domain/personalization/EnglishCefrPlacement';
import { RouteEngine } from '@/domain/personalization/RouteEngine';
import { InMemoryCourseRepository } from '@/data/repositories/InMemoryCourseRepository';
import { InMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';
import { SubmitPlacementTestUseCase } from '@/domain/usecases/SubmitPlacementTestUseCase';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { usePlacementStore } from '@/app/store/usePlacementStore';
import { KnowledgeMapView } from '@/features/knowledge-map/KnowledgeMapView';
import { PlacementTestView } from '@/features/placement/PlacementTestView';

vi.mock('@/core/context/AuthContext', () => ({
  useAuth: () => ({
    profile: null,
    user: null,
    isAuthenticated: false,
    isLoading: false,
  }),
}));

describe('W1-B3: Placement CEFR Calibration, Priors, Prerequisites & Retake Integrity', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('FIX-P0-11 & FIX-P1-14: starts English placement at medium (A2), enforces 1-step Markov transitions, and requires B1 evidence for B1 placement', () => {
    const engBank = PLACEMENT_QUESTIONS['course_eng_01'];
    const skills = ['skill_eng_vocab', 'skill_eng_grammar', 'skill_eng_listening', 'skill_eng_reading'];

    // 1. Starts at medium (A2)
    const first = AdaptiveQuestionSelector.getNextQuestion(engBank, skills, [], 2);
    expect(first?.difficulty).toBe('medium');
    expect(first?.cefrLevel).toBe('A2');

    // 2. 1-step Markov transition parity: [easy:true, medium:false] -> easy (not medium)
    expect(
      AdaptiveQuestionSelector.determineNextDifficulty('skill_eng_vocab', [
        { questionId: 'q_eng_place_vocab_a1', skillId: 'skill_eng_vocab', difficulty: 'easy', isCorrect: true },
        { questionId: 'q_eng_place_vocab_a2', skillId: 'skill_eng_vocab', difficulty: 'medium', isCorrect: false },
      ]),
    ).toBe('easy');

    // [hard:false, medium:true] -> hard
    expect(
      AdaptiveQuestionSelector.determineNextDifficulty('skill_eng_vocab', [
        { questionId: 'q_eng_place_vocab_b1', skillId: 'skill_eng_vocab', difficulty: 'hard', isCorrect: false },
        { questionId: 'q_eng_place_vocab_a2', skillId: 'skill_eng_vocab', difficulty: 'medium', isCorrect: true },
      ]),
    ).toBe('hard');

    // 3. 8/8 on A1+A2 (b1Total === 0) caps at A2, while 8/8 on A2+B1 awards B1
    const a1AndA2 = engBank.filter((q) => q.difficulty !== 'hard');
    expect(
      computeEnglishPlacementCefr(
        engBank,
        a1AndA2.map((q) => ({ questionId: q.id, selectedIndex: q.correctIndex ?? 0, isCorrect: true, timeSpentSeconds: 5 })),
      ),
    ).toBe('A2');

    const a2AndB1 = engBank.filter((q) => q.difficulty !== 'easy');
    expect(
      computeEnglishPlacementCefr(
        engBank,
        a2AndB1.map((q) => ({ questionId: q.id, selectedIndex: q.correctIndex ?? 0, isCorrect: true, timeSpentSeconds: 5 })),
      ),
    ).toBe('B1');

    // 4/4 A2 + 0/4 B1 places at A2 (never demoted to A1)
    expect(
      computeEnglishPlacementCefr(
        engBank,
        a2AndB1.map((q) => ({
          questionId: q.id,
          selectedIndex: 0,
          isCorrect: q.cefrLevel === 'A2',
          timeSpentSeconds: 5,
        })),
      ),
    ).toBe('A2');
  });

  it('FIX-P1-16: weights placement item credit by difficulty, gates weakest focus on < 80, and deduplicates last-wins', async () => {
    const engBank = PLACEMENT_QUESTIONS['course_eng_01'];

    // score(m:1, h:0) > score(m:0, e:1)
    const mhScores = SkillScoringEngine.computePlacementScores('course_eng_01', engBank, [
      { questionId: 'q_eng_place_vocab_a2', selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 },
      { questionId: 'q_eng_place_vocab_b1', selectedIndex: 0, isCorrect: false, timeSpentSeconds: 5 },
    ]);
    const meScores = SkillScoringEngine.computePlacementScores('course_eng_01', engBank, [
      { questionId: 'q_eng_place_vocab_a2', selectedIndex: 0, isCorrect: false, timeSpentSeconds: 5 },
      { questionId: 'q_eng_place_vocab_a1', selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 },
    ]);
    expect(mhScores['skill_eng_vocab'].score).toBeGreaterThan(meScores['skill_eng_vocab'].score);

    // Duplicate [false, true] deduplicates last-wins -> 100%, with 0 isWeakestFocus flags at 100%
    const dupScores = SkillScoringEngine.computePlacementScores('course_eng_01', engBank, [
      { questionId: 'q_eng_place_vocab_a2', selectedIndex: 0, isCorrect: false, timeSpentSeconds: 5 },
      { questionId: 'q_eng_place_vocab_a2', selectedIndex: 0, isCorrect: true, timeSpentSeconds: 5 },
    ]);
    expect(dupScores['skill_eng_vocab'].score).toBe(100);
    expect(dupScores['skill_eng_vocab'].isWeakestFocus).toBe(false);

    // SubmitPlacementTestUseCase emits weakestSkillId === '' at 100%
    const courseRepo = new InMemoryCourseRepository();
    const learnerRepo = new InMemoryLearnerRepository();
    await learnerRepo.resetAll();
    const useCase = new SubmitPlacementTestUseCase(courseRepo, learnerRepo);
    const a2AndB1 = engBank.filter((q) => q.difficulty !== 'easy');
    const res = await useCase.execute(
      'course_eng_01',
      a2AndB1.map((q) => ({
        questionId: q.id,
        selectedIndex: q.correctIndex ?? 0,
        isCorrect: true,
        timeSpentSeconds: 4,
      })),
    );
    expect(res.overallScore).toBe(100);
    expect(res.weakestSkillId).toBe('');
    expect(Object.values(res.computedScores).some((s) => s.isWeakestFocus)).toBe(false);
  });

  it('FIX-P0-02, FIX-P1-09 & FIX-P1-46: calibrates 0% placement + 1 starter <= 25%, caps 1/1 below mastered, and supersedes Day-1 misses on retake', async () => {
    const courseRepo = new InMemoryCourseRepository();
    const learnerRepo = new InMemoryLearnerRepository();
    await learnerRepo.resetAll();
    const useCase = new SubmitPlacementTestUseCase(courseRepo, learnerRepo);

    const engBank = PLACEMENT_QUESTIONS['course_eng_01'];
    const a1AndA2 = engBank.filter((q) => q.difficulty !== 'hard');

    // 1. 0/8 English placement -> isolated from scoresByCourse, persisted in placementSkillScoresByCourse
    await useCase.execute(
      'course_eng_01',
      a1AndA2.map((q) => ({
        questionId: q.id,
        selectedIndex: ((q.correctIndex ?? 0) + 1) % 4,
        isCorrect: false,
        timeSpentSeconds: 4,
      })),
    );
    let profile = await learnerRepo.getProfile();
    expect(profile.scoresByCourse['course_eng_01']).toBeUndefined();
    expect(profile.placementScoreByCourse?.['course_eng_01']).toBe(0);
    expect(profile.placementCefrByCourse?.['course_eng_01']).toBe('Pre-A1');
    expect(profile.placementSkillScoresByCourse?.['course_eng_01']?.['skill_eng_vocab']?.score).toBe(0);

    // 2. Answering 1 starter question right after 0% placement stays <= 25% ('needs_remediation')
    await learnerRepo.recordAnswerAttempt({
      courseId: 'course_eng_01',
      skillId: 'skill_eng_vocab',
      lessonId: 'lesson_eng_starter',
      questionId: 'q_lesson_eng_starter_quiz',
      selectedIndex: 0,
      selectedAnswer: "I'm Sam",
      isCorrect: true,
    });
    profile = await learnerRepo.getProfile();
    const starterAfterZero = profile.scoresByCourse['course_eng_01']?.['skill_eng_vocab'];
    expect(starterAfterZero?.score).toBeLessThanOrEqual(25);
    expect(starterAfterZero?.masteryLevel).toBe('needs_remediation');

    // 3. Day-1 0% placement on course_it -> Day-2 100% retake yields 100% (no stale placement_test drag)
    const itBank = await courseRepo.getPlacementQuestions('course_it');
    const itAsked = [
      ...itBank.filter((q) => q.skillId === 'skill_it_python').slice(0, 2),
      ...itBank.filter((q) => q.skillId === 'skill_it_web').slice(0, 2),
    ];
    await useCase.execute(
      'course_it',
      itAsked.map((q) => ({
        questionId: q.id,
        selectedIndex: ((q.correctIndex ?? 0) + 1) % q.options.length,
        isCorrect: false,
        timeSpentSeconds: 4,
      })),
    );
    expect((await learnerRepo.getProfile()).scoresByCourse['course_it']?.['skill_it_python']?.score).toBe(0);

    await useCase.execute(
      'course_it',
      itAsked.map((q) => ({
        questionId: q.id,
        selectedIndex: q.correctIndex ?? 0,
        isCorrect: true,
        timeSpentSeconds: 4,
      })),
    );
    const afterRetake = await learnerRepo.getProfile();
    expect(afterRetake.scoresByCourse['course_it']?.['skill_it_python']?.score).toBe(100);
    expect(afterRetake.scoresByCourse['course_it']?.['skill_it_web']?.score).toBe(100);
  });

  it('FIX-P1-07: chains all 15 A1 English nodes sequentially and unlocks orthogonal IT/Logic skills at Day 0', () => {
    const engA1Nodes = SEED_ROADMAP_NODES['course_eng_01'].filter((n) => n.cefrLevel === 'A1');
    expect(engA1Nodes).toHaveLength(15);

    const openAtDay0 = engA1Nodes.filter((n) => n.prerequisites.length === 0);
    expect(openAtDay0.map((n) => n.id)).toEqual(['node_eng_a1_m1_greetings']);

    const byId = new Map(engA1Nodes.map((n) => [n.id, n]));
    const ancestors = new Set<string>();
    const stack = [...(byId.get('node_eng_a1_exit')?.prerequisites ?? [])];
    while (stack.length > 0) {
      const cur = stack.pop()!;
      if (ancestors.has(cur)) continue;
      ancestors.add(cur);
      for (const p of byId.get(cur)?.prerequisites ?? []) stack.push(p);
    }
    expect(ancestors.size).toBe(14);

    // Day-0 RouteEngine: orthogonal node_it_web & node_logic_patterns are available (not locked)
    const itPath = RouteEngine.adaptRoadmap('course_it', SEED_ROADMAP_NODES['course_it'], {}, [], []);
    expect(itPath.nodes.find((n) => n.id === 'node_it_web')?.status).toBe('available');

    const logicPath = RouteEngine.adaptRoadmap('course_logic', SEED_ROADMAP_NODES['course_logic'], {}, [], []);
    expect(logicPath.nodes.find((n) => n.id === 'node_logic_patterns')?.status).toBe('available');
  });

  it('FIX-P2-09: separates assessedCefr from unlockedCefrFloor on PlacementTestView and renders ConfidenceLevel badges on KnowledgeMapView', () => {
    const engBank = PLACEMENT_QUESTIONS['course_eng_01'];
    const allWrong = engBank
      .filter((q) => q.difficulty !== 'hard')
      .map((q) => ({ questionId: q.id, selectedIndex: 0, isCorrect: false, timeSpentSeconds: 4 }));

    const evalFloor = evaluateEnglishPlacementCefr(engBank, allWrong, ['node_eng_a1_exit']);
    expect(evalFloor).toEqual({
      assessedCefr: 'Pre-A1',
      unlockedCefrFloor: 'A2',
      effectiveCefr: 'A2',
    });

    const engCourse = SEED_COURSES.find((c) => c.id === 'course_eng_01')!;
    const engSkills = SEED_SKILLS.filter((s) => s.courseId === 'course_eng_01');

    useCourseStore.setState({
      courses: SEED_COURSES,
      activeCourse: engCourse,
      activeCourseSkills: engSkills,
      isLoading: false,
    });
    useLearnerStore.setState({
      profile: {
        id: 'learner_w1b3_ui',
        name: 'Nodira',
        selectedCourseId: 'course_eng_01',
        goal: 'mastery',
        dailyMinutes: 15,
        initialLevel: 'beginner',
        xp: 40,
        streakDays: 1,
        lastActiveDate: '2026-11-27',
        scoresByCourse: {
          course_eng_01: {
            skill_eng_vocab: {
              skillId: 'skill_eng_vocab',
              courseId: 'course_eng_01',
              score: 55,
              lastUpdated: Date.now(),
              masteryLevel: 'developing',
              attemptCount: 1,
              confidence: 'low',
            },
          },
        },
        completedLessonIds: ['lesson_eng_a1_exit_assessment'],
        completedNodeIds: ['node_eng_a1_exit'],
        completedReinforcementIds: [],
        createdAt: Date.now(),
      },
      isLoading: false,
    });
    vi.spyOn(useRoadmapStore.getState(), 'loadRoadmap').mockResolvedValue(undefined);
    useRoadmapStore.setState({
      roadmap: RouteEngine.adaptRoadmap(
        'course_eng_01',
        SEED_ROADMAP_NODES['course_eng_01'],
        {},
        ['node_eng_a1_exit'],
        [],
        { placementCefr: 'A2' },
      ),
      isLoading: false,
      error: null,
    });

    render(
      <KnowledgeMapView
        onProceedToRoadmap={() => undefined}
        onStartPlacement={() => undefined}
        onChooseCourse={() => undefined}
      />,
    );
    expect(screen.getByText(/Baholash aniqligi: Dastlabki/i)).toBeInTheDocument();

    // Render PlacementTestView with reassessment result (assessed Pre-A1 vs preserved A2 floor)
    vi.spyOn(usePlacementStore.getState(), 'initPlacement').mockResolvedValue(undefined);
    vi.spyOn(usePlacementStore.getState(), 'resetPlacement').mockImplementation(() => undefined);
    usePlacementStore.setState({
      isLoading: false,
      isSubmitting: false,
      hasFinished: true,
      canRetake: false,
      error: null,
      submissions: allWrong,
      assessmentResult: {
        assessmentId: 'plc_floor_ui',
        courseId: 'course_eng_01',
        submissions: allWrong,
        computedScores: {},
        overallScore: 0,
        weakestSkillId: 'skill_eng_vocab',
        placementCefr: 'A2',
        assessedCefr: 'Pre-A1',
        unlockedCefrFloor: 'A2',
        timestamp: Date.now(),
      },
    });

    render(
      <PlacementTestView
        onComplete={() => undefined}
        onChooseCourse={() => undefined}
        onStartLearning={() => undefined}
      />,
    );
    expect(screen.getByText(/Joriy sinov natijasi: Pre-A1/i)).toBeInTheDocument();
    expect(screen.getByText(/A2 bosqichi ochiq saqlanadi/i)).toBeInTheDocument();
  });
});
