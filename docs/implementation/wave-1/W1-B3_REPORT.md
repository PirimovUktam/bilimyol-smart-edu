# BilimYo‘l Smart Edu — Wave 1 · Batch `W1-B3` Implementation & Verification Report

- **Repository:** `PirimovUktam/bilimyol-smart-edu`
- **Worktree:** `C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_1_b3_placement_priors_prereqs`
- **Branch:** `fix/wave-1-b3-placement-priors-prereqs`
- **Audit Baseline SHA (`READ-ONLY`):** `5c22343b2246dedcee7866cd11931c48346cf65c` (`NO-GO`, `49.28 / 100`)
- **Starting Base Commit (`W1-B2`):** `5c8ff7fa6b385564450f0829253e484b183950b3` (`fix/wave-1-b2-cefr-sql-grading-parity`; `13 / 121` `FIXED_LOCAL`, `1` `BLOCKED`)
- **`W1-B3` Commit Message:** `fix: calibrate English placement CEFR, skill priors, and A1 prerequisites`
- **Batch Status:**
  - **`FIX-P0-02`:** **`FIXED_LOCAL`** *(Canonical `12` CEFR-tagged `q_eng_place_*` items seeded into `public.questions` with `cefr_level`, `text_ru`, `explanation_ru`, `media`, and deterministic `permuteQuestionOptions` parity; legacy `q_live_eng_*` retired into `bilimyol_private.demo_placement_question_ids`; `placement_score_by_course`, `placement_cefr_by_course`, and `placement_skill_scores_by_course` persisted on `public.learner_profiles` behind `trg_guard_learner_profile_derived_placement` (`42501`) and mapped in Web/Mobile `getProfile()`; `'placement_test'` isolated from `course_eng_01` `learner_skill_scores`)*
  - **`FIX-P0-11`:** **`FIXED_LOCAL`** *(`course_eng_01` adaptive placement starts at `'medium'` (`A2`) across Web, Mobile, and PostgreSQL, and requires `b1Total >= 2 && b1Acc >= 0.5` before awarding `'B1'`)*
  - **`FIX-P1-07`:** **`FIXED_LOCAL`** *(All `15` A1 English roadmap nodes chained sequentially `1..15` through Unit 1–4 checkpoints into `node_eng_a1_exit` [`14` transitive ancestors; only `node_eng_a1_m1_greetings` has `prerequisites: []`]; orthogonal `node_it_web` and `node_logic_patterns` unlocked with `prerequisites: []` across Web, Mobile, and SQL)*
  - **`FIX-P1-09`:** **`FIXED_LOCAL`** *(Empirical Bayesian skill calibration (`priorWeight = 4`, `starterOnlyMaxScore = 55`, starter weight `0.5`, spoiled choice-retry discount `0.75`, `attemptCount >= 4` for `'mastered'`) unified across Web, Mobile, and PostgreSQL so `0%` placement + `1` correct starter yields `11%` (`<= 25%`, `'needs_remediation'`))*
  - **`FIX-P1-14`:** **`FIXED_LOCAL`** *(Web `AdaptiveQuestionSelector.ts` aligned to the 1-step Markov transition on `skillHistory.at(-1)` matching Mobile and SQL `next_placement_question`)*
  - **`FIX-P1-16`:** **`FIXED_LOCAL`** *(Placement skill credit weighted by difficulty (`easy: 0.75, medium: 1.0, hard: 1.25`, missed denominator `Math.min(w, 1.0)`), `isWeakestFocus` / `weakestSkillId` gated strictly on `lowestScore < 80`, and Mobile `computePlacementScores` unified to `last wins` deduplication)*
  - **`FIX-P1-46`:** **`FIXED_LOCAL`** *(Day-2 placement retakes (`p_restart => true` / new placement session) supersede prior `'placement_test'` attempts so `8/8 (100%)` retakes achieve `100%` (`>= 70%`) across all skills without Day-1 miss drag)*
  - **`FIX-P2-09`:** **`FIXED_LOCAL`** *(`assessedCefr` separated from `unlockedCefrFloor` across SQL `advance_placement`/`submit_placement_diagnostic`, Web `usePlacementStore`/`PlacementTestView`, and Mobile `PlacementSession`/`PlacementTestScreen`, and `ConfidenceLevel` (`low`/`medium`/`high`) badges wired onto Knowledge Map cards on Web and Mobile)*
  - **Staging / Production Verification:** **`UNVERIFIED`** *(No staging or production database writes or deployments were executed per safety constraints)*

---

## 1. Executive Summary & Remediated Findings

1. **`FIX-P0-02` — Canonical `q_eng_place_*` SQL Seeding, Derived Placement Persistence & `placement_test` Mastery Isolation:**
   - Added `cefr_level`, `text_ru`, `explanation_ru`, and `media` columns to `public.questions`, seeded all `12` canonical `q_eng_place_*` items from `content/english/placement-questions.json` with deterministic FNV-1a `permuteQuestionOptions` option ordering matching Web `PLACEMENT_QUESTIONS` and Mobile `placementQuestionsData`, and retired the `12` legacy `q_live_eng_*` IDs into `bilimyol_private.demo_placement_question_ids`. Updated `public.learner_placement_questions` and Mobile `SupabaseCourseRepository.getDiagnosticQuestions` to expose `cefr_level`, `text_ru`, and `media`.
   - Added `placement_score_by_course`, `placement_cefr_by_course`, and `placement_skill_scores_by_course` (`JSONB NOT NULL DEFAULT '{}'::jsonb`) on `public.learner_profiles`, protected against direct `authenticated`/`anon` client forgery via `BEFORE INSERT OR UPDATE` trigger `trg_guard_learner_profile_derived_placement` (`42501`), populated server-side by `advance_placement` and `submit_placement_diagnostic`, and hydrated in Web `SupabaseLearnerRepository.getProfile()` and Mobile `SupabaseLearnerRepository.getProfile()`.
   - Isolated `'placement_test'` rows from `course_eng_01` `public.learner_skill_scores` so English placement persists exclusively in `placement_*_by_course` and serves as an empirical Bayesian prior once downstream lesson exercises are attempted.

2. **`FIX-P0-11` & `FIX-P1-14` — `medium` (`A2`) English Diagnostic Entry, 1-Step Markov Parity & B1 Evidence Gate:**
   - Updated Web `AdaptiveQuestionSelector.ts`, Mobile `adaptive_question_selector.dart`, and SQL `public.next_placement_question` so `course_eng_01` starts each untested skill at `'medium'` (`A2`) and transitions via a 1-step Markov rule on the last skill answer (`skillHistory.at(-1)`).
   - Hardened `assignEnglishPlacementCefr` / `evaluateEnglishPlacementCefr` (Web), `SkillScoringEngine.evaluateEnglishPlacementCefr` (Mobile), and SQL placement completion so `'B1'` is awarded only when `overallAccuracy >= 0.75 && b1Total >= 2 && b1Acc >= 0.5` (`b1Total === 0` caps at `'A2'`).

3. **`FIX-P1-07` — Sequential 15-Node A1 English Chain & Orthogonal IT/Logic Day-0 Unlock:**
   - Chained all `15` A1 English roadmap nodes sequentially (`order: 1..15`) across `content/english/a1-curriculum.json`, `scripts/validate-english-curriculum.mjs`, `src/data/datasources/roadmaps.ts`, `mobile/lib/data/datasources/english/a1_roadmap_data.dart`, `mobile/lib/data/datasources/english/a1_lessons_data.dart`, and SQL `public.roadmap_nodes`/`public.lessons` (`node_eng_a1_exit` now requires `14` transitive A1 ancestors; only `node_eng_a1_m1_greetings` has `prerequisites: []`).
   - Cleared artificial prerequisites (`prerequisites: []`) on orthogonal `node_it_web` (`course_it_01`) and `node_logic_patterns` (`course_logic_01`) across Web, Mobile, and SQL.

4. **`FIX-P1-09`, `FIX-P1-16` & `FIX-P1-46` — Calibrated Bayesian Skill Priors, Difficulty-Weighted Placement Credit & Clean Retake Superseding:**
   - Unified `SkillScoringEngine` (Web & Mobile) and `public.recalculate_course_skill_scores_for_user` (SQL) with empirical Bayes smoothing (`priorWeight = 4`, default prior `0.50` or placement skill prior `placementScore / 100`), starter-lesson weight `0.5` + `starterOnlyMaxScore = 55`, spoiled choice-retry weight `0.75`, and `attemptCount >= 4` minimum evidence for `'mastered'` (`0%` placement + `1` correct starter yields `11%` `<= 25%`, `'needs_remediation'`).
   - Weighted placement item credit by difficulty (`easy: 0.75, medium: 1.0, hard: 1.25` with missed denominator `Math.min(w, 1.0)`), gated `isWeakestFocus = true` and `weakestSkillId` strictly on `lowestScore < 80`, and unified Mobile `computePlacementScores` deduplication to `last wins`.
   - Superseded prior `'placement_test'` sessions on Day-2 placement retakes (`p_restart => true` in SQL and placement submission in Web/Mobile repositories) so an `8/8 (100%)` retake yields `100%` (`>= 70%`) across all skills without stale Day-1 misses.

5. **`FIX-P2-09` — `assessedCefr` vs `unlockedCefrFloor` Separation & Knowledge Map `ConfidenceLevel` Badges:**
   - Returned both `assessedCefr` (`placement_cefr_by_course`) and monotonic `unlockedCefrFloor` (`unlocked_cefr_by_course`, preserving `node_eng_a1_exit` -> `'A2'` and `node_eng_a2_exit` -> `'B1'` floors) across SQL, Web, and Mobile, rendering a clear floor-retention note on `PlacementTestView` and `PlacementTestScreen` when `assessedCefr` (`'Pre-A1'`) is lower than `unlockedCefrFloor` (`'A2'`).
   - Wired localized (`uz` & `ru`) `ConfidenceLevel` (`low` / `medium` / `high`) badges onto every assessed skill card in `KnowledgeMapView.tsx` and `knowledge_map_screen.dart`.

---

## 2. Changed & Added Files (`W1-B3`)

- **Curriculum & Validator:**
  - `content/english/a1-curriculum.json`
  - `scripts/validate-english-curriculum.mjs`
- **Database Migration & Regression Suites:**
  - `supabase/migrations/20261128000100_w1_b3_placement_cefr_priors_and_prereqs.sql` *(new forward-only idempotent migration)*
  - `supabase/tests/w1_b3_placement_cefr_priors_and_prereqs_regression.sql` *(new SQL regression suite)*
  - `supabase/tests/p1_persistence_regression.sql` *(owned bug-codifying test #15 updated for English `placement_*_by_course` persistence)*
  - `supabase/tests/placement_sessions_regression.sql` *(owned bug-codifying test #13 updated for canonical `q_eng_place_*` & `placement_*_by_course`)*
- **Web (`src/`, `tests/e2e/`, `tsconfig.test.json`):**
  - `src/domain/entities/SkillScore.ts`
  - `src/domain/entities/Assessment.ts`
  - `src/domain/personalization/AdaptiveQuestionSelector.ts`
  - `src/domain/personalization/EnglishCefrPlacement.ts`
  - `src/domain/personalization/SkillScoringEngine.ts`
  - `src/domain/usecases/SubmitPlacementTestUseCase.ts`
  - `src/app/store/usePlacementStore.ts`
  - `src/data/datasources/roadmaps.ts`
  - `src/data/repositories/InMemoryLearnerRepository.ts`
  - `src/data/repositories/SupabaseLearnerRepository.ts`
  - `src/core/locales/messages.ts`
  - `src/core/locales/messages.ru.ts`
  - `src/features/knowledge-map/KnowledgeMapView.tsx`
  - `src/features/placement/PlacementTestView.tsx`
  - `src/__tests__/W1B3PlacementCefrPriorsAndPrereqs.test.tsx` *(new)*
  - `src/__tests__/EnglishPlacementAdaptiveAndYolchi.test.tsx` *(owned `W1-B3` assertions updated)*
  - `src/__tests__/ServerScoringAndAntiCheat.test.ts` *(owned `W1-B3` assertions updated)*
  - `src/__tests__/FlashcardAndFreeText.test.tsx` *(owned `W1-B3` assertion updated)*
  - `tests/e2e/english-suite/tier1-features.mjs` *(owned `W1-B3` starter score calibration assertion updated)*
  - `tsconfig.test.json`
- **Flutter Mobile (`mobile/`):**
  - `mobile/lib/domain/entities/skill_score.dart`
  - `mobile/lib/domain/entities/learner_profile.dart`
  - `mobile/lib/domain/entities/placement_session.dart`
  - `mobile/lib/domain/repositories/i_learner_repository.dart`
  - `mobile/lib/domain/personalization/adaptive_question_selector.dart`
  - `mobile/lib/domain/personalization/skill_scoring_engine.dart`
  - `mobile/lib/domain/usecases/submit_placement_test_use_case.dart`
  - `mobile/lib/data/datasources/english/a1_roadmap_data.dart`
  - `mobile/lib/data/datasources/english/a1_lessons_data.dart`
  - `mobile/lib/data/datasources/roadmaps_data.dart`
  - `mobile/lib/data/repositories/in_memory_learner_repository.dart`
  - `mobile/lib/data/repositories/supabase_course_repository.dart`
  - `mobile/lib/data/repositories/supabase_learner_repository.dart`
  - `mobile/lib/app/providers.dart`
  - `mobile/lib/core/l10n/app_strings.dart`
  - `mobile/lib/features/knowledge_map/knowledge_map_screen.dart`
  - `mobile/lib/features/placement/placement_test_screen.dart`
  - `mobile/test/features/w1_b3_placement_cefr_priors_and_prereqs_test.dart` *(new)*
  - `mobile/test/domain/adaptive_question_selector_test.dart`
  - `mobile/test/domain/placement_persistence_test.dart`
  - `mobile/test/domain/route_engine_test.dart` *(line 299 prerequisite fixture only; `W1-B4` lines 217–264 untouched)*
  - `mobile/test/domain/skill_scoring_engine_test.dart`
  - `mobile/test/features/english_m2_curriculum_test.dart`
  - `mobile/test/features/english_m6_1_2_regression_test.dart`
  - `mobile/test/features/english_starter_lesson_test.dart`

---

## 3. Verification Evidence (`RED` → `GREEN`)

| Gate | Command / Harness | Result |
|---|---|---|
| **English Curriculum Validator** | `node scripts/validate-english-curriculum.mjs` | **`PASS`** (`EXIT=0`, `[OK schema+curriculum]`) |
| **PostgreSQL 17.11 Dual-Posture Fresh Install & `2x` Idempotency** | Disposable PG `17.11` (`bilimyol_cloud` Cloud-Default & `bilimyol_legacy` Legacy-Grant), all `31` migrations + `2x` re-run of `20261128000100` | **`PASS`** (`EXIT=0` on both postures) |
| **PostgreSQL 17.11 SQL Regression Suites (`12/12`)** | All `11` prior suites + `w1_b3_placement_cefr_priors_and_prereqs_regression.sql` on both `bilimyol_cloud` & `bilimyol_legacy` (`24/24` runs) | **`PASS`** (**`24/24` `[PASS]`, `EXIT=0`**) |
| **PostgreSQL 17.11 8-Session Concurrency Race** | 8 parallel `psql` workers racing `advance_placement('course_eng_01')` + `submit_answer_attempt(..., 'conc-idem-key-1')` | **`PASS`** (`attempts:xp:score = 1:2:55`, `0` deadlocks, `0` duplicate XP) |
| **Deno Edge Typecheck** | `deno check supabase/functions/yolchi-tutor/index.ts supabase/functions/yolchi-tutor/math-pilot.ts` | **`PASS`** (`EXIT=0`) |
| **Web Typecheck (`app` + `tests`)** | `npm run typecheck` & `npm run typecheck:tests` (incl. `W1B3PlacementCefrPriorsAndPrereqs.test.tsx`) | **`PASS`** (`EXIT=0`, `0` errors) |
| **Web Lint** | `npm run lint` (`oxlint`) | **`PASS`** (`EXIT=0`, `0` errors, `9` pre-existing warnings) |
| **Web Unit / Integration Tests** | `npm test` (`vitest run`) | **`PASS`** (**`62/62` files, `370/370` tests passed** [`5/5` `W1B3`]) |
| **Web Production Build & `W0-B2` Bundle Isolation** | `npm run build` + `W0B2BundleAnswerKeyIsolation.test.ts` (6/6) | **`PASS`** (`2382` modules, `0` warnings, `0` preloaded seed answer keys) |
| **Web Playwright E2E** | `npm run test:e2e` | **`PASS`** (`EXIT=0`: Product Tour + multi-viewport journeys + Pilot Knowledge Map) |
| **Flutter Static Analysis** | `flutter analyze --no-pub --fatal-infos` | **`PASS`** (`EXIT=0`, `No issues found!`) |
| **Flutter Targeted `W1-B3` & Coupled Suites** | `flutter test --no-pub test/features/w1_b3_placement_cefr_priors_and_prereqs_test.dart ...` | **`PASS`** (`6/6` `W1-B3` + `65/65` coupled regression tests = `71/71` passed) |
| **Flutter Full Test Suite** | `flutter test --no-pub` | **`PASS`** (**`538` passed, `2` env-gated skips, `0` failed**) |

---

## 4. Remaining Blockers & Deferred Items

- **Live Staging / Production Verification (`UNVERIFIED`):** Migration `20261128000100_w1_b3_placement_cefr_priors_and_prereqs.sql` and client builds are verified locally (`FIXED_LOCAL`); applying migrations and running live staging/production smoke tests remain pending deployment approval.
- **Inherited Wave 0 External Blocker (`FIX-P0-26`):** Production Android release keystore and CI secrets (`ANDROID_KEYSTORE_*`, `SUPABASE_*`) remain external secrets (`BLOCKED — RELEASE SIGNING CREDENTIALS MISSING`).
- **Next Scheduled Batch (`W1-B4` — NOT started per instruction):** Math Mastery & RouteEngine unlock/re-lock hysteresis, `FIX-P0-03`, `FIX-P0-12`, `FIX-P1-01`, `FIX-P1-08`, `FIX-P1-17`, `FIX-P1-18`, `FIX-P1-19`.
