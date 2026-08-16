import { Question } from './Question';

export type LessonStepType = 'concept' | 'formula' | 'visual_example' | 'audio_simulation' | 'interactive_question';

export interface LessonStep {
  id: string;
  stepNumber: number;
  type: LessonStepType;
  title: string;
  subtitle?: string;
  content: string;
  highlightNotes?: string[];
  formulaData?: {
    latex: string;
    description: string;
    variables: { symbol: string; meaning: string }[];
  };
  visualModelData?: {
    type: 'function_graph' | 'audio_wave';
    functionExpr?: string; // e.g. "2x + 3"
    points?: { x: number; y: number; label?: string }[];
    audioTranscript?: string;
    speakerName?: string;
  };
  interactiveQuestion?: Question;
}

export interface Lesson {
  id: string;
  courseId: string;
  skillId: string;
  title: string;
  estimatedMinutes: number;
  summary: string;
  steps: LessonStep[];
  reinforcementExercise: Question;
}
