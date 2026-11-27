# BilimYo‘l Smart Edu — Wave 1 · Batch `W1-B2` Implementation & Verification Report

- **Repository:** `PirimovUktam/bilimyol-smart-edu`
- **Worktree:** `C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_1_b2_cefr_sql_grading_parity`
- **Branch:** `fix/wave-1-b2-cefr-sql-grading-parity`
- **Audit Baseline SHA (`READ-ONLY`):** `5c22343b2246dedcee7866cd11931c48346cf65c` (`NO-GO`, `49.28 / 100`)
- **Starting Base Commit (`W1-B1`):** `5376a0cf4f0cef005c7e28ab13bf518318e6fed8` (`fix/wave-1-b1-core-learning-integrity`; `11 / 121` `FIXED_LOCAL`, `1` `BLOCKED`)
- **`W1-B2` Commit Message:** `fix: seed canonical CEFR English curriculum and unify 9-mode server grading`
- **Batch Status:**
  - **`FIX-P0-01`:** **`FIXED_LOCAL`** *(Canonical `33` CEFR A1–B1 English `lessons` + `31` `roadmap_nodes` seeded into PostgreSQL with deterministic `SEED_LESSONS` option permutation; `public.learner_lessons` rewritten to a single `public.unlocked_math_lesson_ids()` CTE [`0` `OFFSET 0`, `0` per-row `can_open_math_lesson`]; `public.sanitize_learner_content` hardened against rich-key leaks; `bilimyol_private.submit_answer_attempt` extended to grade all `9` question modes + `alternate_exercise`; Mobile `getBaseRoadmapNodes` selects all `26` columns; Web & Mobile preserve per-question `skillId`, CEFR disclaimers, and `pedagogy17`)*
  - **`FIX-P1-40`:** **`FIXED_LOCAL`** *(Canonical JSON `p_selected_text` wire format unified across Web and Flutter for `sentence_order`, `word_match`, and `self_assessed`; multi-skill step & `alternate_exercise` completion supported in `public.complete_lesson`; non-MCQ mistake feedback added in `public.tutor_mistake_context` and forwarded/rendered on Mobile `ReinforcementResult` / `ReinforcementSheet`; `<28%` stuck `reinforcement` loops cleared via `GREATEST(50, ...)` on server and `!isReinforcementCompleted` in Web/Mobile `RouteEngine`)*
  - **Staging / Production Verification:** **`UNVERIFIED`** *(No staging or production database writes or deployments were executed per safety constraints)*

---

## 1. Executive Summary & Remediated Findings

1. **`FIX-P0-01` — 33-Lesson CEFR SQL Seeding, `learner_lessons` CTE Rewrite, Rich Sanitization, 9-Mode Server Grading & Mobile 14-Column Parity:**
   - Added `15` CEFR/RU/rich columns to `public.lessons` (`title_ru`, `summary_ru`, `skill_domain`, `communicative_focus`, `cefr_level`, `module_id`, `unit_id`, `can_do_objective`, `can_do_objective_ru`, `prerequisites`, `official_cefr_disclaimer_uz`, `official_cefr_disclaimer_ru`, `pedagogy17`, `alternate_exercise`, `requires_mastery`) and `14` CEFR/RU columns to `public.roadmap_nodes` (`title_ru`, `description_ru`, `skill_domain`, `cefr_level`, `module_id`, `module_title`, `module_title_ru`, `unit_id`, `can_do_objective`, `can_do_objective_ru`, `node_kind`, `is_checkpoint`, `has_rich_exercise`, `task_kind`), preserving column-level least-privilege grants (`SELECT (id), UPDATE (is_published, is_archived, updated_at), DELETE` on `public.lessons` for `authenticated`; `SELECT` only on `public.roadmap_nodes`, `public.learner_lessons`, and `public.admin_lessons`).
   - Seeded all `33` canonical CEFR A1–B1 English `lessons` (`17` A1, `8` A2, `8` B1, with deterministic FNV-1a `permuteQuestionOptions` matching Web `SEED_LESSONS`) and all `31` canonical CEFR A1–B1 `roadmap_nodes` (`15` A1, `8` A2, `8` B1) via idempotent `INSERT ... ON CONFLICT (id) DO UPDATE`.
   - **Coupling #2 (`public.learner_lessons` CTE Rewrite):** Replaced the per-row `CROSS JOIN LATERAL (... NOT public.can_open_math_lesson(l.id) ... OFFSET 0)` gate with a single `SECURITY DEFINER` `public.unlocked_math_lesson_ids()` CTE + `Hash Right Join` (`EXPLAIN` verified in PostgreSQL `17.11` with `0` lateral subplans and `0` `OFFSET 0`), exposing all new lesson columns (`alternate_exercise` sanitized) while keeping locked Math Pilot lessons gated. Updated `public.admin_lessons` and `public.admin_save_lesson` to preserve `requires_mastery`, `pedagogy17`, `reinforcement_exercise`, and all rich columns cleanly even when partial or JSON-`null` payloads are submitted.
   - Hardened `public.sanitize_learner_content(JSONB)` (pure `pg_catalog`, `IMMUTABLE`, `SECURITY INVOKER`-safe) to strip `acceptedAnswers`/`accepted_answers`, `explanationRu`/`explanation_ru`, and `mistakeFeedbackByOption`/`mistake_feedback_by_option`, deterministically scramble `orderedTokens`/`ordered_tokens` (including palindromic token lists) without double-permuting back to solution order in Web `InteractiveLessonView`/`ReinforcementModal`, and cyclically shift `right`/`rightRu`/`right_ru` across `matchPairs`/`match_pairs` (`0` fixed points).
   - Extended `bilimyol_private.submit_answer_attempt` (preserving 100% of `W0-B1` and `W1-B1` UUID idempotency, replay checks, lock ordering, Math 1st-mistake spoiler withholding, and daily stats deduplication) via `bilimyol_private.normalize_free_text` and `bilimyol_private.grade_question_attempt` to grade all `9` question modes (`multiple_choice`, `error_correction`, `conversation_completion`, `text_input`, `fill_blank`, `word_match` [rejecting pair-ID cheats], `sentence_order`, `speaking_prompt`, `writing_prompt`) plus `alternate_exercise`, returning non-spoiler `wrongFeedback` ahead of `explanation` on wrong attempts.
   - Updated Mobile `SupabaseLessonRepository.getBaseRoadmapNodes` (`mobile/lib/data/repositories/supabase_lesson_repository.dart`) to select all columns (`roadmapNodesSelectColumns = '*'`), preserved per-question `skillId` (`raw.skillId || raw.skill_id || skillId`) across both Web `SupabaseLessonRepository.ts` and Mobile `supabase_lesson_repository.dart`, and mapped `officialCefrDisclaimerUz`, `officialCefrDisclaimerRu`, and `pedagogy17`.
   - Updated owned bug-codifying test #12 (`supabase/tests/beginner_learning_start_regression.sql:29-34,50-53`, leaving line 23 untouched for `W4-B2`) for canonical 4-step `text_input` `lesson_eng_starter`.

2. **`FIX-P1-40` — Cross-Platform `p_selected_text` Wire Parity, Multi-Skill & `alternate_exercise` Completion, Anti-Spoiler Wrong-Answer Feedback, & `<28%` Reinforcement Clearance:**
   - Unified non-MCQ `p_selected_text` wire payloads across Web and Flutter:
     - `sentence_order`: JSON token array `["I wake up","at seven."]` (`p_selected_index = 0`), preserving multi-word chips across platforms.
     - `word_match`: key-sorted JSON object `{"<leftId>":"<selectedRightText>"}` (`p_selected_index = 0`) on both Web (`useLessonStore.ts`, `ReinforcementModal.tsx`) and Flutter (`SplayTreeMap` in `SubmitLessonAnswerUseCase` and `SubmitReinforcementUseCase`), working seamlessly with deranged `learner_lessons` `matchPairs`.
     - `speaking_prompt` / `writing_prompt` (`self_assessed`): JSON object `{"response":"...","criteria":[...]}` with sorted rubric criterion IDs and `p_selected_index = 0` across Web and Flutter (`SubmitLessonAnswerUseCase`, `SubmitReinforcementUseCase`, `LessonSessionNotifier` incl. `reinfInputSig`, `ReinforcementModal`, `ReinforcementSheet`, `InteractiveLessonScreen`).
   - Updated `public.complete_lesson` to resolve per-step `skillId` (`COALESCE(NULLIF(COALESCE(q->>'skillId', q->>'skill_id'), ''), l.skill_id)`) and accept a passed `l.alternate_exercise` attempt when swapped for a failed step question.
   - Extended `public.tutor_mistake_context` so `service_role` (`yolchi-tutor`) receives human-readable `selectedOption` (formatting `sentence_order`, `word_match`, and `self_assessed` JSON payloads), `correctOption`, and non-spoiler `wrongFeedback`/`explanation` across all 9 modes, while `public.get_mistake_feedback` withholds `correctOption` on non-MCQ `authenticated` calls (anti-spoiler parity) and clients render non-spoiler feedback without exposing scrambled `orderedTokens` or `To‘g‘ri javob: —` placeholders.
   - Lifted `<28%` skills to `>= 50%` in `public.complete_reinforcement` (`LEAST(100, GREATEST(50, COALESCE(v_current_raw, 0), v_before + 22))`), allowed multi-skill reinforcement exercises when the parent node/lesson skill has an assessed `< required_score` remediation need while rejecting cross-skill `alternate_exercise` duplicate completions with `42501`, and gated `status = 'reinforcement'` on `needsPractice && !isReinforcementCompleted` in Web `RouteEngine.ts` and Mobile `route_engine.dart`.

---

## 2. Changed & Added Files (`W1-B2`)

- **Database Migration & Regression Suites:**
  - `supabase/migrations/20261127000100_w1_b2_cefr_sql_seeding_and_9mode_grading.sql` *(new forward-only idempotent migration)*
  - `supabase/tests/w1_b2_cefr_sql_and_grading_parity_regression.sql` *(new SQL regression suite)*
  - `supabase/tests/beginner_learning_start_regression.sql` *(owned bug-codifying test #12 updated at lines 29–34, 50–53; line 23 untouched)*
- **Web (`src/` & `tsconfig.test.json`):**
  - `src/data/repositories/SupabaseLessonRepository.ts`
  - `src/app/store/useLessonStore.ts`
  - `src/features/lesson/InteractiveLessonView.tsx`
  - `src/features/reinforcement/ReinforcementModal.tsx`
  - `src/domain/usecases/SubmitLessonAnswerUseCase.ts`
  - `src/domain/personalization/RouteEngine.ts`
  - `src/__tests__/W1B2CefrSqlAndGradingParity.test.tsx` *(new)*
  - `tsconfig.test.json`
- **Flutter Mobile (`mobile/`):**
  - `mobile/lib/domain/entities/lesson.dart`
  - `mobile/lib/domain/entities/question.dart`
  - `mobile/lib/data/repositories/supabase_lesson_repository.dart`
  - `mobile/lib/data/repositories/in_memory_learner_repository.dart`
  - `mobile/lib/domain/usecases/submit_lesson_answer_use_case.dart`
  - `mobile/lib/domain/usecases/submit_reinforcement_use_case.dart`
  - `mobile/lib/domain/personalization/route_engine.dart`
  - `mobile/lib/app/providers.dart`
  - `mobile/lib/features/reinforcement/reinforcement_sheet.dart`
  - `mobile/lib/features/lesson/interactive_lesson_screen.dart`
  - `mobile/test/features/w1_b2_cefr_sql_and_grading_parity_test.dart` *(new)*

---

## 3. Verification Evidence (`RED` → `GREEN`)

| Gate | Command / Harness | Result |
|---|---|---|
| **PostgreSQL 17.11 Dual-Posture Fresh Install & `2x` Idempotency** | Disposable PG `17.11` (`bilimyol_cloud` Cloud-Default & `bilimyol_legacy` Legacy-Grant), all `30` migrations + `2x` re-run of `20261127000100` + `EXPLAIN (COSTS OFF)` on `public.learner_lessons` | **`PASS`** (`EXIT=0` on both postures; single `Hash Right Join` over `unlocked_math_lesson_ids`, `0` lateral subplans, `0` `OFFSET 0`) |
| **PostgreSQL 17.11 SQL Regression Suites (`11/11`)** | All `10` baseline suites + `w1_b2_cefr_sql_and_grading_parity_regression.sql` on both `bilimyol_cloud` & `bilimyol_legacy` (`22/22` runs) | **`PASS`** (`RED` `EXIT=3` pre-fix → `GREEN` **`22/22` `EXIT=0`**) |
| **Deno Edge Typecheck** | `deno check supabase/functions/yolchi-tutor/*.ts` | **`PASS`** (`EXIT=0`, `4/4` files) |
| **Web Typecheck (`app` + `tests`)** | `npm run typecheck` & `npm run typecheck:tests` (incl. `W1B2CefrSqlAndGradingParity.test.tsx`) | **`PASS`** (`EXIT=0`, `0` errors) |
| **Web Lint** | `npm run lint` (`oxlint`) | **`PASS`** (`EXIT=0`, `0` errors, `9` pre-existing warnings) |
| **Web Unit / Integration Tests** | `npm test` (`vitest run`) | **`PASS`** (`RED` `4` failed pre-fix → `GREEN` **`61/61` files, `365/365` tests passed** [`5/5` `W1B2`]) |
| **Web Production Build & `W0-B2` Bundle Isolation** | `npm run build` + `W0B2BundleAnswerKeyIsolation.test.ts` (6/6) | **`PASS`** (`2382` modules, `0` warnings, `0` preloaded seed answer keys) |
| **Web Playwright E2E** | `npm run test:e2e` | **`PASS`** (`EXIT=0`: Product Tour + multi-viewport journeys + Pilot Knowledge Map) |
| **Flutter Static Analysis** | `flutter analyze --no-pub --fatal-infos` | **`PASS`** (`EXIT=0`, `No issues found!`) |
| **Flutter Targeted `W1-B2` + `T3.11` Tests** | `flutter test --no-pub test/features/w1_b2_cefr_sql_and_grading_parity_test.dart test/e2e/tier3_pairwise_test.dart` | **`PASS`** (`RED` `EXIT=1` pre-fix → `GREEN` **`17/17` passed** [`5/5` `W1-B2` + `12/12` Tier 3]) |
| **Flutter Full Test Suite** | `flutter test --no-pub` | **`PASS`** (**`532` passed, `2` env-gated skips, `0` failed**) |

---

## 4. Remaining Blockers & Deferred Items

- **Live Staging / Production Verification (`UNVERIFIED`):** Migration `20261127000100_w1_b2_cefr_sql_seeding_and_9mode_grading.sql` and client builds are verified locally (`FIXED_LOCAL`); applying migrations and running live staging/production smoke tests remain pending deployment approval.
- **Inherited Wave 0 External Blocker (`FIX-P0-26`):** Production Android release keystore and CI secrets (`ANDROID_KEYSTORE_*`, `SUPABASE_*`) remain external secrets (`BLOCKED — RELEASE SIGNING CREDENTIALS MISSING`).
- **Next Scheduled Batch (`W1-B3` — NOT started per instruction):** English placement SQL bank (`q_eng_place_*`), CEFR session scoring, `placement_cefr_by_course` persistence, and A1 prerequisite chain (`FIX-P0-02`, `FIX-P0-11`, `FIX-P1-07`, `FIX-P1-09`, `FIX-P1-14`, `FIX-P1-16`, `FIX-P1-46`, `FIX-P2-09`).
