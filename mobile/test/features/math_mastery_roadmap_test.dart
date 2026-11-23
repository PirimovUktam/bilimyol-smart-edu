import 'package:bilimyol_mobile/data/repositories/supabase_lesson_repository.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/personalization/route_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server mastery prevents a historical completion from opening a lesson', () {
    const foundation = LearningPathNode(
      id: 'addition',
      courseId: 'course_math_01',
      skillId: 'addition',
      title: 'Qöşiş',
      prerequisites: [],
      requiredScore: 80,
      status: NodeStatus.reinforcement,
      targetLessonId: 'foundation',
      isReinforcement: false,
      order: 10,
      estimatedMinutes: 8,
      serverMastery: true,
    );
    final multiplication = foundation.copyWith(
      id: 'multiplication',
      prerequisites: ['addition'],
      status: NodeStatus.locked,
      targetLessonId: 'next_lesson',
      order: 20,
    );
    final path = RouteEngine.adaptRoadmap(
      courseId: foundation.courseId,
      baseNodes: [foundation, multiplication],
      skillScores: {},
      completedNodeIds: ['addition', 'multiplication'],
      completedReinforcementIds: [],
    );
    expect(path.activeNodeId, foundation.id);
    expect(path.nodes.last.status, NodeStatus.locked);
    expect(RouteEngine.canStartNode(path.nodes.last, ['addition']), isFalse);
  });

  test('locked catalogue metadata does not become a playable Flutter lesson', () {
    expect(
      () => SupabaseLessonRepository.parseLearnerLesson({
        'id': 'next_lesson',
        'course_id': 'course_math_01',
        'is_locked': true,
        'steps': [],
      }),
      throwsA(isA<FormatException>().having((error) => error.message, 'message', contains('hali oçilmagan'))),
    );
  });
}
