import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';

void main() {
  group('W0-B1: deriveCanonicalReinforcementNodeId on Mobile', () {
    const liveMathRoadmap = LearningPath(
      id: 'roadmap_course_math_01',
      courseId: 'course_math_01',
      title: 'Matematika',
      activeNodeId: 'node_math_addition',
      updatedAt: 0,
      nodes: [
        LearningPathNode(
          id: 'node_math_addition',
          courseId: 'course_math_01',
          skillId: 'skill_math_addition',
          title: 'Qo‘shish va ayirish',
          description: '',
          prerequisites: [],
          requiredScore: 80,
          status: NodeStatus.reinforcement,
          isReinforcement: false,
          targetLessonId: 'lesson_math_starter',
          estimatedMinutes: 10,
          order: 1,
        ),
        LearningPathNode(
          id: 'node_math_alg',
          courseId: 'course_math_01',
          skillId: 'skill_math_algebra',
          title: 'Kvadratni ochish',
          description: '',
          prerequisites: ['node_math_expressions'],
          requiredScore: 80,
          status: NodeStatus.locked,
          isReinforcement: false,
          targetLessonId: 'lesson_math_algebra_01',
          estimatedMinutes: 10,
          order: 7,
        ),
      ],
    );

    test('resolves Live Math non-reinforcement roadmap node via targetLessonId to reinf_<node.id>', () {
      expect(
        deriveCanonicalReinforcementNodeId(
          roadmap: liveMathRoadmap,
          courseId: 'course_math_01',
          skillId: 'skill_math_addition',
          lessonId: 'lesson_math_starter',
        ),
        equals('reinf_node_math_addition'),
      );
      expect(
        deriveCanonicalReinforcementNodeId(
          roadmap: liveMathRoadmap,
          courseId: 'course_math_01',
          skillId: 'skill_math_algebra',
          lessonId: 'lesson_math_algebra_01',
        ),
        equals('reinf_node_math_alg'),
      );
    });

    test('prefers an explicit isReinforcement node when present on non-Math roadmaps', () {
      const engRoadmap = LearningPath(
        id: 'roadmap_course_eng_01',
        courseId: 'course_eng_01',
        title: 'English',
        activeNodeId: 'reinf_node_eng_list',
        updatedAt: 0,
        nodes: [
          LearningPathNode(
            id: 'node_eng_list',
            courseId: 'course_eng_01',
            skillId: 'skill_eng_listening',
            title: 'Listening',
            description: '',
            prerequisites: [],
            requiredScore: 70,
            status: NodeStatus.reinforcement,
            isReinforcement: false,
            targetLessonId: 'lesson_eng_listening_01',
            estimatedMinutes: 10,
            order: 1,
          ),
          LearningPathNode(
            id: 'reinf_node_eng_list',
            courseId: 'course_eng_01',
            skillId: 'skill_eng_listening',
            title: 'Mustahkamlash: Listening',
            description: '',
            prerequisites: [],
            requiredScore: 70,
            status: NodeStatus.available,
            isReinforcement: true,
            targetLessonId: 'lesson_eng_listening_01',
            estimatedMinutes: 5,
            order: 2,
          ),
        ],
      );

      expect(
        deriveCanonicalReinforcementNodeId(
          roadmap: engRoadmap,
          courseId: 'course_eng_01',
          skillId: 'skill_eng_listening',
          lessonId: 'lesson_eng_listening_01',
        ),
        equals('reinf_node_eng_list'),
      );
    });

    test('falls back to reinf_lesson_<lessonId> when roadmap is null instead of reinf_<course>_<skill>', () {
      expect(
        deriveCanonicalReinforcementNodeId(
          roadmap: null,
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          lessonId: 'lesson_eng_a2_u1_checkpoint',
        ),
        equals('reinf_lesson_lesson_eng_a2_u1_checkpoint'),
      );
    });
  });
}
