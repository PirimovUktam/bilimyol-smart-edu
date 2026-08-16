import { DifficultyLevel } from '@/core/types/common';

export interface Question {
  id: string;
  courseId: string;
  skillId: string;
  text: string;
  contextSnippet?: string;
  options: string[];
  correctIndex: number;
  difficulty: DifficultyLevel;
  explanation: string;
  formulaLatex?: string;
  audioSimText?: string;
  audioSimSpeaker?: string;
}

export interface QuestionAnswerSubmission {
  questionId: string;
  selectedIndex: number;
  isCorrect: boolean;
  timeSpentSeconds: number;
}
