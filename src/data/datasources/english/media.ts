import starterMediaJson from '../../../../content/english/starter-media.json';
import a1MediaJson from '../../../../content/english/a1-media.json';
import a2MediaJson from '../../../../content/english/a2-media.json';
import b1MediaJson from '../../../../content/english/b1-media.json';
import type {
  CanonicalAudioAsset,
  CanonicalImageAsset,
  CanonicalMediaManifest,
} from './types';

export const ENGLISH_STARTER_MEDIA = starterMediaJson as unknown as CanonicalMediaManifest;
export const ENGLISH_A1_MEDIA = a1MediaJson as unknown as CanonicalMediaManifest;
export const ENGLISH_A2_MEDIA = a2MediaJson as unknown as CanonicalMediaManifest;
export const ENGLISH_B1_MEDIA = b1MediaJson as unknown as CanonicalMediaManifest;

export const ENGLISH_ALL_AUDIO_ASSETS: CanonicalAudioAsset[] = [
  ...ENGLISH_STARTER_MEDIA.audio,
  ...ENGLISH_A1_MEDIA.audio,
  ...ENGLISH_A2_MEDIA.audio,
  ...ENGLISH_B1_MEDIA.audio,
];

export const ENGLISH_ALL_IMAGE_ASSETS: CanonicalImageAsset[] = [
  ...ENGLISH_STARTER_MEDIA.images,
  ...ENGLISH_A1_MEDIA.images,
  ...ENGLISH_A2_MEDIA.images,
  ...ENGLISH_B1_MEDIA.images,
];

export const ENGLISH_AUDIO_BY_ID: Record<string, CanonicalAudioAsset> = Object.fromEntries(
  ENGLISH_ALL_AUDIO_ASSETS.map((item) => [item.id, item]),
);

export const ENGLISH_IMAGE_BY_ID: Record<string, CanonicalImageAsset> = Object.fromEntries(
  ENGLISH_ALL_IMAGE_ASSETS.map((item) => [item.id, item]),
);
