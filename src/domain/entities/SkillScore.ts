export type SkillId = string;

export interface SkillScore {
  skillId: SkillId;
  courseId: string;
  score: number; // 0 to 100
  lastUpdated: number;
  masteryLevel: 'needs_remediation' | 'developing' | 'proficient' | 'mastered';
  isWeakestFocus?: boolean;
}
