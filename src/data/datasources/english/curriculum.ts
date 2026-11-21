import cefrSkeletonJson from '../../../../content/english/cefr-skeleton.json';
import type { CefrLevelId } from '@/domain/entities/Question';
import type { CanonicalCefrSkeleton, CanonicalSkeletonLevel } from './types';

export const ENGLISH_CEFR_SKELETON = cefrSkeletonJson as unknown as CanonicalCefrSkeleton;

export const ENGLISH_CEFR_LEVEL_ORDER: readonly CefrLevelId[] = [
  'A1',
  'A2',
  'B1',
  'B2',
  'C1',
  'C2',
];

export const ENGLISH_CEFR_LEVELS: CanonicalSkeletonLevel[] = ENGLISH_CEFR_SKELETON.levels;

export const ENGLISH_CEFR_LEVEL_BY_ID: Partial<Record<CefrLevelId, CanonicalSkeletonLevel>> =
  Object.fromEntries(ENGLISH_CEFR_LEVELS.map((lvl) => [lvl.cefrLevel, lvl]));

export const ENGLISH_PRE_A1_ALIGNMENT = ENGLISH_CEFR_SKELETON.preA1FoundationAlignment;

export const ENGLISH_CEFR_DISCLAIMERS = {
  uz: ENGLISH_CEFR_SKELETON.officialCefrDisclaimerUz,
  ru: ENGLISH_CEFR_SKELETON.officialCefrDisclaimerRu,
};
