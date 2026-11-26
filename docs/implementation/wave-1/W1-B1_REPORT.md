# BilimYo‘l Smart Edu — Wave 1 · Batch `W1-B1` Implementation & Verification Report

- **Repository:** `PirimovUktam/bilimyol-smart-edu`
- **Worktree:** `C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_1_b1_core_learning_integrity`
- **Branch:** `fix/wave-1-b1-core-learning-integrity`
- **Audit Baseline SHA (`READ-ONLY`):** `5c22343b2246dedcee7866cd11931c48346cf65c` (`NO-GO`, `49.28 / 100`)
- **Starting Base Commit (`W0-B4`):** `1845f5096e0df4b0cf3c0603ac1184866905f6d2` (`fix/wave-0-b4-release-ci-tests`; `8 / 121` `FIXED_LOCAL`, `1` `BLOCKED`)
- **`W1-B1` Commit Message:** `fix: implement per-attempt learning answer idempotency`
- **Batch Status:**
  - **`FIX-P0-24`:** **`FIXED_LOCAL`** *(Per-attempt UUIDv4 idempotency across PostgreSQL RPCs, Web, and Flutter; `Correct → Wrong → Correct` unblocked with `0` `42501` errors; replay & 2-session `READ COMMITTED` concurrency verified with `0` duplicate XP/mastery)*
  - **`FIX-P1-55`:** **`FIXED_LOCAL`** *(Durable user-scoped pending attempt & `answeredQuestionIds` / `_passedQuestionIds` recovery across timeouts, `complete_lesson` / `complete_reinforcement` partial failures, `F5` reloads, and app restarts; half-signed-up `/register` recovery without HTTP `422`; offline/unconfigured `signOut` guaranteed local cleanup)*
  - **`FIX-P2-23`:** **`FIXED_LOCAL`** *(Bounded RPC/column input sizes `<=128` / `<=4000` preventing `54000` B-tree crashes; domain `CHECK` constraints across 10 tables + `roadmap_nodes.order_index NUMERIC(8,2)` + `<=60/hr` session cap; `(user_id, activity_date, question_id)` daily stats deduplication across PostgreSQL, Web `InMemoryLearnerRepository.ts`, and Mobile `in_memory_learner_repository.dart`)*
  - **Staging / Production Verification:** **`UNVERIFIED`** *(No staging or production database writes or deployments were executed per safety constraints)*

---

## 1. Executive Summary & Remediated Findings

1. **`FIX-P0-24` — Learning Answer Idempotency:**
   - Replaced static payload-keyed `p_idempotency_key` strings (`attempt_${lessonId}_${questionId}_...` on Web and `${lessonId}:${questionId}:${selectedIndex}` on Mobile) with fresh RFC 4122 version-4 UUIDs minted per logical user submission across `SubmitLessonAnswerUseCase` and `SubmitReinforcementUseCase` on both Web and Flutter.
   - Removed the static `p_lesson_id || ':' || p_question_id || ':' || p_selected_index::TEXT` fallback inside PostgreSQL `bilimyol_private.submit_answer_attempt` (preserving `NULL` when `p_idempotency_key IS NULL` so unkeyed callers never collide under `idx_answer_attempts_idempotency`), added `selected_answer` payload-mismatch validation (`22023`) on idempotent replay, gated curated/question explanation return on replay strictly to `v_existing_is_correct = true` (preventing spoiler leakage on replayed wrong attempts), and serialized concurrent duplicate-UUID calls via `pg_advisory_xact_lock` + `ON CONFLICT (user_id, idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING` with `IF NOT FOUND` replay fallback.
   - Unblocked `Correct → Wrong → Correct` followed by `complete_lesson` / `complete_reinforcement` (`0` `42501` errors) while keeping per-question XP capped to `+2` once per `questionId` across PostgreSQL, Web `InMemoryLearnerRepository.ts`, and Mobile `in_memory_learner_repository.dart`.

2. **`FIX-P1-55` — Learning State Recovery & Auth Resilience:**
   - Added user-scoped durable pending attempt (`'submitting' -> 'graded'`) and `answeredQuestionIds` / `_passedQuestionIds` storage (`src/features/lesson/lessonRecoveryStorage.ts` on Web; `LocalStorageService` pending-attempt & passed-question helpers on Mobile), including full pending UI input hydration (`pickedOption`, `textAnswer`, `matchedPairs`, `orderedTokens`, `checkedCriteriaIds`) across `F5` reloads and app restarts.
   - Pending attempts remain persisted across network timeouts, mid-RPC navigation, `F5` reloads, app restarts, and partial `complete_lesson` / `complete_reinforcement` / `getProfile` failures, reusing the exact same UUID on transport retry and skipping duplicate `submit_answer_attempt` calls once graded until full completion confirmation settles.
   - Updated Web `readingPosition.ts` (unifying Demo account scope to `'demo'` with `sessionReset` cleanup) and Mobile `LessonReadingPositionStore` (`reading_position.dart` + `LessonSessionNotifier` including `requiresMastery` lessons outside active reinforcement) to inspect `step.interactiveQuestion != null` and advance the safe step boundary past already-passed interactive questions.
   - Updated Web `AuthContext.signUp` and Mobile `RegisterScreen` to detect an already-active session for the submitted email when `profile` hydration previously failed (recovering the profile without re-calling GoTrue `signUp` or triggering HTTP `422`), while purging stale half-signed-up sessions locally if the learner switches to a different email address.
   - Updated Web `AuthContext.signOut` and Mobile `ProfileScreen._handleLogout` (`SupabaseConfig.forceLocalSignOutCleanup` + `SecureAuthStorageCoordinator.purgePersistedAuthArtifacts`) so offline `global` sign-out failures or `null` auth clients wipe local/encrypted auth tokens, clear `authUserIdListenable`, and reset session stores unconditionally.

3. **`FIX-P2-23` — Data Constraints & Daily Question Statistics Deduplication:**
   - Enforced `p_idempotency_key <= 128` chars (normalizing any legacy `>128`-char rows via collision-free `left(idempotency_key, 58) || ':' || md5(idempotency_key) || ':' || id::TEXT`) and `p_selected_text <= 4000` chars across PostgreSQL RPCs, Web repositories, and Mobile repositories, eliminating `54000` B-tree index crashes and unbounded row bloat.
   - Widened `public.roadmap_nodes.order_index` from `NUMERIC(4,1)` to `NUMERIC(8,2)` (rebuilding dependent `bilimyol_private.math_pilot_objectives` and `bilimyol_private.math_pilot_items` views), added `CHECK` constraints across `profiles`, `learner_profiles` (using `pg_catalog.jsonb_path_exists` so `authenticated` requires zero schema privileges on `bilimyol_private`), `questions`, `lesson_progress`, `gamification_profiles`, `gamification_events`, `daily_learning_stats`, `answer_attempts`, `placement_attempts`, and `learning_sessions`, added `uq_profiles_email_nonempty`, sanitized `handle_new_user()` and client `avatar_url` writes (`https://` `<= 2048` chars), bounded `save_placement_attempt` (`<= 100` submissions), and capped `record_session_heartbeat` new session creation to `<= 60` per hour.
   - Created `bilimyol_private.daily_question_outcomes (user_id, activity_date, question_id)` (backfilled from historical `public.answer_attempts`) so `daily_learning_stats` deduplicates daily question counts and `accuracy_percent` by `(user_id, activity_date, question_id)` on `Asia/Tashkent` (`UTC+5`) dates while tracking `lessons_completed` and completion `xp_earned`, with matching `Asia/Tashkent` deduplication and daily bonus tracking in Web `InMemoryLearnerRepository.ts` and Mobile `in_memory_learner_repository.dart`.

---

## 2. Changed & Added Files (`W1-B1`)

- **Database Migration & Regression Suite:**
  - `supabase/migrations/20261126000100_w1_b1_idempotency_constraints_and_daily_stats.sql` *(new forward-only migration)*
  - `supabase/tests/w1_b1_idempotency_constraints_and_daily_stats_regression.sql` *(new SQL regression suite)*
- **Web (`src/` & `tsconfig.test.json`):**
  - `src/core/utils/attemptUuid.ts` *(new)*
  - `src/features/lesson/lessonRecoveryStorage.ts` *(new)*
  - `src/features/lesson/readingPosition.ts`
  - `src/features/lesson/InteractiveLessonView.tsx`
  - `src/domain/repositories/ILearnerRepository.ts`
  - `src/domain/usecases/SubmitLessonAnswerUseCase.ts`
  - `src/domain/usecases/SubmitReinforcementUseCase.ts`
  - `src/data/repositories/SupabaseLearnerRepository.ts`
  - `src/data/repositories/InMemoryLearnerRepository.ts`
  - `src/app/store/useLessonStore.ts`
  - `src/app/store/useRoadmapStore.ts`
  - `src/core/context/AuthContext.tsx`
  - `src/__tests__/W1B1CoreLearningIntegrity.test.tsx` *(new)*
  - `tsconfig.test.json`
- **Flutter Mobile (`mobile/`):**
  - `mobile/lib/core/utils/attempt_uuid.dart` *(new)*
  - `mobile/lib/core/auth/secure_auth_storage.dart`
  - `mobile/lib/core/config/supabase_config.dart`
  - `mobile/lib/core/storage/local_storage_service.dart`
  - `mobile/lib/features/lesson/reading_position.dart`
  - `mobile/lib/domain/repositories/i_learner_repository.dart`
  - `mobile/lib/domain/usecases/submit_lesson_answer_use_case.dart`
  - `mobile/lib/domain/usecases/submit_reinforcement_use_case.dart`
  - `mobile/lib/data/repositories/supabase_learner_repository.dart`
  - `mobile/lib/data/repositories/in_memory_learner_repository.dart`
  - `mobile/lib/app/providers.dart`
  - `mobile/lib/features/auth/register_screen.dart`
  - `mobile/lib/features/profile/profile_screen.dart`
  - `mobile/test/features/w1_b1_core_learning_integrity_test.dart` *(new)*

---

## 3. Verification Evidence (`RED` → `GREEN`)

| Gate | Command / Harness | Result |
|---|---|---|
| **PostgreSQL 17.11 Dual-Posture Fresh Install, Legacy Key Collision & `2x` Idempotency** | Disposable PG `17.11` (`Cloud-Default` & `Legacy-Grant` `GRANT ALL ON SCHEMA public`), all `29` migrations + `2x` re-run of `20261126000100` + legacy `>128`-char shared-prefix collision harness | **`PASS`** (`EXIT=0` on both postures; `23505` collision remediated) |
| **PostgreSQL 17.11 SQL Regression Suites (`10/10`)** | All `9` baseline suites + `w1_b1_idempotency_constraints_and_daily_stats_regression.sql` on both `bilimyol_cloud` & `bilimyol_legacy` (`20/20` runs) | **`PASS`** (`RED` `EXIT=3` pre-fix → `GREEN` `EXIT=0`) |
| **PostgreSQL 17.11 2-Session `READ COMMITTED` Concurrency** | Two parallel PG `17.11` sessions submitting identical UUID simultaneously | **`PASS`** (`1` `already_processed=false, xp_awarded=2`; `1` `already_processed=true, xp_awarded=0`; `attempts=1, gp_xp=2, gamification_events=1`) |
| **Deno Edge Typecheck** | `deno check supabase/functions/yolchi-tutor/*.ts` | **`PASS`** (`EXIT=0`, `4/4` files) |
| **Web Typecheck (`app` + `tests`)** | `npm run typecheck` & `npm run typecheck:tests` (incl. `W1B1CoreLearningIntegrity.test.tsx`) | **`PASS`** (`EXIT=0`, `0` errors) |
| **Web Lint** | `npm run lint` (`oxlint`) | **`PASS`** (`EXIT=0`, `0` errors, `9` pre-existing warnings) |
| **Web Unit / Integration Tests** | `npm test` (`vitest run`) | **`PASS`** (`RED` `4` failed pre-fix → `GREEN` **`60/60` files, `360/360` tests passed**) |
| **Web Production Build & `W0-B2` Bundle Isolation** | `npm run build` + `W0B2BundleAnswerKeyIsolation.test.ts` (6/6) | **`PASS`** (`2382` modules, `0` warnings, `0` preloaded seed answer keys) |
| **Web Playwright E2E** | `npm run test:e2e` | **`PASS`** (`EXIT=0`: Product Tour `42/42` + multi-viewport journeys + Pilot Knowledge Map `7/7`) |
| **Flutter Static Analysis** | `flutter analyze --no-pub --fatal-infos` | **`PASS`** (`EXIT=0`, `No issues found!`) |
| **Flutter Targeted `W1-B1` Tests** | `flutter test --no-pub test/features/w1_b1_core_learning_integrity_test.dart test/features/lesson_session_persistence_test.dart` | **`PASS`** (`RED` `EXIT=1` pre-fix → `GREEN` **`18/18` passed** [`7/7` `W1-B1` + `11/11` session persistence]) |
| **Flutter Full Test Suite** | `flutter test --no-pub` | **`PASS`** (**`528` passed, `2` env-gated skips, `0` failed**) |

---

## 4. Remaining Blockers & Deferred Items

- **Live Staging / Production Verification (`UNVERIFIED`):** Migration `20261126000100_w1_b1_idempotency_constraints_and_daily_stats.sql` and client builds are verified locally (`FIXED_LOCAL`); applying migrations and running live staging/production smoke tests remain pending deployment approval.
- **Inherited Wave 0 External Blocker (`FIX-P0-26`):** Production Android release keystore and CI secrets (`ANDROID_KEYSTORE_*`, `SUPABASE_*`) remain external secrets (`BLOCKED — RELEASE SIGNING CREDENTIALS MISSING`).
