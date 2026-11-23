import { renderToStaticMarkup } from 'react-dom/server';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Course } from '@/domain/entities/Course';
import type { LearnerProfile } from '@/domain/entities/LearnerProfile';
import type { LearningPath } from '@/domain/entities/LearningPathNode';
import type { Skill } from '@/domain/entities/Skill';
import type { SkillScore } from '@/domain/entities/SkillScore';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { usePreferences } from '@/core/preferences/preferences';
import { setDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { resolveNextLearningLesson } from '@/app/router/lessonResolution';
import { KnowledgeMapView } from '@/features/knowledge-map/KnowledgeMapView';

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

vi.mock('@/core/config/supabase', () => ({
  isSupabaseConfigured: true,
  supabase: {
    auth: { getUser: vi.fn() },
    from: vi.fn(),
    rpc: vi.fn(),
  },
}));

const mathCourse: Course = {
  id: 'course_math_01',
  title: 'Matematika',
  subject: 'mathematics',
  description: 'Matematika kursi',
  iconName: 'Calculator',
  primaryColor: '#4F46E5',
  secondaryColor: '#818CF8',
  primaryColorHex: '#4F46E5',
  secondaryColorHex: '#818CF8',
  skills: ['skill_math_addition', 'skill_math_multiplication'],
  lessons: ['lesson_math_starter', 'lesson_math_foundation_02'],
  totalStudentsEstimate: 1000,
  isActive: true,
};

const mathSkills: Skill[] = [
  {
    id: 'skill_math_addition',
    courseId: 'course_math_01',
    name: 'Qöşiş va ayiriş',
    code: 'MATH_ADD',
    description: 'Miqdorlarni birlaştiriş va farqni topiş.',
    order: -2,
    iconName: 'Calculator',
  },
  {
    id: 'skill_math_multiplication',
    courseId: 'course_math_01',
    name: 'Teng guruhlar',
    code: 'MATH_MUL',
    description: 'Teng miqdorlarni takror qöşiş va köpaytiriş.',
    order: -1,
    iconName: 'Calculator',
  },
];

function makePilotRoadmap(overrides?: {
  additionAnswered?: number;
  additionCorrect?: number;
  additionStatus?: 'available' | 'in_progress' | 'reinforcement' | 'completed' | 'locked';
  multiplicationStatus?: 'available' | 'locked' | 'completed';
  activeNodeId?: string;
}): LearningPath {
  const additionAnswered = overrides?.additionAnswered ?? 0;
  const additionCorrect = overrides?.additionCorrect ?? 0;
  const additionStatus = overrides?.additionStatus ?? 'available';
  const multiplicationStatus = overrides?.multiplicationStatus ?? 'locked';
  return {
    id: 'roadmap_course_math_01',
    courseId: 'course_math_01',
    title: 'Moslaşuvçan Yöl Xaritasi',
    activeNodeId: overrides?.activeNodeId ?? (additionStatus === 'locked' ? '' : 'node_math_addition'),
    updatedAt: 1700000000000,
    nodes: [
      {
        id: 'node_math_addition',
        courseId: 'course_math_01',
        skillId: 'skill_math_addition',
        title: 'Qöşiş va ayiriş',
        description: 'Birlaştiriş va ayrim qismini olib taşlaşni sonlar bilan ifodalang.',
        prerequisites: [],
        requiredScore: 80,
        status: additionStatus,
        isReinforcement: false,
        targetLessonId: 'lesson_math_starter',
        estimatedMinutes: 8,
        order: 10,
        mastery: {
          state: additionAnswered > 0 ? 'practicing' : 'not_started',
          answered: additionAnswered,
          correct: additionCorrect,
          requiredItems: 5,
          passedCheckpoints: 0,
          requiredCheckpoints: 2,
          reviewDue: additionStatus === 'reinforcement',
        },
      },
      {
        id: 'node_math_multiplication',
        courseId: 'course_math_01',
        skillId: 'skill_math_multiplication',
        title: 'Teng guruhlar va köpaytiriş',
        description: 'Teng guruhlarni takroriy qöşiş va köpaytiriş bilan ifodalang.',
        prerequisites: ['node_math_addition'],
        requiredScore: 80,
        status: multiplicationStatus,
        isReinforcement: false,
        targetLessonId: 'lesson_math_foundation_02',
        estimatedMinutes: 8,
        order: 20,
        mastery: {
          state: 'not_started',
          answered: 0,
          correct: 0,
          requiredItems: 5,
          passedCheckpoints: 0,
          requiredCheckpoints: 2,
          reviewDue: false,
        },
      },
    ],
  };
}

function makeProfile(scores: Record<string, SkillScore>): LearnerProfile {
  return {
    id: 'learner_math_pilot',
    name: 'Ali',
    firstName: 'Ali',
    lastName: 'Valiyev',
    email: 'ali@example.test',
    avatarUrl: '',
    selectedCourseId: 'course_math_01',
    goal: 'mastery',
    dailyMinutes: 15,
    initialLevel: 'intermediate',
    courseLevels: { course_math_01: 'intermediate' },
    xp: 20,
    streakDays: 1,
    lastActiveDate: '2026-11-18',
    scoresByCourse: Object.keys(scores).length ? { course_math_01: scores } : {},
    completedLessonIds: [],
    completedNodeIds: [],
    completedReinforcementIds: [],
    createdAt: 1700000000000,
  };
}

function seedStores(scores: Record<string, SkillScore>, roadmap: LearningPath) {
  useCourseStore.setState({
    courses: [mathCourse],
    activeCourse: mathCourse,
    activeCourseSkills: mathSkills,
    isLoading: false,
    error: null,
  });
  useLearnerStore.setState({
    profile: makeProfile(scores),
    isLoading: false,
  });
  useRoadmapStore.setState({
    roadmap,
    selectedNode: roadmap.nodes[0] ?? null,
    isLoading: false,
    isUpdating: false,
    error: null,
  });
}

function countOccurrences(haystack: string, needle: string): number {
  return haystack.split(needle).length - 1;
}

describe('math pilot KnowledgeMapView states (FIX B-01-WEB)', () => {
  beforeEach(() => {
    setDemoRuntimeActive(false);
    usePreferences.setState({ language: 'uz', theme: 'light' });
    vi.spyOn(useCourseStore, 'getInitialState').mockImplementation(useCourseStore.getState);
    vi.spyOn(useLearnerStore, 'getInitialState').mockImplementation(useLearnerStore.getState);
    vi.spyOn(useRoadmapStore, 'getInitialState').mockImplementation(useRoadmapStore.getState);
    vi.spyOn(usePreferences, 'getInitialState').mockImplementation(usePreferences.getState);
  });

  afterEach(() => {
    vi.restoreAllMocks();
    setDemoRuntimeActive(false);
    useCourseStore.getState().clearSession();
    useLearnerStore.getState().clearSession();
    useRoadmapStore.getState().clearSession();
  });

  it('State A: shows Diagnostikani boşlaş when diagnostics have not been started', () => {
    seedStores({}, makePilotRoadmap());
    const html = renderToStaticMarkup(
      <KnowledgeMapView
        onProceedToRoadmap={vi.fn()}
        onStartPlacement={vi.fn()}
        onChooseCourse={vi.fn()}
      />
    );

    expect(html).toContain('Diagnostikani boşlaş');
    expect(html).not.toContain('Birinçi maşqni boşlaş');
  });

  it('State B (4/4 diagnostics, answered = 0): shows diagnostic result, confirmation next step, 0% mastery, locked next topic, single start button, and no mistake text from isWeakestFocus', () => {
    const perfectScores: Record<string, SkillScore> = {
      skill_math_addition: {
        skillId: 'skill_math_addition',
        courseId: 'course_math_01',
        score: 100,
        lastUpdated: 1700000000000,
        masteryLevel: 'mastered',
        isWeakestFocus: true,
      },
      skill_math_multiplication: {
        skillId: 'skill_math_multiplication',
        courseId: 'course_math_01',
        score: 100,
        lastUpdated: 1700000000000,
        masteryLevel: 'mastered',
        isWeakestFocus: false,
      },
    };
    const roadmap = makePilotRoadmap();
    seedStores(perfectScores, roadmap);

    const html = renderToStaticMarkup(
      <KnowledgeMapView
        onProceedToRoadmap={vi.fn()}
        onStartPlacement={vi.fn()}
        onChooseCourse={vi.fn()}
      />
    );

    expect(html).not.toContain('Diagnostikani boşlaş');
    expect(countOccurrences(html, 'Birinçi maşqni boşlaş')).toBe(1);
    expect(html).toContain('aria-valuenow="0"');
    expect(html).toContain('0/5');
    expect(html).toContain('Qulflangan');
    expect(html).not.toMatch(/xato qildingiz|Bilim böşliği aniqlandi/i);
    expect(html).toMatch(/tasdiqlaş uçun tayanç maşq/i);
    expect(resolveNextLearningLesson(mathCourse, useLearnerStore.getState().profile, roadmap)).toBe(
      roadmap.nodes[0].targetLessonId
    );
  });

  it('State B (diagnostic score < 100 on any pilot skill, answered = 0): names the skill with score < 100 and shows a single start button', () => {
    const gapScores: Record<string, SkillScore> = {
      skill_math_addition: {
        skillId: 'skill_math_addition',
        courseId: 'course_math_01',
        score: 100,
        lastUpdated: 1700000000000,
        masteryLevel: 'mastered',
        isWeakestFocus: false,
      },
      skill_math_multiplication: {
        skillId: 'skill_math_multiplication',
        courseId: 'course_math_01',
        score: 50,
        lastUpdated: 1700000000000,
        masteryLevel: 'developing',
        isWeakestFocus: true,
      },
    };
    seedStores(gapScores, makePilotRoadmap());

    const html = renderToStaticMarkup(
      <KnowledgeMapView
        onProceedToRoadmap={vi.fn()}
        onStartPlacement={vi.fn()}
        onChooseCourse={vi.fn()}
      />
    );

    expect(html).not.toContain('Diagnostikani boşlaş');
    expect(countOccurrences(html, 'Birinçi maşqni boşlaş')).toBe(1);
    expect(html).toContain('Teng guruhlar');
    expect(html).toContain('50%');
  });

  it('State B (addition diagnostic score < 100, answered = 0): names addition skill and supports Russian locale', async () => {
    const { loadRussian } = await import('@/core/locales/messages');
    await loadRussian();
    const gapScores: Record<string, SkillScore> = {
      skill_math_addition: {
        skillId: 'skill_math_addition',
        courseId: 'course_math_01',
        score: 50,
        lastUpdated: 1700000000000,
        masteryLevel: 'developing',
        isWeakestFocus: true,
      },
      skill_math_multiplication: {
        skillId: 'skill_math_multiplication',
        courseId: 'course_math_01',
        score: 100,
        lastUpdated: 1700000000000,
        masteryLevel: 'mastered',
        isWeakestFocus: false,
      },
    };
    seedStores(gapScores, makePilotRoadmap());

    const uzHtml = renderToStaticMarkup(
      <KnowledgeMapView
        onProceedToRoadmap={vi.fn()}
        onStartPlacement={vi.fn()}
        onChooseCourse={vi.fn()}
        onStartLesson={vi.fn()}
      />
    );
    expect(uzHtml).toContain('Qöşiş va ayiriş');
    expect(uzHtml).toContain('50%');
    expect(countOccurrences(uzHtml, 'Birinçi maşqni boşlaş')).toBe(1);

    usePreferences.setState({ language: 'ru', theme: 'light' });
    const ruHtml = renderToStaticMarkup(
      <KnowledgeMapView
        onProceedToRoadmap={vi.fn()}
        onStartPlacement={vi.fn()}
        onChooseCourse={vi.fn()}
        onStartLesson={vi.fn()}
      />
    );
    expect(ruHtml).toContain('Результат диагностики');
    expect(ruHtml).toContain('Текущая тема');
    expect(countOccurrences(ruHtml, 'Начать первое упражнение')).toBe(1);
    expect(ruHtml).not.toContain('Начать диагностику');
  });

  it('State B with no open lesson: resolves next learning lesson to null for Ta’lim yöli fallback', () => {
    const perfectScores: Record<string, SkillScore> = {
      skill_math_addition: {
        skillId: 'skill_math_addition',
        courseId: 'course_math_01',
        score: 100,
        lastUpdated: 1700000000000,
        masteryLevel: 'mastered',
        isWeakestFocus: true,
      },
    };
    const lockedRoadmap = makePilotRoadmap({ additionStatus: 'locked', activeNodeId: '' });
    seedStores(perfectScores, lockedRoadmap);

    const html = renderToStaticMarkup(
      <KnowledgeMapView
        onProceedToRoadmap={vi.fn()}
        onStartPlacement={vi.fn()}
        onChooseCourse={vi.fn()}
        onStartLesson={vi.fn()}
      />
    );

    expect(countOccurrences(html, 'Birinçi maşqni boşlaş')).toBe(1);
    expect(resolveNextLearningLesson(mathCourse, useLearnerStore.getState().profile, lockedRoadmap)).toBeNull();
  });

  it('Post-exercise (answered > 0): shows lesson progress on the knowledge map', () => {
    const perfectScores: Record<string, SkillScore> = {
      skill_math_addition: {
        skillId: 'skill_math_addition',
        courseId: 'course_math_01',
        score: 100,
        lastUpdated: 1700000000000,
        masteryLevel: 'mastered',
        isWeakestFocus: true,
      },
    };
    seedStores(perfectScores, makePilotRoadmap({ additionAnswered: 2, additionCorrect: 2, additionStatus: 'in_progress' }));

    const html = renderToStaticMarkup(
      <KnowledgeMapView
        onProceedToRoadmap={vi.fn()}
        onStartPlacement={vi.fn()}
        onChooseCourse={vi.fn()}
      />
    );

    expect(html).not.toContain('Diagnostikani boşlaş');
    expect(html).not.toContain('Birinçi maşqni boşlaş');
    expect(html).toContain('1 · Baholangan mavzular');
    expect(html).toContain('2/5');
    expect(html).toContain('Maşqlardagi aniqlik');
    expect(html).toContain('100%');
  });
});
