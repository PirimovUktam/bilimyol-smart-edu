# BilimYo‘l Smart Edu — Wave 1 · Batch `W1-B2` Implementation Plan

- **Repository:** `PirimovUktam/bilimyol-smart-edu`
- **Base Commit:** `5376a0cf4f0cef005c7e28ab13bf518318e6fed8` (`fix/wave-1-b1-core-learning-integrity`)
- **Feature Branch:** `fix/wave-1-b2-cefr-sql-grading-parity`
- **Worktree:** `C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_1_b2_cefr_sql_grading_parity`
- **Target Findings:** `FIX-P0-01`, `FIX-P1-40` *(plus Cross-Batch Coupling #2 on `public.learner_lessons` and Owned Bug-Codifying SQL Test #12 `supabase/tests/beginner_learning_start_regression.sql`)*

---

## 1. Root Cause Summary

1. **`FIX-P0-01` — English Live SQL Chasm, Non-MCQ Grading Rejection, Answer-Key Leakage & Mobile 14-Column Truncation:**
   - Live PostgreSQL (`supabase/migrations/20261106150620_publish_curated_lesson_paths.sql` and `20261107140400_foundation_learning_paths.sql`) contains only `6` legacy English `lessons` and `4` legacy `roadmap_nodes` (missing `27/33` canonical CEFR A1–B1 lessons, `27/31` CEFR nodes, and `15`/`14` CEFR/RU/rich columns on `public.lessons` and `public.roadmap_nodes`).
   - `public.learner_lessons` (`20261116000100_math_mastery_pilot.sql:321-330`) executes a per-row `CROSS JOIN LATERAL (... NOT public.can_open_math_lesson(l.id) ... OFFSET 0)` gate and omits the new CEFR/RU/rich columns (`title_ru`, `summary_ru`, `skill_domain`, `communicative_focus`, `cefr_level`, `module_id`, `unit_id`, `can_do_objective`, `can_do_objective_ru`, `prerequisites`, `official_cefr_disclaimer_uz`, `official_cefr_disclaimer_ru`, `pedagogy17`, `alternate_exercise`, `requires_mastery`).
   - `public.sanitize_learner_content(JSONB)` (`20261015000001:24-48`) strips only MCQ `correct_index`/`explanation` keys, leaking `acceptedAnswers`, `explanationRu`, `mistakeFeedbackByOption`, exact solution order of `orderedTokens`, and paired `left ↔ right` alignment of `matchPairs`.
   - `bilimyol_private.submit_answer_attempt` (`20261126000100:1221-1232`) grades only `v_correct_index IS NOT NULL`, throwing `22023` (`Savol server bazasida to‘liq sozlanmagan.`) on all `39` non-MCQ English exercises (`text_input`, `fill_blank`, `word_match`, `sentence_order`, `speaking_prompt`, `writing_prompt`) and rich `alternate_exercise` retries.
   - Mobile `SupabaseLessonRepository.getBaseRoadmapNodes` (`mobile/lib/data/repositories/supabase_lesson_repository.dart:628-632`) explicitly selects only `12` columns, stripping all `14` CEFR/RU columns (`cefr_level`, `module_id`, `module_title`, `module_title_ru`, `unit_id`, `skill_domain`, `can_do_objective`, `can_do_objective_ru`, `node_kind`, `is_checkpoint`, `has_rich_exercise`, `task_kind`, `title_ru`, `description_ru`), while Web `SupabaseLessonRepository.ts` and Mobile `supabase_lesson_repository.dart` overwrite per-question `skillId` with `row.skill_id` and Web `mapLearnerLesson` drops `officialCefrDisclaimerUz`, `officialCefrDisclaimerRu`, and `pedagogy17`.

2. **`FIX-P1-40` — Cross-Platform `p_selected_text` Wire-Format Divergence, Multi-Skill Step & `alternate_exercise` Completion Rejections, Blind Mobile Reinforcement Feedback, & `<28%` Stuck `reinforcement` Loop:**
   - Web and Flutter serialize non-MCQ `p_selected_text` incompatibly: `sentence_order` sends JSON array `["I","am","Sam"]` on Web vs space-joined string on Mobile (corrupting multi-word chips); `word_match` sends `{leftId: rightPairId}` on Web (which breaks once `learner_lessons` deranges `matchPairs[].right`!) vs unsorted `{leftId: rightText}` on Mobile; `self_assessed` sends `{"response":"...","criteria":[...]}` on Web vs rubric-stripped raw string on Mobile.
   - `public.complete_lesson` (`20261124000100:626-640`) checks `aa.skill_id = l.skill_id`, rejecting multi-skill English unit checkpoints and exit exams with `42501`, and rejects lessons where a step question was retried via `switchToAlternateExercise()` (`l.alternate_exercise`).
   - `public.tutor_mistake_context` (`20261124000100:1785-1801`) returns `NULL` for all non-MCQ questions; Mobile `SubmitReinforcementUseCase` (`submit_reinforcement_use_case.dart:13-27, 129-135`) discards `answerAttempt.correctOption` and `explanation`, leaving `ReinforcementSheet` blind on wrong answers when `correctIndex == -1` (and displaying scrambled `q.orderedTokens` on `sentence_order` misses).
   - `public.complete_reinforcement` (`20261124000100:1594`) computes `LEAST(100, GREATEST(v_current_raw, v_before + 22))`, leaving `<28%` skills below `50%` after one-shot reinforcement, while Web `RouteEngine.ts:66` and Mobile `route_engine.dart:93` keep `status = 'reinforcement'` even when `reinf_<node_id>` is in `completedReinforcementIds`.

---

## 2. Scoped Changes

### 2.1 PostgreSQL Forward Migration (`supabase/migrations/20261127000100_w1_b2_cefr_sql_seeding_and_9mode_grading.sql`)
- Add missing CEFR/RU/rich columns to `public.lessons` (`15` columns) and `public.roadmap_nodes` (`14` columns) with safe `IF NOT EXISTS` defaults.
- Upsert all `33` canonical CEFR A1–B1 English `lessons` (with deterministic FNV-1a option permutation matching Web `SEED_LESSONS`) and all `31` canonical CEFR A1–B1 `roadmap_nodes` (`ON CONFLICT (id) DO UPDATE`), preserving `courses.starter_lesson_id` (`lesson_eng_starter`) and `foundation_lesson_ids`.
- Harden `public.sanitize_learner_content(JSONB)` to strip `acceptedAnswers`/`accepted_answers`, `explanationRu`/`explanation_ru`, and `mistakeFeedbackByOption`/`mistake_feedback_by_option`, deterministically scramble `orderedTokens`/`ordered_tokens` (including palindromic token sequences) so neither raw view order nor client UI rotation equals the solution order, and cyclically derange `right`/`rightRu` across `matchPairs`/`match_pairs` (`0` fixed points).
- Rewrite `public.learner_lessons` using a single `public.unlocked_math_lesson_ids()` CTE (`0` `OFFSET 0`, `0` per-row `can_open_math_lesson` lateral calls) exposing all new lesson columns (`alternate_exercise` sanitized); refresh `public.admin_lessons` with least-privilege grants and update `public.admin_save_lesson` to preserve `requires_mastery`, `pedagogy17`, `reinforcement_exercise`, and all rich columns even when partial/null JSON payloads are submitted.
- Extend `bilimyol_private.submit_answer_attempt` (preserving 100% of `W0-B1` and `W1-B1` idempotency, replay, lock-ordering, Math spoiler, and daily dedup invariants) to grade all `9` question modes (`multiple_choice`, `error_correction`, `conversation_completion`, `text_input`, `fill_blank`, `word_match`, `sentence_order`, `speaking_prompt`, `writing_prompt`) plus `alternate_exercise`, returning non-spoiler `wrongFeedback` ahead of `explanation` on wrong attempts.
- Update `public.complete_lesson` to resolve per-step `COALESCE(NULLIF(COALESCE(q->>'skillId', q->>'skill_id'), ''), l.skill_id)` and accept a passed `l.alternate_exercise` attempt when swapped for a step exercise.
- Update `public.complete_reinforcement` (`GREATEST(50, COALESCE(v_current_raw, 0), v_before + 22)`) so `<28%` skills reach `>= 50%` upon canonical reinforcement completion, allow multi-skill reinforcement exercises when the parent node/lesson skill has an assessed remediation deficit (`< required_score`), reject cross-skill `alternate_exercise` duplicate completions with controlled `42501`, and extend `public.tutor_mistake_context` / `public.get_mistake_feedback` so `service_role` AI tutoring receives formatted `selectedOption`, `correctOption`, and `explanation` across all 9 modes while `authenticated` non-MCQ calls withhold raw `correctOption` spoilers.

### 2.2 Web (`src/`)
- `src/data/repositories/SupabaseLessonRepository.ts`: Preserve per-question `skillId` (`raw.skillId || raw.skill_id || skillId`), `officialCefrDisclaimerUz`, `officialCefrDisclaimerRu`, and `pedagogy17` in `mapLearnerLesson`.
- `src/app/store/useLessonStore.ts`, `src/features/lesson/InteractiveLessonView.tsx`, `src/features/reinforcement/ReinforcementModal.tsx`, `src/domain/entities/Question.ts`, `src/domain/usecases/SubmitLessonAnswerUseCase.ts`: Serialize `word_match` as key-sorted `{"<leftId>":"<selectedRightText>"}` and `self_assessed` with sorted `criteria` IDs, evaluate normalized `right` text in `evaluateWordMatch`, avoid double-permuting already sanitized `learner_lessons` `orderedTokens`/`matchPairs`, and preserve non-spoiler `wrongFeedback` on non-MCQ wrong answers.
- `src/domain/personalization/RouteEngine.ts`: Clear parent node `'reinforcement'` status to `'available'` once `reinf_<node_id>` is in `completedReinforcementIds` (preserving `SkillScoringEngine.calculateReinforcementScore` unit semantics tested in `P1ClosureSecurity.test.ts`).

### 2.3 Flutter Mobile (`mobile/`)
- `mobile/lib/data/repositories/supabase_lesson_repository.dart`, `mobile/lib/domain/entities/lesson.dart`: Select full columns (`.select('*')`) in `getBaseRoadmapNodes`, preserve per-question `skillId` in `_question`, and map `pedagogy17` on `Lesson`.
- `mobile/lib/domain/usecases/submit_lesson_answer_use_case.dart`, `mobile/lib/domain/usecases/submit_reinforcement_use_case.dart`, `mobile/lib/app/providers.dart`, `mobile/lib/domain/entities/question.dart`, `mobile/lib/data/repositories/in_memory_learner_repository.dart`: Standardize `p_selected_text` wire format (`jsonEncode(tokens)` for `sentenceOrder`, key-sorted `SplayTreeMap` `jsonEncode` for `wordMatch`, `jsonEncode({'response': ..., 'criteria': ...})` with `selectedIndex: 0` for `self_assessed`), include `checkedCriteriaIds` in `reinfInputSig`, forward non-spoiler `wrongFeedback`/`explanation` on `ReinforcementResult` and non-MCQ `LessonAnswerResult`, and align `InMemoryLearnerRepository.submitAnswerAttempt`.
- `mobile/lib/features/reinforcement/reinforcement_sheet.dart`, `mobile/lib/features/lesson/interactive_lesson_screen.dart`: Pass sorted `_checkedRubricIds` on `self_assessed` submission, suppress `To‘g‘ri javob: —` when `result.correctOption` is withheld on 1st-mistake Math Mastery MCQs, and render non-spoiler feedback on wrong reinforcement attempts without showing scrambled `orderedTokens`.
- `mobile/lib/domain/personalization/route_engine.dart`: Clear parent node `NodeStatus.reinforcement` to `NodeStatus.available` once `reinf_<node_id>` is in `completedReinforcementIds` while keeping the completed `reinf_<node_id>` node in `adaptedNodes`.

---

## 3. Verification Gates (TDD `RED` → `GREEN`)

1. `supabase/tests/w1_b2_cefr_sql_and_grading_parity_regression.sql` + updated `supabase/tests/beginner_learning_start_regression.sql` + all `9` remaining SQL regression suites + `2x` migration idempotency across `Cloud-Default` and `Legacy-Grant` disposable PostgreSQL `17.11` databases.
2. `src/__tests__/W1B2CefrSqlAndGradingParity.test.tsx` + `npm run typecheck`, `npm run typecheck:tests`, `npm run lint`, `npm test`, `npm run build`, `npm run test:e2e`, and `deno check supabase/functions/yolchi-tutor/*.ts`.
3. `mobile/test/features/w1_b2_cefr_sql_and_grading_parity_test.dart` + `flutter analyze --no-pub --fatal-infos`, `flutter test --no-pub`.
