import { useId, useRef, useState } from 'react';
import type { SyntheticEvent } from 'react';
import { useTranslation } from '@/core/locales/useTranslation';
import type { LessonMedia } from '@/domain/entities/LessonMedia';

export function LessonMediaPlayer({ media, accountId, lessonId }: {
  media: LessonMedia; accountId?: string; lessonId: string;
}) {
  const { t } = useTranslation();
  const speedId = useId();
  const player = useRef<HTMLMediaElement>(null);
  const lastSavedBucket = useRef(-1);
  const [failed, setFailed] = useState(false);
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
    src: media.source, controls: true, preload: 'metadata' as const, 'aria-label': media.title,
    onError: () => setFailed(true),
    onLoadedMetadata: (e: SyntheticEvent<HTMLMediaElement>) => restorePosition(e.currentTarget),
    onTimeUpdate: (e: SyntheticEvent<HTMLMediaElement>) => savePosition(e.currentTarget),
    onPause: (e: SyntheticEvent<HTMLMediaElement>) => savePosition(e.currentTarget, true),
    onEnded: (e: SyntheticEvent<HTMLMediaElement>) => savePosition(e.currentTarget, true),
  };
  const seconds = Math.ceil(media.durationSeconds);
  const duration = Math.floor(seconds / 60) + ':' + String(seconds % 60).padStart(2, '0');

  return (
    <section className="space-y-3 rounded-2xl border border-hairline bg-canvas/50 p-4" aria-label={media.title}>
      <div className="flex flex-wrap justify-between gap-2">
        <h3 className="font-bold text-ink">{media.title}</h3>
        <span className="text-sm text-slatefine">{duration}</span>
      </div>
      {media.kind === 'audio' ? (
        <audio {...props} ref={(element) => { player.current = element; }} className="w-full" />
      ) : (
        <video {...props} ref={(element) => { player.current = element; }} playsInline className="w-full rounded-xl">
          <track default kind="captions" src={media.captions} srcLang={media.language} label={media.language === 'uz' ? 'O‘zbekcha' : 'Русский'} />
        </video>
      )}
      {failed ? <p role="status" className="text-sm text-slatefine">{t('lesson.mediaFailed')}</p> : (
        <div className="flex flex-wrap items-center gap-2 text-sm">
          <label htmlFor={speedId}>{t('lesson.mediaSpeed')}</label>
          <select id={speedId} defaultValue={1} className="rounded-lg border border-hairline bg-paper p-2"
            onChange={(e) => { if (player.current) player.current.playbackRate = Number(e.target.value); }}>
            {[0.75, 1, 1.25, 1.5, 2].map((speed) => <option value={speed} key={speed}>{speed}×</option>)}
          </select>
        </div>
      )}
      <details className="text-sm">
        <summary className="cursor-pointer font-semibold text-brand">{t('lesson.mediaTranscript')}</summary>
        <p lang={media.language} className="mt-2 whitespace-pre-wrap text-slatefine">{media.transcript}</p>
      </details>
    </section>
  );
}
