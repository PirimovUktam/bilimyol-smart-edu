interface MediaDetails {
  title: string;
  source: string;
  transcript: string;
  language: 'uz' | 'ru';
  durationSeconds: number;
}

export type LessonMedia = MediaDetails & (
  | { kind: 'audio' }
  | { kind: 'video'; captions: string }
);

const lessonAsset = /^\/lesson-media\/(?:[a-z0-9_-]+\/)*[a-z0-9_-]+\.[a-z0-9]+$/;

export function readApprovedLessonMedia(raw: unknown): LessonMedia | undefined {
  if (!raw || typeof raw !== 'object') return undefined;
  const media = raw as Record<string, unknown>;
  if (media.reviewStatus !== 'approved' || typeof media.title !== 'string' || !media.title.trim() ||
    typeof media.transcript !== 'string' || !media.transcript.trim() || media.transcript.length > 16000 ||
    (media.language !== 'uz' && media.language !== 'ru') ||
    typeof media.durationSeconds !== 'number' || !Number.isFinite(media.durationSeconds) || media.durationSeconds <= 0 ||
    typeof media.source !== 'string' || !lessonAsset.test(media.source)) return undefined;

  const details: MediaDetails = {
    title: media.title, transcript: media.transcript, language: media.language,
    durationSeconds: media.durationSeconds, source: media.source,
  };
  if (media.kind === 'audio' && /\.(mp3|m4a|ogg|wav)$/.test(media.source)) {
    return { ...details, kind: 'audio' };
  }
  if (media.kind === 'video' && /\.(mp4|webm)$/.test(media.source) &&
    typeof media.captions === 'string' && lessonAsset.test(media.captions) && media.captions.endsWith('.vtt')) {
    return { ...details, kind: 'video', captions: media.captions };
  }
}
