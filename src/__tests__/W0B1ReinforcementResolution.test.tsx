import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { deriveReinforcementNodeId } from '@/features/reinforcement/reinforcementNodeId';
import type { LearningPath } from '@/domain/entities/LearningPathNode';

describe('W0-B1: canonical reinforcement node ID resolution across Web & Live Math', () => {
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
        orderIndex: 1,
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
        orderIndex: 3,
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
        orderIndex: 7,
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

    // Disambiguates shared skill_math_algebra between node_math_expressions and node_math_alg by lessonId
    expect(
      deriveReinforcementNodeId(
        liveMathRoadmap,
        'course_math_01',
        'skill_math_algebra',
        'lesson_math_algebra_01',
      ),
    ).toBe('reinf_node_math_alg');
  });

  it('resolves mid-lesson reinforcement when score >= 50% (no isReinforcement node injected) to reinf_<baseNode.id>', () => {
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
          orderIndex: 1,
        },
      ],
    };

    expect(
      deriveReinforcementNodeId(itRoadmap, 'course_it', 'skill_it_python', 'lesson_it_python_01'),
    ).toBe('reinf_node_it_python');
  });

  it('falls back to reinf_lesson_<lessonId> when roadmap is not yet hydrated but lessonId is known', () => {
    expect(
      deriveReinforcementNodeId(
        null,
        'course_eng_01',
        'skill_eng_vocab',
        'lesson_eng_a2_u1_checkpoint',
      ),
    ).toBe('reinf_lesson_lesson_eng_a2_u1_checkpoint');
  });

  it('wires lessonId into ReinforcementModal from InteractiveLessonView and RoadmapView', () => {
    const lessonViewSrc = readFileSync(
      resolve(process.cwd(), 'src/features/lesson/InteractiveLessonView.tsx'),
      'utf-8',
    );
    const roadmapViewSrc = readFileSync(
      resolve(process.cwd(), 'src/features/roadmap/RoadmapView.tsx'),
      'utf-8',
    );
    expect(lessonViewSrc).toMatch(/<ReinforcementModal[\s\S]{0,260}lessonId=\{currentLesson\.id\}/);
    expect(roadmapViewSrc).toMatch(/<ReinforcementModal[\s\S]{0,320}lessonId=/);
  });
});
