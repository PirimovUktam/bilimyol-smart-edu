import { describe, it, expect } from 'vitest';
import { RouteEngine } from '../domain/personalization/RouteEngine';
import { SEED_ROADMAP_NODES } from '../data/datasources/roadmaps';
import { SkillScore } from '../domain/entities/SkillScore';

describe('RouteEngine', () => {
  const mockBaseNodes = SEED_ROADMAP_NODES['course_math_01'];

  it('should mark node as reinforcement when score is below 50', () => {
    const skillScores: Record<string, SkillScore> = {
      skill_math_algebra: { skillId: 'skill_math_algebra', courseId: 'course_math_01', score: 82, lastUpdated: 0, masteryLevel: 'proficient' },
      skill_math_equations: { skillId: 'skill_math_equations', courseId: 'course_math_01', score: 74, lastUpdated: 0, masteryLevel: 'proficient' },
      skill_math_functions: { skillId: 'skill_math_functions', courseId: 'course_math_01', score: 41, lastUpdated: 0, masteryLevel: 'needs_remediation' },
      skill_math_graphs: { skillId: 'skill_math_graphs', courseId: 'course_math_01', score: 68, lastUpdated: 0, masteryLevel: 'developing' },
    };

    const completedNodeIds = ['node_math_alg', 'node_math_eq'];
    const completedReinforcementIds: string[] = [];

    const roadmap = RouteEngine.adaptRoadmap(
      'course_math_01',
      mockBaseNodes,
      skillScores,
      completedNodeIds,
      completedReinforcementIds
    );

    const funcNode = roadmap.nodes.find((n) => n.id === 'node_math_func');
    expect(funcNode).toBeDefined();
    expect(funcNode?.status).toBe('reinforcement');

    const reinfNode = roadmap.nodes.find((n) => n.id === 'reinf_node_math_func');
    expect(reinfNode).toBeDefined();
    expect(reinfNode?.isReinforcement).toBe(true);

    const graphsNode = roadmap.nodes.find((n) => n.id === 'node_math_graphs');
    expect(graphsNode?.status).toBe('locked'); // Dependent on node_math_func
  });

  it('should unlock downstream nodes when reinforcement and target node are completed', () => {
    const skillScores: Record<string, SkillScore> = {
      skill_math_algebra: { skillId: 'skill_math_algebra', courseId: 'course_math_01', score: 82, lastUpdated: 0, masteryLevel: 'proficient' },
      skill_math_equations: { skillId: 'skill_math_equations', courseId: 'course_math_01', score: 74, lastUpdated: 0, masteryLevel: 'proficient' },
      skill_math_functions: { skillId: 'skill_math_functions', courseId: 'course_math_01', score: 63, lastUpdated: 0, masteryLevel: 'developing' },
      skill_math_graphs: { skillId: 'skill_math_graphs', courseId: 'course_math_01', score: 68, lastUpdated: 0, masteryLevel: 'developing' },
    };

    const completedNodeIds = ['node_math_alg', 'node_math_eq', 'node_math_func'];
    const completedReinforcementIds = ['reinf_node_math_func'];

    const roadmap = RouteEngine.adaptRoadmap(
      'course_math_01',
      mockBaseNodes,
      skillScores,
      completedNodeIds,
      completedReinforcementIds
    );

    const funcNode = roadmap.nodes.find((n) => n.id === 'node_math_func');
    expect(funcNode?.status).toBe('completed');

    const graphsNode = roadmap.nodes.find((n) => n.id === 'node_math_graphs');
    expect(graphsNode?.status).toBe('available');
  });
});
