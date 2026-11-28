import { describe, expect, it } from 'vitest';
import {
  deriveReinforcementNodeId,
  resolveRoadmapPracticeBaseNode,
} from '@/features/reinforcement/reinforcementNodeId';
import { RouteEngine } from '@/domain/personalization/RouteEngine';
import type { LearningPath, LearningPathNode } from '@/domain/entities/LearningPathNode';

describe('W0-B1: canonical reinforcement node ID & RouteEngine roadmap resolution', () => {
  const liveMathRoadmap: LearningPath = {
    id: 'roadmap_course_math_01',
    courseId: 'course_math_01',
    title: 'Matematika',
    activeNodeId: 'node_math_addition',
    updatedAt: 0,
    nodes: [
      {
        id: 'node_math_addition',
        courseId: 'course_math_01',
        skillId: 'skill_math_addition',
        title: 'Qo‘shish va ayirish',
        description: '',
        prerequisites: [],
        requiredScore: 80,
        status: 'reinforcement',
        isReinforcement: false,
        targetLessonId: 'lesson_math_starter',
        estimatedMinutes: 10,
        order: 1,
      },
      {
        id: 'node_math_expressions',
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        title: 'Harfli ifodalar',
        description: '',
        prerequisites: ['node_math_multiplication'],
        requiredScore: 80,
        status: 'available',
        isReinforcement: false,
        targetLessonId: 'lesson_math_expressions_intro',
        estimatedMinutes: 10,
        order: 3,
      },
      {
        id: 'node_math_alg',
        courseId: 'course_math_01',
        skillId: 'skill_math_algebra',
        title: 'Kvadratni ochish',
        description: '',
        prerequisites: ['node_math_expressions'],
        requiredScore: 80,
        status: 'locked',
        isReinforcement: false,
        targetLessonId: 'lesson_math_algebra_01',
        estimatedMinutes: 10,
        order: 7,
        isOptional: true,
      },
    ],
  };

  it('resolves Live Math roadmap nodes (where isReinforcement is false) to reinf_<node_id> via lessonId', () => {
    expect(
      deriveReinforcementNodeId(
        liveMathRoadmap,
        'course_math_01',
        'skill_math_addition',
        'lesson_math_starter',
      ),
    ).toBe('reinf_node_math_addition');

    expect(
      deriveReinforcementNodeId(
        liveMathRoadmap,
        'course_math_01',
        'skill_math_algebra',
        'lesson_math_algebra_01',
      ),
    ).toBe('reinf_node_math_alg');
  });

  it('does NOT misroute starter or foundation lessons to an unrelated same-skill roadmap node', () => {
    const itRoadmap: LearningPath = {
      id: 'roadmap_course_it',
      courseId: 'course_it',
      title: 'IT',
      activeNodeId: 'node_it_python',
      updatedAt: 0,
      nodes: [
        {
          id: 'node_it_python',
          courseId: 'course_it',
          skillId: 'skill_it_python',
          title: 'Python asoslari',
          description: '',
          prerequisites: [],
          requiredScore: 70,
          status: 'available',
          isReinforcement: false,
          targetLessonId: 'lesson_it_python_01',
          estimatedMinutes: 9,
          order: 1,
        },
      ],
    };

    expect(
      deriveReinforcementNodeId(itRoadmap, 'course_it', 'skill_it_python', 'lesson_it_python_01'),
    ).toBe('reinf_node_it_python');

    expect(
      deriveReinforcementNodeId(itRoadmap, 'course_it', 'skill_it_python', 'lesson_it_starter'),
    ).toBe('reinf_lesson_lesson_it_starter');
    expect(
      deriveReinforcementNodeId(itRoadmap, 'course_it', 'skill_it_python', 'lesson_it_foundation_02'),
    ).toBe('reinf_lesson_lesson_it_foundation_02');
  });

  it('keeps multi-lesson shared skillId isolated from an earlier completed isReinforcement node', () => {
    const engRoadmap = RouteEngine.adaptRoadmap(
      'course_eng_01',
      [
        {
          id: 'node_eng_a1_1',
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          title: 'Greetings',
          description: '',
          prerequisites: [],
          requiredScore: 70,
          status: 'available',
          isReinforcement: false,
          targetLessonId: 'lesson_eng_vocab_01',
          estimatedMinutes: 8,
          order: 1,
        },
        {
          id: 'node_eng_a2_1',
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          title: 'Directions',
          description: '',
          prerequisites: ['node_eng_a1_1'],
          requiredScore: 70,
          status: 'available',
          isReinforcement: false,
          targetLessonId: 'lesson_eng_a2_m1_directions',
          estimatedMinutes: 8,
          order: 2,
        },
      ],
      {
        skill_eng_vocab: {
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          skillName: 'Vocabulary',
          score: 75,
          masteryLevel: 'proficient',
          attemptCount: 3,
          lastUpdated: 0,
        },
      },
      [],
      ['reinf_node_eng_a1_1'],
    );

    expect(
      deriveReinforcementNodeId(
        engRoadmap,
        'course_eng_01',
        'skill_eng_vocab',
        'lesson_eng_a2_m1_directions',
      ),
    ).toBe('reinf_node_eng_a2_1');

    expect(
      deriveReinforcementNodeId(
        engRoadmap,
        'course_eng_01',
        'skill_eng_vocab',
        'lesson_eng_starter',
      ),
    ).toBe('reinf_lesson_lesson_eng_starter');
  });

  it('disambiguates RouteEngine-synthesized reinforcement nodes even without targetLessonId (including optional nodes)', () => {
    const adaptedMath = RouteEngine.adaptRoadmap(
      'course_math_01',
      liveMathRoadmap.nodes,
      {
        skill_math_algebra: {
          courseId: 'course_math_01',
          skillId: 'skill_math_algebra',
          skillName: 'Algebra',
          score: 35,
          masteryLevel: 'needs_remediation',
          attemptCount: 2,
          lastUpdated: 0,
        },
      },
      ['node_math_addition'],
      [],
    );

    const algReinf = adaptedMath.nodes.find((n) => n.id === 'reinf_node_math_alg');
    expect(algReinf).toBeDefined();
    expect(algReinf?.targetLessonId).toBe('lesson_math_algebra_01');

    const resolvedAlg = resolveRoadmapPracticeBaseNode(adaptedMath.nodes, {
      ...algReinf!,
      targetLessonId: undefined,
    });
    expect(resolvedAlg?.id).toBe('node_math_alg');
    expect(resolvedAlg?.targetLessonId).toBe('lesson_math_algebra_01');

    const firstEngReinf = RouteEngine.adaptRoadmap(
      'course_eng_01',
      [
        {
          id: 'node_eng_1',
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          title: 'First',
          description: '',
          prerequisites: [],
          requiredScore: 70,
          status: 'available',
          isReinforcement: false,
          targetLessonId: 'lesson_eng_1',
          estimatedMinutes: 8,
          order: 1,
        },
        {
          id: 'node_eng_2',
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          title: 'Second',
          description: '',
          prerequisites: [],
          requiredScore: 70,
          status: 'available',
          isReinforcement: false,
          targetLessonId: 'lesson_eng_2',
          estimatedMinutes: 8,
          order: 2,
        },
      ] satisfies LearningPathNode[],
      {
        skill_eng_vocab: {
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          skillName: 'Vocabulary',
          score: 35,
          masteryLevel: 'needs_remediation',
          attemptCount: 2,
          lastUpdated: 0,
        },
      },
      [],
      [],
    );

    const secondReinf = firstEngReinf.nodes.find((n) => n.id === 'reinf_node_eng_2');
    expect(secondReinf).toBeDefined();
    const resolvedSecond = resolveRoadmapPracticeBaseNode(firstEngReinf.nodes, secondReinf!);
    expect(resolvedSecond?.id).toBe('node_eng_2');
    expect(resolvedSecond?.targetLessonId).toBe('lesson_eng_2');
  });

  it('falls back to reinf_lesson_<lessonId> when roadmap is not yet hydrated', () => {
    expect(
      deriveReinforcementNodeId(
        null,
        'course_eng_01',
        'skill_eng_vocab',
        'lesson_eng_a2_u1_checkpoint',
      ),
    ).toBe('reinf_lesson_lesson_eng_a2_u1_checkpoint');
  });
});
