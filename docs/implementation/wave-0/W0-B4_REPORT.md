# BilimYo‘l Smart Edu — Wave 0 · Batch `W0-B4` Implementation & Verification Report

- **Worktree:** `C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_0_b4_release_ci_tests`
- **Branch:** `fix/wave-0-b4-release-ci-tests`
- **Audit Baseline SHA (`READ-ONLY`):** `5c22343b2246dedcee7866cd11931c48346cf65c` (`NO-GO`, `49.28 / 100`)
- **Starting Checkpoint SHA (`W0-B3`):** `a86d5e43642bb9ac279e13514a5720b99952ba40` (`fix/wave-0-critical-containment`; `7 / 121` `FIXED_LOCAL`)
- **`W0-B4` Commit Status:** Single local commit (`fix: harden Android release pipeline and test infrastructure`) on `fix/wave-0-b4-release-ci-tests` (unpushed, unmerged)
- **Batch Status:**
  - **`FIX-P2-11`:** **`FIXED_LOCAL`** *(Mobile `usesMathMastery` + Coupling #6 wired to `demoSessionActive` & `isDemoModeActive`)*
  - **`FIX-P0-26`:** **`BLOCKED — RELEASE SIGNING CREDENTIALS MISSING`** *(Local/CI release keystore & production Supabase secrets absent; Android Gradle fail-closed signing, R8/ProGuard shrinking, `.github/workflows/ci.yml` secret-free PR / gated release split, `APP_ENV=production` fail-closed zero-Demo / zero-`service_role` runtime validation, disposable-keystore R8 APK + `apksigner` verification, and `W0-B4` DOM TDD infra all implemented and verified locally; `15/16` bug-codifying test suites remain owned by `W1`–`W5`)*

---

## 1. Executive Summary & Exact Scope (`W0-B4` Only)

Wave 0 · Batch `W0-B4` executes release-pipeline security hardening, `FIX-P2-11` / Coupling #6 remediation, full 16-suite bug-codifying test auditing, and minimal Web DOM TDD enabling infrastructure strictly within [W0-B4_IMPLEMENTATION_PLAN.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_0_b4_release_ci_tests/docs/implementation/wave-0/W0-B4_IMPLEMENTATION_PLAN.md):

- **Included (`W0-B4`):**
  1. **`FIX-P0-26` — Android Release Signing, R8/ProGuard, CI Hardening & `APP_ENV=production` Fail-Closed Guard:** Removed debug-keystore fallback from `release` in `mobile/android/app/build.gradle.kts`, enforced fail-closed `GradleException("BLOCKED — RELEASE SIGNING CREDENTIALS MISSING: ...")` across release/R8/bundle signing tasks, enabled `isMinifyEnabled = true` and `isShrinkResources = true` with `mobile/android/app/proguard-rules.pro` (`Flutter`, `just_audio`, `audio_session`, `androidx.media3`, `flutter_secure_storage`/Tink, `app_links`, `shared_preferences`), split `.github/workflows/ci.yml` into secret-free `mobile-test` and gated `mobile-release` with top-level `permissions: contents: read`, `concurrency:`, `$RUNNER_TEMP` secret isolation (`if: always()` cleanup), `release_gate` (`sb_secret_*` + JWT `role: "service_role"` rejection), and `apksigner` non-debug verification, and added `APP_ENV=production` fail-closed zero-Demo / HTTPS-only / `isServiceRoleKey()` enforcement in `mobile/lib/core/config/supabase_config.dart` and `src/core/config/supabase.ts`.
  2. **`FIX-P2-11` & Coupling #6:** Updated `usesMathMastery` (`mobile/lib/domain/personalization/learning_start.dart`) to check `(SupabaseConfig.isProductionEnv || !demoSessionActive.value)` and wired `isDemoModeActive` / `isDemoAllowed` across Coupling #6 (`main.dart`, `router.dart`, `providers.dart`, `welcome_screen.dart`, `login_screen.dart`, `demo_control_bar.dart`, `in_memory_*_repository.dart`, `supabase_*_repository.dart`, `supabase_ai_tutor_service.dart`, `ai_tutor_screen.dart`) plus test-setup isolation in `mobile/test/features/auth_accessibility_and_ui_test.dart:1879-1886,3517-3524`.
  3. **Minimal Web DOM TDD Infrastructure (`ENGINEERING_TRANSFORMATION_MASTER_PLAN.md:125`):** Added only `jsdom@^29.1.1`, `@testing-library/react@^16.3.3`, and `@testing-library/jest-dom@^7.0.1` (`devDependencies`), DOM-guarded `src/test/setup.ts`, `tsconfig.test.json`, `testTimeout: 15000` in `vite.config.ts` (avoiding worker-pool contention timeouts on `W0B2BundleAnswerKeyIsolation.test.ts:654`), and `npm run typecheck:tests`, while preserving `vite.config.ts` default `environment: 'node'` and all `57` existing Web test files.
  4. **Full 16-Suite Bug-Codifying Test Audit:** Inspected all `14` Stage 8 + `2` Stage 10 SQL suites in full (`0/16` modified in `W0-B4`; `1` already remediated in `W0-B1`; `15` deferred to owning `W1`–`W5` batches).
- **Explicitly Excluded / Out of Scope:**
  - `assetlinks.json` (`0` matches in `docs/hackathon-audit/`; absent from `public/.well-known/`; `AndroidManifest.xml:30-35` only registers custom scheme `uz.bilimyol.mobile://auth/reset-password`) — **`BLOCKED`** until real production release signing certificate SHA-256 is provisioned.
  - `W5-B3` (`FIX-P1-04`: exposing the 1-click Demo button on remote `LoginScreen`) — kept gated in `login_screen.dart:108,389-390`.
  - `W6-B1` (`FIX-P1-43`: migrating legacy static/SSR tests & fixing `51` pre-existing test TS errors across `15` files).
  - `W0-B1`..`W0-B3` tests, SQL suites, and production invariants, plus `W1`–`W6` production code.
  - Zero remote mutations: no `git push`, `git merge`, `git rebase`, Vercel deploy, or staging/production Supabase writes.

---

## 2. Reference Baselines & Non-Modification Verification

| Worktree / Artifact | Branch | Verified `HEAD` SHA | Status & Invariant Verification |
|---|---|---|---|
| **Original Audit Baseline** (`C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\global_ai_hackathon_jury`) | audit snapshot | `5c22343b2246dedcee7866cd11931c48346cf65c` | **Unmodified (`READ-ONLY`).** `git status --short` shows only pre-existing `?? docs/`. Composite score `49.28 / 100 (NO-GO)` preserved. |
| **`W0-B3` Completed Baseline** (`C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_0_critical_containment`) | `fix/wave-0-critical-containment` | `a86d5e43642bb9ac279e13514a5720b99952ba40` | **Unmodified.** `git status --short` is empty (clean). `7 / 121` `FIXED_LOCAL` preserved. |
| **`W0-B4` Target Worktree** (`C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_0_b4_release_ci_tests`) | `fix/wave-0-b4-release-ci-tests` | `a86d5e43642bb9ac279e13514a5720b99952ba40` | Clean branch from `W0-B3`; `0` `.agents/teamwork/` directories inside any git worktree. |

**Upstream `W0-B1`..`W0-B3` Preservation Verified (`PROTECTED_COUNT=29 DIRTY_COUNT=0`):**
- `W0-B1`: `deriveCanonicalReinforcementNodeId` in `mobile/lib/app/providers.dart` and SQL suites (`w0_b1_security_and_reinforcement_regression.sql`, `tutor_and_learning_activity_regression.sql`) untouched.
- `W0-B2`: `build.rolldownOptions.output.codeSplitting.groups` in `vite.config.ts:17-36`, `sessionReset.ts`, and `W0B2BundleAnswerKeyIsolation.test.ts` untouched; Web `e2e-offline` Demo behavior preserved for `npm run test:e2e`.
- `W0-B3`: `applicationId = "uz.bilimyol.mobile"` (`build.gradle.kts:67`), `namespace = "uz.bilimyol.bilimyol_mobile"` (`build.gradle.kts:57`), `android:allowBackup="false"` (`AndroidManifest.xml:7`), `SecureAuthStorageCoordinator`, `verifyActiveSessionOrSignOut()`, `authSessionUserIdProvider`, `postLoginHydrating`, `flowType: 'pkce'` (`src/core/config/supabase.ts`), `resolveAppRedirect` default `bool isDemoAllowed = true` (`w0_b3_account_isolation_and_secure_storage_test.dart` unchanged), and `p1_persistence_contracts_test.dart` all preserved (`0/13` `W0-B1..B3` test/SQL/E2E files modified).

---

## 3. Root Causes (`a86d5e4` Baseline Before `W0-B4`)

1. **`FIX-P0-26` — Debug-Signed Offline Release APK, Missing R8/ProGuard & Unhardened CI:**
   - `mobile/android/app/build.gradle.kts` assigned `signingConfigs.getByName("debug")` to `buildTypes.release` and left `isMinifyEnabled`/`isShrinkResources` disabled with no `proguard-rules.pro`. Running `:app:signingReport` printed `Variant: release -> Config: debug, Alias: AndroidDebugKey`.
   - `.github/workflows/ci.yml` lacked top-level `permissions`/`concurrency`, lacked job timeouts and `typecheck:tests`, ran `flutter build apk --release` inside the single `mobile` job on PRs without `--dart-define-from-file`, `--obfuscate`, `release_gate`, or signing cert validation.
   - `mobile/lib/core/config/supabase_config.dart` and `src/core/config/supabase.ts` lacked `isServiceRoleKey()` checks; Mobile lacked `APP_ENV=production` fail-closed enforcement (allowing `http://localhost` and offline Demo fallback even in production release configs).
2. **`FIX-P2-11` (`ROAD-09`) & Coupling #6 — `usesMathMastery` Ignores `demoSessionActive`:**
   - `mobile/lib/domain/personalization/learning_start.dart:8-9` gated `usesMathMastery` strictly on `SupabaseConfig.hasRemoteConfiguration` without checking `!demoSessionActive.value` or `isProductionEnv`, while `main.dart`, `router.dart`, `providers.dart`, `welcome_screen.dart`, `login_screen.dart`, `demo_control_bar.dart`, repositories, `SupabaseAITutorService`, and `AITutorScreen` coupled Demo mode to `!hasRemoteConfiguration`.
3. **Minimal Web DOM TDD Infrastructure Gap:**
   - `package.json` lacked `jsdom`, `@testing-library/react`, `@testing-library/jest-dom`, and `typecheck:tests`, preventing component DOM interaction tests (`// @vitest-environment jsdom`) in Wave 1–5 TDD cycles while keeping `vite.config.ts` default `environment: 'node'`.

---

## 4. TDD `RED` -> `GREEN` Evidence Table

| Defect / Workstream | TDD `RED` Observation (`a86d5e4` Baseline / Pre-Fix) | Verified `GREEN` Result (`W0-B4`) |
|---|---|---|
| **CI Workflow Split, `release_gate` & Web `isServiceRoleKey`** (`W0B4ReleasePipelineAndSecurity.test.ts`) | `npx vitest run` -> **`EXIT=1`** (`6/6` tests failed: missing `permissions: contents: read`, missing `mobile-test`/`mobile-release` split, `build.gradle.kts` matched `signingConfigs.getByName("debug")`, missing `proguard-rules.pro`, `isServiceRoleKey` `undefined`); Wave 2 remediation `RED` (`2/6` failed before JWT `.role` gate & extended `releaseTaskRegex`) | **`EXIT=0`** (`6/6` tests pass); PyYAML `safe_load` (`4` jobs) + `bash -n` (`22` blocks) exit `0`; Git Bash `release_gate` simulation rejects `service_role` JWTs (`rc=1`) & `sb_secret_*` (`rc=1`) and passes `anon`/`sb_publishable` (`rc=0`, `ready=true`) |
| **Android Release Signing Fail-Closed & R8/ProGuard** (`mobile/android/app/build.gradle.kts`, `proguard-rules.pro`) | `gradle.bat :app:signingReport` -> `Variant: release` printed `Config: debug`, `Alias: AndroidDebugKey`; `proguard-rules.pro` absent (`Error: Missing required file`) | `:app:signingReport` prints `Config: null, Store: null, Alias: null`; `:app:assembleRelease`, `:app:minifyReleaseWithR8`, `:app:signReleaseBundle`, `:app:packageReleaseBundle` without creds -> **`EXIT=1`** (`BLOCKED — RELEASE SIGNING CREDENTIALS MISSING`); disposable-keystore `flutter build apk --release --dart-define=APP_ENV=production --obfuscate` -> **`EXIT=0`** (`79.6MB` APK, `mapping.txt` `23,021,590` bytes, `apksigner` DN `CN=BilimYol Probe QA` != `Android Debug`) |
| **Mobile `FIX-P2-11`, Coupling #6, `APP_ENV=production`, `isServiceRoleKey` & HTTPS URL** (`w0_b4_release_config_and_demo_guard_test.dart`) | `flutter test` -> **`EXIT=1`** (compile errors: missing `isProductionEnvOverride`, `isDemoModeAllowed`, `isDemoModeActive`, `isServiceRoleKey`, `resolveAppRedirect(..., isDemoAllowed:)`); Wave 2 URL `RED` -> **`EXIT=1`** (`isValidSupabaseUrl('http://127.0.0.1:54321')` returned `true` in prod) | **`EXIT=0`** (`7/7` tests pass in `w0_b4_release_config_and_demo_guard_test.dart`; full `flutter test --no-pub`: **`521` passed, `2` env-gated offline skips, `0` failed**; `flutter analyze --fatal-infos`: `0` issues) |
| **Web DOM TDD Infra (`jsdom` + RTL + `jest-dom` + `tsconfig.test.json`)** (`W0B4DomTestInfra.test.tsx`) | `npx vitest run` -> **`EXIT=1`** (`Cannot find package 'jsdom' imported from vitest`) | **`EXIT=0`** (`2/2` real component DOM tests pass on `PasswordInput` & `Button`; `npm run typecheck:tests` exit `0`; full `npm test`: **`59/59` files, `355/355` tests passed**, Node-env suites isolated from DOM globals) |

---

## 5. Implementation & Hardening Summary

### 5.1 Android Release Signing & R8/ProGuard (`mobile/android/app/`)
- **`mobile/android/app/build.gradle.kts`:**
  - Preserves `namespace = "uz.bilimyol.bilimyol_mobile"` (`L57`) and `applicationId = "uz.bilimyol.mobile"` (`L67`).
  - Loads signing credentials from `ANDROID_KEY_PROPERTIES_PATH` / `mobile/android/key.properties` (resolving relative `storeFile` against `keyPropertiesFile.parentFile`, then `rootProject.file`, then `file`) or `ANDROID_KEYSTORE_*` environment variables, explicitly rejecting `debug.keystore` and `androiddebugkey` (case-insensitive).
  - Removes debug signing from `release`, configures `signingConfigs.create("release")` only when `hasValidReleaseSigning` is true, enables `isMinifyEnabled = true` and `isShrinkResources = true` with `proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")`.
  - Enforces `gradle.taskGraph.whenReady` with `releaseTaskRegex = Regex("^(assemble|bundle|package|sign|minify|lintVital).*Release([A-Z].*)?$|^validateSigning.*Release$")` throwing `GradleException("BLOCKED — RELEASE SIGNING CREDENTIALS MISSING: ...")` whenever release/R8/bundle signing tasks execute without valid release signing credentials.
- **`mobile/android/app/proguard-rules.pro`:**
  - Scoped keep rules (zero `-dontobfuscate` and zero wildcard `-keep class **`) covering `io.flutter.**`, `@androidx.annotation.Keep`, `com.ryanheise.just_audio.**`, `com.ryanheise.audio_session.**`, `androidx.media3.**`, `com.it_nomads.fluttersecurestorage.**`, `com.google.crypto.tink.**`, `com.llfbandit.app_links.**`, and `io.flutter.plugins.sharedpreferences.**`.

### 5.2 GitHub Actions CI Hardening (`.github/workflows/ci.yml`)
- Added top-level `permissions: contents: read` (`L8-9`) and `concurrency:` (`cancel-in-progress: true`, `L11-13`), plus `timeout-minutes` on `web` (`20`), `mobile-test` (`25`), and `mobile-release` (`30`).
- Added `npm run typecheck:tests` to `web` (`L31-32`); preserved `supabase-journey` (`L44-83`).
- Split `mobile` into:
  1. **`mobile-test`** (secret-free, runs on all PRs including forks): `flutter pub get --enforce-lockfile`, `flutter analyze --fatal-infos`, `flutter test`.
  2. **`mobile-release`** (`needs: mobile-test`, excluded from fork PRs via `if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository`): `release_gate` checks all 6 secrets (`ANDROID_KEYSTORE_*`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`), sets `ready=false` with `BLOCKED — RELEASE SIGNING CREDENTIALS MISSING` when absent, trims/case-folds `SUPABASE_ANON_KEY` and exits `1` on `sb_secret_*`, `*service_role*`, or 3-part JWT payloads with `.role == "service_role"`, decodes keystore (`tr -d '\r\n '` before `base64 -d`), writes backslash-escaped `key.properties` and `dart-defines.json` (`APP_ENV: "production"`) into `"$RUNNER_TEMP"` (`chmod 600`), builds `--obfuscate --split-debug-info="$RUNNER_TEMP/debug-info"`, verifies APK signer certificate != `Android Debug` via `apksigner verify --print-certs`, restricts `actions/upload-artifact@v4` to `steps.release_gate.outputs.ready == 'true' && github.event_name == 'push' && github.ref == 'refs/heads/main'`, and cleans up all `$RUNNER_TEMP` secret artifacts under `if: always()`.

### 5.3 Mobile `APP_ENV=production`, `FIX-P2-11` & Coupling #6 + Web `isServiceRoleKey` & DOM Infra
- **`mobile/lib/core/config/supabase_config.dart`:** Added `appEnv`, `@visibleForTesting isProductionEnvOverride`, `isProductionEnv`, `isDemoModeAllowed`, `isDemoModeActive`, `configurationError`, and `isServiceRoleKey()`. Enforced `https://`-only `isValidSupabaseUrl` when `isProductionEnv == true`, forced `demoSessionActive.value = false` in production `initialize()` and active auth sessions (`_applyAuthState`, `syncCurrentAuthState`), and rejected `service_role` keys (`hasRemoteConfiguration = false`, `isConfigured = false`).
- **`mobile/lib/domain/personalization/learning_start.dart` (`FIX-P2-11`) & Coupling #6:** Updated `usesMathMastery` to require `(SupabaseConfig.isProductionEnv || !demoSessionActive.value)` and updated `main.dart`, `router.dart` (defaulting `bool isDemoAllowed = true`), `providers.dart`, `welcome_screen.dart`, `login_screen.dart` (keeping `FIX-P1-04` gated for `W5-B3`), `demo_control_bar.dart`, `in_memory_*_repository.dart`, `supabase_*_repository.dart`, `supabase_ai_tutor_service.dart`, and `ai_tutor_screen.dart` to fail closed in production without Demo/offline fallback.
- **`src/core/config/supabase.ts`:** Exported `isServiceRoleKey()` and gated `isSupabaseConfigured` on `!isServiceRoleKey(rawSupabaseKey)` while preserving `flowType: 'pkce'` and `vite build --mode e2e-offline` Demo mode for `npm run test:e2e`.
- **Web DOM TDD Infra (`package.json`, `vite.config.ts`, `src/test/setup.ts`, `tsconfig.test.json`):** `src/test/setup.ts` dynamically loads `@testing-library/jest-dom/vitest` and `@testing-library/react` `cleanup()` strictly when `typeof window !== 'undefined' && typeof document !== 'undefined'`, leaving all Node-env suites isolated; `vite.config.ts` sets `testTimeout: 15000` so added `jsdom` pool overhead never starves existing `W0-B2` dynamic-import tests; `tsconfig.test.json` cleanly typechecks `src/test/**` and `src/__tests__/W0B4*.{ts,tsx}`.

---

## 6. Audit Summary of All 16 Bug-Codifying Test Suites (`0 / 16` Modified in `W0-B4`)

Every one of the `14` Stage 8 + `2` Stage 10 SQL bug-codifying test suites (`QA_COVERAGE_AUDIT.md:85-90`) was inspected in full (`worker_survey_2`, locked in `W0-B4_IMPLEMENTATION_PLAN.md` §5). **`0 / 16` were modified in `W0-B4`** (`1` was already remediated in `W0-B1`; `15` codify defects owned by `W1`–`W5`):

| # | Suite | Coupled Lines & Codified Defect | Contract Status | Batch Owner | `W0-B4` Action |
|---:|---|---|---|---|---|
| 1 | `src/__tests__/EnglishPlacementAdaptiveAndYolchi.test.tsx` | `L128-153,180-193` (`B1` without `B1` items, `FIX-P0-11`); `L412-417,438,953-1000` (Light badge contrast, `FIX-P0-19`); `L310,411` (`(DEFERRED)`, `FIX-P2-17`) | Broken Contract | `W1-B3`, `W5-B1`, `W5-B2` | Untouched |
| 2 | `src/__tests__/ServerScoringAndAntiCheat.test.ts` | `L52,147-153` (`1/1 = 100%` `mastered` on placement ID in lesson, `FIX-P1-09`) | Broken Contract | `W1-B3` | Untouched |
| 3 | `src/__tests__/FlashcardAndFreeText.test.tsx` | `L138` (`1/1 = 100%` starter mastery, `FIX-P1-09`) | Broken Contract | `W1-B3` | Untouched |
| 4 | `src/__tests__/LessonViewLocalization.test.tsx` | `L39,75` (Uzbek heading in `ru` mode, `FIX-P1-06`) | Broken Contract | `W2-B4` | Untouched |
| 5 | `mobile/test/domain/gemini_ai_tutor_test.dart` | `L50-67` (`L65` offline `model == 'gemini-3.6-flash'`, `FIX-P1-25`) | Broken Contract | `W3-B1` | Untouched |
| 6 | `mobile/test/domain/skill_scoring_engine_test.dart` | `L200-210` (`8/8` `A1+A2` yields `'B1'`, `FIX-P0-11`) | Broken Contract | `W1-B3` | Untouched |
| 7 | `mobile/test/domain/route_engine_test.dart` | `L217-264` (`>=80%` unstudied diagnostic marked `completed`, `FIX-P1-08`) | Broken Contract | `W1-B4` | Untouched |
| 8 | `mobile/test/e2e/e2e_harness.dart` | `L400-655` (`L537` `'"ababab"'`, `L552` typo, `L561` `Vali–Ali–Olim`, coupled options: `FIX-P0-09`, `FIX-P0-10`, `FIX-P1-22`, `FIX-P3-03`) | Broken Contract | `W2-B1`, `W2-B3`, `W6-B4` | Untouched |
| 9 | `mobile/test/e2e/tier4_journeys_test.dart` | `L82-85,304-307` (`Dashboardga O‘tish` forced exit, `FIX-P1-33`) | Broken Contract | `W4-B3`, `W2-B1` | Untouched |
| 10 | `tests/e2e/journey.mjs` | `L258` (Uzbek title in `ru` view, `FIX-P1-06`) | Broken Contract | `W2-B4` | Untouched |
| 11 | `tests/e2e/english-suite/tier1-features.mjs` | `L249-253,337-340,812-816,1100-1104` (`(DEFERRED)`, `FIX-P2-17`); `L325-336,989-990` (`B1` placement, `FIX-P0-11`) | Broken Contract | `W1-B3`, `W5-B2` | Untouched |
| 12 | `supabase/tests/beginner_learning_start_regression.sql` | `L23` (manual `UPDATE` hiding `FIX-P1-39`); `L29-33,49-52` (3-step MCQ starter, `FIX-P0-01`) | Broken Contract | `W1-B2`, `W4-B2` | Untouched |
| 13 | `supabase/tests/placement_sessions_regression.sql` | `L30-39,105-108` (`q_live_*`, `FIX-P0-02`); `L116-118` (`learner_skill_scores` pollution, `FIX-P0-02`, `FIX-P1-19`) | Broken Contract | `W1-B3` | Untouched |
| 14 | `supabase/tests/math_mastery_pilot_regression.sql` | `L61` (`4/4` unlocks `0`, `FIX-P1-08`); `L171` (Day-8 slip re-locks `nodes->1`, `FIX-P1-17`) | Broken Contract | `W1-B4` | Untouched |
| 15 | `supabase/tests/p1_persistence_regression.sql` *(Stage 10 #1)* | `L141-142` (`save_placement_attempt` writes English placement into `learner_skill_scores`, `FIX-P0-02`, `FIX-P1-19`) | Broken Contract | `W1-B3` | Untouched |
| 16 | `supabase/tests/tutor_and_learning_activity_regression.sql` *(Stage 10 #2)* | `L46-58` (`correctOption IS NULL` on 1st Math miss, `'7'` on 2nd miss) | **Fixed (`W0-B1`)** | `W0-B1` (Completed) | Untouched |

*Notes:*
- `mobile/test/features/auth_accessibility_and_ui_test.dart` (`L1879-1886`, `L3517-3524`, non-protected test file): explicitly sets `demoSessionActive.value = false` and restores `prevDemoActive`/`prevDemo` in `addTearDown` inside the two online `AITutorScreen` tests where `setUp()` (`L350`) set `demoSessionActive.value = true`; zero assertions weakened or removed.
- Pre-existing Web test TypeScript errors (`51` diagnostics across `15` files: `13` in protected `W0B1ReinforcementResolution.test.tsx` / `W0B2BundleAnswerKeyIsolation.test.ts` + `38` across `13` `W6-B1` files) remain untouched and excluded from `tsconfig.test.json` per `R3`/`R5` (`W6-B1` backlog).

---

## 7. Complete Changed Files (`31` Total in `W0-B4` Plan) & `package-lock.json` Audit

### 7.1 Modified Tracked Files (`23` Total)
1. `.github/workflows/ci.yml` — top-level `permissions`/`concurrency`, timeouts, `typecheck:tests`, secret-free `mobile-test` vs gated `mobile-release` with JWT `service_role` + `sb_secret_*` `release_gate`, `$RUNNER_TEMP` isolation, `apksigner` cert check, `push` `refs/heads/main` artifact gate, `if: always()` cleanup.
2. `mobile/android/app/build.gradle.kts` — removed debug signing on `release`, `keyPropertiesFile.parentFile` / env `signingConfigs.create("release")`, debug keystore/alias rejection, R8 minification & resource shrinking, `gradle.taskGraph.whenReady` fail-closed `GradleException`.
3. `mobile/lib/core/config/supabase_config.dart` — `appEnv`, `isProductionEnv`, `isProductionEnvOverride`, `isDemoModeAllowed`, `isDemoModeActive`, `configurationError`, `isServiceRoleKey()`, production HTTPS enforcement, zero-Demo fail-closed init.
4. `mobile/lib/domain/personalization/learning_start.dart` — `FIX-P2-11` (`SupabaseConfig.isProductionEnv || !demoSessionActive.value` in `usesMathMastery`).
5. `mobile/lib/main.dart` — production guard on `demoSessionActive` restore/listener.
6. `mobile/lib/app/router.dart` — defaulted `bool isDemoAllowed = true` on `resolveAppRedirect`, wired `effectiveDemoActive` and `isProductionEnv`.
7. `mobile/lib/app/providers.dart` — updated `_resolveCurrentAuthSessionScope()`, `aiTutorServiceProvider`, and `_completeLesson` to use `isProductionEnv` / `isDemoModeActive`.
8. `mobile/lib/features/auth/welcome_screen.dart` — gated `hasActiveSession` demo check on `!SupabaseConfig.isProductionEnv`.
9. `mobile/lib/features/auth/login_screen.dart` — hardened `L108`/`L389-390` with `isProductionEnv` (keeping `FIX-P1-04` gated for `W5-B3`) + cleared `demoSessionActive` on real login.
10. `mobile/lib/core/widgets/demo_control_bar.dart` — branched on `SupabaseConfig.isDemoModeActive`.
11. `mobile/lib/data/repositories/in_memory_course_repository.dart` — guarded fallback on `SupabaseConfig.isDemoModeActive`.
12. `mobile/lib/data/repositories/in_memory_lesson_repository.dart` — guarded fallback on `SupabaseConfig.isDemoModeActive`.
13. `mobile/lib/data/repositories/supabase_course_repository.dart` — guarded fallback on `SupabaseConfig.isDemoModeActive`.
14. `mobile/lib/data/repositories/supabase_learner_repository.dart` — guarded capability flags and `17` methods on `SupabaseConfig.isDemoModeActive` (preserving `W0-B3` `bilimyol.srs.<uid>`).
15. `mobile/lib/data/repositories/supabase_lesson_repository.dart` — guarded fallback on `SupabaseConfig.isDemoModeActive`.
16. `mobile/lib/data/services/supabase_ai_tutor_service.dart` — failed closed (`AITutorUnavailableException`) when `!SupabaseConfig.isDemoModeActive`.
17. `mobile/lib/features/ai_tutor/ai_tutor_screen.dart` — status badge branched on `SupabaseConfig.isDemoModeActive`.
18. `mobile/test/features/auth_accessibility_and_ui_test.dart` — reset `demoSessionActive.value = false` (+ `addTearDown`) in two online `AITutorScreen` test blocks (`L1879-1886`, `L3517-3524`).
19. `package.json` — added `"typecheck:tests": "tsc -p tsconfig.test.json --noEmit"` and `devDependencies`: `@testing-library/jest-dom@^7.0.1`, `@testing-library/react@^16.3.3`, `jsdom@^29.1.1`.
20. `package-lock.json` — strictly additive (`817` insertions, `0` deletions) for those 3 devDependencies + transitive packages.
21. `src/core/config/supabase.ts` — exported `isServiceRoleKey()` and gated `isSupabaseConfigured` on `!isServiceRoleKey(rawSupabaseKey)`.
22. `vite.config.ts` — preserved `environment: 'node'` and `W0-B2` `codeSplitting.groups`; added `setupFiles: ['./src/test/setup.ts']` and `testTimeout: 15000`.
23. `docs/implementation/REMEDIATION_PROGRESS.md` — updated `W0-B4` status (`8 / 121` `FIXED_LOCAL`, `1 / 121` `BLOCKED`, `112 / 121` `OPEN`), preserving `121` total and `49.28 / 100 (NO-GO)` baseline.

### 7.2 New Files (`8` Total: `7` code/test/plan + `1` this report)
1. `docs/implementation/wave-0/W0-B4_IMPLEMENTATION_PLAN.md` — pre-implementation scope, 16-suite audit, and TDD plan.
2. `docs/implementation/wave-0/W0-B4_REPORT.md` — this implementation & verification report.
3. `mobile/android/app/proguard-rules.pro` — R8/ProGuard keep rules for Flutter and Android native plugins.
4. `mobile/test/features/w0_b4_release_config_and_demo_guard_test.dart` — `7`-test Mobile `FIX-P2-11`, Coupling #6, `APP_ENV=production`, `isServiceRoleKey`, and HTTPS URL suite.
5. `src/__tests__/W0B4ReleasePipelineAndSecurity.test.ts` — `6`-test Node-env CI, Gradle, ProGuard, and Web `isServiceRoleKey` suite.
6. `src/__tests__/W0B4DomTestInfra.test.tsx` — `2`-test `// @vitest-environment jsdom` RTL + `jest-dom` suite.
7. `src/test/setup.ts` — DOM-guarded `@testing-library/jest-dom/vitest` + `cleanup()` setup.
8. `tsconfig.test.json` — scoped TypeScript config for `src/test/**` and `src/__tests__/W0B4*.{ts,tsx}`.

### 7.3 `package-lock.json` Diff Audit & Lockfile SHA-256 Hashes
- `git diff --numstat package-lock.json` -> **`817` insertions, `0` deletions** (`61` packages added, `0` removed, `0` pre-existing package versions altered).
- `git ls-files | Select-String -Pattern "keystore|\.jks|\.p12|\.pem|key\.properties|dart-defines|secret"` -> **`0` matches**.

| File | SHA-256 (`Get-FileHash -Algorithm SHA256`) | Status |
|---|---|---|
| `package.json` | `6E43AF8322BE9BB78A5FFB01FBF25557C28D2A782CD4941D8C59DEDBE2184C13` | Updated (`typecheck:tests` + 3 devDependencies) |
| `package-lock.json` | `C51EA1A70CA3D1FAD710E96D3BE929CF0BC6CC30068A7E6060A4AE47A6B4840A` | Updated (`+817 / -0` additive only) |
| `mobile/pubspec.lock` | `A40D4802B41CA25B6541FC47D320FEDA27B7D0158EC988F9DAE8E594ABDBAA72` | **Exact Match with `W0-B3` (Unchanged)** |

---

## 8. Exact Verified Commands, Exit Codes & Counts

### 8.1 Web Uncontended Post-Remediation Verification (`worker_m5_docs` Final Run)
| Check | Exact Command | Exit Code | Exact Observed Output / Counts |
|---|---|---:|---|
| Web TypeScript | `npm run typecheck` (`tsc -b --pretty false`) | `0` | `0` errors |
| Web Test TypeScript | `npm run typecheck:tests` (`tsc -p tsconfig.test.json --noEmit`) | `0` | `0` errors |
| Web Lint | `npm run lint` (`oxlint`) | `0` | `Found 9 warnings and 0 errors. Finished in 49ms on 227 files` (all 9 warnings pre-existing `react(only-export-components)`) |
| Web Full Vitest | `npm test` (`vitest run`) | `0` | **`Test Files 59 passed (59)`, `Tests 355 passed (355)`**, Duration `12.66s` (incl. `W0B4ReleasePipelineAndSecurity` `6/6`, `W0B4DomTestInfra` `2/2`, `W0B2` `6/6`, `W0B3` `5/5`, `W0B1` `5/5`) |
| Web Production Build | `npm run build` (`tsc -b && vite build`) | `0` | `2380 modules transformed`, `built in 990ms`, `0` warnings (`dist/assets/index-kmRFlIJ1.js` `164.68 kB`) |
| Web Playwright E2E | `npm run test:e2e` (`node tests/e2e/run.mjs`) | `0` | `PRODUCT TOUR E2E PASSED — 42 verification groups passed with 0 page errors`; `E2E PASSED — 88 layout assertions and demo journeys`; `PILOT KNOWLEDGE MAP CLICK TEST PASSED` |
| Git Hygiene | `git diff --check` *(after restoring LF->CRLF touches on `mobile/{linux,macos,windows}`)* | `0` | Clean (`0` trailing whitespace / conflict marker errors) |

### 8.2 Flutter, Android Gradle & CI Verification (Post-Remediation & Disposable-Keystore R8)
| Domain / Check | Exact Command | Exit Code | Exact Observed Output / Counts |
|---|---|---:|---|
| Flutter Static (`worker_remediate_reviews`, `security_reviewer_r2`) | `Set-Location mobile; flutter analyze --fatal-infos` | `0` | `No issues found!` |
| Flutter Full Suite (`worker_remediate_reviews`) | `Set-Location mobile; flutter test --no-pub` | `0` | **`03:18 +521 ~2: All tests passed!`** (`521` passed = `514` baseline + `7` in `w0_b4_release_config_and_demo_guard_test.dart`; `2` pre-existing env-gated skips in `local_supabase_test.dart`; `0` failed) |
| Flutter Targeted `W0-B4` (`security_reviewer_r2`, `teamwork_auditor_r2`) | `flutter test --no-pub test/features/w0_b4_release_config_and_demo_guard_test.dart` | `0` | **`+7: All tests passed!`** (`7/7`) |
| Android Signing Report (`worker_remediate_reviews`, `security_reviewer_r2`) | `gradle.bat :app:signingReport --no-daemon --console=plain` | `0` | `Variant: release` prints `Config: null`, `Store: null`, `Alias: null` (zero `debug` fallback) |
| Android Debug Unit Tests (`worker_remediate_reviews`) | `gradle.bat :app:testDebugUnitTest --no-daemon --console=plain` | `0` | `BUILD SUCCESSFUL` (`NO-SOURCE`) |
| Android Fail-Closed Release / R8 / Bundle (`security_reviewer_r2`) | `gradle.bat :app:assembleRelease`, `:app:minifyReleaseWithR8`, `:app:signReleaseBundle`, `:app:packageReleaseBundle` (no creds) | `1` *(each)* | `GradleException: BLOCKED — RELEASE SIGNING CREDENTIALS MISSING: ...` on all 4 tasks |
| Android Disposable-Keystore R8 APK + `apksigner` (`qa_reviewer`, on identical `proguard-rules.pro` & R8 config) | `flutter build apk --release --dart-define=APP_ENV=production --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=... --obfuscate --split-debug-info="<temp>\symbols"` + `apksigner.bat verify --print-certs` | `0` | `Built build\app\outputs\flutter-apk\app-release.apk (79.6MB)`; `mapping.txt` generated (`23,021,590` bytes); `Signer #1 certificate DN: CN=BilimYol Probe QA` (`b21b1b14a32cf47352918013b3e5b86efb0365aca7ac41f71acf9c5d7cda94bc`, NOT `Android Debug`); temp probe deleted (`PROBE_CLEANED=True`) |
| CI YAML & Bash Syntax (`worker_remediate_reviews`, `security_reviewer_r2`) | PyYAML `yaml.safe_load` + Git Bash `bash -n` across all `22` `run:` blocks | `0` | `YAML_AND_BASH_N_OK: checked=22`; jobs `['web', 'supabase-journey', 'mobile-test', 'mobile-release']` |
| CI `release_gate` Git Bash Simulation (`security_reviewer_r2`) | Verbatim `release_gate` bash step with temp Python `jq` shim | `0`/`1` | `service_role_jwt` -> `rc=1`; `service_role_jwt_ws_case` -> `rc=1`; `sb_secret_upper_ws` -> `rc=1`; `whitespace_only_key` -> `rc=0 (ready=false)`; `anon_jwt` -> `rc=0 (ready=true)`; `sb_publishable` -> `rc=0 (ready=true)` |

---

## 9. Independent Review & Forensic Audit Summary

| Role / Round | Agent Conversation | Verdict | Notes & Resolution |
|---|---|---|---|
| **`spec-reviewer`** | `spec_reviewer` | **`APPROVE`** | `0` Critical, `0` Important (`0/16` bug-codifying suites modified, `0` `W0-B1..B3` regressions, `0` unrelated `package-lock.json` upgrades); noted M4 Gradle verification (subsequently completed by `qa-reviewer`, `worker_remediate_reviews`, `security-reviewer-r2`). |
| **`code-reviewer`** | `code_reviewer` | **`APPROVE`** | `0` Critical, `0` Important, `4` Minor defense-in-depth notes (`release_gate` JWT check & Gradle regex/relative `storeFile` subsequently remediated in Wave 2). |
| **`qa-reviewer`** | `qa_reviewer` | **`APPROVE`** | `0` Critical, `0` Important, `4` Minor notes; independently verified full Web (`59/59`, `355/355`, `build`, `test:e2e`), Flutter (`520/520` pre-Wave-2), Gradle fail-closed, and disposable-keystore R8 APK + `apksigner`. |
| **`security-reviewer` (R1 -> R2)** | `security_reviewer` -> `security_reviewer_r2` | **`REQUEST_CHANGES` -> `APPROVE`** | Round 1 raised `1` Important (`release_gate` JWT `service_role` check) + `6` Minor. Wave 2 (`worker_remediate_reviews`) remediated Finding 1 plus Minor Findings 2, 4, 5, and 6. Round 2 verified all fixes and issued **`APPROVE`** (`LOW` risk, `0` Critical, `0` Important). |
| **`teamwork_challenger`** | `teamwork_challenger` | **`ISSUES_FOUND`** *(Remediated)* | Identified `release_gate` JWT bypass (fixed in Wave 2), `build.gradle.kts` relative `storeFile`/`releaseTaskRegex` edges (fixed in Wave 2), and `W0B2` 5s timeout contention under parallel `jsdom` CPU load (documented below). |
| **`teamwork_auditor` (R1 -> R2)** | `teamwork_auditor` -> `teamwork_auditor_r2` | **`CLEAN` -> `CLEAN`** | Forensic integrity audit before and after Wave 2 remediation confirmed `0` cheating/facades, `0` leaked secrets/keystores, `0` pre-populated artifacts, and `ALL_PROTECTED_FILES_CLEAN` (`29/29`). |
| **`final-reviewer`** | `final_reviewer` (verified on final local commit `fix: harden Android release pipeline and test infrastructure`) | **`APPROVE`** | Whole-branch diff, `121`-row `REMEDIATION_PROGRESS.md`, Git/baseline isolation, and full sequential suites verified (`0` Critical, `0` Important). |

---

## 10. Explicit Caveats & Remaining Risks

1. **Release Signing Credentials Absent (`FIX-P0-26` `BLOCKED` for Real-Signed APK Verification):** No production Android release keystore or GitHub Actions production secrets exist locally, so real-signed `app-release.apk` assembly and live GitHub Actions `mobile-release` execution remain **`BLOCKED — RELEASE SIGNING CREDENTIALS MISSING`** until repository secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`) are provisioned. All Gradle fail-closed guards, R8/ProGuard rules (verified with a disposable test keystore), CI gates, and `APP_ENV=production` client fail-closed protections are implemented and verified locally.
2. **`assetlinks.json` (`BLOCKED` / Out of Scope):** Server-hosted `/.well-known/assetlinks.json` remains `BLOCKED` until the real production release signing certificate SHA-256 fingerprint is generated from the production keystore.
3. **Host Tooling (`actionlint` & Native `jq`):** `actionlint` is not installed on the Windows host (`.github/workflows/ci.yml` validated via PyYAML `safe_load` and Git Bash `bash -n` on all `22` `run:` blocks). Native `jq` is absent on Windows, so the local `release_gate` simulation used a temporary Python `jq` shim (GitHub Actions `ubuntu-latest` provides `jq` natively).
4. **`W0B2BundleAnswerKeyIsolation.test.ts:654` 5s Default Timeout Contention Resolved via `vite.config.ts` `testTimeout: 15000`:** Under `5000ms` default Vitest timeout, adding `jsdom` (`W0B4DomTestInfra.test.tsx`) + `setupFiles` pushed `W0B2BundleAnswerKeyIsolation.test.ts:654` to `5036ms`–`5063ms` under parallel 16-thread execution. Adding `testTimeout: 15000` in `vite.config.ts` eliminates that contention timeout without modifying protected `W0-B2` test files (`R3`).
5. **Pre-Existing Web Test TS Debt (`W6-B1`) & Offline Integration Skips:** `51` pre-existing TypeScript diagnostics across `15` test files (`13` in protected `W0-B1..B2` tests + `38` across `13` `W6-B1` files) remain untouched and excluded from `tsconfig.test.json`. `mobile/test/integration/local_supabase_test.dart` has `2` expected environment-gated skips when local Supabase is not running.
6. **Carried Non-Blocking Minor Notes (`security-reviewer-r2`):** `.github/workflows/ci.yml:118,172,241` uses `@v4`/`@v2` major tags on `actions/checkout`, `subosito/flutter-action`, and `actions/upload-artifact` in `mobile-release` (commit-SHA pinning recommended in `W6-B1` `FIX-P2-21`), and `profile_screen.dart:139` / `forgot_password_screen.dart:62` / `register_screen.dart:108` retain UI-only error-message wording checks while still failing closed at runtime.

---

## 11. Cumulative Status & Next-Step Recommendation

- **Baseline Audit Score Preserved:** **`49.28 / 100` (`NO-GO`)** in [REMEDIATION_PROGRESS.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_0_b4_release_ci_tests/docs/implementation/REMEDIATION_PROGRESS.md).
- **Canonical Ledger (`121` total findings):**
  - `FIXED_LOCAL`: **`8 / 121`** (`P0`: `4`, `P1`: `2`, `P2`: `2`, `P3`: `0`)
  - `BLOCKED`: **`1 / 121`** (`P0`: `1` — `FIX-P0-26` `BLOCKED — RELEASE SIGNING CREDENTIALS MISSING` for real-signed APK verification; local Gradle/R8/CI/`APP_ENV=production` hardening complete)
  - `VERIFIED_STAGING` / `VERIFIED_PRODUCTION`: **`0 / 121`**
  - `OPEN`: **`112 / 121`** (`P0`: `23`, `P1`: `53`, `P2`: `28`, `P3`: `8`)
- **Next Steps:**
  1. Provision GitHub Secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`) in repository settings to execute `mobile-release`, verify the real-signed `app-release.apk` (`apksigner verify`), and extract the production release SHA-256 fingerprint for `assetlinks.json` (`FIX-P0-26` closure).
  2. Proceed to **Wave 1 (`W1-B1`)** using `W0-B4`'s `jsdom` + `@testing-library/react` TDD harness to remediate the `15` deferred bug-codifying suites alongside their owning `W1`–`W5` batches (do NOT push/merge yet until ready).
