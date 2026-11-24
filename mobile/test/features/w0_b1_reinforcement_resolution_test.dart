import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/app/providers.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_course_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_learner_repository.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_lesson_repository.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/domain/usecases/get_roadmap_use_case.dart';

class _FailingRoadmapUseCase extends GetRoadmapUseCase {
  const _FailingRoadmapUseCase(super.lessonRepository, super.learnerRepository);

  @override
  Future<LearningPath> execute(String courseId) async {
    throw StateError('roadmap unavailable');
  }
}

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

    test('prefers an explicit isReinforcement node matching lessonId and never steals earlier node of same skillId', () {
      const engRoadmap = LearningPath(
        id: 'roadmap_course_eng_01',
        courseId: 'course_eng_01',
        title: 'English',
        activeNodeId: 'node_eng_a2_vocab',
        updatedAt: 0,
        nodes: [
          LearningPathNode(
            id: 'node_eng_a1_vocab',
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            title: 'A1 Vocab',
            description: '',
            prerequisites: [],
            requiredScore: 70,
            status: NodeStatus.completed,
            isReinforcement: false,
            targetLessonId: 'lesson_eng_vocab_01',
            estimatedMinutes: 10,
            order: 1,
          ),
          LearningPathNode(
            id: 'reinf_node_eng_a1_vocab',
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            title: 'Mustahkamlash: A1 Vocab',
            description: '',
            prerequisites: [],
            requiredScore: 70,
            status: NodeStatus.completed,
            isReinforcement: true,
            targetLessonId: 'lesson_eng_vocab_01',
            estimatedMinutes: 5,
            order: 1.5,
          ),
          LearningPathNode(
            id: 'node_eng_a2_vocab',
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            title: 'A2 Vocab',
            description: '',
            prerequisites: ['node_eng_a1_vocab'],
            requiredScore: 70,
            status: NodeStatus.available,
            isReinforcement: false,
            targetLessonId: 'lesson_eng_a2_m1_directions',
            estimatedMinutes: 10,
            order: 2,
          ),
        ],
      );

      expect(
        deriveCanonicalReinforcementNodeId(
          roadmap: engRoadmap,
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          lessonId: 'lesson_eng_vocab_01',
        ),
        equals('reinf_node_eng_a1_vocab'),
      );

      expect(
        deriveCanonicalReinforcementNodeId(
          roadmap: engRoadmap,
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          lessonId: 'lesson_eng_a2_m1_directions',
        ),
        equals('reinf_node_eng_a2_vocab'),
      );

      expect(
        deriveCanonicalReinforcementNodeId(
          roadmap: engRoadmap,
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          lessonId: 'lesson_eng_starter',
        ),
        equals('reinf_lesson_lesson_eng_starter'),
      );
    });

    test('does NOT misroute starter or foundation lessons to an unrelated same-skill roadmap node', () {
      const itRoadmap = LearningPath(
        id: 'roadmap_course_it',
        courseId: 'course_it',
        title: 'IT',
        activeNodeId: 'node_it_python',
        updatedAt: 0,
        nodes: [
          LearningPathNode(
            id: 'node_it_python',
            courseId: 'course_it',
            skillId: 'skill_it_python',
            title: 'Python asoslari',
            description: '',
            prerequisites: [],
            requiredScore: 70,
            status: NodeStatus.available,
            isReinforcement: false,
            targetLessonId: 'lesson_it_python_01',
            estimatedMinutes: 9,
            order: 1,
          ),
        ],
      );

      expect(
        deriveCanonicalReinforcementNodeId(
          roadmap: itRoadmap,
          courseId: 'course_it',
          skillId: 'skill_it_python',
          lessonId: 'lesson_it_starter',
        ),
        equals('reinf_lesson_lesson_it_starter'),
      );
      expect(
        deriveCanonicalReinforcementNodeId(
          roadmap: itRoadmap,
          courseId: 'course_it',
          skillId: 'skill_it_python',
          lessonId: 'lesson_it_foundation_02',
        ),
        equals('reinf_lesson_lesson_it_foundation_02'),
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

    test(
      'LessonSessionNotifier.submitReinforcement recovers cleanly when roadmapStateNotifierProvider is AsyncError',
      () async {
        final learnerRepo = InMemoryLearnerRepository();
        await learnerRepo.saveSkillScores('course_it', {
          'skill_it_python': const SkillScore(
            skillId: 'skill_it_python',
            courseId: 'course_it',
            score: 35,
            lastUpdated: 0,
            masteryLevel: MasteryLevel.needsRemediation,
          ),
        });
        final lessonRepo = InMemoryLessonRepository();
        final container = ProviderContainer(
          overrides: [
            learnerRepositoryProvider.overrideWithValue(learnerRepo),
            courseRepositoryProvider.overrideWithValue(
              InMemoryCourseRepository(),
            ),
            lessonRepositoryProvider.overrideWithValue(lessonRepo),
            getRoadmapUseCaseProvider.overrideWithValue(
              _FailingRoadmapUseCase(lessonRepo, learnerRepo),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(roadmapStateNotifierProvider.notifier)
            .loadRoadmap('course_it');
        expect(container.read(roadmapStateNotifierProvider).hasError, isTrue);

        final session = container.read(lessonSessionNotifierProvider.notifier);
        await session.startLesson('lesson_it_starter');
        expect(session.state.lesson, isNotNull);

        final result = await session.submitReinforcement(
          session.state.lesson!.reinforcementExercise.correctIndex,
        );
        expect(result, isNotNull);
        expect(result!.isCorrect, isTrue);
        expect(session.state.isSubmittingAnswer, isFalse);

        final profile = await learnerRepo.getProfile();
        expect(
          profile.completedReinforcementIds,
          contains('reinf_lesson_lesson_it_starter'),
        );
      },
    );
  });
}
