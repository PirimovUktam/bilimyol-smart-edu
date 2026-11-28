// @vitest-environment jsdom
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { SEED_COURSES } from '@/data/datasources/courses';
import { SEED_SKILLS } from '@/data/datasources/skills';
import { SEED_ROADMAP_NODES } from '@/data/datasources/roadmaps';
import { SEED_LESSONS } from '@/data/datasources/lessons';
import { AdaptiveCycleEngine } from '@/domain/personalization/AdaptiveCycleEngine';
import { RouteEngine } from '@/domain/personalization/RouteEngine';
import type { LearnerProfile } from '@/domain/entities/LearnerProfile';
import type { LearningPath, LearningPathNode } from '@/domain/entities/LearningPathNode';
import type { SkillScore } from '@/domain/entities/SkillScore';
import * as learningStart from '@/domain/personalization/learningStart';
import { supabaseLessonRepository } from '@/data/repositories/SupabaseLessonRepository';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { DashboardView } from '@/features/dashboard/DashboardView';
import { ProgressView } from '@/features/progress/ProgressView';
import { RoadmapView } from '@/features/roadmap/RoadmapView';
import { KnowledgeMapView } from '@/features/knowledge-map/KnowledgeMapView';

vi.mock('canvas-confetti', () => ({
  default: vi.fn(),
}));

vi.mock('@/core/context/AuthContext', () => ({
  useAuth: () => ({
    profile: null,
    user: null,
    isAuthenticated: true,
    isLoading: false,
  }),
}));

function makeScore(courseId: string, skillId: string, score: number): SkillScore {
  return {
    courseId,
    skillId,
    score,
    lastUpdated: 1700000000000,
    masteryLevel: score >= 80 ? 'mastered' : score >= 70 ? 'proficient' : score >= 50 ? 'developing' : 'needs_remediation',
  };
}

function makeProfile(overrides: Partial<LearnerProfile> = {}): LearnerProfile {
  return {
    id: 'learner_w1_b4',
    name: 'Sardor Test',
    firstName: 'Sardor',
    lastName: 'Test',
    email: 'sardor@bilimyol.uz',
    selectedCourseId: 'course_math_01',
    goal: 'mastery',
    dailyMinutes: 15,
    initialLevel: 'intermediate',
    courseLevels: {
      course_math_01: 'intermediate',
      course_eng_01: 'intermediate',
      course_it: 'intermediate',
      course_logic: 'intermediate',
    },
    xp: 40,
    streakDays: 2,
    lastActiveDate: '2026-11-28',
    scoresByCourse: {},
    placementScoreByCourse: {},
    placementCefrByCourse: {},
    placementSkillScoresByCourse: {},
    completedLessonIds: [],
    completedNodeIds: [],
    completedReinforcementIds: [],
    createdAt: 1700000000000,
    ...overrides,
  };
}

describe('W1-B4: Unified Roadmap Unlock Policy, Targeted Reinforcement & Honest 5-Step XAI', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('FIX-P1-08: Scenario C & D diagnostic >=80% unlocks downstream prerequisites without fabricating completed nodes', () => {
    const mathNodes = SEED_ROADMAP_NODES['course_math_01'];

    // Scenario C: alg=100, eq=100, func=0, graphs=0 -> alg & eq available (not completed!), func reinforcement (active), graphs locked
    const scenarioCScores: Record<string, SkillScore> = {
      skill_math_algebra: makeScore('course_math_01', 'skill_math_algebra', 100),
      skill_math_equations: makeScore('course_math_01', 'skill_math_equations', 100),
      skill_math_functions: makeScore('course_math_01', 'skill_math_functions', 0),
      skill_math_graphs: makeScore('course_math_01', 'skill_math_graphs', 0),
    };
    const scenarioC = RouteEngine.adaptRoadmap('course_math_01', mathNodes, scenarioCScores, [], []);
    const baseC = scenarioC.nodes.filter((n) => !n.isReinforcement);
    expect(baseC.filter((n) => n.status === 'completed')).toHaveLength(0);
    expect(baseC.find((n) => n.id === 'node_math_alg')?.status).toBe('available');
    expect(baseC.find((n) => n.id === 'node_math_eq')?.status).toBe('available');
    expect(baseC.find((n) => n.id === 'node_math_func')?.status).toBe('reinforcement');
    expect(baseC.find((n) => n.id === 'node_math_graphs')?.status).toBe('locked');
    expect(scenarioC.activeNodeId).toBe('node_math_func');
    expect(RouteEngine.canStartNode(baseC.find((n) => n.id === 'node_math_eq')!, [])).toBe(true);

    // Scenario D: 100% across all skills -> all 4 base nodes available, 0 completed
    const scenarioDScores: Record<string, SkillScore> = {
      skill_math_algebra: makeScore('course_math_01', 'skill_math_algebra', 100),
      skill_math_equations: makeScore('course_math_01', 'skill_math_equations', 100),
      skill_math_functions: makeScore('course_math_01', 'skill_math_functions', 100),
      skill_math_graphs: makeScore('course_math_01', 'skill_math_graphs', 100),
    };
    const scenarioD = RouteEngine.adaptRoadmap('course_math_01', mathNodes, scenarioDScores, [], []);
    const baseD = scenarioD.nodes.filter((n) => !n.isReinforcement);
    expect(baseD.filter((n) => n.status === 'completed')).toHaveLength(0);
    expect(baseD.filter((n) => n.status === 'available')).toHaveLength(4);
    expect(scenarioD.activeNodeId).toBe('node_math_alg');

    // Exam-prep goal on 100% diagnostic targets culminating node instead of lesson 1
    const scenarioDExam = RouteEngine.adaptRoadmap('course_math_01', mathNodes, scenarioDScores, [], [], {
      goal: 'exam_prep',
      dailyMinutes: 30,
    });
    expect(scenarioDExam.activeNodeId).toBe('node_math_graphs');
  });

  it('FIX-P1-19: Scenario F returning learner injects reinf_node_math_alg, keeps English A2 activeNodeId, and makes canStartNode(reinf_*) true', () => {
    const mathNodes = SEED_ROADMAP_NODES['course_math_01'];
    const zeroMathScores: Record<string, SkillScore> = {
      skill_math_algebra: makeScore('course_math_01', 'skill_math_algebra', 0),
      skill_math_equations: makeScore('course_math_01', 'skill_math_equations', 0),
      skill_math_functions: makeScore('course_math_01', 'skill_math_functions', 0),
      skill_math_graphs: makeScore('course_math_01', 'skill_math_graphs', 0),
    };

    const returningMath = RouteEngine.adaptRoadmap(
      'course_math_01',
      mathNodes,
      zeroMathScores,
      ['node_math_alg'],
      [],
    );
    const reinfAlg = returningMath.nodes.find((n) => n.id === 'reinf_node_math_alg');
    expect(reinfAlg).toBeDefined();
    expect(reinfAlg?.status).toBe('available');
    expect(reinfAlg?.targetLessonId).toBe('lesson_math_algebra_01');
    expect(RouteEngine.canStartNode(reinfAlg!, [])).toBe(true);
    expect(returningMath.activeNodeId).toBe('reinf_node_math_alg');

    // Uncompleted baseNode with <50% also produces startable reinf_* when completedNodeIds is empty
    const day0Math = RouteEngine.adaptRoadmap('course_math_01', mathNodes, zeroMathScores, [], []);
    const day0ReinfAlg = day0Math.nodes.find((n) => n.id === 'reinf_node_math_alg')!;
    expect(day0ReinfAlg.status).toBe('available');
    expect(day0ReinfAlg.prerequisites).toEqual([]);
    expect(RouteEngine.canStartNode(day0ReinfAlg, [])).toBe(true);

    // Returning A2-placed English learner with <50% lesson scores keeps activeNodeId on A2 entry
    const engNodes = SEED_ROADMAP_NODES['course_eng_01'];
    const lowEngScores: Record<string, SkillScore> = {
      skill_eng_vocab: makeScore('course_eng_01', 'skill_eng_vocab', 30),
      skill_eng_grammar: makeScore('course_eng_01', 'skill_eng_grammar', 30),
      skill_eng_listening: makeScore('course_eng_01', 'skill_eng_listening', 30),
      skill_eng_reading: makeScore('course_eng_01', 'skill_eng_reading', 30),
    };
    const returningEng = RouteEngine.adaptRoadmap(
      'course_eng_01',
      engNodes,
      lowEngScores,
      ['node_eng_a1_exit'],
      [],
      { placementCefr: 'A2' },
    );
    expect(returningEng.activeNodeId).toBe('node_eng_a2_m1_directions');
  });

  it('FIX-P0-12: clicking reinf_node_eng_b1_m1_travel in RoadmapView loads lesson_eng_b1_m1_travel and completes reinf_node_eng_b1_m1_travel', async () => {
    const engCourse = SEED_COURSES.find((c) => c.id === 'course_eng_01')!;
    const engSkills = SEED_SKILLS.filter((s) => s.courseId === 'course_eng_01');
    const engNodes = SEED_ROADMAP_NODES['course_eng_01'];
    const b1BaseNode = engNodes.find((n) => n.id === 'node_eng_b1_m1_travel')!;
    const b1Lesson = SEED_LESSONS['lesson_eng_b1_m1_travel'];
    expect(b1BaseNode).toBeDefined();
    expect(b1Lesson).toBeDefined();

    const lowB1SkillScores: Record<string, SkillScore> = {
      [b1BaseNode.skillId]: makeScore('course_eng_01', b1BaseNode.skillId, 32),
    };
    const b1Roadmap = RouteEngine.adaptRoadmap(
      'course_eng_01',
      engNodes,
      lowB1SkillScores,
      [],
      [],
      { placementCefr: 'B1' },
    );
    const b1Reinf = b1Roadmap.nodes.find((n) => n.id === 'reinf_node_eng_b1_m1_travel');
    expect(b1Reinf).toBeDefined();
    expect(b1Reinf?.targetLessonId).toBe('lesson_eng_b1_m1_travel');
    expect(b1Reinf?.status).toBe('available');

    const getLessonSpy = vi
      .spyOn(supabaseLessonRepository, 'getLessonById')
      .mockImplementation(async (id: string) => SEED_LESSONS[id] ?? null);
    vi.spyOn(useRoadmapStore.getState(), 'loadRoadmap').mockResolvedValue();
    const completeSpy = vi.fn().mockResolvedValue({
      isCorrect: true,
      oldScore: 32,
      newScore: 54,
      xpAwarded: 30,
      updatedRoadmap: b1Roadmap,
    });

    useCourseStore.setState({
      courses: SEED_COURSES,
      activeCourse: engCourse,
      activeCourseSkills: engSkills,
    });
    useLearnerStore.setState({
      profile: makeProfile({
        selectedCourseId: 'course_eng_01',
        placementCefrByCourse: { course_eng_01: 'B1' },
        scoresByCourse: { course_eng_01: lowB1SkillScores },
      }),
    });
    useRoadmapStore.setState({
      roadmap: b1Roadmap,
      isLoading: false,
      isUpdating: false,
      error: null,
      completeReinforcement: completeSpy,
    });

    render(
      <RoadmapView
        onStartLesson={vi.fn()}
        onOpenKnowledgeMap={vi.fn()}
        onChooseCourse={vi.fn()}
        onConfigure={vi.fn()}
      />,
    );

    const b1ReinfItem = document.querySelector('[data-node-id="reinf_node_eng_b1_m1_travel"]') as HTMLElement | null;
    expect(b1ReinfItem).not.toBeNull();
    const startBtn = within(b1ReinfItem!).getByRole('button', { name: /Mashqni boshlash/i });
    fireEvent.click(startBtn);

    await waitFor(() => {
      expect(getLessonSpy).toHaveBeenCalledWith('lesson_eng_b1_m1_travel');
    });

    const q = b1Lesson.reinforcementExercise;
    expect(await screen.findByText(q.text)).toBeInTheDocument();

    if (q.questionType === 'text_input' || q.questionType === 'fill_blank') {
      const input = screen.getByRole('textbox');
      fireEvent.change(input, { target: { value: q.acceptedAnswers?.[0] ?? 'answer' } });
    } else {
      const optionText = q.options[q.correctIndex ?? 0];
      fireEvent.click(screen.getByText(optionText));
    }

    const dialog = screen.getByRole('dialog');
    const submitBtn = within(dialog).getByRole('button', { name: /Javobni tekshirish|Yuborish|Tasdiqlash/i });
    fireEvent.click(submitBtn);

    await waitFor(() => {
      expect(completeSpy).toHaveBeenCalledTimes(1);
    });
    expect(completeSpy.mock.calls[0][2]).toBe('reinf_node_eng_b1_m1_travel');
  });

  it('FIX-P1-01: prevents Step 4/5 inversion, reports 0% growth at 0 lessons, targets reinf_node_math_func on Scenario C, and sizes tasks by dailyMinutes', () => {
    const mathCourse = SEED_COURSES.find((c) => c.id === 'course_math_01')!;
    const mathSkills = SEED_SKILLS.filter((s) => s.courseId === 'course_math_01');
    const mathNodes = SEED_ROADMAP_NODES['course_math_01'];

    // Scenario D (100% placement, 0 lessons completed): Step 05 must be upcoming and growthDelta === 0
    const dScores: Record<string, SkillScore> = {
      skill_math_algebra: makeScore('course_math_01', 'skill_math_algebra', 100),
      skill_math_equations: makeScore('course_math_01', 'skill_math_equations', 100),
      skill_math_functions: makeScore('course_math_01', 'skill_math_functions', 100),
      skill_math_graphs: makeScore('course_math_01', 'skill_math_graphs', 100),
    };
    const dRoadmap = RouteEngine.adaptRoadmap('course_math_01', mathNodes, dScores, [], []);
    const dProfile = makeProfile({
      initialLevel: 'intermediate',
      scoresByCourse: { course_math_01: dScores },
      placementScoreByCourse: { course_math_01: 100 },
      placementSkillScoresByCourse: { course_math_01: dScores },
      completedLessonIds: [],
      completedNodeIds: [],
      completedReinforcementIds: [],
    });

    const dCycle = AdaptiveCycleEngine.evaluateCycle({
      course: mathCourse,
      profile: dProfile,
      skills: mathSkills,
      skillScores: dScores,
      roadmap: dRoadmap,
    });
    expect(dCycle.steps[3].status).toBe('upcoming');
    expect(dCycle.steps[4].status).toBe('upcoming');

    const dMetrics = AdaptiveCycleEngine.measureEffectiveness({
      course: mathCourse,
      profile: dProfile,
      skills: mathSkills,
      skillScores: dScores,
      roadmap: dRoadmap,
    });
    expect(dMetrics.baselineScore).toBe(100);
    expect(dMetrics.currentScore).toBe(100);
    expect(dMetrics.growthDelta).toBe(0);

    // Unassessed learner without placement baseline shows hasDiagnosticBaseline === false and 0% delta
    const noPlcMetrics = AdaptiveCycleEngine.measureEffectiveness({
      course: mathCourse,
      profile: makeProfile({
        scoresByCourse: { course_math_01: dScores },
        completedLessonIds: ['lesson_math_algebra_01'],
      }),
      skills: mathSkills,
      skillScores: dScores,
      roadmap: dRoadmap,
    });
    expect(noPlcMetrics.hasDiagnosticBaseline).toBe(false);
    expect(noPlcMetrics.growthDelta).toBe(0);

    // Scenario C: alg=100, eq=100, func=0, graphs=50 -> micro_reinf targets reinf_node_math_func
    const cScores: Record<string, SkillScore> = {
      skill_math_algebra: makeScore('course_math_01', 'skill_math_algebra', 100),
      skill_math_equations: makeScore('course_math_01', 'skill_math_equations', 100),
      skill_math_functions: makeScore('course_math_01', 'skill_math_functions', 0),
      skill_math_graphs: makeScore('course_math_01', 'skill_math_graphs', 50),
    };
    const cRoadmap = RouteEngine.adaptRoadmap('course_math_01', mathNodes, cScores, [], []);
    const cTasks15Min = AdaptiveCycleEngine.buildDailyMicroTasks({
      course: mathCourse,
      profile: makeProfile({ dailyMinutes: 15 }),
      skills: mathSkills,
      skillScores: cScores,
      roadmap: cRoadmap,
    });
    const cTasks30Min = AdaptiveCycleEngine.buildDailyMicroTasks({
      course: mathCourse,
      profile: makeProfile({ dailyMinutes: 30 }),
      skills: mathSkills,
      skillScores: cScores,
      roadmap: cRoadmap,
    });
    expect(cTasks30Min[0].id).toBe('micro_reinf');
    expect(cTasks30Min[0].targetNodeId).toBe('reinf_node_math_func');
    expect(cTasks15Min.length).toBe(2);
    expect(cTasks30Min.length).toBe(3);
  });

  it('FIX-P0-03: renders 5-Step Adaptive Cycle & Effectiveness on Live Math Pilot across Dashboard, Roadmap, Progress, and KnowledgeMap', async () => {
    vi.spyOn(learningStart, 'usesMathMastery').mockReturnValue(true);
    vi.spyOn(supabaseLearnerRepository, 'getDailyActivity').mockResolvedValue([]);
    vi.spyOn(useRoadmapStore.getState(), 'loadRoadmap').mockResolvedValue();

    const mathCourse = SEED_COURSES.find((c) => c.id === 'course_math_01')!;
    const mathSkills = SEED_SKILLS.filter((s) => s.courseId === 'course_math_01');
    const pilotNodes: LearningPathNode[] = [
      {
        id: 'node_math_addition',
        courseId: 'course_math_01',
        skillId: 'skill_math_addition',
        title: 'Qo‘shish va ayirish',
        description: 'Tayanch arifmetika',
        prerequisites: [],
        requiredScore: 80,
        status: 'completed',
        isReinforcement: false,
        targetLessonId: 'lesson_math_starter',
        estimatedMinutes: 8,
        order: 10,
        mastery: {
          state: 'mastered',
          answered: 5,
          correct: 5,
          requiredItems: 5,
          passedCheckpoints: 2,
          requiredCheckpoints: 2,
          reviewDue: false,
        },
      },
      {
        id: 'node_math_multiplication',
        courseId: 'course_math_01',
        skillId: 'skill_math_multiplication',
        title: 'Teng guruhlar va ko‘paytirish',
        description: 'Ko‘paytirish ma’nosi',
        prerequisites: ['node_math_addition'],
        requiredScore: 80,
        status: 'reinforcement',
        isReinforcement: false,
        targetLessonId: 'lesson_math_foundation_02',
        estimatedMinutes: 8,
        order: 20,
        mastery: {
          state: 'needs_review',
          answered: 3,
          correct: 1,
          requiredItems: 5,
          passedCheckpoints: 1,
          requiredCheckpoints: 2,
          reviewDue: false,
        },
      },
    ];
    const pilotRoadmap: LearningPath = RouteEngine.adaptRoadmap('course_math_01', pilotNodes, {}, [], []);
    const pilotProfile = makeProfile({
      selectedCourseId: 'course_math_01',
      completedLessonIds: ['lesson_math_starter'],
      placementScoreByCourse: { course_math_01: 50 },
      placementSkillScoresByCourse: {
        course_math_01: {
          skill_math_addition: makeScore('course_math_01', 'skill_math_addition', 50),
          skill_math_multiplication: makeScore('course_math_01', 'skill_math_multiplication', 50),
        },
      },
    });

    useCourseStore.setState({
      courses: SEED_COURSES,
      activeCourse: mathCourse,
      activeCourseSkills: mathSkills,
    });
    useLearnerStore.setState({ profile: pilotProfile });
    useRoadmapStore.setState({ roadmap: pilotRoadmap, isLoading: false, error: null });

    const { unmount: unmountDash } = render(
      <DashboardView
        onContinueLesson={vi.fn()}
        onOpenRoadmap={vi.fn()}
        onOpenCourses={vi.fn()}
        onOpenOnboarding={vi.fn()}
        onStartPlacement={vi.fn()}
        onOpenAITutor={vi.fn()}
        onOpenProgress={vi.fn()}
        onOpenProfile={vi.fn()}
        onOpenKnowledgeMap={vi.fn()}
      />,
    );
    expect(document.getElementById('adaptive-cycle-heading')).not.toBeNull();
    unmountDash();

    const { unmount: unmountRoadmap } = render(
      <RoadmapView
        onStartLesson={vi.fn()}
        onOpenKnowledgeMap={vi.fn()}
        onChooseCourse={vi.fn()}
        onConfigure={vi.fn()}
      />,
    );
    expect(document.getElementById('adaptive-cycle-heading')).not.toBeNull();
    unmountRoadmap();

    const { unmount: unmountProgress } = render(
      <ProgressView
        onContinueLesson={vi.fn()}
        onOpenRoadmap={vi.fn()}
        onOpenKnowledgeMap={vi.fn()}
      />,
    );
    expect(document.getElementById('adaptive-effectiveness-heading')).not.toBeNull();
    unmountProgress();

    const { unmount: unmountMap } = render(
      <KnowledgeMapView
        onProceedToRoadmap={vi.fn()}
        onChooseCourse={vi.fn()}
        onStartPlacement={vi.fn()}
      />,
    );
    expect(screen.getByRole('heading', { name: /Qo‘shish va ayirish/i })).toBeInTheDocument();
    expect(screen.getByText(/Bo‘shliq aniqlangan/i)).toBeInTheDocument();
    unmountMap();
  });
});
