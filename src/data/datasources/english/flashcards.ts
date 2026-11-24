import type { LessonFlashcard } from '@/domain/entities/Lesson';
import {
  ENGLISH_A1_FLASHCARD_ENTRIES,
  ENGLISH_EMPTY_FLASHCARD_LESSON_IDS,
  type EnglishFlashcardEntry,
} from './flashcardCatalog';
import {
  ENGLISH_A2_FLASHCARD_ENTRIES,
  ENGLISH_B1_FLASHCARD_ENTRIES,
} from './flashcardCatalogA2B1';

export type { EnglishFlashcardEntry };
export {
  ENGLISH_A1_FLASHCARD_ENTRIES,
  ENGLISH_A2_FLASHCARD_ENTRIES,
  ENGLISH_B1_FLASHCARD_ENTRIES,
};

export const ENGLISH_A1_FLASHCARDS: LessonFlashcard[] = ENGLISH_A1_FLASHCARD_ENTRIES.map(
  (entry) => entry.card,
);

export const ENGLISH_A2_FLASHCARDS: LessonFlashcard[] = ENGLISH_A2_FLASHCARD_ENTRIES.map(
  (entry) => entry.card,
);

export const ENGLISH_B1_FLASHCARDS: LessonFlashcard[] = ENGLISH_B1_FLASHCARD_ENTRIES.map(
  (entry) => entry.card,
);

export const ENGLISH_ALL_FLASHCARD_ENTRIES: EnglishFlashcardEntry[] = [
  ...ENGLISH_A1_FLASHCARD_ENTRIES,
  ...ENGLISH_A2_FLASHCARD_ENTRIES,
  ...ENGLISH_B1_FLASHCARD_ENTRIES,
];

export const ENGLISH_ALL_FLASHCARDS: LessonFlashcard[] = ENGLISH_ALL_FLASHCARD_ENTRIES.map(
  (entry) => entry.card,
);

export const ENGLISH_FLASHCARD_BY_ID: Record<string, LessonFlashcard> = Object.fromEntries(
  ENGLISH_ALL_FLASHCARDS.map((card) => [card.id, card]),
);

const cardsByLesson: Record<string, LessonFlashcard[]> = Object.fromEntries(
  ENGLISH_EMPTY_FLASHCARD_LESSON_IDS.map((lessonId) => [lessonId, []]),
);
for (const entry of ENGLISH_ALL_FLASHCARD_ENTRIES) {
  (cardsByLesson[entry.lessonId] ??= []).push(entry.card);
}

export const ENGLISH_FLASHCARDS_BY_LESSON: Record<string, LessonFlashcard[]> = cardsByLesson;
