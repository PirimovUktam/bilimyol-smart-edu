import { useEffect, useId, useRef, useState } from 'react';
import type { SyntheticEvent } from 'react';
import { RotateCcw } from 'lucide-react';
import { useTranslation } from '@/core/locales/useTranslation';
import type { LessonMedia, MediaLanguage } from '@/domain/entities/LessonMedia';

const CAPTION_LABELS: Record<MediaLanguage, string> = {
  en: 'English',
  uz: 'O‘zbekcha',
  ru: 'Русский',
};

export function getCaptionLabel(language: MediaLanguage): string {
  return CAPTION_LABELS[language];
}

export function parseTranscriptTurns(transcript: string): Array<{ speaker?: string; text: string }> {
  const lines = transcript
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  return lines.map((line) => {
    const match = line.match(/^([A-Za-z0-9'‘’.-]+(?:\s+[A-Za-z0-9'‘’.-]+)?):\s+(.+)$/);
    if (match) {
      return { speaker: match[1], text: match[2] };
    }
    return { text: line };
  });
}

export function replayMediaElement(element: HTMLMediaElement | null): void {
  if (!element) return;
  try {
    element.currentTime = 0;
    const maybePromise = element.play?.();
    if (maybePromise && typeof maybePromise.catch === 'function') {
      maybePromise.catch(() => {});
    }
  } catch {
    /* Media playback remains controllable via native element controls. */
  }
}

export function LessonMediaPlayer({ media, accountId, lessonId }: {
  media: LessonMedia; accountId?: string; lessonId: string;
}) {
  const { t } = useTranslation();
  const speedId = useId();
  const player = useRef<HTMLMediaElement | null>(null);
  const lastSavedBucket = useRef(-1);
  const [failed, setFailed] = useState(false);
  const [imageFailed, setImageFailed] = useState(false);

  const posterSrc = media.kind === 'image' ? media.source : media.posterImage;
  const illustrationSrc = media.kind === 'image' ? media.source : media.posterImage;
  const illustrationAlt = media.kind === 'image' ? media.alt : (media.posterAlt || media.title);

  useEffect(() => {
    setFailed(false);
    setImageFailed(false);
    lastSavedBucket.current = -1;
  }, [media.source, posterSrc]);

  const key = accountId ? 'bilimyol-media:' + JSON.stringify([accountId, lessonId, media.source]) : null;

  const savePosition = (element: HTMLMediaElement, force = false) => {
    if (!key || !Number.isFinite(element.currentTime)) return;
    const bucket = Math.floor(element.currentTime / 5);
    if (!force && bucket === lastSavedBucket.current) return;
    lastSavedBucket.current = bucket;
    try { localStorage.setItem(key, String(element.ended ? 0 : element.currentTime)); } catch { /* Optional device storage. */ }
  };

  const restorePosition = (element: HTMLMediaElement) => {
    if (!key) return;
    try {
      const seconds = Number(localStorage.getItem(key));
      if (seconds > 0 && seconds < element.duration - 1) element.currentTime = seconds;
    } catch { /* Media remains playable without device storage. */ }
  };

  const props = {
    src: media.source,
    controls: true,
    preload: 'metadata' as const,
    'aria-label': media.title,
    onError: () => setFailed(true),
    onLoadedMetadata: (e: SyntheticEvent<HTMLMediaElement>) => restorePosition(e.currentTarget),
    onTimeUpdate: (e: SyntheticEvent<HTMLMediaElement>) => savePosition(e.currentTarget),
    onPause: (e: SyntheticEvent<HTMLMediaElement>) => savePosition(e.currentTarget, true),
    onEnded: (e: SyntheticEvent<HTMLMediaElement>) => savePosition(e.currentTarget, true),
  };

  const hasDuration =
    typeof media.durationSeconds === 'number' &&
    Number.isFinite(media.durationSeconds) &&
    media.durationSeconds > 0;
  const seconds = hasDuration ? Math.ceil(media.durationSeconds!) : 0;
  const duration = hasDuration
    ? Math.floor(seconds / 60) + ':' + String(seconds % 60).padStart(2, '0')
    : null;

  const turns = media.transcript?.trim() ? parseTranscriptTurns(media.transcript) : [];

  return (
    <section
      className="min-w-0 space-y-3 rounded-2xl border border-hairline bg-canvas/70 p-4"
      aria-label={media.title}
    >
      <div className="flex min-w-0 flex-wrap items-center justify-between gap-2">
        <h3 className="min-w-0 break-words font-bold text-ink">{media.title}</h3>
        {duration && <span className="font-mono text-sm text-slatefine">{duration}</span>}
      </div>

      {illustrationSrc && (
        imageFailed ? (
          <div
            role="img"
            aria-label={illustrationAlt}
            className="rounded-xl border border-hairline bg-paper p-4 text-sm text-slatefine"
          >
            {t('lesson.imageFailed')} {illustrationAlt}
          </div>
        ) : (
          <figure className="overflow-hidden rounded-xl border border-hairline bg-paper">
            <img
              src={illustrationSrc}
              alt={illustrationAlt}
              loading="lazy"
              onError={() => setImageFailed(true)}
              className="max-h-72 w-full object-cover sm:max-h-80"
            />
          </figure>
        )
      )}

      {media.kind === 'audio' && (
        <audio
          {...props}
          ref={(element) => { player.current = element; }}
          className="w-full"
        >
          {media.captions && (
            <track
              default
              kind="captions"
              src={media.captions}
              srcLang={media.language}
              label={getCaptionLabel(media.language)}
            />
          )}
        </audio>
      )}

      {media.kind === 'video' && (
        <video
          {...props}
          poster={!imageFailed && media.posterImage ? media.posterImage : undefined}
          ref={(element) => { player.current = element; }}
          playsInline
          className="w-full rounded-xl"
        >
          <track
            default
            kind="captions"
            src={media.captions}
            srcLang={media.language}
            label={getCaptionLabel(media.language)}
          />
        </video>
      )}

      {media.kind !== 'image' && (
        failed ? (
          <div
            role="status"
            className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-hairline bg-paper p-3 text-sm text-slatefine"
          >
            <span>{t('lesson.mediaFailed')}</span>
            <button
              type="button"
              onClick={() => {
                setFailed(false);
                player.current?.load?.();
              }}
              className="inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-xl border border-hairline bg-sand px-3.5 py-2 text-sm font-semibold text-ink hover:bg-muted"
            >
              <RotateCcw className="size-4 text-brand" aria-hidden="true" />
              {t('lesson.mediaRetry')}
            </button>
          </div>
        ) : (
          <div className="flex flex-wrap items-center gap-2 text-sm sm:gap-3">
            <button
              type="button"
              onClick={() => replayMediaElement(player.current)}
              className="inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-xl border border-hairline bg-paper px-3.5 py-2 text-sm font-semibold text-ink hover:bg-sand"
            >
              <RotateCcw className="size-4 text-brand" aria-hidden="true" />
              {t('lesson.mediaReplay')}
            </button>
            <div className="flex items-center gap-2">
              <label htmlFor={speedId} className="font-medium text-graphite">
                {t('lesson.mediaSpeed')}
              </label>
              <select
                id={speedId}
                defaultValue={1}
                className="min-h-11 rounded-xl border border-hairline bg-paper px-3 py-2 text-sm text-ink"
                onChange={(e) => {
                  if (player.current) player.current.playbackRate = Number(e.target.value);
                }}
              >
                {[0.75, 1, 1.25, 1.5, 2].map((speed) => (
                  <option value={speed} key={speed}>
                    {speed}×
                  </option>
                ))}
              </select>
            </div>
          </div>
        )
      )}

      {turns.length > 0 && (
        <details className="text-sm">
          <summary className="inline-flex min-h-11 cursor-pointer select-none items-center gap-2 rounded-lg px-2 py-1 text-sm font-semibold text-brand-dark hover:text-brand">
            {t('lesson.mediaTranscript')}
          </summary>
          <div lang={media.language} className="mt-2 space-y-2">
            {turns.map((turn, index) =>
              turn.speaker ? (
                <div
                  key={`${turn.speaker}-${index}`}
                  className="rounded-xl border border-hairline bg-paper px-3 py-2 text-sm"
                >
                  <span className="mr-1.5 font-bold text-ink">{turn.speaker}:</span>
                  <span className="text-graphite">{turn.text}</span>
                </div>
              ) : (
                <p key={index} className="whitespace-pre-wrap text-sm text-slatefine">
                  {turn.text}
                </p>
              )
            )}
          </div>
        </details>
      )}
    </section>
  );
}
