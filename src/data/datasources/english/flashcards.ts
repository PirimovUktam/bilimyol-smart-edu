import type { Lesson, LessonFlashcard } from '@/domain/entities/Lesson';
import { ENGLISH_A1_LESSONS_LIST } from './a1';
import { ENGLISH_A2_LESSONS_LIST } from './a2';
import { ENGLISH_B1_LESSONS_LIST } from './b1';

export interface EnglishFlashcardEntry {
  card: LessonFlashcard;
  lessonId: string;
  moduleId?: string;
}

const collectFlashcardEntries = (lessons: Lesson[]): EnglishFlashcardEntry[] => {
  const seen = new Set<string>();
  const entries: EnglishFlashcardEntry[] = [];
  for (const lesson of lessons) {
    for (const step of lesson.steps) {
      if (!step.flashcards) continue;
      for (const card of step.flashcards) {
        if (seen.has(card.id)) continue;
        seen.add(card.id);
        entries.push({
          card,
          lessonId: lesson.id,
          moduleId: lesson.moduleId,
        });
      }
    }
  }
  return entries;
};

export const ENGLISH_A1_FLASHCARD_ENTRIES: EnglishFlashcardEntry[] =
  collectFlashcardEntries(ENGLISH_A1_LESSONS_LIST);

export const ENGLISH_A1_FLASHCARDS: LessonFlashcard[] = ENGLISH_A1_FLASHCARD_ENTRIES.map(
  (entry) => entry.card,
);

export const ENGLISH_A2_FLASHCARD_ENTRIES: EnglishFlashcardEntry[] =
  collectFlashcardEntries(ENGLISH_A2_LESSONS_LIST);

export const ENGLISH_A2_FLASHCARDS: LessonFlashcard[] = ENGLISH_A2_FLASHCARD_ENTRIES.map(
  (entry) => entry.card,
);

export const ENGLISH_B1_FLASHCARD_ENTRIES: EnglishFlashcardEntry[] =
  collectFlashcardEntries(ENGLISH_B1_LESSONS_LIST);

export const ENGLISH_B1_FLASHCARDS: LessonFlashcard[] = ENGLISH_B1_FLASHCARD_ENTRIES.map(
  (entry) => entry.card,
);

const ENGLISH_ALL_LESSONS_FOR_CARDS: Lesson[] = [
  ...ENGLISH_A1_LESSONS_LIST,
  ...ENGLISH_A2_LESSONS_LIST,
  ...ENGLISH_B1_LESSONS_LIST,
];

export const ENGLISH_ALL_FLASHCARD_ENTRIES: EnglishFlashcardEntry[] =
  collectFlashcardEntries(ENGLISH_ALL_LESSONS_FOR_CARDS);

export const ENGLISH_ALL_FLASHCARDS: LessonFlashcard[] = ENGLISH_ALL_FLASHCARD_ENTRIES.map(
  (entry) => entry.card,
);

export const ENGLISH_FLASHCARD_BY_ID: Record<string, LessonFlashcard> = Object.fromEntries(
  ENGLISH_ALL_FLASHCARDS.map((card) => [card.id, card]),
);

export const ENGLISH_FLASHCARDS_BY_LESSON: Record<string, LessonFlashcard[]> = Object.fromEntries(
  ENGLISH_ALL_LESSONS_FOR_CARDS.map((lesson) => [
    lesson.id,
    lesson.steps.flatMap((step) => step.flashcards ?? []),
  ]),
);
