# BilimYo‘l Smart Edu — Cumulative Engineering Remediation Progress Tracker

- **Repository:** `PirimovUktam/bilimyol-smart-edu`
- **Implementation Worktree:** `C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_1_b2_cefr_sql_grading_parity` (`fix/wave-1-b2-cefr-sql-grading-parity`, continuing from `fix/wave-1-b1-core-learning-integrity` @ `5376a0cf4f0cef005c7e28ab13bf518318e6fed8`)
- **Baseline Audit Commit (`READ-ONLY`):** `5c22343b2246dedcee7866cd11931c48346cf65c`
- **Baseline Composite Score (Preserved):** **`49.28 / 100` (`NO-GO`)** — *score is NOT inflated before full cross-wave remediation + staging/production verification*
- **Latest Executed Batch:** **Wave 1 · Batch `W1-B2`** (`FIX-P0-01`, `FIX-P1-40` `FIXED_LOCAL`; `FIX-P0-26` remains `BLOCKED — RELEASE SIGNING CREDENTIALS MISSING` from `W0-B4`)
- **Status Taxonomy:** `OPEN` | `IN_PROGRESS` | `FIXED_LOCAL` | `VERIFIED_STAGING` | `VERIFIED_PRODUCTION` | `BLOCKED`

> [!NOTE]
> Completed Wave 0 & Wave 1 (`W1-B1`, `W1-B2`) items (`FIX-P0-27`, `FIX-P0-28`, `FIX-P2-22`, `FIX-P0-23`, `FIX-P0-25`, `FIX-P1-44`, `FIX-P1-48`, `FIX-P2-11`, `FIX-P0-24`, `FIX-P1-55`, `FIX-P2-23`, `FIX-P0-01`, `FIX-P1-40`) are marked strictly **`FIXED_LOCAL`** based on local test, build, disposable PostgreSQL `17.11`, Deno, Flutter, Android Gradle, and E2E verification. `FIX-P0-26` remains **`BLOCKED`** (`BLOCKED — RELEASE SIGNING CREDENTIALS MISSING`) until real production keystore and CI secrets are provisioned. Zero items are claimed `VERIFIED_STAGING` or `VERIFIED_PRODUCTION`.

---

## 1. Summary Counts by Severity

| Original Severity | Total Findings | `FIXED_LOCAL` | `VERIFIED_STAGING` | `VERIFIED_PRODUCTION` | `OPEN` | `BLOCKED` |
|---|---:|---:|---:|---:|---:|---:|
| `P0` | 28 | 6 | 0 | 0 | 21 | 1 |
| `P1` | 55 | 4 | 0 | 0 | 51 | 0 |
| `P2` | 30 | 3 | 0 | 0 | 27 | 0 |
| `P3` | 8 | 0 | 0 | 0 | 8 | 0 |
| **Total** | **121** | **13** | **0** | **0** | **107** | **1** |

---

## 2. Summary Counts by Wave & Batch

| Wave | Batches (`FIXED_LOCAL` / Total) | Total Findings | `FIXED_LOCAL` | `OPEN` | `BLOCKED` | Status |
|---|---|---:|---:|---:|---:|---|
| **Wave 0** | `W0-B1` (3/3), `W0-B2` (1/1), `W0-B3` (3/3), `W0-B4` (1/2, 1 `BLOCKED`) | 9 | 8 | 0 | 1 | Wave 0 Local Hardening Complete (`FIX-P0-26` Real Signing `BLOCKED` on Secrets) |
| **Wave 1** | `W1-B1` (3/3), `W1-B2` (2/2), `W1-B3` (0/8), `W1-B4` (0/7) | 20 | 5 | 15 | 0 | In Progress (`W1-B1`, `W1-B2` `FIXED_LOCAL`; `W1-B3` Next) |
| **Wave 2** | `W2-B1` (0/4), `W2-B2` (0/5), `W2-B3` (0/6), `W2-B4` (0/9) | 24 | 0 | 24 | 0 | Not Started |
| **Wave 3** | `W3-B1` (0/5), `W3-B2` (0/5), `W3-B3` (0/4) | 14 | 0 | 14 | 0 | Not Started |
| **Wave 4** | `W4-B1` (0/4), `W4-B2` (0/6), `W4-B3` (0/6) | 16 | 0 | 16 | 0 | Not Started |
| **Wave 5** | `W5-B1` (0/4), `W5-B2` (0/7), `W5-B3` (0/6), `W5-B4` (0/5) | 22 | 0 | 22 | 0 | Not Started |
| **Wave 6** | `W6-B1` (0/3), `W6-B2` (0/1), `W6-B3` (0/6), `W6-B4` (0/6) | 16 | 0 | 16 | 0 | Not Started |
| **Total** | **26 Atomic Batches** | **121** | **13** | **107** | **1** | **13 / 121 Fixed Locally, 1 / 121 Blocked** |

---

## 3. Complete Canonical Findings Ledger (`121` Unique Findings: `FIX-P0-01`..`FIX-P3-08`)

| Finding ID | Original Severity | Assigned Wave/Batch | Current Status | Fix Commit | Regression Evidence | Reviewer Verdict | Remaining Verification |
|---|---|---|---|---|---|---|---|
| `FIX-P0-01` | `P0` | `W1-B2` | `FIXED_LOCAL` | `fix/wave-1-b2-cefr-sql-grading-parity` (`708f8d3` + review hardening) | PG 17.11 migration `20261127000100` (`33` CEFR A1-B1 lessons + `31` nodes seeded with `SEED_LESSONS` option permutation, `learner_lessons` `unlocked_math_lesson_ids` single-CTE rewrite `0` `OFFSET 0`, `admin_save_lesson` JSON-null safe preservation, `sanitize_learner_content` stripping `acceptedAnswers`/`explanationRu`/`mistakeFeedbackByOption` & scrambling `orderedTokens`/`matchPairs` without Web double-permutation, 9-mode + `alternate_exercise` server grading; `2x` idempotency + `11/11` SQL suites x2 postures = `22/22` runs); Web `SupabaseLessonRepository.ts`, `InteractiveLessonView.tsx`, `ReinforcementModal.tsx` (`W1B2CefrSqlAndGradingParity.test.tsx` 5/5, `61/61` Vitest, `365/365` tests); Mobile `supabase_lesson_repository.dart` `select('*')` (`w1_b2_cefr_sql_and_grading_parity_test.dart` 5/5, `532` passed / `2` skips) | Independent skeptical reviewer (`W1-B2`): 7 issues found & fixed, re-verified `GREEN` | Staging & production Supabase migration `20261127000100` apply + live end-to-end verification (`UNVERIFIED`) |
| `FIX-P0-02` | `P0` | `W1-B3` | `OPEN` | — | — | — | Implement in `W1-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-03` | `P0` | `W1-B4` | `OPEN` | — | — | — | Implement in `W1-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-04` | `P0` | `W2-B2` | `OPEN` | — | — | — | Implement in `W2-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-05` | `P0` | `W2-B2` | `OPEN` | — | — | — | Implement in `W2-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-06` | `P0` | `W2-B3` | `OPEN` | — | — | — | Implement in `W2-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-07` | `P0` | `W2-B3` | `OPEN` | — | — | — | Implement in `W2-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-08` | `P0` | `W3-B2` | `OPEN` | — | — | — | Implement in `W3-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-09` | `P0` | `W2-B3` | `OPEN` | — | — | — | Implement in `W2-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-10` | `P0` | `W2-B1` | `OPEN` | — | — | — | Implement in `W2-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-11` | `P0` | `W1-B3` | `OPEN` | — | — | — | Implement in `W1-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-12` | `P0` | `W1-B4` | `OPEN` | — | — | — | Implement in `W1-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-13` | `P0` | `W2-B1` | `OPEN` | — | — | — | Implement in `W2-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-14` | `P0` | `W2-B2` | `OPEN` | — | — | — | Implement in `W2-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-15` | `P0` | `W2-B1` | `OPEN` | — | — | — | Implement in `W2-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-16` | `P0` | `W3-B1` | `OPEN` | — | — | — | Implement in `W3-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-17` | `P0` | `W3-B2` | `OPEN` | — | — | — | Implement in `W3-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-18` | `P0` | `W3-B1` | `OPEN` | — | — | — | Implement in `W3-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-19` | `P0` | `W5-B1` | `OPEN` | — | — | — | Implement in `W5-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-20` | `P0` | `W5-B1` | `OPEN` | — | — | — | Implement in `W5-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-21` | `P0` | `W5-B2` | `OPEN` | — | — | — | Implement in `W5-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-22` | `P0` | `W5-B2` | `OPEN` | — | — | — | Implement in `W5-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-23` | `P0` | `W0-B2` | `FIXED_LOCAL` | `08a2004`, `00fa3a9` | Web `W0B2BundleAnswerKeyIsolation.test.ts` (6/6), Vitest (56/56 files, 342/342 tests), `tsc` (0), `oxlint` (0 errors), `vite build` (`index` 160.17 kB, 0 preloaded answer keys, flashcards <25 kB, all chunks <500 kB, 0 warnings); Deno (2/2); PG 17.11 W0-B1 gate + Flutter passed | `spec-reviewer` (`3b31d323`): `COMPLIANT`; `final-reviewer` (`2808834f`): `APPROVED`; `research` (`ef01612e`): `PASS`; `re-reviewer` (`5d3d54ce`): `ALL ADDRESSED — APPROVED` | Staging/production CDN deploy asset & network-waterfall verification + Wave 4 compile-time demo bundle removal |
| `FIX-P0-24` | `P0` | `W1-B1` | `FIXED_LOCAL` | `fix/wave-1-b1-core-learning-integrity` (`1464250` + review hardening) | PG 17.11 (`29/29` Cloud & Legacy migrations + `2x` idempotency + legacy `>128`-char collision guard, `10/10` SQL suites x2 postures incl. `w1_b1_idempotency_constraints_and_daily_stats_regression.sql`, 2-session `READ COMMITTED` duplicate-UUID race `attempts=1, gp_xp=2, events=1`); Web `W1B1CoreLearningIntegrity.test.tsx` (5/5), Vitest (`60/60` files, `360/360` tests), `typecheck` & `typecheck:tests` (0), `lint` (0 err), `build` (`0` warnings), `test:e2e` (0); Flutter `w1_b1_core_learning_integrity_test.dart` (7/7), `flutter analyze --fatal-infos` (0), `flutter test --no-pub` (`528` passed, `2` skips) | Independent skeptical reviewer (`W1-B1`): 7 issues found & fixed, re-verified `GREEN` | Staging & production Supabase migration `20261126000100` apply + live end-to-end verification (`UNVERIFIED`) |
| `FIX-P0-25` | `P0` | `W0-B3` | `FIXED_LOCAL` | `f4972ae`, `8ab11ed`, `02435d2`, `5e85b79`, `32ad3c6` | Web `W0B3AuthSessionAndRecoveryIsolation.test.tsx` (5/5), Vitest (57/57 files, 347/347 tests), `tsc` (0), `oxlint` (0 errors), `vite build` (0 warnings, 0 preloaded answer keys); Flutter `w0_b3_account_isolation_and_secure_storage_test.dart` (15/15 incl. GoRouter & standalone `ResetPasswordScreen._save()`), `flutter analyze --fatal-infos` (0), `flutter test` (`514` passed, `2` offline skips); Deno (`2/2`); PG 17.11 (`18/18` SQL suites) | `spec-reviewer` (`0a6dea03`, `2e5629d3` -> `re-reviewer` `f07f4c3e`, `31c91577`): `COMPLIANT`/`APPROVE`; `code-reviewer` (`9bd1a397` -> `b0e57a13`, `c1bc561e`, `d0a468f4` -> `459fd74c`): `APPROVE`; `teamwork_auditor` (`d57308b0`): `CLEAN`; `final-reviewer` (`9f5ddc48`): `APPROVED` | Staging/production multi-account & `/reset-password` browser/device E2E verification against deployed Supabase (`FIXED_LOCAL` only) |
| `FIX-P0-26` | `P0` | `W0-B4` | `BLOCKED` | `fix/wave-0-b4-release-ci-tests` (`fix: harden Android release pipeline and test infrastructure`) | Local hardening & fail-closed verified (`W0B4ReleasePipelineAndSecurity` 6/6, `W0B4DomTestInfra` 2/2, `npm test` 59/59 & 355/355, `typecheck` 0, `typecheck:tests` 0, `lint` 0 err, `build` 0, `test:e2e` 0; `flutter analyze --fatal-infos` 0, `flutter test` 521 passed / 2 skips, `w0_b4_release_config_and_demo_guard_test` 7/7; Gradle `:app:signingReport` `Config: null`, release/R8/bundle tasks fail-closed; disposable-keystore R8 APK 79.6MB + `mapping.txt` 23MB + `apksigner` verified; CI PyYAML + 22x `bash -n` + `release_gate` JWT sim; 0/16 bug-codifying suites modified, 15 owned by `W1`–`W5`) | `spec-reviewer`: `APPROVE`; `code-reviewer`: `APPROVE`; `qa-reviewer`: `APPROVE`; `security-reviewer`: `REQUEST_CHANGES` -> `security-reviewer-r2`: `APPROVE`; `teamwork_challenger`: `ISSUES_FOUND` -> remediated; `teamwork_auditor`: `CLEAN` -> `r2`: `CLEAN`; `final-reviewer`: `APPROVE` | **`BLOCKED — RELEASE SIGNING CREDENTIALS MISSING`**: provision GitHub Secrets (`ANDROID_KEYSTORE_*`, `SUPABASE_*`), verify real-signed CI `mobile-release` APK (`apksigner`), extract real cert SHA-256 for `assetlinks.json`, and remediate 15 deferred bug-codifying suites in `W1`–`W5` |
| `FIX-P0-27` | `P0` | `W0-B1` | `FIXED_LOCAL` | `10a652a`, `6040f39` (`2028245`) | PG 17.11 (27/27 Cloud & Legacy migrations, 2x idempotency, 16/16 SQL suites, 16-worker concurrency 0 deadlocks); Web (`W0B1ReinforcementResolution` + full Vitest); Flutter (`w0_b1_reinforcement_resolution_test` + 499 passed / 2 skipped); Deno (2/2) | `re-reviewer` (`e74a556a`): `ALL ADDRESSED — APPROVED`; `spec-reviewer` (`406922c2`): `COMPLIANT` | Staging & production Supabase migration apply + live RPC/Edge verification (NOT deployed yet) |
| `FIX-P0-28` | `P0` | `W0-B1` | `FIXED_LOCAL` | `10a652a`, `6040f39` (`2028245`) | PG 17.11 (27/27 Cloud & Legacy migrations, 2x idempotency, 16/16 SQL suites, 16-worker concurrency 0 deadlocks); Web (`W0B1ReinforcementResolution` + full Vitest); Flutter (`w0_b1_reinforcement_resolution_test` + 499 passed / 2 skipped); Deno (2/2) | `re-reviewer` (`e74a556a`): `ALL ADDRESSED — APPROVED`; `spec-reviewer` (`406922c2`): `COMPLIANT` | Staging & production Supabase migration apply + live RPC/Edge verification (NOT deployed yet) |
| `FIX-P1-01` | `P1` | `W1-B4` | `OPEN` | — | — | — | Implement in `W1-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-02` | `P1` | `W3-B1` | `OPEN` | — | — | — | Implement in `W3-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-03` | `P1` | `W4-B3` | `OPEN` | — | — | — | Implement in `W4-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-04` | `P1` | `W5-B3` | `OPEN` | — | — | — | Implement in `W5-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-05` | `P1` | `W2-B4` | `OPEN` | — | — | — | Implement in `W2-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-06` | `P1` | `W2-B4` | `OPEN` | — | — | — | Implement in `W2-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-07` | `P1` | `W1-B3` | `OPEN` | — | — | — | Implement in `W1-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-08` | `P1` | `W1-B4` | `OPEN` | — | — | — | Implement in `W1-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-09` | `P1` | `W1-B3` | `OPEN` | — | — | — | Implement in `W1-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-10` | `P1` | `W2-B2` | `OPEN` | — | — | — | Implement in `W2-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-11` | `P1` | `W2-B3` | `OPEN` | — | — | — | Implement in `W2-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-12` | `P1` | `W4-B2` | `OPEN` | — | — | — | Implement in `W4-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-13` | `P1` | `W6-B3` | `OPEN` | — | — | — | Implement in `W6-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-14` | `P1` | `W1-B3` | `OPEN` | — | — | — | Implement in `W1-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-15` | `P1` | `W2-B2` | `OPEN` | — | — | — | Implement in `W2-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-16` | `P1` | `W1-B3` | `OPEN` | — | — | — | Implement in `W1-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-17` | `P1` | `W1-B4` | `OPEN` | — | — | — | Implement in `W1-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-18` | `P1` | `W1-B4` | `OPEN` | — | — | — | Implement in `W1-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-19` | `P1` | `W1-B4` | `OPEN` | — | — | — | Implement in `W1-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-20` | `P1` | `W2-B1` | `OPEN` | — | — | — | Implement in `W2-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-21` | `P1` | `W2-B3` | `OPEN` | — | — | — | Implement in `W2-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-22` | `P1` | `W2-B3` | `OPEN` | — | — | — | Implement in `W2-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-23` | `P1` | `W2-B4` | `OPEN` | — | — | — | Implement in `W2-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-24` | `P1` | `W2-B4` | `OPEN` | — | — | — | Implement in `W2-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-25` | `P1` | `W3-B1` | `OPEN` | — | — | — | Implement in `W3-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-26` | `P1` | `W3-B3` | `OPEN` | — | — | — | Implement in `W3-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-27` | `P1` | `W3-B3` | `OPEN` | — | — | — | Implement in `W3-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-28` | `P1` | `W3-B2` | `OPEN` | — | — | — | Implement in `W3-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-29` | `P1` | `W3-B3` | `OPEN` | — | — | — | Implement in `W3-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-30` | `P1` | `W3-B2` | `OPEN` | — | — | — | Implement in `W3-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-31` | `P1` | `W5-B2` | `OPEN` | — | — | — | Implement in `W5-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-32` | `P1` | `W5-B1` | `OPEN` | — | — | — | Implement in `W5-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-33` | `P1` | `W4-B3` | `OPEN` | — | — | — | Implement in `W4-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-34` | `P1` | `W5-B2` | `OPEN` | — | — | — | Implement in `W5-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-35` | `P1` | `W5-B2` | `OPEN` | — | — | — | Implement in `W5-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-36` | `P1` | `W4-B1` | `OPEN` | — | — | — | Implement in `W4-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-37` | `P1` | `W4-B1` | `OPEN` | — | — | — | Implement in `W4-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-38` | `P1` | `W4-B2` | `OPEN` | — | — | — | Implement in `W4-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-39` | `P1` | `W4-B2` | `OPEN` | — | — | — | Implement in `W4-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-40` | `P1` | `W1-B2` | `FIXED_LOCAL` | `fix/wave-1-b2-cefr-sql-grading-parity` (`708f8d3` + review hardening) | Unified JSON `p_selected_text` wire format across Web (`useLessonStore.ts`, `ReinforcementModal.tsx`) & Flutter (`SubmitLessonAnswerUseCase`, `SubmitReinforcementUseCase`, `LessonSessionNotifier`); multi-skill step, `alternate_exercise`, & multi-skill parent-remediation completion in `public.complete_lesson` / `public.complete_reinforcement`; anti-spoiler non-MCQ `wrongFeedback` + `service_role` vs `authenticated` separation in `tutor_mistake_context` / `get_mistake_feedback`; `<28% -> >=50%` clearance in `complete_reinforcement` & `RouteEngine` (`22/22` PG17 SQL runs, `61/61` Vitest [`365/365` tests], `532` Flutter tests incl. `5/5` `W1B2` & `T3.11`, `test:e2e` 0) | Independent skeptical reviewer (`W1-B2`): 7 issues found & fixed, re-verified `GREEN` | Staging & production cross-platform RPC & reinforcement verification (`UNVERIFIED`) |
| `FIX-P1-41` | `P1` | `W4-B3` | `OPEN` | — | — | — | Implement in `W4-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-42` | `P1` | `W4-B1` | `OPEN` | — | — | — | Implement in `W4-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-43` | `P1` | `W6-B1` | `OPEN` | — | — | — | Implement in `W6-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-44` | `P1` | `W0-B3` | `FIXED_LOCAL` | `bb65c3c`, `f4972ae`, `e221439` | Web `flowType: 'pkce'` (`W0B3AuthSessionAndRecoveryIsolation.test.tsx`, `57/57` Vitest); Flutter `flutter_secure_storage` `10.3.1` (`--offline`), `SecureAuthStorageCoordinator` + iOS uninstall Keychain purge + `MissingPluginException` test-only gate + `uz.bilimyol.mobile` IDs + `android:allowBackup="false"` (`flutter analyze --fatal-infos` 0, `514` passed / `2` offline skips); `config.toml` redirect/PKCE alignment | `spec-reviewer` (`0a6dea03`, `77e83062`, `31c91577`): `COMPLIANT`; `code-reviewer` (`9dd8b3aa`, `d0a468f4` -> `459fd74c`): `APPROVED`; `teamwork_auditor` (`d57308b0`): `CLEAN`; `final-reviewer` (`9f5ddc48`): `APPROVED` | Real Android/iOS native builds & hardware Keystore/Keychain check; OS App Links / Universal Links (`assetlinks.json` / `apple-app-site-association`) `BLOCKED` until `W0-B4` release cert SHA-256 & `W6-B2` Apple `DEVELOPMENT_TEAM`; `/callback` signup link in `W4-B2` |
| `FIX-P1-45` | `P1` | `W3-B1` | `OPEN` | — | — | — | Implement in `W3-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-46` | `P1` | `W1-B3` | `OPEN` | — | — | — | Implement in `W1-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-47` | `P1` | `W5-B4` | `OPEN` | — | — | — | Implement in `W5-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-48` | `P1` | `W0-B3` | `FIXED_LOCAL` | `bb65c3c`, `f4972ae`, `e221439`, `02435d2`, `5e85b79`, `32ad3c6` | PG 17.11 (`28/28` fresh install, `Cloud-Default` & `Legacy-Grant` `2x` idempotency, `18/18` SQL suites across `9` suites, rollback, real 2-session `READ COMMITTED` mutual demotion lock & post-lock `is_admin()` rejection, `0` postgres procs); Web `AdminContentService.getUser()` (`AdminContentQueries.test.ts` 4/4, `W0B3` 5/5); Flutter `verifyActiveSessionOrSignOut()` (`514` passed / `2` skipped); `node --check tests/e2e/supabase.mjs`; Deno (`2/2`) | `spec-reviewer` (`12a242a0`, `0a6dea03`, `77e83062`, `31c91577`): `COMPLIANT`; `code-reviewer` (`bf8086b8`, `9dd8b3aa`, `c1bc561e`, `d0a468f4` -> `459fd74c`): `APPROVED`; `teamwork_auditor` (`d57308b0`): `CLEAN`; `final-reviewer` (`9f5ddc48`): `APPROVED` | Staging & production Supabase migration apply + Hosted Supabase Cloud Auth Dashboard toggle verification (`UNVERIFIED`) + live `npm run test:e2e:supabase` & `local_supabase_test.dart` against local/staging Docker stack |
| `FIX-P1-49` | `P1` | `W4-B2` | `OPEN` | — | — | — | Implement in `W4-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-50` | `P1` | `W5-B4` | `OPEN` | — | — | — | Implement in `W5-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-51` | `P1` | `W5-B4` | `OPEN` | — | — | — | Implement in `W5-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-52` | `P1` | `W5-B3` | `OPEN` | — | — | — | Implement in `W5-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-53` | `P1` | `W5-B3` | `OPEN` | — | — | — | Implement in `W5-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-54` | `P1` | `W6-B2` | `OPEN` | — | — | — | Implement in `W6-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P1-55` | `P1` | `W1-B1` | `FIXED_LOCAL` | `fix/wave-1-b1-core-learning-integrity` (`1464250` + review hardening) | Web durable `lessonRecoveryStorage.ts` + unified Demo `readingPosition.ts` + `InteractiveLessonView.tsx` input hydration + `useLessonStore` + `useRoadmapStore` + `AuthContext` (`signUp` half-signed-up recovery, email-switch purge & offline `signOut` local wipe) (`W1B1CoreLearningIntegrity.test.tsx` 5/5, `60/60` Vitest, `test:e2e` 0); Mobile `LocalStorageService` + `LessonReadingPositionStore` (`interactiveQuestion != null`, `passedQuestionIds`, `requiresMastery`) + `LessonSessionNotifier` (`'submitting' -> 'graded'` restart cache) + `RegisterScreen` + `SupabaseConfig.forceLocalSignOutCleanup` (`w1_b1_core_learning_integrity_test.dart` 7/7, `528` passed / `2` skips) | Independent skeptical reviewer (`W1-B1`): 7 issues found & fixed, re-verified `GREEN` | Staging & production browser/device crash/reload/auth recovery verification (`UNVERIFIED`) |
| `FIX-P2-01` | `P2` | `W2-B4` | `OPEN` | — | — | — | Implement in `W2-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-02` | `P2` | `W2-B4` | `OPEN` | — | — | — | Implement in `W2-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-03` | `P2` | `W4-B3` | `OPEN` | — | — | — | Implement in `W4-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-04` | `P2` | `W2-B4` | `OPEN` | — | — | — | Implement in `W2-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-05` | `P2` | `W2-B4` | `OPEN` | — | — | — | Implement in `W2-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-06` | `P2` | `W6-B1` | `OPEN` | — | — | — | Implement in `W6-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-07` | `P2` | `W6-B3` | `OPEN` | — | — | — | Implement in `W6-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-08` | `P2` | `W4-B2` | `OPEN` | — | — | — | Implement in `W4-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-09` | `P2` | `W1-B3` | `OPEN` | — | — | — | Implement in `W1-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-10` | `P2` | `W4-B2` | `OPEN` | — | — | — | Implement in `W4-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-11` | `P2` | `W0-B4` | `FIXED_LOCAL` | `fix/wave-0-b4-release-ci-tests` (`fix: harden Android release pipeline and test infrastructure`) | Mobile `learning_start.dart` (`usesMathMastery`) + Coupling #6 (`main.dart`, `router.dart`, `providers.dart`, `welcome_screen.dart`, `login_screen.dart`, `demo_control_bar.dart`, `InMemory*`/`Supabase*` repos, `SupabaseAITutorService`, `AITutorScreen`); `w0_b4_release_config_and_demo_guard_test.dart` (7/7), `flutter analyze --fatal-infos` (0), `flutter test` (`521` passed, `2` env-gated skips), `p1_persistence_contracts_test.dart` & `w0_b3_account_isolation_and_secure_storage_test.dart` unchanged | `spec-reviewer`: `APPROVE`; `code-reviewer`: `APPROVE`; `qa-reviewer`: `APPROVE`; `security-reviewer-r2`: `APPROVE`; `teamwork_auditor_r2`: `CLEAN`; `final-reviewer`: `APPROVE` | Staging/production APK verification with live Supabase & Demo-off production config (`FIXED_LOCAL` only) |
| `FIX-P2-12` | `P2` | `W4-B3` | `OPEN` | — | — | — | Implement in `W4-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-13` | `P2` | `W2-B4` | `OPEN` | — | — | — | Implement in `W2-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-14` | `P2` | `W3-B3` | `OPEN` | — | — | — | Implement in `W3-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-15` | `P2` | `W3-B2` | `OPEN` | — | — | — | Implement in `W3-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-16` | `P2` | `W5-B1` | `OPEN` | — | — | — | Implement in `W5-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-17` | `P2` | `W5-B2` | `OPEN` | — | — | — | Implement in `W5-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-18` | `P2` | `W5-B2` | `OPEN` | — | — | — | Implement in `W5-B2`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-19` | `P2` | `W4-B1` | `OPEN` | — | — | — | Implement in `W4-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-20` | `P2` | `W4-B3` | `OPEN` | — | — | — | Implement in `W4-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-21` | `P2` | `W6-B1` | `OPEN` | — | — | — | Implement in `W6-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-22` | `P2` | `W0-B1` | `FIXED_LOCAL` | `10a652a`, `6040f39` (`2028245`) | PG 17.11 (27/27 Cloud & Legacy migrations, 2x idempotency, 16/16 SQL suites, 16-worker concurrency 0 deadlocks); Web (`W0B1ReinforcementResolution` + full Vitest); Flutter (`w0_b1_reinforcement_resolution_test` + 499 passed / 2 skipped); Deno (2/2) | `re-reviewer` (`e74a556a`): `ALL ADDRESSED — APPROVED`; `spec-reviewer` (`406922c2`): `COMPLIANT` | Staging & production Supabase migration apply + live RPC/Edge verification (NOT deployed yet) |
| `FIX-P2-23` | `P2` | `W1-B1` | `FIXED_LOCAL` | `fix/wave-1-b1-core-learning-integrity` (`1464250` + review hardening) | PG 17.11 migration `20261126000100` (collision-safe `<=128` key & `<=4000` text bounds, `CHECK` constraints across 10 tables, `roadmap_nodes.order_index NUMERIC(8,2)`, `<=100` placement cap, `<=60/hr` session cap, `bilimyol_private.daily_question_outcomes` `(user_id, activity_date, question_id)` deduplication; `10/10` SQL suites x2 postures); Web `InMemoryLearnerRepository.ts` + `SupabaseLearnerRepository.ts` (`60/60` Vitest, `360/360` tests); Mobile `in_memory_learner_repository.dart` (`Asia/Tashkent` + daily bonus parity) + `supabase_learner_repository.dart` (`528` passed / `2` skips) | Independent skeptical reviewer (`W1-B1`): 7 issues found & fixed, re-verified `GREEN` | Staging & production Supabase migration `20261126000100` apply + live constraint/telemetry verification (`UNVERIFIED`) |
| `FIX-P2-24` | `P2` | `W6-B3` | `OPEN` | — | — | — | Implement in `W6-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-25` | `P2` | `W6-B3` | `OPEN` | — | — | — | Implement in `W6-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-26` | `P2` | `W5-B4` | `OPEN` | — | — | — | Implement in `W5-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-27` | `P2` | `W5-B3` | `OPEN` | — | — | — | Implement in `W5-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-28` | `P2` | `W5-B3` | `OPEN` | — | — | — | Implement in `W5-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-29` | `P2` | `W5-B3` | `OPEN` | — | — | — | Implement in `W5-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P2-30` | `P2` | `W5-B4` | `OPEN` | — | — | — | Implement in `W5-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P3-01` | `P3` | `W6-B4` | `OPEN` | — | — | — | Implement in `W6-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P3-02` | `P3` | `W6-B4` | `OPEN` | — | — | — | Implement in `W6-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P3-03` | `P3` | `W6-B4` | `OPEN` | — | — | — | Implement in `W6-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P3-04` | `P3` | `W6-B4` | `OPEN` | — | — | — | Implement in `W6-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P3-05` | `P3` | `W6-B4` | `OPEN` | — | — | — | Implement in `W6-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P3-06` | `P3` | `W6-B3` | `OPEN` | — | — | — | Implement in `W6-B3`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P3-07` | `P3` | `W6-B4` | `OPEN` | — | — | — | Implement in `W6-B4`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P3-08` | `P3` | `W6-B3` | `OPEN` | — | — | — | Implement in `W6-B3`, pass TDD/regression gates, then verify in staging & production |

---

## 4. `W0-B4` Batch Execution Summary (`fix/wave-0-b4-release-ci-tests` — Committed Local Remediation)

- **Report:** [W0-B4_REPORT.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_0_b4_release_ci_tests/docs/implementation/wave-0/W0-B4_REPORT.md) | **Plan:** [W0-B4_IMPLEMENTATION_PLAN.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_0_b4_release_ci_tests/docs/implementation/wave-0/W0-B4_IMPLEMENTATION_PLAN.md)
- **Findings Resolved / Status:**
  - **`FIX-P2-11` (`FIXED_LOCAL`):** `usesMathMastery` (`mobile/lib/domain/personalization/learning_start.dart`) and all Coupling #6 sites now honor `demoSessionActive` in non-production while forcing production fail-closed behavior (`isDemoModeAllowed == false`).
  - **`FIX-P0-26` (`BLOCKED — RELEASE SIGNING CREDENTIALS MISSING`):** All local/CI hardening is implemented and verified locally (`mobile/android/app/build.gradle.kts` fail-closed signing + `proguard-rules.pro` R8/shrinking; `.github/workflows/ci.yml` secret-free `mobile-test` vs gated `mobile-release` with JWT `service_role` + `sb_secret_*` `release_gate`, `$RUNNER_TEMP` cleanup, and `apksigner` check; `APP_ENV=production` fail-closed + HTTPS-only + `isServiceRoleKey` in Mobile/Web; disposable-keystore R8 APK `79.6MB` + `mapping.txt` `23,021,590` bytes + `apksigner` DN `CN=BilimYol Probe QA` verified). Real-signed production APK verification and `assetlinks.json` remain `BLOCKED` until real GitHub Secrets (`ANDROID_KEYSTORE_*`, `SUPABASE_*`) are provisioned.
  - **Minimal Web DOM TDD Infra:** Installed `jsdom@^29.1.1`, `@testing-library/react@^16.3.3`, `@testing-library/jest-dom@^7.0.1` (`package-lock.json` `+817 / -0` only), DOM-guarded `src/test/setup.ts`, `tsconfig.test.json`, `testTimeout: 15000` in `vite.config.ts`, and `npm run typecheck:tests`, while preserving `vite.config.ts` `environment: 'node'` default.
  - **16-Suite Bug-Codifying Audit:** `0 / 16` modified (`1` already fixed in `W0-B1`; `15` deferred to owning `W1`–`W5` batches); `0 / 13` `W0-B1..B3` test/SQL/E2E files modified.
- **Uncontended Post-Remediation Verification Summary:**
  - **Web:** `npm run typecheck` (`0`), `npm run typecheck:tests` (`0`), `npm run lint` (`0` errors, `9` pre-existing warnings), `npm test` (`59/59` files, `355/355` tests), `npm run build` (`2380` modules, `0` warnings), `npm run test:e2e` (`42` Product Tour + `88` layout/demo + Pilot Knowledge Map checks passed), `git diff --check` (`0`).
  - **Flutter & Gradle & CI:** `flutter analyze --fatal-infos` (`0`), `flutter test --no-pub` (`521` passed, `2` env-gated skips, `0` failed), Gradle `:app:signingReport` (`Config: null`), fail-closed `:app:assembleRelease` / `:app:minifyReleaseWithR8` / `:app:signReleaseBundle` / `:app:packageReleaseBundle` (`EXIT=1` `BLOCKED — RELEASE SIGNING CREDENTIALS MISSING`), PyYAML + `22`x `bash -n` + Git Bash `release_gate` JWT simulation (`0`).
- **Next Step:** Provision GitHub Secrets (`ANDROID_KEYSTORE_*`, `SUPABASE_*`) to close `FIX-P0-26` real-signed APK verification & extract release SHA-256 for `assetlinks.json` -> begin **Wave 1 (`W1-B1`)** on approval.

---

## 5. `W1-B1` Batch Execution Summary (`fix/wave-1-b1-core-learning-integrity` — Committed Local Remediation)

- **Report:** [W1-B1_REPORT.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_1_b1_core_learning_integrity/docs/implementation/wave-1/W1-B1_REPORT.md) | **Plan:** [W1-B1_IMPLEMENTATION_PLAN.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_1_b1_core_learning_integrity/docs/implementation/wave-1/W1-B1_IMPLEMENTATION_PLAN.md) | **Audit Mirror:** [W1-B1_EXECUTION_REPORT.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_1_b1_core_learning_integrity/docs/hackathon-audit/W1-B1_EXECUTION_REPORT.md)
- **Findings Resolved (`FIXED_LOCAL`):**
  - **`FIX-P0-24` (`FIXED_LOCAL`):** Per-attempt RFC 4122 v4 UUIDs across Web and Flutter lesson + reinforcement flows, exact UUID reuse on transport retry, `pg_advisory_xact_lock` + `ON CONFLICT` serialization, `selected_answer` replay verification, non-spoiler replay explanation gating, per-question XP cap (`+2` once per `questionId`), and `Correct → Wrong → Correct` completion parity (`0` `42501` errors).
  - **`FIX-P1-55` (`FIXED_LOCAL`):** Durable user-scoped pending attempt & `answeredQuestionIds` / `_passedQuestionIds` persistence across timeouts, `complete_lesson` / `complete_reinforcement` partial failures, `F5` reloads, and app restarts; `step.interactiveQuestion != null` & `passedQuestionIds`-aware step clamping; `/register` half-signed-up session recovery without HTTP `422`; offline/unconfigured `signOut` guaranteed local cleanup.
  - **`FIX-P2-23` (`FIXED_LOCAL`):** `<=128` idempotency key and `<=4000` selected text bounds (`0` `54000` B-tree crashes), domain `CHECK` constraints across 10 tables + `roadmap_nodes.order_index NUMERIC(8,2)` + `<=60/hr` session creation cap, and `(user_id, activity_date, question_id)` daily question statistics deduplication across PostgreSQL (`bilimyol_private.daily_question_outcomes`), Web `InMemoryLearnerRepository.ts`, and Mobile `in_memory_learner_repository.dart`.
- **Verification Summary:**
  - **PostgreSQL `17.11` (Disposable Local):** `29/29` migrations + `2x` idempotency + legacy `>128`-char shared-prefix collision harness on `Cloud-Default` & `Legacy-Grant`; `10/10` SQL suites (`20/20` runs); real 2-session `READ COMMITTED` duplicate-UUID race (`attempts=1, gp_xp=2, gamification_events=1`).
  - **Web & Deno:** `npm run typecheck` (`0`), `npm run typecheck:tests` (`0`), `npm run lint` (`0` errors), `npm test` (`60/60` files, `360/360` tests), `npm run build` (`2382` modules, `0` warnings), `npm run test:e2e` (`0`), `deno check supabase/functions/yolchi-tutor/*.ts` (`0`).
  - **Flutter:** `flutter analyze --no-pub --fatal-infos` (`0`), `flutter test --no-pub test/features/w1_b1_core_learning_integrity_test.dart test/features/lesson_session_persistence_test.dart` (`18/18` [`7/7` `W1-B1` + `11/11` session persistence]), `flutter test --no-pub` (`528` passed, `2` env-gated skips, `0` failed).
- **Next Step:** Stop after `W1-B1` report; await review before `W1-B2`.

---

## 6. `W1-B2` Batch Execution Summary (`fix/wave-1-b2-cefr-sql-grading-parity` — Committed Local Remediation)

- **Report:** [W1-B2_REPORT.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_1_b2_cefr_sql_grading_parity/docs/implementation/wave-1/W1-B2_REPORT.md) | **Plan:** [W1-B2_IMPLEMENTATION_PLAN.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_1_b2_cefr_sql_grading_parity/docs/implementation/wave-1/W1-B2_IMPLEMENTATION_PLAN.md) | **Audit Mirror:** [W1-B2_EXECUTION_REPORT.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_1_b2_cefr_sql_grading_parity/docs/hackathon-audit/W1-B2_EXECUTION_REPORT.md)
- **Findings Resolved (`FIXED_LOCAL`):**
  - **`FIX-P0-01` (`FIXED_LOCAL`):** Seeded all `33` canonical CEFR A1–B1 English `lessons` and `31` `roadmap_nodes` into PostgreSQL (`20261127000100`) with deterministic `SEED_LESSONS` option permutation; rewrote `public.learner_lessons` to a single `public.unlocked_math_lesson_ids()` CTE (`0` `OFFSET 0`, `0` per-row `can_open_math_lesson` lateral loops, Coupling #2) and hardened `public.admin_save_lesson` against JSON-`null`/partial rich-column loss; hardened `public.sanitize_learner_content(JSONB)` against `acceptedAnswers`, `explanationRu`, `mistakeFeedbackByOption`, `orderedTokens` (including palindromes), and `matchPairs` leaks without Web double-permutation un-scrambling; extended `bilimyol_private.submit_answer_attempt` to grade all `9` question modes + `alternate_exercise` with non-spoiler `wrongFeedback` precedence; selected all `26` columns in Mobile `SupabaseLessonRepository.getBaseRoadmapNodes` (`select('*')`); preserved per-question `skillId`, CEFR disclaimers, and `pedagogy17` across Web & Mobile; and updated owned bug-codifying test #12 (`supabase/tests/beginner_learning_start_regression.sql:29-34,50-53`).
  - **`FIX-P1-40` (`FIXED_LOCAL`):** Standardized `p_selected_text` JSON wire format across Web and Flutter (`sentence_order` JSON token array, key-sorted `word_match` `{"<leftId>":"<selectedRightText>"}`, `self_assessed` `{"response":"...","criteria":[...]}` with sorted criterion IDs and `selectedIndex: 0`); added multi-skill step & `alternate_exercise` completion support in `public.complete_lesson`, plus multi-skill parent-remediation completion and cross-skill `alternate_exercise` `42501` deduplication in `public.complete_reinforcement`; separated `service_role` AI tutoring context (`tutor_mistake_context`) from `authenticated` non-MCQ anti-spoiler rules (`get_mistake_feedback`); and cleared `<28%` stuck `reinforcement` loops via `GREATEST(50, ...)` in `public.complete_reinforcement` and `!isReinforcementCompleted` in Web/Mobile `RouteEngine`.
- **Verification Summary:**
  - **PostgreSQL `17.11` (Disposable Local):** `30/30` migrations + `2x` idempotency + `EXPLAIN` single-CTE check on `Cloud-Default` & `Legacy-Grant`; `11/11` SQL suites (`22/22` runs, `EXIT=0`).
  - **Web & Deno:** `npm run typecheck` (`0`), `npm run typecheck:tests` (`0`), `npm run lint` (`0` errors), `npm test` (`61/61` files, `365/365` tests), `npm run build` (`2382` modules, `0` warnings), `npm run test:e2e` (`0`), `deno check supabase/functions/yolchi-tutor/*.ts` (`0`, `4/4` files).
  - **Flutter:** `flutter analyze --no-pub --fatal-infos` (`0`), `flutter test --no-pub test/features/w1_b2_cefr_sql_and_grading_parity_test.dart` (`5/5`), `flutter test --no-pub` (`532` passed, `2` env-gated skips, `0` failed).
- **Next Step:** Stop after `W1-B2` report; await review before `W1-B3`.
