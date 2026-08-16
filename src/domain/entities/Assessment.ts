import { Question, QuestionAnswerSubmission } from './Question';
import { SkillScore } from './SkillScore';

export interface PlacementAssessment {
  id: string;
  courseId: string;
  title: string;
  description: string;
  questions: Question[];
}

export interface AssessmentResult {
  assessmentId: string;
  courseId: string;
  submissions: QuestionAnswerSubmission[];
  computedScores: Record<string, SkillScore>;
  weakestSkillId: string;
  timestamp: number;
}
