# BilimYo‘l Smart Edu — Wave 1 · Batch `W1-B1` Implementation Plan

- **Repository:** `PirimovUktam/bilimyol-smart-edu`
- **Base Commit:** `1845f5096e0df4b0cf3c0603ac1184866905f6d2` (`fix/wave-0-b4-release-ci-tests`)
- **Feature Branch:** `fix/wave-1-b1-core-learning-integrity`
- **Worktree:** `C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_1_b1_core_learning_integrity`
- **Target Findings:** `FIX-P0-24`, `FIX-P1-55`, `FIX-P2-23`

---

## 1. Root Cause Summary

1. **`FIX-P0-24` — Deterministic Static `p_idempotency_key` & Replay Gaps:**
   - Web (`SubmitLessonAnswerUseCase.ts`, `SubmitReinforcementUseCase.ts`, `SupabaseLearnerRepository.recordAnswerAttempt`) and Mobile (`SupabaseLearnerRepository._submitServerAnswer` for non-`q_pilot_*` items) synthesize static `(lessonId, questionId, selectedIndex/payload)` idempotency keys. Answering `Correct → Wrong → Correct` hits `v_existing_id IS NOT NULL` (`already_processed: true`), skips inserting the corrected attempt, leaves the wrong attempt newest, and permanently rejects `complete_lesson` / `complete_reinforcement` with `42501`.
   - PostgreSQL `bilimyol_private.submit_answer_attempt` falls back to `p_lesson_id || ':' || p_question_id || ':' || p_selected_index::TEXT` when `p_idempotency_key IS NULL` and omits `selected_answer` comparison on idempotent replay.
   - Mobile `in_memory_learner_repository.dart` (and Web `InMemoryLearnerRepository.recordAnswerAttempt`) keyed per-question XP on `answer_${questionId}_${record.id}`, allowing duplicate XP on repeated attempts.

2. **`FIX-P1-55` — Partial-Failure, Reload, Half-Signed-Up `/register` & Offline `signOut` Desync:**
   - Web `useLessonStore` only created an in-memory `pendingMasteryAnswer` on `requiresMastery` lessons and cleared it before `complete_lesson` / `getProfile()` settled; Mobile `_pendingMasteryAnswer` was in-memory only for `q_pilot_*`. App restarts or `F5` reloads lost pending attempts and `answeredQuestionIds` / `_passedQuestionIds`.
   - `LessonReadingPositionStore.maxSafeStepIndex` checked `step.type == LessonStepType.interactiveQuestion` without checking `step.interactiveQuestion != null` or advancing past already-passed interactive steps.
   - Web `AuthContext.signUp` and Mobile `RegisterScreen` re-invoked `auth.signUp` when a session was already established after a transient `fetchProfile` / `loadProfile` failure, stranding users on HTTP `422`.
   - Web `AuthContext.signOut('global')` threw before `clearAuthState()` when offline, and Mobile `ProfileScreen._handleLogout` threw `StateError('No auth client.')` before local cleanup when unconfigured or offline.

3. **`FIX-P2-23` — Unbounded Inputs (`54000`), Missing `CHECK` Constraints & Daily Accuracy Farming:**
   - Unbounded `p_idempotency_key` (`>2,704B` B-tree crash `54000`), `p_selected_text`, `profiles`, and `learner_profiles` columns; missing `CHECK` constraints on `learner_profiles`, `profiles`, `questions`, `lesson_progress`, `gamification_profiles`, `gamification_events`, `daily_learning_stats`, `answer_attempts`, `placement_attempts`, and `learning_sessions`; narrow `roadmap_nodes.order_index NUMERIC(4,1)`; uncapped hourly `learning_sessions` in `record_session_heartbeat`.
   - `daily_learning_stats` incremented `questions_answered` and `correct_answers` on every new attempt UUID for the same question on the same day, allowing trivial accuracy farming; Mobile `in_memory_learner_repository.dart` and Web `InMemoryLearnerRepository.ts` lacked `(activity_date, question_id)` deduplication parity.

---

## 2. Scoped Changes

### 2.1 PostgreSQL Forward Migration (`supabase/migrations/20261126000100_w1_b1_idempotency_constraints_and_daily_stats.sql`)
- Widen `public.roadmap_nodes.order_index` from `NUMERIC(4,1)` to `NUMERIC(8,2)` safely across `bilimyol_private.math_pilot_objectives` and `bilimyol_private.math_pilot_items`.
- Normalize any legacy `>128`-char `idempotency_key` rows in `answer_attempts` and `placement_attempts` using collision-free `left(idempotency_key, 58) || ':' || md5(idempotency_key) || ':' || id::TEXT` before adding `<=128` `CHECK` constraints.
- Add built-in `pg_catalog.jsonb_path_exists(...)` validation on `course_levels` and domain `CHECK` constraints across `profiles`, `learner_profiles`, `questions`, `lesson_progress`, `gamification_profiles`, `gamification_events`, `daily_learning_stats`, `answer_attempts`, `placement_attempts`, and `learning_sessions`, plus partial unique index `uq_profiles_email_nonempty` and sanitized `handle_new_user()`.
- Add `bilimyol_private.daily_question_outcomes (user_id, activity_date, question_id)` (backfilled from `public.answer_attempts`) so `daily_learning_stats` deduplicates `(user_id, activity_date, question_id)` using the latest outcome per question on that Tashkent day while preserving daily `lessons_completed` and completion `xp_earned`.
- Harden `bilimyol_private.submit_answer_attempt`, `public.submit_answer_attempt`, `public.save_placement_attempt` (`<=100` submissions), and `public.record_session_heartbeat` (keeping `NULL` when `p_idempotency_key IS NULL` instead of static payload fallback, `selected_answer` payload check on replay, curated/question explanation lookup gated strictly on `v_existing_is_correct = true`, `pg_advisory_xact_lock` + `ON CONFLICT (user_id, idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING` with replay fallback, `<=128` idempotency key & `<=4000` selected text bounds, and `<=60/hour` session cap).

### 2.2 Web (`src/`)
- `src/core/utils/attemptUuid.ts` & `src/features/lesson/lessonRecoveryStorage.ts`: RFC 4122 v4 UUID helper and user-scoped durable pending attempt (including structured/self-assessed inputs) + `answeredQuestionIds` storage (zero static seed imports, preserving `W0-B2` bundle isolation; one-way `sessionReset` cleanup).
- `src/domain/usecases/SubmitLessonAnswerUseCase.ts`, `src/domain/usecases/SubmitReinforcementUseCase.ts`, `src/data/repositories/SupabaseLearnerRepository.ts`, `src/data/repositories/InMemoryLearnerRepository.ts`: Per-attempt UUIDs, replay payload verification, per-question XP cap, and `(date, questionId)` daily activity deduplication + daily `lessonsCompleted` / completion `xpEarned` parity.
- `src/app/store/useLessonStore.ts`, `src/app/store/useRoadmapStore.ts`, `src/features/lesson/readingPosition.ts`, `src/features/lesson/InteractiveLessonView.tsx`: Durable pending attempt & UI input recovery across timeouts, mid-RPC navigation, `complete_lesson` / `complete_reinforcement` partial failures, and `F5` reloads; unified Demo reading-position scope (`demo`) + `sessionReset` cleanup; persisted `answeredQuestionIds` and safe step clamping past answered checkpoints.
- `src/core/context/AuthContext.tsx`: Recover existing half-signed-up session in `signUp` without re-triggering `422` (and purge stale session if user switches email), sanitize `avatar_url`, and guarantee local `clearAuthState()` + local GoTrue token wipe in `signOut` `finally` even when `global` logout fails offline.

### 2.3 Flutter Mobile (`mobile/`)
- `mobile/lib/core/storage/local_storage_service.dart`, `mobile/lib/features/lesson/reading_position.dart`: User-scoped durable pending attempt + passed question IDs persistence; `maxSafeStepIndex` checking `step.interactiveQuestion != null` and advancing past passed questions (including `requiresMastery` lessons outside active reinforcement).
- `mobile/lib/domain/repositories/i_learner_repository.dart`, `mobile/lib/domain/usecases/submit_lesson_answer_use_case.dart`, `mobile/lib/domain/usecases/submit_reinforcement_use_case.dart`, `mobile/lib/data/repositories/supabase_learner_repository.dart`, `mobile/lib/data/repositories/in_memory_learner_repository.dart`: Per-attempt UUID v4 across lesson & reinforcement flows, `idempotencyKey` + `answer_correct_<questionId>` XP parity + `Asia/Tashkent` `(date, questionId)` daily stats deduplication and `lessonsCompleted` / `xpEarned` parity in `InMemoryLearnerRepository`, sanitized `avatar_url`, and `DailyActivitySummary` fields (`questionsAnswered`, `correctAnswers`, `accuracyPercent`).
- `mobile/lib/app/providers.dart`, `mobile/lib/core/auth/secure_auth_storage.dart`, `mobile/lib/core/config/supabase_config.dart`, `mobile/lib/features/auth/register_screen.dart`, `mobile/lib/features/profile/profile_screen.dart`: Durable `'submitting' -> 'graded'` pending attempt & `_passedQuestionIds` + UI input recovery across restarts and `complete_lesson` / `complete_reinforcement` retries; half-signed-up `/register` recovery (plus stale session purge on email switch); guaranteed local logout cleanup (`forceLocalSignOutCleanup` + `purgePersistedAuthArtifacts`) when offline or unconfigured.

---

## 3. Verification Gates (TDD Red → Green)

1. `supabase/tests/w1_b1_idempotency_constraints_and_daily_stats_regression.sql` + all 9 existing SQL regression suites + `2x` migration idempotency + 2-session `READ COMMITTED` concurrency test on disposable PostgreSQL `17.11`.
2. `src/__tests__/W1B1CoreLearningIntegrity.test.tsx` + `npm run typecheck`, `npm run typecheck:tests`, `npm run lint`, `npm test`, `npm run build`, `npm run test:e2e`.
3. `mobile/test/features/w1_b1_core_learning_integrity_test.dart` + `flutter analyze --fatal-infos`, `flutter test`.
