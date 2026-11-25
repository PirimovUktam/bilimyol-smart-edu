# BilimYo‘l Smart Edu — Cumulative Engineering Remediation Progress Tracker

- **Repository:** `PirimovUktam/bilimyol-smart-edu`
- **Implementation Worktree:** `C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_0_critical_containment` (`fix/wave-0-critical-containment`)
- **Baseline Audit Commit (`READ-ONLY`):** `5c22343b2246dedcee7866cd11931c48346cf65c`
- **Baseline Composite Score (Preserved):** **`49.28 / 100` (`NO-GO`)** — *score is NOT inflated before full cross-wave remediation + staging/production verification*
- **Latest Completed Batch:** **Wave 0 · Batch `W0-B3`** (`FIX-P0-25`, `FIX-P1-44`, `FIX-P1-48`) — **`W0-B4` NOT started**
- **Status Taxonomy:** `OPEN` | `IN_PROGRESS` | `FIXED_LOCAL` | `VERIFIED_STAGING` | `VERIFIED_PRODUCTION` | `BLOCKED`

> [!NOTE]
> All completed Wave 0 items (`FIX-P0-27`, `FIX-P0-28`, `FIX-P2-22`, `FIX-P0-23`, `FIX-P0-25`, `FIX-P1-44`, `FIX-P1-48`) are marked strictly **`FIXED_LOCAL`** based on local test, build, SQL/Postgres 17.11, Deno, Flutter, and independent multi-reviewer verification inside `fix_wave_0_critical_containment`. Zero items are claimed `VERIFIED_STAGING` or `VERIFIED_PRODUCTION` until deployed and verified against live staging/production targets.

---

## 1. Summary Counts by Severity

| Original Severity | Total Findings | `FIXED_LOCAL` | `VERIFIED_STAGING` | `VERIFIED_PRODUCTION` | `OPEN` | `BLOCKED` |
|---|---:|---:|---:|---:|---:|---:|
| `P0` | 28 | 4 | 0 | 0 | 24 | 0 |
| `P1` | 55 | 2 | 0 | 0 | 53 | 0 |
| `P2` | 30 | 1 | 0 | 0 | 29 | 0 |
| `P3` | 8 | 0 | 0 | 0 | 8 | 0 |
| **Total** | **121** | **7** | **0** | **0** | **114** | **0** |

---

## 2. Summary Counts by Wave & Batch

| Wave | Batches (`FIXED_LOCAL` / Total) | Total Findings | `FIXED_LOCAL` | `OPEN` | Status |
|---|---|---:|---:|---:|---|
| **Wave 0** | `W0-B1` (3/3), `W0-B2` (1/1), `W0-B3` (3/3), `W0-B4` (0/2) | 9 | 7 | 2 | In Progress (`W0-B1`, `W0-B2`, `W0-B3` Complete; `W0-B4` Next) |
| **Wave 1** | `W1-B1` (0/3), `W1-B2` (0/2), `W1-B3` (0/8), `W1-B4` (0/7) | 20 | 0 | 20 | Not Started |
| **Wave 2** | `W2-B1` (0/4), `W2-B2` (0/5), `W2-B3` (0/6), `W2-B4` (0/9) | 24 | 0 | 24 | Not Started |
| **Wave 3** | `W3-B1` (0/5), `W3-B2` (0/5), `W3-B3` (0/4) | 14 | 0 | 14 | Not Started |
| **Wave 4** | `W4-B1` (0/4), `W4-B2` (0/6), `W4-B3` (0/6) | 16 | 0 | 16 | Not Started |
| **Wave 5** | `W5-B1` (0/4), `W5-B2` (0/7), `W5-B3` (0/6), `W5-B4` (0/5) | 22 | 0 | 22 | Not Started |
| **Wave 6** | `W6-B1` (0/3), `W6-B2` (0/1), `W6-B3` (0/6), `W6-B4` (0/6) | 16 | 0 | 16 | Not Started |
| **Total** | **26 Atomic Batches** | **121** | **7** | **114** | **7 / 121 Fixed Locally** |

---

## 3. Complete Canonical Findings Ledger (`121` Unique Findings: `FIX-P0-01`..`FIX-P3-08`)

| Finding ID | Original Severity | Assigned Wave/Batch | Current Status | Fix Commit | Regression Evidence | Reviewer Verdict | Remaining Verification |
|---|---|---|---|---|---|---|---|
| `FIX-P0-01` | `P0` | `W1-B2` | `OPEN` | — | — | — | Implement in `W1-B2`, pass TDD/regression gates, then verify in staging & production |
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
| `FIX-P0-24` | `P0` | `W1-B1` | `OPEN` | — | — | — | Implement in `W1-B1`, pass TDD/regression gates, then verify in staging & production |
| `FIX-P0-25` | `P0` | `W0-B3` | `FIXED_LOCAL` | `f4972ae`, `8ab11ed`, `02435d2`, `5e85b79`, `32ad3c6` | Web `W0B3AuthSessionAndRecoveryIsolation.test.tsx` (5/5), Vitest (57/57 files, 347/347 tests), `tsc` (0), `oxlint` (0 errors), `vite build` (0 warnings, 0 preloaded answer keys); Flutter `w0_b3_account_isolation_and_secure_storage_test.dart` (15/15 incl. GoRouter & standalone `ResetPasswordScreen._save()`), `flutter analyze --fatal-infos` (0), `flutter test` (`514` passed, `2` offline skips); Deno (`2/2`); PG 17.11 (`18/18` SQL suites) | `spec-reviewer` (`0a6dea03`, `2e5629d3` -> `re-reviewer` `f07f4c3e`, `31c91577`): `COMPLIANT`/`APPROVE`; `code-reviewer` (`9bd1a397` -> `b0e57a13`, `c1bc561e`, `d0a468f4` -> `459fd74c`): `APPROVE`; `teamwork_auditor` (`d57308b0`): `CLEAN`; `final-reviewer` (`9f5ddc48`): `APPROVED` | Staging/production multi-account & `/reset-password` browser/device E2E verification against deployed Supabase (`FIXED_LOCAL` only) |
| `FIX-P0-26` | `P0` | `W0-B4` | `OPEN` | — | — | — | Implement in `W0-B4`, pass TDD/regression gates, then verify in staging & production |
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
| `FIX-P1-40` | `P1` | `W1-B2` | `OPEN` | — | — | — | Implement in `W1-B2`, pass TDD/regression gates, then verify in staging & production |
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
| `FIX-P1-55` | `P1` | `W1-B1` | `OPEN` | — | — | — | Implement in `W1-B1`, pass TDD/regression gates, then verify in staging & production |
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
| `FIX-P2-11` | `P2` | `W0-B4` | `OPEN` | — | — | — | Implement in `W0-B4`, pass TDD/regression gates, then verify in staging & production |
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
| `FIX-P2-23` | `P2` | `W1-B1` | `OPEN` | — | — | — | Implement in `W1-B1`, pass TDD/regression gates, then verify in staging & production |
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
