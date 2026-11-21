import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { SEED_COURSES } from '@/data/datasources/courses';
import { SEED_LESSONS } from '@/data/datasources/lessons';
import { SEED_ROADMAP_NODES } from '@/data/datasources/roadmaps';
import { STARTER_LESSONS } from '@/data/datasources/starterLessons';
import {
  ENGLISH_A1_CURRICULUM,
  ENGLISH_A1_LESSONS,
  ENGLISH_A1_QUESTIONS,
  ENGLISH_A1_ROADMAP_NODES,
} from '@/data/datasources/english/a1';
import {
  ENGLISH_A2_CURRICULUM,
  ENGLISH_A2_LESSONS,
  ENGLISH_A2_QUESTIONS,
  ENGLISH_A2_ROADMAP_NODES,
} from '@/data/datasources/english/a2';
import {
  ENGLISH_B1_CURRICULUM,
  ENGLISH_B1_LESSONS,
  ENGLISH_B1_QUESTIONS,
  ENGLISH_B1_ROADMAP_NODES,
} from '@/data/datasources/english/b1';
import {
  ENGLISH_ALL_FLASHCARDS,
  ENGLISH_ALL_LESSONS_ORDER,
  ENGLISH_ALL_QUESTIONS,
  ENGLISH_ALL_ROADMAP_NODES,
} from '@/data/datasources/english';
import { ENGLISH_CEFR_LEVELS } from '@/data/datasources/english/curriculum';
import {
  ENGLISH_A1_FLASHCARDS,
  ENGLISH_A2_FLASHCARDS,
  ENGLISH_B1_FLASHCARDS,
} from '@/data/datasources/english/flashcards';
import {
  ENGLISH_ALL_AUDIO_ASSETS,
  ENGLISH_ALL_IMAGE_ASSETS,
} from '@/data/datasources/english/media';

describe('M2.2 & M3.3 Web English Curriculum Canonical Parity', () => {
  it('wires all 33 A1+A2+B1 lessons, 31 roadmap nodes, 98 questions, and 49 flashcards from canonical JSON', () => {
    const englishCourse = SEED_COURSES.find((c) => c.id === 'course_eng_01');
    expect(englishCourse).toBeDefined();
    expect(englishCourse?.lessons).toHaveLength(33);
    expect(englishCourse?.lessons[0]).toBe('lesson_eng_listening_01');
    expect(englishCourse?.starterLessonId).toBe('lesson_eng_starter');
    expect(englishCourse?.foundationLessonIds).toEqual([
      'lesson_eng_starter',
      'lesson_eng_foundation_02',
    ]);

    expect(Object.keys(ENGLISH_A1_LESSONS)).toHaveLength(17);
    expect(ENGLISH_A1_ROADMAP_NODES).toHaveLength(15);
    expect(ENGLISH_A1_QUESTIONS).toHaveLength(42);
    expect(ENGLISH_A1_FLASHCARDS).toHaveLength(17);

    expect(Object.keys(ENGLISH_A2_LESSONS)).toHaveLength(8);
    expect(ENGLISH_A2_ROADMAP_NODES).toHaveLength(8);
    expect(ENGLISH_A2_QUESTIONS).toHaveLength(27);
    expect(ENGLISH_A2_FLASHCARDS).toHaveLength(16);

    expect(Object.keys(ENGLISH_B1_LESSONS)).toHaveLength(8);
    expect(ENGLISH_B1_ROADMAP_NODES).toHaveLength(8);
    expect(ENGLISH_B1_QUESTIONS).toHaveLength(29);
    expect(ENGLISH_B1_FLASHCARDS).toHaveLength(16);

    expect(ENGLISH_ALL_LESSONS_ORDER).toHaveLength(33);
    expect(ENGLISH_ALL_ROADMAP_NODES).toHaveLength(31);
    expect(SEED_ROADMAP_NODES['course_eng_01']).toHaveLength(31);
    expect(ENGLISH_ALL_QUESTIONS).toHaveLength(98);
    expect(ENGLISH_ALL_FLASHCARDS).toHaveLength(49);

    expect(ENGLISH_CEFR_LEVELS.map((l) => l.cefrLevel)).toEqual([
      'A1',
      'A2',
      'B1',
      'B2',
      'C1',
      'C2',
    ]);

    for (const id of ENGLISH_ALL_LESSONS_ORDER) {
      expect(SEED_LESSONS[id]).toBeDefined();
      expect(SEED_LESSONS[id].courseId).toBe('course_eng_01');
    }
    expect(STARTER_LESSONS['lesson_eng_starter'].id).toBe('lesson_eng_starter');
    expect(STARTER_LESSONS['lesson_eng_foundation_02'].id).toBe('lesson_eng_foundation_02');
  });

  it('preserves T2-F4-03 listening 03:15 AM/PM disambiguation and upgraded A1 vocab/grammar content', () => {
    const listening = SEED_LESSONS['lesson_eng_listening_01'];
    const listenQ = listening.steps.find((s) => s.interactiveQuestion)?.interactiveQuestion;
    expect(listenQ?.options).toContain('03:15 (quarter past three AM)');
    expect(listenQ?.options).toContain('15:15 (quarter past three)');
    expect(listenQ?.mistakeFeedbackByOption?.['03:15 (quarter past three AM)']?.uz).toContain(
      'in the afternoon',
    );

    const vocab = SEED_LESSONS['lesson_eng_vocab_01'];
    const vocabQ = vocab.steps.find((s) => s.interactiveQuestion)?.interactiveQuestion;
    expect(vocabQ?.options).toContain('between the chair and the shelf');
    expect(vocabQ?.options).not.toContain('Extremely important');

    const grammar = SEED_LESSONS['lesson_eng_grammar_01'];
    const grammarQ = grammar.steps.find((s) => s.interactiveQuestion)?.interactiveQuestion;
    expect(grammarQ?.options).toContain('does');
    expect(grammarQ?.options).not.toContain('will pass');
  });

  it('keeps q_eng_a1_u1_cp_main unpermuted at correctIndex 0 for E2E determinism', () => {
    const cp = SEED_LESSONS['lesson_eng_a1_u1_checkpoint'];
    const cpQ = cp.steps.find((s) => s.interactiveQuestion)?.interactiveQuestion;
    expect(cpQ?.id).toBe('q_eng_a1_u1_cp_main');
    expect(cpQ?.correctIndex).toBe(0);
  });

  it('verifies every lesson media source & poster resolves to an approved manifest asset across A1+A2+B1', () => {
    const approvedSources = new Set([
      ...ENGLISH_ALL_AUDIO_ASSETS.filter((a) => a.reviewStatus === 'approved').map(
        (a) => a.canonicalSource,
      ),
      ...ENGLISH_ALL_IMAGE_ASSETS.filter((i) => i.reviewStatus === 'approved').map(
        (i) => i.canonicalSource,
      ),
    ]);

    for (const id of ENGLISH_ALL_LESSONS_ORDER) {
      const lesson = SEED_LESSONS[id];
      for (const step of lesson.steps) {
        if (step.media) {
          expect(step.media.reviewStatus).toBe('approved');
          expect(step.media.language).toBe('en');
          expect(approvedSources.has(step.media.source)).toBe(true);
          if ('posterImage' in step.media && step.media.posterImage) {
            expect(approvedSources.has(step.media.posterImage)).toBe(true);
          }
        }
        if (step.flashcards) {
          for (const card of step.flashcards) {
            if (card.audioSrc) expect(approvedSources.has(card.audioSrc)).toBe(true);
            if (card.imageSrc) expect(approvedSources.has(card.imageSrc)).toBe(true);
          }
        }
      }
    }
  });

  it('matches canonical JSON counts against content/english/{a1,a2,b1}-curriculum.json', () => {
    const rawA1 = JSON.parse(readFileSync('content/english/a1-curriculum.json', 'utf8'));
    expect(ENGLISH_A1_CURRICULUM.lessons).toHaveLength(rawA1.lessons.length);
    expect(ENGLISH_A1_CURRICULUM.roadmapNodes).toHaveLength(rawA1.roadmapNodes.length);

    const rawA2 = JSON.parse(readFileSync('content/english/a2-curriculum.json', 'utf8'));
    expect(ENGLISH_A2_CURRICULUM.lessons).toHaveLength(rawA2.lessons.length);
    expect(ENGLISH_A2_CURRICULUM.roadmapNodes).toHaveLength(rawA2.roadmapNodes.length);

    const rawB1 = JSON.parse(readFileSync('content/english/b1-curriculum.json', 'utf8'));
    expect(ENGLISH_B1_CURRICULUM.lessons).toHaveLength(rawB1.lessons.length);
    expect(ENGLISH_B1_CURRICULUM.roadmapNodes).toHaveLength(rawB1.roadmapNodes.length);
  });
});
