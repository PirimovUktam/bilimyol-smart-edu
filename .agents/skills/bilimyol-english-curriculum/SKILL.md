---
name: bilimyol-english-curriculum
description: Use when designing, authoring, or expanding CEFR levels, modules, units, lessons, grammar/vocabulary progressions, flashcards, exercises, or adaptive pathways for BilimYo‘l course_eng_01 across Web and Flutter.
---

# BilimYo‘l English Curriculum Design (`course_eng_01`)

## Overview

Build `course_eng_01` as a connected, CEFR-aligned, adaptive English learning system across Web and Flutter: **Working product > Mockup**, **Learning quality > Content quantity**, **Correct progression > Random difficulty**, **Pedagogical value > Decorative media**.

**Non-Negotiable Boundaries:**
- **Course isolation**: Never apply `course_math_01` pilot rules (`usesMathMastery`, `get_math_progression`, `can_open_math_lesson`, `q_pilot_*`, `min_checkpoints`, 7-day `review_interval`) to `course_eng_01`. Keep `course_eng_01` on `RouteEngine.adaptRoadmap`, English CEFR progression, and spaced-repetition flashcards.
- **Canonical parity**: Author lessons, flashcards, questions, and media metadata canonically under `content/english/` and sync identically to Web (`src/data/datasources/`) and Flutter (`mobile/lib/data/datasources/`).

## CEFR Hierarchy & Prerequisite Mapping

Ordered levels: `Pre-A1` (Beginner Foundation) -> `A1` (Elementary) -> `A2` (Pre-Intermediate) -> `B1` (Intermediate) -> `B2` (Upper-Intermediate) -> `C1` (Advanced, architecture-ready + modules) -> `C2` (Proficiency).

Every level requires:
1. Level `Can-Do` learning objectives -> `Modules` -> `Units` -> `Lessons` -> `Unit Assessments` -> `Level Final Assessment`.
2. Explicit `prerequisites[]` per unit and lesson. Beginners (`foundationLessonIds`: `lesson_eng_starter`, `lesson_eng_foundation_02`) never receive unintroduced B1+ grammar or vocabulary.
3. All 6 skill pillars: `skill_eng_vocab`, `skill_eng_grammar`, `skill_eng_listening`, `skill_eng_reading`, plus communicative `speaking_prompt` and `writing_prompt` tasks with sample models and self-assessment rubrics.

## 17-Part Lesson Standard (Explain -> Example -> Practice -> Feedback -> Review)

Author every full lesson as compact, mobile-first microlearning mapped into `Lesson` / `LessonStep` structures:

| # | Component | Required Output |
|---|---|---|
| 1–3 | Intro, Objective, Warm-up | Real-life situation, 1 observable Can-Do goal, prior-knowledge activation |
| 4–6 | Vocabulary, Grammar, Pronunciation | New items with UZ/RU meanings, step-by-step grammar rule, IPA + stress + `'en'` audio |
| 7–9 | Examples, Guided, Independent | Natural models, scaffolded check, unassisted task (`text_input` / structured mode) |
| 10–13 | Listening, Reading, Speaking, Writing | Real `'en'` audio + toggleable transcript, evidence-based text, communicative prompts + rubrics |
| 14–16 | Knowledge Check, Final Quiz, Feedback | Quick check, non-duplicate end quiz, specific error diagnosis explaining *why* |
| 17 | Summary & Revision | Key takeaways + spaced-repetition `flashcard` step |

**Honesty rule**: Explicitly badge `speaking_prompt` / `writing_prompt` without automated grading as self-assessment / independent practice. Never claim internal quizzes grant official CEFR certification.

## Grammar, Vocabulary & Flashcard Contracts

- **Grammar (8 parts)**: `Rule`, `Simple explanation` (active UZ/RU for Pre-A1/A1, progressively more English from A2->C2), `Structure`, `Positive examples`, `Negative examples`, `Questions`, `Common mistakes` (targeting UZ/RU L1 interference), `Contextual exercises`.
- **Vocabulary (10 parts)**: `word`, `uzMeaning`, `ruMeaning`, `partOfSpeech`, `ipa`, `audioSrc`, `example`, `exampleUz`, `exampleRu`, `imageSrc` (where concrete/helpful) + `cefrLevel`. Keep primary accent consistent; note US/UK differences only where meaningful.
- **Flashcard (`LessonFlashcard`)**: `id`, `front`, `backUz`, `backRu`, `partOfSpeech`, `ipa`, `cefrLevel`, `example`, `exampleUz`, `exampleRu`, `audioSrc`, `imageSrc`, `alt`.
  - Modes: `Tap to reveal` (`"Javobni ko‘rish"` / `"Показать ответ"`), `Remembered` (`"Eslab qoldim"`), `Need practice` (`"Yana mashq qilaman"`), `En->Uz/Ru`, `Uz/Ru->En`, `Image->Word`, `Audio->Word`, `Random`.
  - **Mastery rule**: Revealing a card or finishing audio/video NEVER grants mastery. `"Yana mashq qilaman"` re-queues immediately in the session and shortens the SRS interval in `flashcardSrsByCourse`.

## Exercise Taxonomy & Evaluation Rules

- **Supported `QuestionMode`**: `multiple_choice`, `text_input`, `fill_blank`, `word_match`, `sentence_order`, `error_correction`, `conversation_completion`, `self_assessed` (speaking/writing).
- **Required metadata**: `id`, `courseId: 'course_eng_01'`, `skillId`, `cefrLevel`, `topic`, `difficulty`, `correctIndex` or `acceptedAnswers[]`, `explanation`, `explanationRu`, `wrongFeedback` (+ option-specific `mistakeFeedbackByOption`).
- **Free-text normalization**: Trim spaces, collapse internal whitespace, map `’`/`‘` -> `'`, case-fold, strip trailing `.!?`, and accept all valid target variants (e.g., `"I'm Sam"`, `"My name is Sam"`, `"I am Sam"`). Never force a multi-valid prompt into single-answer MCQ.
- **Checkpoint separation**: Placement, in-lesson exercises, `reinforcementExercise`, unit checkpoints, and level exit exams must use distinct items and situations.

## Bilingual Scaffolding, Media & Adaptive Rules

- **Media language isolation**: Spoken English media uses `LessonMedia.language = 'en'` (independent of UI `'uz' | 'ru'`) at canonical `/lesson-media/english/<file>` (`public/lesson-media/english/` on Web, `mobile/assets/lesson_media/english/` on Flutter).
- **Pedagogical media**: Consistent editorial illustrations with `alt` text and zero baked-in text (render labels in UI). Multi-speaker audio uses distinct voices and speaker-labeled transcripts. Generate video (MP4 + poster + WebVTT) only when motion clarifies the goal, at authoring time.
- **Adaptive pathway**: Store placement score separately from independent mastery. Adapt placement difficulty progressively. Check prerequisites before unlocking; route `score < 50` or repeated error patterns to targeted remedial practice. Level advancement never depends on one test alone.

## Common Mistakes & Required Sub-Skills

| Mistake | Fix |
|---|---|
| Reusing `interactiveQuestion` as `reinforcementExercise` | Author a fresh scenario testing the same objective |
| Baking `"Hi!"` or labels inside PNG/SVG artwork | Keep artwork text-free; render text in UI layers |
| Marking flashcard flip as mastery | Require `"Eslab qoldim"` / independent recall |
| Calling `usesMathMastery` for `course_eng_01` | Gate math mastery strictly to `course_math_01` |

- **REQUIRED SUB-SKILL:** Use `bilimyol-english-content-qa` before marking any lesson, module, or assessment ready.
- **REQUIRED SUB-SKILL:** Use `ui-ux-pro-max` when designing flashcard, media player, or roadmap UI layouts.
