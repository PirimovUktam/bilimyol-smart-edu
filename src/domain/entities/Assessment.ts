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
  review?: PlacementReviewAnswer[];
}

export interface PlacementReviewAnswer extends QuestionAnswerSubmission {
  questionText: string;
  selectedOption: string;
  correctOption: string;
  explanation: string;
}

export interface PlacementSession {
  id: string;
  question: Question | null;
  number: number;
  total: number;
  wasReset: boolean;
  canRetake: boolean;
  result: Omit<AssessmentResult, 'computedScores'> | null;
}
