export interface AIExplanationRequest {
  courseId: string;
  skillId: string;
  questionId: string;
  questionText: string;
  selectedOption: string;
  correctOption: string;
  learnerName?: string;
}

export interface AIExplanationResponse {
  tutorName: string;
  title: string;
  explanation: string;
  remediationStep: string;
  suggestedAction: string;
  isDeterministicFallback: boolean;
}

export interface IAITutorService {
  explainMistake(request: AIExplanationRequest): Promise<AIExplanationResponse>;
}
