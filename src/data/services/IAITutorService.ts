export interface AIExplanationRequest {
  courseId: string;
  skillId: string;
  questionId: string;
  questionText: string;
  selectedOption: string;
  correctOption?: string;
  learnerName?: string;
}

export interface AIExplanationResponse {
  tutorName: string;
  title: string;
  explanation: string;
  remediationStep: string;
  suggestedAction: string;
  motivation?: string;
  reinforcementNeeded?: boolean;
  isDeterministicFallback: boolean;
}

export interface GenerateQuestionRequest {
  courseId: string;
  skillId: string;
  skillName?: string;
  difficulty: 'easy' | 'medium' | 'hard';
  learnerScore?: number;
  recentMistakes?: string[];
}

export interface GeneratedQuestionResponse {
  id: string;
  courseId: string;
  skillId: string;
  text: string;
  formulaLatex?: string | null;
  options: string[];
  difficulty: 'easy' | 'medium' | 'hard';
  isAiGenerated: boolean;
  isDeterministicFallback?: boolean;
}

export interface GenerateReinforcementRequest {
  courseId: string;
  skillId: string;
  skillName?: string;
  misconceptionTitle?: string;
  previousQuestionText?: string;
}

export interface IAITutorService {
  explainMistake(request: AIExplanationRequest): Promise<AIExplanationResponse>;
  generateQuestion?(request: GenerateQuestionRequest): Promise<GeneratedQuestionResponse>;
  generateReinforcement?(request: GenerateReinforcementRequest): Promise<GeneratedQuestionResponse>;
}
