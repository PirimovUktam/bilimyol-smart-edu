import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it, vi } from 'vitest';
import { readApprovedLessonMedia } from '@/domain/entities/LessonMedia';
import { mapLearnerLesson } from '@/data/repositories/SupabaseLessonRepository';
import {
  LessonMediaPlayer,
  getCaptionLabel,
  parseTranscriptTurns,
  replayMediaElement,
} from '@/features/lesson/LessonMediaPlayer';

const video = {
  kind: 'video',
  title: 'Qo‘shish',
  language: 'uz',
  reviewStatus: 'approved',
  transcript: 'Ikki va uchni qo‘shamiz.',
  durationSeconds: 40,
  source: '/lesson-media/test/addition.webm',
  captions: '/lesson-media/test/addition.vtt',
};

const englishAudio = {
  id: 'media_eng_starter_dialogue',
  kind: 'audio',
  title: 'Aziza va Ben tanishuv dialogi',
  language: 'en',
  reviewStatus: 'approved',
  transcript: "Aziza: Hi, I'm Aziza. What's your name?\nBen: I'm Ben. Nice to meet you.",
  durationSeconds: 5.907,
  source: '/lesson-media/english/a1-starter-dialogue.wav',
  posterImage: '/lesson-media/english/a1-starter-greeting.png',
  posterAlt: 'Toshkentdagi maktab oldida Aziza va Ben salomlashmoqda',
};

const englishImage = {
  id: 'media_eng_starter_greeting_img',
  kind: 'image',
  title: 'Aziza va Ben uchrashuvi',
  language: 'en',
  reviewStatus: 'approved',
  source: '/lesson-media/english/a1-starter-greeting.png',
  alt: 'Toshkentdagi maktab oldida Aziza va Ben salomlashmoqda',
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
      { ...englishAudio, language: 'fr' },
      { ...englishAudio, posterImage: 'https://example.invalid/greeting.png' },
      { ...englishAudio, posterImage: '/lesson-media/../greeting.png' },
      { ...englishImage, alt: '' },
      { ...englishImage, reviewStatus: 'draft' },
      { ...englishImage, source: '/lesson-media/english/a1-starter-dialogue.wav' },
    ]) {
      expect(readApprovedLessonMedia(invalid)).toBeUndefined();
    }

    expect(readApprovedLessonMedia({ ...video, kind: 'audio', source: '/lesson-media/test/addition.mp3' })?.kind).toBe('audio');
    const approvedAudio = readApprovedLessonMedia(englishAudio);
    expect(approvedAudio?.kind).toBe('audio');
    expect(approvedAudio?.language).toBe('en');
    if (approvedAudio?.kind === 'audio') {
      expect(approvedAudio.posterImage).toBe(englishAudio.posterImage);
      expect(approvedAudio.posterAlt).toBe(englishAudio.posterAlt);
    }

    const approvedImage = readApprovedLessonMedia(englishImage);
    expect(approvedImage?.kind).toBe('image');
    expect(approvedImage?.language).toBe('en');
    if (approvedImage?.kind === 'image') {
      expect(approvedImage.alt).toBe(englishImage.alt);
    }
  });

  it('preserves approved English and Math media in mapLearnerLesson while stripping unapproved media', () => {
    const mappedEng = mapLearnerLesson({
      id: 'lesson_eng_test',
      course_id: 'course_eng_01',
      skill_id: 'skill_eng_vocab',
      title: 'English Media Lesson',
      steps: [
        {
          id: 'step_1',
          stepNumber: 1,
          type: 'audio_simulation',
          title: 'Dialogue',
          content: 'Listen',
          media: englishAudio,
        },
        {
          id: 'step_2',
          stepNumber: 2,
          type: 'visual_example',
          title: 'Draft Image',
          content: 'Look',
          media: { ...englishImage, reviewStatus: 'draft' },
        },
        {
          id: 'step_3',
          stepNumber: 3,
          type: 'interactive_question',
          title: 'Quiz',
          content: 'Answer',
          interactiveQuestion: {
            id: 'q_eng_map_1',
            questionType: 'text_input',
            text: 'Introduce yourself as Sam.',
            options: [],
          },
        },
      ],
    });
    expect(mappedEng.steps[0].media?.source).toBe(englishAudio.source);
    expect(mappedEng.steps[0].media?.language).toBe('en');
    expect(mappedEng.steps[1].media).toBeUndefined();
    expect(mappedEng.steps[2].interactiveQuestion?.questionType).toBe('text_input');

    const mappedMath = mapLearnerLesson({
      id: 'lesson_math_test',
      course_id: 'course_math_01',
      skill_id: 'skill_math_algebra',
      title: 'Math Video Lesson',
      steps: [
        {
          id: 'step_m1',
          stepNumber: 1,
          type: 'visual_example',
          title: 'Addition',
          content: 'Watch',
          media: video,
        },
        {
          id: 'step_m2',
          stepNumber: 2,
          type: 'interactive_question',
          title: 'Quiz',
          content: 'Solve',
          interactiveQuestion: {
            id: 'q_math_map_1',
            text: '2 + 3 = ?',
            options: ['4', '5', '6'],
          },
        },
      ],
    });
    expect(mappedMath.steps[0].media?.source).toBe(video.source);
  });

  it('renders the approved video with native controls, captions, replay, and transcript', () => {
    const media = readApprovedLessonMedia(video);
    if (!media) throw new Error('Expected a reviewed fixture');
    const html = renderToStaticMarkup(<LessonMediaPlayer media={media} lessonId="addition" />);
    expect(html).toContain('<video');
    expect(html).toContain('<track');
    expect(html).toContain('label="O‘zbekcha"');
    expect(html).toContain('<select');
    expect(html).toContain('Qayta tinglash');
    expect(html).toContain('Matnli bayon');
    expect(html).toContain(video.transcript);
  });

  it('renders English video captions as English, audio with poster & speaker turns, and standalone images', () => {
    const engVideo = readApprovedLessonMedia({
      ...video,
      language: 'en',
    });
    if (!engVideo) throw new Error('Expected approved English video');
    const engVideoHtml = renderToStaticMarkup(<LessonMediaPlayer media={engVideo} lessonId="eng-vid" />);
    expect(engVideoHtml).toContain('label="English"');
    expect(engVideoHtml).toContain('srcLang="en"');

    const audio = readApprovedLessonMedia(englishAudio);
    if (!audio) throw new Error('Expected approved English audio');
    const audioHtml = renderToStaticMarkup(<LessonMediaPlayer media={audio} lessonId="lesson_eng_starter" />);
    expect(audioHtml).toContain('<audio');
    expect(audioHtml).toContain(`src="${englishAudio.posterImage}"`);
    expect(audioHtml).toContain(`alt="${englishAudio.posterAlt}"`);
    expect(audioHtml).toContain('Qayta tinglash');
    expect(audioHtml).toContain('Aziza:');
    expect(audioHtml).toContain('Ben:');

    const image = readApprovedLessonMedia(englishImage);
    if (!image) throw new Error('Expected approved English image');
    const imageHtml = renderToStaticMarkup(<LessonMediaPlayer media={image} lessonId="lesson_eng_img" />);
    expect(imageHtml).toContain(`src="${englishImage.source}"`);
    expect(imageHtml).toContain(`alt="${englishImage.alt}"`);
    expect(imageHtml).not.toContain('<audio');
    expect(imageHtml).not.toContain('<video');
    expect(imageHtml).not.toContain('<select');
    expect(imageHtml).not.toContain('Qayta tinglash');
  });

  it('provides pure helpers for caption labels, transcript turns, and media replay', () => {
    expect(getCaptionLabel('en')).toBe('English');
    expect(getCaptionLabel('uz')).toBe('O‘zbekcha');
    expect(getCaptionLabel('ru')).toBe('Русский');

    expect(parseTranscriptTurns("Aziza: Hi!\nBen: Hello!\nPlain note.")).toEqual([
      { speaker: 'Aziza', text: 'Hi!' },
      { speaker: 'Ben', text: 'Hello!' },
      { text: 'Plain note.' },
    ]);

    const play = vi.fn().mockResolvedValue(undefined);
    const fakeEl = { currentTime: 4.2, play } as unknown as HTMLMediaElement;
    replayMediaElement(fakeEl);
    expect(fakeEl.currentTime).toBe(0);
    expect(play).toHaveBeenCalledOnce();
  });

  it('sanitizes flashcard audioSrc and imageSrc in mapLearnerLesson', () => {
    const mapped = mapLearnerLesson({
      id: 'lesson_eng_fc_sanitize',
      course_id: 'course_eng_01',
      skill_id: 'skill_eng_vocab',
      title: 'Flashcard Sanitization',
      steps: [
        {
          id: 'step_fc',
          stepNumber: 1,
          type: 'flashcard',
          title: 'Cards',
          content: 'Practice',
          flashcards: [
            {
              id: 'fc_safe',
              front: "What's your name?",
              backUz: 'Ismingiz nima?',
              backRu: 'Как вас зовут?',
              example: "Hi, I'm Aziza. What's your name?",
              exampleUz: 'Salom, men Azizaman.',
              exampleRu: 'Привет, я Азиза.',
              audioSrc: '/lesson-media/english/a1-starter-whats-your-name.wav',
              imageSrc: '/lesson-media/english/a1-starter-greeting.png',
              alt: 'Aziza and Ben',
            },
            {
              id: 'fc_unsafe',
              front: 'Nice to meet you.',
              backUz: 'Tanishganimdan xursandman.',
              backRu: 'Приятно познакомиться.',
              example: "I'm Ben. Nice to meet you.",
              exampleUz: 'Men Benman.',
              exampleRu: 'Я Бен.',
              audioSrc: 'https://evil.com/steal.wav',
              imageSrc: '/lesson-media/english/../secret.png',
              alt: 'Should be stripped with unsafe imageSrc',
            },
          ],
        },
        {
          id: 'step_q',
          stepNumber: 2,
          type: 'interactive_question',
          title: 'Quiz',
          content: 'Answer',
          interactiveQuestion: {
            id: 'q_fc_sanitize',
            questionType: 'text_input',
            text: 'Introduce yourself.',
            options: [],
          },
        },
      ],
    });

    const cards = mapped.steps[0].flashcards;
    expect(cards).toHaveLength(2);
    expect(cards?.[0].audioSrc).toBe('/lesson-media/english/a1-starter-whats-your-name.wav');
    expect(cards?.[0].imageSrc).toBe('/lesson-media/english/a1-starter-greeting.png');
    expect(cards?.[0].alt).toBe('Aziza and Ben');
    expect(cards?.[1].audioSrc).toBeUndefined();
    expect(cards?.[1].imageSrc).toBeUndefined();
    expect(cards?.[1].alt).toBeUndefined();
  });
});
