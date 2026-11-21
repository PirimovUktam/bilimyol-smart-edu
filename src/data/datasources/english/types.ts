import type { LearningPathNode } from '@/domain/entities/LearningPathNode';
import type { Lesson } from '@/domain/entities/Lesson';
import type { CefrLevelId } from '@/domain/entities/Question';

export interface CanonicalSkeletonUnit {
  id: string;
  moduleId: string;
  order: number;
  titleUz: string;
  titleRu: string;
  canDoObjectiveUz: string;
  canDoObjectiveRu: string;
  prerequisites: string[];
  plannedLessonIds: string[];
  checkpointNodeId: string;
}

export interface CanonicalSkeletonModule {
  id: string;
  cefrLevel: CefrLevelId;
  order: number;
  titleUz: string;
  titleRu: string;
  canDoObjectiveUz: string;
  canDoObjectiveRu: string;
  prerequisites: string[];
  units: CanonicalSkeletonUnit[];
  grammarScope: string[];
  vocabularyThemes: string[];
  plannedLessonIds: string[];
  checkpointNodeId?: string;
}

export interface CanonicalSkeletonLevel {
  cefrLevel: CefrLevelId;
  order: number;
  titleUz: string;
  titleRu: string;
  canDoObjectivesUz: string[];
  canDoObjectivesRu: string[];
  prerequisites: string[];
  modules: CanonicalSkeletonModule[];
  units: string[];
  grammarScope: string[];
  vocabularyThemes: string[];
  plannedLessonIds: string[];
  exitAssessmentNodeId?: string;
}

export interface CanonicalCefrSkeleton {
  schemaVersion: number;
  documentType: 'cefr_skeleton';
  courseId: string;
  preA1FoundationAlignment: {
    cefrLevel: CefrLevelId;
    titleUz: string;
    titleRu: string;
    noteUz: string;
    noteRu: string;
    foundationLessonIds: string[];
  };
  officialCefrDisclaimerUz: string;
  officialCefrDisclaimerRu: string;
  levels: CanonicalSkeletonLevel[];
}

export interface CanonicalLevelCurriculum {
  schemaVersion: number;
  documentType: 'level_curriculum';
  courseId: string;
  cefrLevel: CefrLevelId;
  starterLessonId: string;
  foundationLessonIds: string[];
  skills: string[];
  lessonsOrder: string[];
  officialCefrDisclaimerUz: string;
  officialCefrDisclaimerRu: string;
  modules: CanonicalSkeletonModule[];
  lessons: Lesson[];
  roadmapNodes: LearningPathNode[];
}

export interface CanonicalAudioAsset {
  id: string;
  lessonId: string;
  kind: 'audio';
  language: 'en';
  reviewStatus: 'approved' | 'draft';
  filename: string;
  canonicalSource: string;
  posterImage?: string;
  posterAltUz?: string;
  posterAltRu?: string;
  titleUz: string;
  titleRu: string;
  transcript: string;
  durationSeconds: number;
  usedBy?: {
    lessons?: string[];
    flashcards?: string[];
  };
}

export interface CanonicalImageAsset {
  id: string;
  lessonId: string;
  kind: 'image';
  language: 'en';
  filename: string;
  svgFilename?: string;
  canonicalSource: string;
  width: number;
  height: number;
  altUz: string;
  altRu: string;
  reviewStatus: 'approved' | 'draft';
  usedBy?: {
    lessons?: string[];
    flashcards?: string[];
  };
}

export interface CanonicalMediaManifest {
  courseId: string;
  cefrLevel?: CefrLevelId;
  language: 'en';
  reviewStatus: 'approved' | 'draft';
  webOutputDir: string;
  flutterOutputDir: string;
  audio: CanonicalAudioAsset[];
  images: CanonicalImageAsset[];
}
