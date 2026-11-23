export type MediaLanguage = 'en' | 'uz' | 'ru';

interface MediaBase {
  id?: string;
  title: string;
  titleUz?: string;
  titleRu?: string;
  source: string;
  language: MediaLanguage;
  reviewStatus?: 'approved';
  provenance?: string;
  attribution?: string;
}

interface TimedMediaDetails extends MediaBase {
  transcript: string;
  durationSeconds: number;
  posterImage?: string;
  posterAlt?: string;
}

export type LessonMedia =
  | (TimedMediaDetails & { kind: 'audio'; captions?: string })
  | (TimedMediaDetails & { kind: 'video'; captions: string })
  | (MediaBase & { kind: 'image'; alt: string; altRu?: string; transcript?: string; durationSeconds?: number });

const lessonAsset = /^\/lesson-media\/(?:[a-z0-9_-]+\/)*[a-z0-9_-]+\.[a-z0-9]+$/;
const audioExt = /\.(mp3|m4a|ogg|wav)$/;
const videoExt = /\.(mp4|webm)$/;
const imageExt = /\.(png|jpg|jpeg|webp|svg)$/;

export const isSafeLessonAudioSource = (value: unknown): value is string =>
  typeof value === 'string' && lessonAsset.test(value) && audioExt.test(value);

export const isSafeLessonImageSource = (value: unknown): value is string =>
  typeof value === 'string' && lessonAsset.test(value) && imageExt.test(value);

const isApprovedLanguage = (value: unknown): value is MediaLanguage =>
  value === 'en' || value === 'uz' || value === 'ru';

const isValidVtt = (value: unknown): value is string =>
  typeof value === 'string' && lessonAsset.test(value) && value.endsWith('.vtt');

export function readApprovedLessonMedia(raw: unknown): LessonMedia | undefined {
  if (!raw || typeof raw !== 'object') return undefined;
  const media = raw as Record<string, unknown>;
  if (
    media.reviewStatus !== 'approved' ||
    typeof media.title !== 'string' ||
    !media.title.trim() ||
    !isApprovedLanguage(media.language) ||
    typeof media.source !== 'string' ||
    !lessonAsset.test(media.source)
  ) {
    return undefined;
  }

  const id = typeof media.id === 'string' && media.id.trim() ? media.id.trim() : undefined;
  const titleUz = typeof media.titleUz === 'string' && media.titleUz.trim() ? media.titleUz.trim() : undefined;
  const titleRu = typeof media.titleRu === 'string' && media.titleRu.trim() ? media.titleRu.trim() : undefined;
  const provenance = typeof media.provenance === 'string' && media.provenance.trim() ? media.provenance.trim() : undefined;
  const attribution = typeof media.attribution === 'string' && media.attribution.trim() ? media.attribution.trim() : undefined;
  const base: MediaBase = {
    ...(id ? { id } : {}),
    title: media.title.trim(),
    ...(titleUz ? { titleUz } : {}),
    ...(titleRu ? { titleRu } : {}),
    source: media.source,
    language: media.language,
    reviewStatus: 'approved',
    ...(provenance ? { provenance } : {}),
    ...(attribution ? { attribution } : {}),
  };

  if (media.kind === 'image') {
    if (!imageExt.test(media.source) || typeof media.alt !== 'string' || !media.alt.trim()) {
      return undefined;
    }
    let transcript: string | undefined;
    if (media.transcript !== undefined) {
      if (typeof media.transcript !== 'string' || media.transcript.length > 16000) return undefined;
      if (media.transcript.trim()) transcript = media.transcript.trim();
    }
    const durationSeconds =
      typeof media.durationSeconds === 'number' &&
      Number.isFinite(media.durationSeconds) &&
      media.durationSeconds > 0
        ? media.durationSeconds
        : undefined;

    return {
      ...base,
      kind: 'image',
      alt: media.alt.trim(),
      ...(typeof media.altRu === 'string' && media.altRu.trim() ? { altRu: media.altRu.trim() } : {}),
      ...(transcript ? { transcript } : {}),
      ...(durationSeconds !== undefined ? { durationSeconds } : {}),
    };
  }

  if (
    typeof media.transcript !== 'string' ||
    !media.transcript.trim() ||
    media.transcript.length > 16000 ||
    typeof media.durationSeconds !== 'number' ||
    !Number.isFinite(media.durationSeconds) ||
    media.durationSeconds <= 0
  ) {
    return undefined;
  }

  let posterImage: string | undefined;
  if (media.posterImage !== undefined) {
    if (
      typeof media.posterImage !== 'string' ||
      !lessonAsset.test(media.posterImage) ||
      !imageExt.test(media.posterImage)
    ) {
      return undefined;
    }
    posterImage = media.posterImage;
  }

  const posterAlt =
    posterImage && typeof media.posterAlt === 'string' && media.posterAlt.trim()
      ? media.posterAlt.trim()
      : undefined;

  const timedDetails: TimedMediaDetails = {
    ...base,
    transcript: media.transcript,
    durationSeconds: media.durationSeconds,
    ...(posterImage ? { posterImage } : {}),
    ...(posterAlt ? { posterAlt } : {}),
  };

  if (media.kind === 'audio' && audioExt.test(media.source)) {
    if (media.captions !== undefined && !isValidVtt(media.captions)) return undefined;
    const captions = typeof media.captions === 'string' ? media.captions : undefined;
    return {
      ...timedDetails,
      kind: 'audio',
      ...(captions ? { captions } : {}),
    };
  }

  if (media.kind === 'video' && videoExt.test(media.source) && isValidVtt(media.captions)) {
    return {
      ...timedDetails,
      kind: 'video',
      captions: media.captions,
    };
  }

  return undefined;
}
