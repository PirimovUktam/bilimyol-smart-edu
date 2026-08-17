import { LessonStep } from '../../domain/entities/Lesson';

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

export interface GenerateLessonRequest {
  courseId: string;
  skillId: string;
  topic?: string;
  level?: string;
  difficulty?: 'easy' | 'medium' | 'hard' | number;
  questionCount?: number;
  language?: string;
  learnerScore?: number;
  recentMistakes?: string[];
}

export interface GeneratedLessonResponse {
  lessonId: string;
  courseId: string;
  skillId: string;
  topic: string;
  level: string;
  difficulty: 'easy' | 'medium' | 'hard' | string;
  title: string;
  summary: string;
  objective: string;
  estimatedMinutes: number;
  steps: LessonStep[];
  questions: GeneratedQuestionResponse[];
  isAiGenerated: boolean;
  model?: string;
  isDeterministicFallback?: boolean;
}

export interface IAITutorService {
  explainMistake(request: AIExplanationRequest): Promise<AIExplanationResponse>;
  generateQuestion?(request: GenerateQuestionRequest): Promise<GeneratedQuestionResponse>;
  generateReinforcement?(request: GenerateReinforcementRequest): Promise<GeneratedQuestionResponse>;
  generateLesson?(request: GenerateLessonRequest): Promise<GeneratedLessonResponse>;
}
