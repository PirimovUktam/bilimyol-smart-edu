import { CefrLevelId, Question } from './Question';
import type { LessonMedia } from './LessonMedia';

export type LessonStepType =
  | 'concept'
  | 'formula'
  | 'visual_example'
  | 'audio_simulation'
  | 'interactive_question'
  | 'flashcard';

export interface LessonFlashcard {
  id: string;
  front: string;
  backUz: string;
  backRu: string;
  ipa?: string;
  ipaAmE?: string;
  partOfSpeech?: string;
  cefrLevel?: string;
  example: string;
  exampleUz: string;
  exampleRu: string;
  audioSrc?: string;
  imageSrc?: string;
  alt?: string;
  altRu?: string;
  srsDefaults?: {
    initialBucket: number;
    intervalsDays: number[];
  };
}

export interface LessonStep {
  id: string;
  stepNumber: number;
  type: LessonStepType;
  title: string;
  titleRu?: string;
  subtitle?: string;
  subtitleRu?: string;
  content: string;
  contentRu?: string;
  highlightNotes?: string[];
  highlightNotesRu?: string[];
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
  flashcards?: LessonFlashcard[];
  interactiveQuestion?: Question;
  masteryCheckpoint?: 'application' | 'retrieval';
  media?: LessonMedia;
}

export interface Lesson {
  id: string;
  courseId: string;
  skillId: string;
  skillDomain?: string;
  communicativeFocus?: string;
  cefrLevel?: CefrLevelId;
  moduleId?: string;
  unitId?: string;
  canDoObjective?: string;
  canDoObjectiveRu?: string;
  prerequisites?: string[];
  title: string;
  titleRu?: string;
  estimatedMinutes: number;
  summary: string;
  summaryRu?: string;
  officialCefrDisclaimerUz?: string;
  officialCefrDisclaimerRu?: string;
  pedagogy17?: unknown;
  steps: LessonStep[];
  reinforcementExercise: Question;
  alternateExercise?: Question;
  requiresMastery?: boolean;
  /** Set when the lesson was produced by the live AI edge function. */
  isAiGenerated?: boolean;
  /** Set when AI failed and this is a deterministic demo fallback lesson. */
  isDeterministicFallback?: boolean;
}
