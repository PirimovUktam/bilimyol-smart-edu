---
name: bilimyol-english-content-qa
description: Use when auditing, validating, or reviewing BilimYo‘l English lessons, questions, flashcards, CEFR placement items, uz/ru explanations, or media assets for course_eng_01 before marking content ready.
---

# BilimYo‘l English Content Quality Assurance (`course_eng_01`)

## Overview

Every `course_eng_01` lesson, exercise, flashcard, placement item, and media asset must pass deterministic pedagogical, linguistic, technical, and Web/Flutter parity checks before approval.

**Evidence Honesty Rule:** Label verification status strictly by evidence (`LOCAL VERIFIED`, `STAGING/DEVICE VERIFIED`, `DEFERRED`, `PUBLISHED`). NEVER mark AI-authored content as `"human editor approved"` (`"inson muharriri tasdiqladi"`) without actual human review.

## 10 Mandatory QA Gates

| Gate | Scope | Hard Fail Condition |
|---|---|---|
| **G1: CEFR & Prerequisites** | `cefrLevel`, `prerequisites[]`, vocab/grammar difficulty | `Pre-A1`/`A1` lesson uses unintroduced B1+ forms or broken prerequisite ID |
| **G2: 17-Part Structure & Links** | Lesson steps, Can-Do objective, feedback, roadmap node targets | Empty step, missing objective/feedback, or dangling node (e.g. `node_eng_read` missing target) |
| **G3: Linguistic & UZ/RU Accuracy** | Grammar rules/forms, IPA, `uz` & `ru` glosses | Translationese English, wrong IPA, missing `ru` localization, or wrong UZ/RU explanation |
| **G4: Question & Distractor Integrity** | Unique `id`, `skillId`, `cefrLevel`, `topic`, `difficulty`, single defensible MCQ or `acceptedAnswers[]`, diagnostic `wrongFeedback` | Duplicate ID/prompt, ambiguous MCQ with 2 valid options, absurd distractor, or bare `"Wrong"` feedback |
| **G5: Anti-Spoiler & Sanitization** | Prompt, title, image, `alt`, translations vs answer key; `sanitize_learner_content` | Prompt/alt/image leaks target answer (e.g. `"I'm Sam"` in hint, or listening script printed inline in placement prompt) |
| **G6: Listening & Reading Evidence** | Audio/transcript vs question; reading text vs question | Answer not verifiable from audio/passage alone (e.g. `"quarter past three"` missing `"in the afternoon"` for `15:15`) |
| **G7: Non-Duplication** | In-lesson quiz vs `reinforcementExercise` vs placement vs checkpoints | Reused prompt or key across practice and reinforcement |
| **G8: Flashcard & Media Audit** | `reviewStatus: 'approved'`, `/lesson-media/english/*`, Web + Flutter files, `durationSeconds > 0`, speaker-labeled transcript, `language: 'en'`, `alt`, zero baked image text, retry/fallback | Missing file on Web/Flutter, `durationSeconds <= 0`, silent/corrupt WAV, transcript mismatch, baked text in artwork, or flip granting mastery |
| **G9: Cross-Platform Parity & Isolation** | `content/english/` vs `src/data/datasources/` vs `mobile/lib/data/datasources/` vs SQL; `course_eng_01` isolation | Web/Flutter ID, `acceptedAnswers`, or media mismatch; any `course_math_01` (`q_pilot_`, `usesMathMastery`) leakage |
| **G10: Originality & Safety** | Original dialogues/texts/items; age-appropriateness | Copied copyrighted textbook passages or unsafe/inappropriate examples |

## Verification Protocol

1. **Automated Parity & Media Audit**: Validate canonical `content/english/` manifests, confirm byte-for-byte parity between `public/lesson-media/english/*` and `mobile/assets/lesson_media/english/*`, verify WAV/MP4 headers and `durationSeconds > 0`, and check zero duplicate question IDs/prompts.
2. **Independent Item Solving**: Solve every quiz, placement, and checkpoint question from the lesson/audio/reading passage alone without looking at the answer key to detect ambiguity or missing clues.
3. **Runtime Journey Verification**:
   - **REQUIRED SUB-SKILL:** Use `bilimyol-journey-qa` for Web (`vitest`, `typecheck`, `build`, `test:e2e`, `390px` + desktop + keyboard + light/dark + slow network, opening/closing Yo‘lchi AI before submit) and Flutter (`flutter analyze`, `flutter test`, `flutter build apk --release`).

## QA Report Output Format

Report every audit using this compact table:

| Level | Planned / Verified Lessons | Independent Questions | Flashcards | Listened Audio | Verified Visuals/Video | Status | Open Items |
|---|---|---|---|---|---|---|---|
| `A1` | `X / Y` | `N` | `N` | `N` | `N` | `LOCAL VERIFIED` | `None` or explicit item |
