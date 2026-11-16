import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { readApprovedLessonMedia } from '@/domain/entities/LessonMedia';
import { LessonMediaPlayer } from '@/features/lesson/LessonMediaPlayer';

const video = {
  kind: 'video', title: 'Qo‘shish', language: 'uz', reviewStatus: 'approved',
  transcript: 'Ikki va uchni qo‘shamiz.', durationSeconds: 40,
  source: '/lesson-media/test/addition.webm', captions: '/lesson-media/test/addition.vtt',
};

describe('reviewed lesson media', () => {
  it('requires actual source metadata and accessible video captions', () => {
    for (const invalid of [
      { ...video, reviewStatus: 'draft' },
      { ...video, source: '' },
      { ...video, source: 'https://example.invalid/addition.webm' },
      { ...video, source: '/lesson-media/../addition.webm' },
      { ...video, captions: '' },
      { ...video, transcript: '' },
    ]) expect(readApprovedLessonMedia(invalid)).toBeUndefined();
    expect(readApprovedLessonMedia({ ...video, kind: 'audio', source: '/lesson-media/test/addition.mp3' })?.kind).toBe('audio');
  });

  it('renders the approved video with native controls, captions and transcript', () => {
    const media = readApprovedLessonMedia(video);
    if (!media) throw new Error('Expected a reviewed fixture');
    const html = renderToStaticMarkup(<LessonMediaPlayer media={media} lessonId="addition" />);
    expect(html).toContain('<video');
    expect(html).toContain('<track');
    expect(html).toContain('<select');
    expect(html).toContain('Matnli bayon');
    expect(html).toContain(video.transcript);
  });
});
