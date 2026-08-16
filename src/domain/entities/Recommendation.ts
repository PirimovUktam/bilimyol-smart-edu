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
}
