import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/domain/personalization/route_engine.dart';
import 'package:bilimyol_mobile/domain/entities/learning_path_node.dart';
import 'package:bilimyol_mobile/domain/entities/skill_score.dart';
import 'package:bilimyol_mobile/data/datasources/roadmaps_data.dart';

void main() {
  group('RouteEngine Tests', () {
    test('adapts learning path and injects reinforcement node for score < 50', () {
      final baseNodes = seedRoadmapNodes['course_math_01']!;
      final skillScores = {
        'skill_math_algebra': const SkillScore(
          skillId: 'skill_math_algebra',
          courseId: 'course_math_01',
          score: 82,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.proficient,
        ),
        'skill_math_equations': const SkillScore(
          skillId: 'skill_math_equations',
          courseId: 'course_math_01',
          score: 74,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.proficient,
        ),
        'skill_math_functions': const SkillScore(
          skillId: 'skill_math_functions',
          courseId: 'course_math_01',
          score: 41,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.needsRemediation,
        ),
        'skill_math_graphs': const SkillScore(
          skillId: 'skill_math_graphs',
          courseId: 'course_math_01',
          score: 68,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.developing,
        ),
      };

      final roadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_math_01',
        baseNodes: baseNodes,
        skillScores: skillScores,
        completedNodeIds: ['node_math_alg', 'node_math_eq'],
        completedReinforcementIds: [],
      );

      // Functions node must be in reinforcement
      final funcNode = roadmap.nodes.firstWhere((n) => n.id == 'node_math_func');
      expect(funcNode.status, equals(NodeStatus.reinforcement));

      // Dynamic reinforcement node must be injected
      final reinfNode = roadmap.nodes.firstWhere((n) => n.id == 'reinf_node_math_func');
      expect(reinfNode.isReinforcement, isTrue);
      expect(reinfNode.status, equals(NodeStatus.available));

      // Graphs node must be locked due to unmet functions prerequisite
      final graphNode = roadmap.nodes.firstWhere((n) => n.id == 'node_math_graphs');
      expect(graphNode.status, equals(NodeStatus.locked));
    });

    test('unlocks downstream node when prerequisite and reinforcement are completed', () {
      final baseNodes = seedRoadmapNodes['course_math_01']!;
      final skillScores = {
        'skill_math_algebra': const SkillScore(
          skillId: 'skill_math_algebra',
          courseId: 'course_math_01',
          score: 82,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.proficient,
        ),
        'skill_math_equations': const SkillScore(
          skillId: 'skill_math_equations',
          courseId: 'course_math_01',
          score: 74,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.proficient,
        ),
        'skill_math_functions': const SkillScore(
          skillId: 'skill_math_functions',
          courseId: 'course_math_01',
          score: 63, // Upgraded after reinforcement
          lastUpdated: 2000,
          masteryLevel: MasteryLevel.developing,
        ),
        'skill_math_graphs': const SkillScore(
          skillId: 'skill_math_graphs',
          courseId: 'course_math_01',
          score: 68,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.developing,
        ),
      };

      final roadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_math_01',
        baseNodes: baseNodes,
        skillScores: skillScores,
        completedNodeIds: ['node_math_alg', 'node_math_eq', 'node_math_func'],
        completedReinforcementIds: ['reinf_node_math_func'],
      );

      final funcNode = roadmap.nodes.firstWhere((n) => n.id == 'node_math_func');
      expect(funcNode.status, equals(NodeStatus.completed));

      final graphNode = roadmap.nodes.firstWhere((n) => n.id == 'node_math_graphs');
      expect(graphNode.status, equals(NodeStatus.available));
    });
  });
}
