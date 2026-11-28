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

    test('empty skillScores on course_eng_01 does not mark unlocked nodes as reinforcement or inject reinf_* nodes', () {
      final engNodes = seedRoadmapNodes['course_eng_01']!;
      final roadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_eng_01',
        baseNodes: engNodes,
        skillScores: const {},
        completedNodeIds: const [],
        completedReinforcementIds: const [],
      );

      expect(roadmap.nodes.any((n) => n.isReinforcement), isFalse);
      final firstNode = roadmap.nodes.firstWhere((n) => n.id == 'node_eng_a1_m1_greetings');
      expect(firstNode.status, equals(NodeStatus.available));
      expect(firstNode.score, isNull);
    });

    test('50..69 score keeps node available with needsTargetedPractice and no reinf_* node', () {
      final engNodes = seedRoadmapNodes['course_eng_01']!;
      final roadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_eng_01',
        baseNodes: engNodes,
        skillScores: const {
          'skill_eng_vocab': SkillScore(
            skillId: 'skill_eng_vocab',
            courseId: 'course_eng_01',
            score: 60,
            lastUpdated: 1000,
            masteryLevel: MasteryLevel.proficient,
          ),
        },
        completedNodeIds: const [],
        completedReinforcementIds: const [],
      );

      final firstNode = roadmap.nodes.firstWhere((n) => n.id == 'node_eng_a1_m1_greetings');
      expect(firstNode.status, equals(NodeStatus.available));
      expect(firstNode.needsTargetedPractice, isTrue);
      expect(roadmap.nodes.where((n) => n.skillId == 'skill_eng_vocab' && n.isReinforcement), isEmpty);
    });

    test('placementCefrTier A2/B1 unlocks placed entry node without marking prerequisites completed', () {
      final engNodes = seedRoadmapNodes['course_eng_01']!;
      final a2Roadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_eng_01',
        baseNodes: engNodes,
        skillScores: const {},
        completedNodeIds: const [],
        completedReinforcementIds: const [],
        placementCefrTier: 'A2',
      );
      expect(a2Roadmap.activeNodeId, equals('node_eng_a2_m1_directions'));
      final a2Entry = a2Roadmap.nodes.firstWhere((n) => n.id == 'node_eng_a2_m1_directions');
      expect(a2Entry.status, equals(NodeStatus.available));
      expect(RouteEngine.canStartNode(a2Entry, const [], placementCefrTier: 'A2'), isTrue);

      final b1Roadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_eng_01',
        baseNodes: engNodes,
        skillScores: const {},
        completedNodeIds: const [],
        completedReinforcementIds: const [],
        placementCefrTier: 'B1',
      );
      expect(b1Roadmap.activeNodeId, equals('node_eng_b1_m1_travel'));
      final b1Entry = b1Roadmap.nodes.firstWhere((n) => n.id == 'node_eng_b1_m1_travel');
      expect(b1Entry.status, equals(NodeStatus.available));
      expect(RouteEngine.canStartNode(b1Entry, const [], placementCefrTier: 'B1'), isTrue);
    });

    test('<50% on skill 1 produces actionable reinforcement node with targetLessonId while keeping downstream locked', () {
      final baseNodes = seedRoadmapNodes['course_math_01']!;
      final skillScores = {
        for (final skill in [
          'skill_math_algebra',
          'skill_math_equations',
          'skill_math_functions',
          'skill_math_graphs',
        ])
          skill: SkillScore(
            skillId: skill,
            courseId: 'course_math_01',
            score: 25,
            lastUpdated: 1000,
            masteryLevel: MasteryLevel.needsRemediation,
          ),
      };

      final roadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_math_01',
        baseNodes: baseNodes,
        skillScores: skillScores,
        completedNodeIds: [],
        completedReinforcementIds: [],
      );

      final reinfAlg = roadmap.nodes.firstWhere((n) => n.id == 'reinf_node_math_alg');
      expect(reinfAlg.status, equals(NodeStatus.available));
      expect(reinfAlg.targetLessonId, equals('lesson_math_algebra_01'));
      expect(RouteEngine.canStartNode(reinfAlg, const []), isTrue);

      final reinfEq = roadmap.nodes.firstWhere((n) => n.id == 'reinf_node_math_eq');
      expect(reinfEq.status, equals(NodeStatus.locked));
      expect(RouteEngine.canStartNode(reinfEq, const []), isFalse);
    });

    test('>=80% early diagnostic skills unlock downstream steps and advance activeNodeId', () {
      final baseNodes = seedRoadmapNodes['course_math_01']!;
      final skillScores = {
        'skill_math_algebra': const SkillScore(
          skillId: 'skill_math_algebra',
          courseId: 'course_math_01',
          score: 82,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.mastered,
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
          masteryLevel: MasteryLevel.developing,
        ),
        'skill_math_graphs': const SkillScore(
          skillId: 'skill_math_graphs',
          courseId: 'course_math_01',
          score: 68,
          lastUpdated: 1000,
          masteryLevel: MasteryLevel.proficient,
        ),
      };

      final roadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_math_01',
        baseNodes: baseNodes,
        skillScores: skillScores,
        completedNodeIds: [],
        completedReinforcementIds: [],
      );

      final algNode = roadmap.nodes.firstWhere((n) => n.id == 'node_math_alg');
      final eqNode = roadmap.nodes.firstWhere((n) => n.id == 'node_math_eq');
      expect(algNode.status, equals(NodeStatus.available));
      expect(algNode.isPlacementUnlocked, isTrue);
      expect(eqNode.status, equals(NodeStatus.available));
      expect(roadmap.activeNodeId, equals('node_math_eq'));
      expect(RouteEngine.canStartNode(eqNode, const []), isTrue);

      // English Reading node also has a playable targetLessonId when unlocked
      final engRoadmap = RouteEngine.adaptRoadmap(
        courseId: 'course_eng_01',
        baseNodes: seedRoadmapNodes['course_eng_01']!,
        skillScores: {
          'skill_eng_vocab': const SkillScore(
            skillId: 'skill_eng_vocab',
            courseId: 'course_eng_01',
            score: 90,
            lastUpdated: 1000,
            masteryLevel: MasteryLevel.mastered,
          ),
          'skill_eng_grammar': const SkillScore(
            skillId: 'skill_eng_grammar',
            courseId: 'course_eng_01',
            score: 85,
            lastUpdated: 1000,
            masteryLevel: MasteryLevel.mastered,
          ),
          'skill_eng_listening': const SkillScore(
            skillId: 'skill_eng_listening',
            courseId: 'course_eng_01',
            score: 80,
            lastUpdated: 1000,
            masteryLevel: MasteryLevel.mastered,
          ),
          'skill_eng_reading': const SkillScore(
            skillId: 'skill_eng_reading',
            courseId: 'course_eng_01',
            score: 55,
            lastUpdated: 1000,
            masteryLevel: MasteryLevel.developing,
          ),
        },
        completedNodeIds: ['node_eng_a1_u3_checkpoint'],
        completedReinforcementIds: [],
      );
      final readNode = engRoadmap.nodes.firstWhere((n) => n.id == 'node_eng_read');
      expect(readNode.status, equals(NodeStatus.available));
      expect(readNode.targetLessonId, equals('lesson_eng_reading_01'));
    });
  });
}
