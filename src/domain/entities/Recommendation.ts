export type ExplainableFactorKey =
  | 'goal'
  | 'skill_profile'
  | 'knowledge_level'
  | 'error_pattern'
  | 'learning_speed'
  | 'daily_time';

export interface ExplainableFactor {
  key: ExplainableFactorKey;
  label: string;
  value: string;
  impact: string;
}

export interface DailyMicroTask {
  id: string;
  title: string;
  minutes: number;
  type: 'lesson' | 'reinforcement' | 'diagnostic';
  targetNodeId?: string;
  reason: string;
}

export interface Recommendation {
  id: string;
  courseId: string;
  title: string;
  subtitle: string;
  targetSkillId: string;
  targetSkillName: string;
  targetNodeId: string;
  reason: string;
  suggestedMinutes: number;
  priority: 'high' | 'medium' | 'normal';
  explainableFactors?: ExplainableFactor[];
  cycleImpact?: string;
  dailyMicroTasks?: DailyMicroTask[];
}
