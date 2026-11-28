import { describe, it, expect } from 'vitest';
import { AdaptiveCycleEngine } from '../domain/personalization/AdaptiveCycleEngine';
import { RecommendationEngine } from '../domain/personalization/RecommendationEngine';
import { RouteEngine } from '../domain/personalization/RouteEngine';
import { SEED_COURSES } from '../data/datasources/courses';
import { SEED_SKILLS } from '../data/datasources/skills';
import { SEED_ROADMAP_NODES } from '../data/datasources/roadmaps';
import { LearnerProfile } from '../domain/entities/LearnerProfile';
import { SkillScore } from '../domain/entities/SkillScore';

function makeProfile(overrides: Partial<LearnerProfile> = {}): LearnerProfile {
  return {
    id: 'learner_test_01',
    name: 'Test Learner',
    firstName: 'Test',
    lastName: 'Learner',
    email: 'test@bilimyol.uz',
    selectedCourseId: 'course_math_01',
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
    createdAt: 1700000000000,
    ...overrides,
  };
}

const mathCourse = SEED_COURSES.find((c) => c.id === 'course_math_01')!;
const mathSkills = SEED_SKILLS.filter((s) => s.courseId === 'course_math_01');
const mathBaseNodes = SEED_ROADMAP_NODES['course_math_01'];

describe('AdaptiveCycleEngine & 5-Step Loop', () => {
  it('evaluates cycle progression from unassessed beginner -> gap detection -> measured progress', () => {
    // 1. Unassessed beginner (no diagnostics, no course level configured)
    const beginnerProfile = makeProfile();
    const emptyRoadmap = RouteEngine.adaptRoadmap('course_math_01', mathBaseNodes, {}, [], []);
    const step1Snapshot = AdaptiveCycleEngine.evaluateCycle({
      course: mathCourse,
      profile: beginnerProfile,
      skills: mathSkills,
      skillScores: {},
      roadmap: emptyRoadmap,
    });

    expect(step1Snapshot.activeStep).toBe(1);

    // 2. Learner with a <50% gap on skill_math_functions (38%) and no completed lessons yet
    const gapScores: Record<string, SkillScore> = {
      skill_math_algebra: {
        skillId: 'skill_math_algebra',
        courseId: 'course_math_01',
        score: 82,
        lastUpdated: 1000,
        masteryLevel: 'mastered',
      },
      skill_math_equations: {
        skillId: 'skill_math_equations',
        courseId: 'course_math_01',
        score: 74,
        lastUpdated: 1000,
        masteryLevel: 'proficient',
      },
      skill_math_functions: {
        skillId: 'skill_math_functions',
        courseId: 'course_math_01',
        score: 38,
        lastUpdated: 1000,
        masteryLevel: 'needs_remediation',
        isWeakestFocus: true,
      },
      skill_math_graphs: {
        skillId: 'skill_math_graphs',
        courseId: 'course_math_01',
        score: 68,
        lastUpdated: 1000,
        masteryLevel: 'proficient',
      },
    };
    const gapRoadmap = RouteEngine.adaptRoadmap('course_math_01', mathBaseNodes, gapScores, [], []);
    const gapSnapshot = AdaptiveCycleEngine.evaluateCycle({
      course: mathCourse,
      profile: makeProfile({
        courseLevels: { course_math_01: 'intermediate' },
        scoresByCourse: { course_math_01: gapScores },
      }),
      skills: mathSkills,
      skillScores: gapScores,
      roadmap: gapRoadmap,
    });

    expect(gapSnapshot.needsReinforcement).toBe(true);
    expect(gapSnapshot.weakestSkillName).toBe('Funksiyalar');
    expect(gapSnapshot.weakSkillsCount).toBeGreaterThanOrEqual(1);

    // 3. Learner after completing reinforcement + lesson progresses to step 5
    const reinforceNode = gapRoadmap.nodes.find(
      (n) => n.isReinforcement && n.skillId === 'skill_math_functions'
    );
    const updatedScores: Record<string, SkillScore> = {
      ...gapScores,
      skill_math_functions: {
        skillId: 'skill_math_functions',
        courseId: 'course_math_01',
        score: 60,
        lastUpdated: 2000,
        masteryLevel: 'proficient',
      },
    };
    const completedReinforcements = reinforceNode ? [reinforceNode.id] : [];
    const progressedRoadmap = RouteEngine.adaptRoadmap(
      'course_math_01',
      mathBaseNodes,
      updatedScores,
      ['node_math_alg', 'node_math_eq'],
      completedReinforcements
    );
    const step5Snapshot = AdaptiveCycleEngine.evaluateCycle({
      course: mathCourse,
      profile: makeProfile({
        courseLevels: { course_math_01: 'intermediate' },
        scoresByCourse: { course_math_01: updatedScores },
        completedLessonIds: ['lesson_math_algebra_01'],
        completedNodeIds: ['node_math_alg', 'node_math_eq'],
        completedReinforcementIds: completedReinforcements,
      }),
      skills: mathSkills,
      skillScores: updatedScores,
      roadmap: progressedRoadmap,
    });

    expect(step5Snapshot.activeStep).toBe(5);
  });

  it('builds all 6 Explainable AI factors reflecting learner goal and daily time budget', () => {
    const scores: Record<string, SkillScore> = {
      skill_math_functions: {
        skillId: 'skill_math_functions',
        courseId: 'course_math_01',
        score: 42,
        lastUpdated: 1000,
        masteryLevel: 'developing',
      },
    };
    const roadmap = RouteEngine.adaptRoadmap('course_math_01', mathBaseNodes, scores, [], []);
    const profile = makeProfile({
      goal: 'exam_prep',
      dailyMinutes: 30,
      streakDays: 3,
      completedLessonIds: ['lesson_math_algebra_01'],
    });

    const factors = AdaptiveCycleEngine.buildExplainableFactors({
      course: mathCourse,
      profile,
      skills: mathSkills,
      skillScores: scores,
      roadmap,
    });

    expect(factors.map((f) => f.key)).toEqual([
      'goal',
      'skill_profile',
      'knowledge_level',
      'error_pattern',
      'learning_speed',
      'daily_time',
    ]);

    const goalFactor = factors.find((f) => f.key === 'goal')!;
    expect(goalFactor.value).toContain('Imtihon');

    const timeFactor = factors.find((f) => f.key === 'daily_time')!;
    expect(timeFactor.value).toContain('30 daqiqa');
  });

  it('populates Explainable AI factors, cycleImpact, and dailyMicroTasks in RecommendationEngine', () => {
    const scores: Record<string, SkillScore> = {
      skill_math_functions: {
        skillId: 'skill_math_functions',
        courseId: 'course_math_01',
        score: 36,
        lastUpdated: 1000,
        masteryLevel: 'needs_remediation',
      },
    };
    const roadmap = RouteEngine.adaptRoadmap('course_math_01', mathBaseNodes, scores, [], []);
    const profile = makeProfile({ goal: 'skills_boost', dailyMinutes: 30 });

    const recommendation = RecommendationEngine.generateRecommendation(
      'course_math_01',
      mathSkills,
      scores,
      roadmap,
      profile
    );

    expect(recommendation.explainableFactors).toHaveLength(6);
    expect(recommendation.cycleImpact).toBeTruthy();
    expect(recommendation.dailyMicroTasks?.length).toBeGreaterThan(0);
  });

  it('measures positive effectiveness metrics when knowledge gaps are closed after reinforcement', () => {
    const initialScores: Record<string, SkillScore> = {
      skill_math_algebra: {
        skillId: 'skill_math_algebra',
        courseId: 'course_math_01',
        score: 78,
        lastUpdated: 1000,
        masteryLevel: 'proficient',
      },
      skill_math_functions: {
        skillId: 'skill_math_functions',
        courseId: 'course_math_01',
        score: 38,
        lastUpdated: 1000,
        masteryLevel: 'needs_remediation',
      },
    };
    const initialRoadmap = RouteEngine.adaptRoadmap('course_math_01', mathBaseNodes, initialScores, [], []);
    const reinforceNode = initialRoadmap.nodes.find(
      (n) => n.isReinforcement && n.skillId === 'skill_math_functions'
    );
    expect(reinforceNode).toBeDefined();

    const postScores: Record<string, SkillScore> = {
      ...initialScores,
      skill_math_functions: {
        skillId: 'skill_math_functions',
        courseId: 'course_math_01',
        score: 60,
        lastUpdated: 2000,
        masteryLevel: 'proficient',
      },
    };
    const completedReinforcementIds = [reinforceNode!.id];
    const postRoadmap = RouteEngine.adaptRoadmap(
      'course_math_01',
      mathBaseNodes,
      postScores,
      ['node_math_alg'],
      completedReinforcementIds
    );
    // Ensure the completed reinforcement node remains represented in roadmap nodes if RouteEngine prunes it once >= 50
    const roadmapForMetrics = postRoadmap.nodes.some((n) => n.id === reinforceNode!.id)
      ? postRoadmap
      : { ...postRoadmap, nodes: [...postRoadmap.nodes, { ...reinforceNode!, status: 'completed' as const }] };

    const metrics = AdaptiveCycleEngine.measureEffectiveness({
      course: mathCourse,
      profile: makeProfile({
        initialLevel: 'beginner',
        courseLevels: { course_math_01: 'beginner' },
        placementSkillScoresByCourse: { course_math_01: initialScores },
        scoresByCourse: { course_math_01: postScores },
        completedLessonIds: ['lesson_math_algebra_01'],
        completedReinforcementIds,
      }),
      skills: mathSkills,
      skillScores: postScores,
      roadmap: roadmapForMetrics,
    });

    expect(metrics.growthDelta).toBeGreaterThan(0);
    expect(metrics.detectedGapsCount).toBeGreaterThanOrEqual(1);
    expect(metrics.closedGapsCount).toBeGreaterThanOrEqual(1);
    expect(metrics.adaptiveUpdatesCount).toBeGreaterThan(0);
  });
});
