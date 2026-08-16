export type SkillId = string;

export interface Skill {
  id: SkillId;
  courseId: string;
  name: string;
  code: string;
  description: string;
  order: number;
  iconName: string;
}

export interface SkillScore {
  skillId: SkillId;
  courseId: string;
  score: number; // 0 to 100
  lastUpdated: number;
  masteryLevel: 'needs_remediation' | 'developing' | 'proficient' | 'mastered';
  isWeakestFocus?: boolean;
}
