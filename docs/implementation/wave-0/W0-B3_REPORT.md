# BilimYo‘l Smart Edu — Wave 0 · Batch `W0-B3` Implementation & Verification Report

**Worktree:** `C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_0_critical_containment`  
**Branch:** `fix/wave-0-critical-containment`  
**Audit Baseline SHA:** `5c22343b2246dedcee7866cd11931c48346cf65c` (`NO-GO`, `49.28/100`)  
**Starting Checkpoint SHA before `W0-B3`:** `935e9aa76d508dc9ee62aa22f4f714342c6975b0` (`W0-B1`: `10a652a`, `6040f39`, `2028245`; `W0-B2`: `08a2004`, `00fa3a9`, `19e6c55`)  
**`W0-B3` Implementation Commits:** `bb65c3c`, `f4972ae`, `8ab11ed`, `e221439`, `02435d2`, `5e85b79`, `32ad3c6`  
**Local Status:** **`FIXED_LOCAL`** *(Stopped after `W0-B3`; `W0-B4` NOT started)*

---

## 1. Exact Scope (`W0-B3` Only)

Wave 0 · Batch `W0-B3` executes controlled security containment across PostgreSQL, Web, and Flutter Mobile strictly within the approved [W0-B3_IMPLEMENTATION_PLAN.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_0_critical_containment/docs/implementation/wave-0/W0-B3_IMPLEMENTATION_PLAN.md):

- **Included:** `FIX-P0-25` (Multi-Account Session Isolation, Logged-Out/Hydration Guards & `/reset-password` Lock across Web & Flutter), `FIX-P1-44` (`flutter_secure_storage` `10.3.1` token + PKCE encryption, canonical `uz.bilimyol.mobile` IDs, `android:allowBackup="false"`, redirect URI validation, and Web `flowType: 'pkce'`), and `FIX-P1-48` (PostgreSQL concurrency-safe last-admin protection, step-up `aal2` `is_admin()`, private `admin_audit_log`, `supabase/config.toml` auth hardening, E2E Mailpit confirmation alignment, Web `AdminContentService.getUser()`, and non-blocking Mobile startup revocation check).
- **Explicitly Excluded / Untouched:** `W0-B4` (`FIX-P0-26`, `FIX-P2-11`, `jsdom`, release keystore signing/R8, production `assetlinks.json`), `W1-B1` (`FIX-P1-55`), `W4-B2` (`FIX-P1-12`, `FIX-P1-39` `/callback` signup deep-link), `W6-B2` (`FIX-P1-54` Apple `DEVELOPMENT_TEAM` / `apple-app-site-association`), `package.json`, `package-lock.json`, historical `supabase/migrations/202608..20261124*.sql`, `mobile/ios/Runner/Info.plist`, `C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\global_ai_hackathon_jury` (read-only audit worktree), and remote git/cloud mutations (NO push, NO merge, NO deploy).
- **Upstream `W0-B1` & `W0-B2` Preservation:**
  - `W0-B1` privilege invariants (`20261124000100:686-692`: `PUBLIC`/`anon` revoked on `public.is_admin()`, `PUBLIC`/`anon`/`authenticated`/`service_role` revoked on `public.promote_user_to_admin(TEXT)`, `sync_profile` absent) and `deriveCanonicalReinforcementNodeId` (`mobile/lib/app/providers.dart`) remain intact.
  - `W0-B2` zero-answer-key bundle isolation (`src/core/runtime/sessionReset.ts` and `BANNED_LIVE_MODULES`) remains intact: `AuthContext.tsx` and `sessionReset.ts` perform zero static imports of `questionAnswerKeys.ts`, `InMemoryLessonRepository.ts`, `InMemoryLearnerRepository.ts`, `lessons.ts`, or `questions.ts`; cleanup handlers register one-way.

---

## 2. Finding IDs Covered

| Finding ID | Original Severity | Status after `W0-B3` | Scope Summary |
|---|---|---|---|
| `FIX-P0-25` | `P0` (`Critical`) | `FIXED_LOCAL` | Multi-account SRS/reading-position/Riverpod/Zustand isolation, logged-out & `postLoginHydrating` route/query guards, Web & Mobile `/reset-password` lock across reloads/tabs/restarts |
| `FIX-P1-44` | `P1` (`High`) | `FIXED_LOCAL` | `flutter_secure_storage` `10.3.1` (`--offline`) encrypted session & PKCE persistence, canonical `uz.bilimyol.mobile` IDs, `android:allowBackup="false"`, redirect URI validation, production `MissingPluginException` non-fallback, Web `flowType: 'pkce'` |
| `FIX-P1-48` | `P1` (`High`) | `FIXED_LOCAL` | Concurrency-safe last-admin guard (`pg_advisory_xact_lock` + `FOR UPDATE` + post-lock `is_admin()`), `aal2` MFA `is_admin()`, confirmed-email + `IF NOT FOUND` `promote_user_to_admin`, `bilimyol_private.admin_audit_log`, `config.toml` + `tests/e2e/supabase.mjs` + `local_supabase_test.dart`, Web `AdminContentService.getUser()`, Mobile `verifyActiveSessionOrSignOut()` |

---

## 3. Root Causes (`935e9aa` Baseline Before `W0-B3`)

1. **`FIX-P0-25` — Multi-Account Leakage, Logged-Out Probes, Hydration Race & Recovery Escalation:**
   - **Mobile SRS & Reading Position:** Authenticated `SupabaseLearnerRepository.recordFlashcardReview` wrote SRS cards to unscoped `SharedPreferences['bilimyol.demo_learner_snapshot']` (`clearLocalState()` was never called on logout), and `LessonReadingPositionStore.readStepIndex` checked unscoped `bilimyol-reading:<lessonId>` (`primaryKey`) ahead of `tupleKey(accountId, courseId, lessonId)` while `LessonSessionNotifier` passed `profile?.id` (`null` prior to profile hydration).
   - **Mobile Provider & Router Lifecycle:** Riverpod repositories and all 5 `StateNotifierProvider`s did not watch the active user/session scope; Demo/Recovery/background `signedOut` paths did not consistently reset `activeSessionHasStartedCourse` and local caches; `router.dart` evaluated `courseStateNotifierProvider` / `learnerStateNotifierProvider` on logged-out routes (`/welcome`, `/login`); and `LoginScreen` allowed `onAuthStateChange(signedIn)` to trigger `GoRouter.redirect` mid-login before `loadProfile()` completed, routing returning learners prematurely to `/courses`.
   - **Web & Mobile `/reset-password` Lock Bypass:** Web stored `recoveryUserId` only in a React `useRef`, `AppRouter` omitted `!isPasswordRecovery` from `hasUsableAuth` and evaluated `isShowcase || isTourView` before the recovery redirect, `ResetPasswordView` skipped `signOut()` when `isPasswordRecovery` reset on `F5`, and `AuthContext` lacked cross-tab `storage` sync and post-`updatePassword()` `amr` clearance. Mobile attached `_AuthRefreshNotifier` lazily and held `_recoveryUserId` only in RAM, losing recovery state across cold-start / restart.
   - **Web Logout Cache Residuals:** `questionAnswerKeys.ts`, `sessionStorage['bilimyol_demo_progress']`, `SupabaseLearnerRepository.fallbackRepo`, `SupabaseLessonRepository.demoRepoInstance`, and `AdminContentService.demoStores` were not wired to `sessionReset.ts`.
2. **`FIX-P1-44` — Cleartext Token/PKCE Storage, ID Divergence, Backup & Implicit Flow:**
   - `SupabaseConfig.initialize()` used default cleartext `SharedPreferences` for both `LocalStorage` (`sb-<ref>-auth-token`) and `GotrueAsyncStorage` (`supabase.auth.token-code-verifier`), lacked `https://` URL validation and `detectSessionInUriPredicate`, and omitted `android:allowBackup="false"`.
   - Android (`uz.bilimyol.bilimyol_mobile`) and iOS/macOS (`uz.bilimyol.bilimyolMobile`) diverged from canonical deep-link scheme `uz.bilimyol.mobile`, risking orphaned Keychain/Keystore sandboxes in downstream `W4-B2`/`W6-B2`.
   - Web `src/core/config/supabase.ts` omitted `flowType: 'pkce'`.
3. **`FIX-P1-48` — Sole-Admin Self-Demotion, `READ COMMITTED` Races, Weak Config & Stale JWT Acceptance:**
   - `public.admin_update_user_role` allowed a sole admin to demote themselves (`0` remaining admins), lacked `pg_advisory_xact_lock` / `FOR UPDATE` serialization and post-lock caller `is_admin()` re-verification under `READ COMMITTED`, and had no private audit log.
   - `public.is_admin()` did not enforce `aal2` when an admin had a verified MFA factor; `public.promote_user_to_admin` did not verify `email_confirmed_at IS NOT NULL` or missing `public.profiles` rows (`IF NOT FOUND`).
   - `supabase/config.toml` had `enable_confirmations = false`, `secure_password_change = false`, `minimum_password_length = 6`, `password_requirements = ""`, `email_sent = 2`, disabled password-change notifications, incomplete loopback `/reset-password` redirects, and disabled session timeboxes / TOTP MFA.
   - `AdminContentService` made `0` `supabase.auth.getUser()` calls before admin PostgREST/RPC requests, and Mobile startup performed no server-side session revocation check.

---

## 4. Before / After Reproduction (TDD `RED` & Verified `GREEN`)

| Domain & Suite | TDD `RED` Observation (`935e9aa` Baseline) | Verified `GREEN` Result (`W0-B3`) |
|---|---|---|
| **PostgreSQL `17.11`** (`supabase/tests/w0_b3_admin_and_session_regression.sql`) | `psql -v ON_ERROR_STOP=1` -> **`RED_EXIT=3`**: `ERROR: ASSERT [W0-B3]: Check 1: sole_admin_self_demote must return success=false` | **`EXIT=0`** across Fresh `28/28` install, `Cloud-Default` & `Legacy-Grant` `27->28` upgrades + `2x` idempotency, `18/18` SQL suite runs (`9/9` × `2` postures), rollback (`0` residual rows), and real 2-session `READ COMMITTED` mutual demotion race |
| **Web** (`src/__tests__/W0B3AuthSessionAndRecoveryIsolation.test.tsx`) | `npx vitest run` -> **`EXIT=1`** (`5/5` failed: `'implicit' !== 'pkce'`, missing `RECOVERY_USER_STORAGE_KEY`, missing `shouldSignOutOnRecoveryExit`, leaked `questionAnswerKeys`, `getUser` called `0` times) | **`EXIT=0`**: `5/5` tests pass (`flowType: 'pkce'`, `F5` + `INITIAL_SESSION` + cross-tab `storage` unlock, `AppRouter` lock, logout cache purge preserving `bilimyol.product_tour_completed === 'true'`, live `AdminContentService.getUser()`) |
| **Mobile Part A** (`w0_b3_account_isolation_and_secure_storage_test.dart`) | `flutter test` -> **`EXIT=1`**: missing `secure_auth_storage.dart`, `secureStorageInitializedKey`, `isValidSupabaseUrl`, `isAllowedAuthRedirectUri`, `verifyActiveSessionOrSignOut` | **`EXIT=0`**: `7/7` Part A tests pass (`SecureAuthStorageCoordinator` migration + cleartext purge, iOS fresh-install `deleteAll()`, `PlatformException` recovery, `MissingPluginException` production throw vs test-only RAM, canonical `uz.bilimyol.mobile` + `allowBackup="false"`, `refreshSession()`/`getUser()`/`TimeoutException` checks) |
| **Mobile Part B** (`w0_b3_account_isolation_and_secure_storage_test.dart`) | `flutter test` -> **`EXIT=1`**: missing `postLoginHydrating`, `authSessionUserIdProvider`, `isRecoveryActive`, `resolveAppHasStartedCourse`, `isHydratingProfile`, `getUserFlashcardSrsJson` | **`EXIT=0`**: `8/8` Part B tests pass (incl. `ResetPasswordScreen._save()` GoRouter SnackBar & standalone `_saved = true` tests `7` & `8`, totaling **`15/15`** tests in the suite) |

---

## 5. Implementation & Secure Storage Design

### 5.1 PostgreSQL Admin Hardening (`20261125000100_w0_b3_admin_role_and_session_hardening.sql`)
- Transactional `BEGIN; ... COMMIT;` migration (`SET search_path = ''` on all functions), strictly forward-only with zero mutations to historical migrations or existing `public.profiles` rows.
- **`bilimyol_private.admin_audit_log`**: Private audit table (`ENABLE ROW LEVEL SECURITY`, `REVOKE ALL FROM PUBLIC, anon, authenticated, service_role`, index `(target_user_id, created_at DESC)`), intentionally omitting a `RESTRICT` FK to `auth.users` so future user deletions never fail with `23503`.
- **`public.is_admin()`** (`PL/pgSQL`, `STABLE`, `SECURITY DEFINER`): Checks `public.profiles.role = 'admin'` and, whenever `pg_catalog.to_regclass('auth.mfa_factors') IS NOT NULL` and the caller has a row with `mf.status::TEXT = 'verified'`, requires `COALESCE(NULLIF(pg_catalog.current_setting('request.jwt.claim.aal', true), ''), (NULLIF(pg_catalog.current_setting('request.jwt.claims', true), '')::pg_catalog.jsonb ->> 'aal'), 'aal1') = 'aal2'`. Existing admins with `0` verified MFA factors remain unaffected (`0` lockout risk). Preserves `W0-B1` grants (`REVOKE ALL FROM PUBLIC, anon; GRANT EXECUTE TO authenticated, service_role;`).
- **`public.admin_update_user_role(p_user_id UUID, p_new_role TEXT)`**: Acquires `pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('bilimyol:admin_role_mutation', 0))`, deterministically locks `public.profiles` rows (`WHERE p.id IN (v_caller_id, p_user_id) OR p.role = 'admin' ORDER BY p.id FOR UPDATE`), **re-verifies `public.is_admin()` after acquiring the lock** to close the `READ COMMITTED` revoked-admin snapshot race, blocks self-demotion and `< 1` remaining admin, requires `auth.users.email_confirmed_at IS NOT NULL` when promoting to `'admin'`, sets `bilimyol.authorized_role_change = 'true'`, updates `public.profiles`, and logs to `bilimyol_private.admin_audit_log`.
- **`public.promote_user_to_admin(p_email TEXT)`**: Enforces `auth.users.email_confirmed_at IS NOT NULL`, locks `public.profiles` `FOR UPDATE` and rejects `IF NOT FOUND` prior to any audit write, logs to `bilimyol_private.admin_audit_log`, and re-applies `W0-B1` `REVOKE ALL FROM PUBLIC, anon, authenticated, service_role; GRANT EXECUTE TO postgres;`.
- **`supabase/config.toml` & E2E Alignment**: Configured `additional_redirect_urls` (`127.0.0.1` & `localhost` ports `3000`/`4173`/`5173` root + `/reset-password`, plus `uz.bilimyol.mobile://auth/reset-password`), `minimum_password_length = 8`, `password_requirements = "letters_digits"`, `email_sent = 30`, `enable_confirmations = true`, `secure_password_change = true`, `[auth.email.notification.password_changed] enabled = true`, `[auth.sessions]` (`timebox = "24h"`, `inactivity_timeout = "8h"`), and `[auth.mfa.totp]` (`enroll_enabled = true`, `verify_enabled = true`). Updated `tests/e2e/supabase.mjs` (`mailLink(email, expectedType)` filtering `type=signup` vs `type=recovery`) and `mobile/test/integration/local_supabase_test.dart` for confirmed signups.

### 5.2 Mobile Encrypted Storage & Canonical Sandbox Design (`mobile/lib/core/auth/secure_auth_storage.dart`)
- Resolved `flutter_secure_storage: ^10.0.0` (`10.3.1` in `mobile/pubspec.lock`) offline via `flutter pub get --offline`.
- **`SecureAuthStorageCoordinator`**: Single memoized `ensureInitialized()` `Future<void>` shared by both `SecureAuthLocalStorage` (`LocalStorage`) and `SecureGotrueAsyncStorage` (`GotrueAsyncStorage`, which lacks `initialize()`), eliminating dual-adapter init races.
  - Platform options: `AndroidOptions(storageNamespace: 'uz.bilimyol.mobile.secure_auth')` (avoiding deprecated `sharedPreferencesName`), `IOSOptions(accountName: 'uz.bilimyol.mobile.auth', accessibility: KeychainAccessibility.first_unlock_this_device, synchronizable: false)`, and matching `MacOsOptions`.
  - **One-Time Migration & Cleartext Purge:** Migrates `persistSessionKey`, `'${persistSessionKey}-code-verifier'`, and `'supabase.auth.token-code-verifier'` into `FlutterSecureStorage`, then removes the cleartext copies from `SharedPreferences`.
  - **iOS Fresh-Install Keychain Purge:** If `bilimyol.secure_storage_initialized_v1` is `false` and no legacy `SharedPreferences` auth keys exist (`!kIsWeb`), purges stale Keychain entries via `deleteAll()` before marking the flag `true`.
  - **Failure & Production Fallback Policy:** `PlatformException` deletes corrupted secure keys and returns `null` without cleartext fallback. `MissingPluginException` uses an instance-scoped in-memory `Map<String, String>` **strictly** when `Platform.environment['FLUTTER_TEST'] == 'true'` (or `@visibleForTesting allowInMemoryTestFallback`, with `!kIsWeb`) and **rethrows** in production (`SupabaseConfig.initialize()` fails closed with `isConfigured = false`; zero cleartext disk fallback).
- **Canonical Identifiers & Transport Validation:** Unified Android `applicationId = "uz.bilimyol.mobile"` (keeping `namespace = "uz.bilimyol.bilimyol_mobile"` so `MainActivity.kt` resolves cleanly), iOS/macOS `PRODUCT_BUNDLE_IDENTIFIER = uz.bilimyol.mobile` (`uz.bilimyol.mobile.RunnerTests`), and `android:allowBackup="false"`. Added `SupabaseConfig.isValidSupabaseUrl` (`https://` or local loopback) and callback-parameterized `isAllowedAuthRedirectUri` (`uz.bilimyol.mobile://auth/reset-password` and `https://bilimyol.uz/reset-password` requiring non-empty `code`, `access_token`, `token_hash`, or `error`).

### 5.3 Web PKCE, Recovery Lock & Zero-Seed Cache Containment (`src/`)
- **`src/core/config/supabase.ts`**: Enabled `flowType: 'pkce'`.
- **`src/core/context/AuthContext.tsx`, `ResetPasswordView.tsx`, `AppRouter.tsx`**:
  - Persists `RECOVERY_USER_STORAGE_KEY = 'bilimyol_recovery_user_id'` and `CLEARED_RECOVERY_STORAGE_KEY` in `localStorage` (with `sessionStorage` fallback), evaluates recovery before `else if (changedAccount)` so `INITIAL_SESSION` (`F5`) and cross-tab `SIGNED_IN` do not wipe recovery, and ignores bare `/reset-password` paths without recovery markers.
  - Subscribes to `window` `storage` events (`syncRecoveryFromStorage`, cleaned up on unmount) so Tab 2 immediately observes recovery unlock once Tab 1 completes `updatePassword()`, and records cleared recovery markers so historical `amr: [{ method: 'recovery' }]` claims do not re-lock the session.
  - `AppRouter.tsx` sets `hasUsableAuth = !isPasswordRecovery && isProtectedAuthReady(...)` and forces recovery redirects before `isShowcase || isTourView`; `ResetPasswordView.tsx` executes `signOut()` on exit whenever `isPasswordRecovery || done || hasSession`.
- **One-Way Session Reset & Admin `getUser()`:** Registered `clearQuestionAnswerKeys`, `SupabaseLessonRepository.clearRuntimeCache()` (including `demoRepoInstance`), `SupabaseLearnerRepository.clearSessionState()` (`fallbackRepo`, `demoReminders`, `srsQueue`, `sessionStorage['bilimyol_demo_progress']`), and `AdminContentService.clearAdminDemoStores()` into `sessionReset.ts` while preserving `localStorage['bilimyol.product_tour_completed'] === 'true'`. Added `AdminContentService.requireAdminSession()` (`supabase.auth.getUser()`) before every live PostgREST/RPC call (once before the pagination loop in `getSkillOptions`).

---

## 6. Auth Lifecycle & Concurrency Verification

1. **Mobile `authSessionUserIdProvider` & User-Scoped Storage (`02435d2`, `5e85b79`, `32ad3c6`):**
   - `authSessionUserIdProvider` watches `SupabaseConfig.authUserIdListenable`, `recoveryActiveListenable`, `authStateRevisionListenable`, and `demoSessionActive`, clearing `activeSessionHasStartedCourse`, `postLoginHydrating`, and `_fallbackRepo` on session transitions (`user-a -> null`, `user-a -> user-b`, `demo -> null`) while preserving `activeSessionHasStartedCourse` on `null -> 'demo'`. All 4 service/repository providers and all 5 `StateNotifierProvider`s watch `authSessionUserIdProvider` and gate logged-out remote reads/writes on `_isLoggedOutRemote`.
   - `SupabaseLearnerRepository` stores live SRS in user-scoped `bilimyol.srs.<uid>`, verifies `client.auth.currentUser?.id == expectedUserId` before and after async reads/writes (including post-`getProfile()`), and leaves `bilimyol.demo_learner_snapshot` untouched. `LessonReadingPositionStore` restricts reads/writes/clears strictly to `tupleKey(accountId, courseId, lessonId)` when `accountId` is non-empty.
   - `LoginScreen` sets `postLoginHydrating.value = true` before `signInWithPassword`, calls synchronous `SupabaseConfig.syncCurrentAuthState()` before clearing `postLoginHydrating` (and in `finally`), and holds `GoRouter` on `/login` until `loadProfile()` and `courseStateNotifierProvider.notifier.init()` settle.
   - `SupabaseConfig.initialize(storage: storage)` attaches the cold-start auth/recovery listener before `runApp()`, `main.dart` launches non-blocking `unawaited(SupabaseConfig.verifyActiveSessionOrSignOut())` (`10s` timeout; `refreshSession()` when `session.isExpired`, `getUser()` otherwise; local `signOut` only on `AuthException` `400`/`401`/`403` for the same `initialUserId`), and `ResetPasswordScreen._save()` captures root `ScaffoldMessenger`, `GoRouter` presence, and `ProviderScope` container before `await` so fail-closed `/login` redirect displays `s.passwordUpdatedHeading` via SnackBar while standalone non-router widgets still render `_saved = true`.
2. **PostgreSQL `READ COMMITTED` 2-Session Concurrency Proof (PG `17.11`):**
   - Pre-seeded 2 confirmed admins (`Admin A` `...0901`, `Admin B` `...0902`). Session 1 (`Admin A`) invoked `admin_update_user_role('...0902', 'student')` and held the transaction open `1.5s` before `COMMIT`.
   - Session 2 (`Admin B`) launched `300ms` later under `READ COMMITTED`, passed pre-lock `is_admin()` (`S2_PRELOCK_IS_ADMIN=true`), blocked `1398ms` on `pg_advisory_xact_lock`, and was rejected post-lock (`S2_RESULT={"message": "Ruxsat etilmagan: Administrator huquqi bekor qilingan.", "success": false}`), leaving `remaining_admins = 1`.

---

## 7. Migration & Rollback Strategy

- **Forward-Only Upgrade:** `20261125000100_w0_b3_admin_role_and_session_hardening.sql` wraps all DDL/DML inside `BEGIN; ... COMMIT;` with `CREATE TABLE IF NOT EXISTS bilimyol_private.admin_audit_log`, `CREATE INDEX IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, and idempotent `REVOKE`/`GRANT` statements. Verified safe on both `28`-migration fresh installs and `27 -> 28` upgrades (`2x` idempotent) under both `Cloud-Default` and `Legacy-Grant` postures.
- **Transactional Rollback Safety:** Verified `BEGIN; ... promote_user_to_admin ... admin_update_user_role ... ROLLBACK;` leaves `0` audit or profile side effects. If a future production rollback of `20261125000100` is ever required, deploy a forward compensating migration dropping `bilimyol_private.admin_audit_log` (if empty/archived) and restoring the prior `20261018000001` / `20261012000001` / `20260817000008` function definitions while retaining `W0-B1` `REVOKE` grants.
- **Client Rollback Safety:** Web `flowType: 'pkce'` and Mobile `SecureAuthStorageCoordinator` operate without destructive schema drops; `W0-B3` Mobile installations unify on `uz.bilimyol.mobile` prior to store release (`W4-B2`/`W6-B2`) so Keystore/Keychain containers remain consistent across upgrades.

---

## 8. Exact Changed Files (`43` Total on `fix/wave-0-critical-containment`: `935e9aa..HEAD`)

### 8.1 Planned Updated Files (`31`)

1. `supabase/config.toml` — loopbacks + `/reset-password` + `uz.bilimyol.mobile://auth/reset-password` redirects, password policy (`>=8`, `letters_digits`), `email_sent = 30`, `enable_confirmations = true`, `secure_password_change = true`, `password_changed` notification, `[auth.sessions]` timebox, `[auth.mfa.totp]`.
2. `tests/e2e/supabase.mjs` — Mailpit `expectedType` (`signup` vs `recovery`) link filtering and email confirmation for `first` and `second` users.
3. `src/core/config/supabase.ts` — `flowType: 'pkce'`.
4. `src/core/context/AuthContext.tsx` — `bilimyol_recovery_user_id` & cleared-recovery storage, `INITIAL_SESSION` / `amr` state machine, cross-tab `storage` listener (`syncRecoveryFromStorage`).
5. `src/features/auth/ResetPasswordView.tsx` — `shouldSignOutOnRecoveryExit` ensuring `signOut()` on any active-session/recovery exit.
6. `src/app/router/AppRouter.tsx` — `hasUsableAuth` gated on `!isPasswordRecovery`, recovery redirect ahead of `isShowcase || isTourView`.
7. `src/core/runtime/questionAnswerKeys.ts` — one-way `registerSessionResetHandler(clearQuestionAnswerKeys)`.
8. `src/data/repositories/SupabaseLessonRepository.ts` — `this.demoRepoInstance?.clearRuntimeCache()` inside `clearRuntimeCache()`.
9. `src/data/repositories/SupabaseLearnerRepository.ts` — `clearSessionState()` (`fallbackRepo`, `demoReminders`, `srsQueue`, `sessionStorage['bilimyol_demo_progress']`) registered via `sessionReset.ts`.
10. `src/data/services/AdminContentService.ts` — `requireAdminSession()` (`supabase.auth.getUser()`) on all live methods + `clearAdminDemoStores()` registered via `sessionReset.ts`.
11. `src/__tests__/AdminContentQueries.test.ts` — `vi.spyOn(supabase.auth, 'getUser')` mock for existing pagination tests.
12. `mobile/pubspec.yaml` — `flutter_secure_storage: ^10.0.0`.
13. `mobile/pubspec.lock` — offline resolution of `flutter_secure_storage 10.3.1` + platform bindings.
14. `mobile/android/app/build.gradle.kts` — `applicationId = "uz.bilimyol.mobile"` (retaining `namespace = "uz.bilimyol.bilimyol_mobile"`).
15. `mobile/android/app/src/main/AndroidManifest.xml` — `android:allowBackup="false"`.
16. `mobile/ios/Runner.xcodeproj/project.pbxproj` — `PRODUCT_BUNDLE_IDENTIFIER = uz.bilimyol.mobile` / `uz.bilimyol.mobile.RunnerTests` (`Info.plist` untouched).
17. `mobile/macos/Runner/Configs/AppInfo.xcconfig` — `PRODUCT_BUNDLE_IDENTIFIER = uz.bilimyol.mobile`.
18. `mobile/macos/Runner.xcodeproj/project.pbxproj` — `uz.bilimyol.mobile.RunnerTests`.
19. `mobile/lib/core/config/supabase_config.dart` — `isValidSupabaseUrl`, callback-parameterized `isAllowedAuthRedirectUri`, `SecureAuthStorageCoordinator` adapters, bounded `10s` `verifyActiveSessionOrSignOut()`, cold-start recovery tracking + `syncCurrentAuthState()`.
20. `mobile/lib/core/storage/local_storage_service.dart` — `secure_storage_initialized_v1`, `recovery_user_id`, and `bilimyol.srs.<uid>` helpers.
21. `mobile/test/integration/local_supabase_test.dart` — Mailpit `expectedType` filtering and signup confirmation handling.
22. `mobile/lib/core/auth/demo_session.dart` — `postLoginHydrating = ValueNotifier<bool>(false)`.
23. `mobile/lib/data/repositories/supabase_learner_repository.dart` — `bilimyol.srs.<uid>` persistence, logged-out/post-await/post-`getProfile()` user checks, `clearLocalState()` cleanup.
24. `mobile/lib/features/lesson/reading_position.dart` — `tupleKey`-only behavior when `accountId` is non-empty.
25. `mobile/lib/app/providers.dart` — `authSessionUserIdProvider`, `resetSessionState`, watched across repositories and all 5 `StateNotifierProvider`s (preserving `W0-B1` `deriveCanonicalReinforcementNodeId`).
26. `mobile/lib/app/router.dart` — eager `SupabaseConfig` + `postLoginHydrating` refresh listenables, logged-out `resolveAppHasStartedCourse` guard, `isHydratingProfile` redirect hold.
27. `mobile/lib/main.dart` — `LocalStorageService.load()` before `SupabaseConfig.initialize()`, `unawaited(SupabaseConfig.verifyActiveSessionOrSignOut())`.
28. `mobile/lib/features/profile/profile_screen.dart` — unified Live & Demo logout clearing recovery + awaiting `resetSessionState`.
29. `mobile/lib/features/auth/login_screen.dart` — `postLoginHydrating` lifecycle + `syncCurrentAuthState()` around `signInWithPassword` + `_handleQuickDemo()` cleanup.
30. `mobile/lib/features/auth/reset_password_screen.dart` — fail-closed `_save()` / `_leave()` session/recovery cleanup + root `ScaffoldMessenger` SnackBar confirmation across `/login` redirect (preserving standalone `_saved = true`).
31. `docs/implementation/REMEDIATION_PROGRESS.md` — updated cumulative ledger (`7 / 121` `FIXED_LOCAL`, `114 / 121` `OPEN`).

### 8.2 Flutter CLI `pub get` Generated Plugin Registrant & CMake Files (`5`, in `e221439`)

- `mobile/linux/flutter/generated_plugin_registrant.cc`
- `mobile/linux/flutter/generated_plugins.cmake`
- `mobile/macos/Flutter/GeneratedPluginRegistrant.swift`
- `mobile/windows/flutter/generated_plugin_registrant.cc`
- `mobile/windows/flutter/generated_plugins.cmake`

### 8.3 Planned New Files (`6`) + Implementation Plan (`1`)

1. `supabase/migrations/20261125000100_w0_b3_admin_role_and_session_hardening.sql` — additive PostgreSQL admin, `aal2`, and audit-log migration.
2. `supabase/tests/w0_b3_admin_and_session_regression.sql` — PG `17.11` admin guard, `aal2`, privilege, and audit regression suite.
3. `src/__tests__/W0B3AuthSessionAndRecoveryIsolation.test.tsx` — `5`-test Web PKCE, recovery lock, cache purge, and `AdminContentService.getUser()` suite.
4. `mobile/lib/core/auth/secure_auth_storage.dart` — `SecureAuthStorageCoordinator`, `SecureAuthLocalStorage`, `SecureGotrueAsyncStorage`.
5. `mobile/test/features/w0_b3_account_isolation_and_secure_storage_test.dart` — `15`-test Mobile secure storage, isolation, hydration, and recovery suite.
6. `docs/implementation/wave-0/W0-B3_REPORT.md` — this `W0-B3` implementation and verification report.
7. `docs/implementation/wave-0/W0-B3_IMPLEMENTATION_PLAN.md` — pre-implementation scope review and task plan committed locally per `R5`.

---

## 9. Exact Commands, Exit Codes & Counts

### 9.1 Full-Stack Verification (`5e85b79` — Last Web, Edge & SQL Code State; `0` Web/SQL Changes Afterward)

| Domain / Check | Exact Command | Exit Code | Exact Output / Counts |
|---|---|---:|---|
| Web TypeScript | `npm run typecheck` (`tsc -b --pretty false`) | `0` | `0` errors |
| Web Lint | `npm run lint` (`oxlint`) | `0` | `0` errors, `9` `react(only-export-components)` warnings across `224` files (`ResetPasswordView.tsx` [1], `FlashcardDeck.tsx` [2], `LessonMediaPlayer.tsx` [3], `AuthContext.tsx` [3]) |
| Web Full Vitest | `npm test` (`vitest run`) | `0` | **`57/57` test files passed, `347/347` tests passed** (`13.34s` Vitest duration) |
| Web Targeted Vitest | `npx vitest run src/__tests__/W0B3AuthSessionAndRecoveryIsolation.test.tsx src/__tests__/AdminContentQueries.test.ts src/__tests__/W0B2BundleAnswerKeyIsolation.test.ts src/__tests__/ProductTour.test.tsx` | `0` | **`4/4` files passed, `21/21` tests passed** (`5 + 4 + 6 + 6`) |
| Web Build & Bundle Scan | `npm run build` (`tsc -b && vite build`) + `dist/index.html` preloaded script scan | `0` | `2380` modules transformed, `built in 1.67s`, `0` warnings; **`12` initial/preloaded chunks scanned, `0` preloaded answer keys** (`correctIndex: 0`, `acceptedAnswers: 0`, `orderedTokens: 0`, `matchPairs: 0`) |
| Deno Edge Check & Test | `deno check supabase/functions/yolchi-tutor/{index,learner-content,math-pilot,math-pilot_test}.ts` + `deno test supabase/functions/yolchi-tutor/` | `0` | `0` check errors; **`2 passed \| 0 failed`** (`48ms`) |
| E2E Script Syntax | `node --check tests/e2e/supabase.mjs` | `0` | Valid JS syntax |
| Flutter (`5e85b79`) | `flutter analyze --fatal-infos`, `dart analyze test/integration/local_supabase_test.dart`, targeted `5`-file `flutter test`, full `flutter test` | `0` | `No issues found!`; `+67` targeted; **`+512 ~2: All tests passed!`** (`512` passed, `2` pre-existing skips in `local_supabase_test.dart`) |
| Disposable PG `17.11` | Fresh `28/28` + `seed.sql`; `Cloud-Default` & `Legacy-Grant` `27->28` + `2x` idempotency; `9/9` SQL suites × `2` postures; rollback; 2-session `READ COMMITTED` race | `0` | `18/18` SQL suite runs `EXIT=0`; rollback `0` rows; 2-session race blocked `1398ms` and rejected post-lock (`remaining_admins = 1`); **`0` `postgres` processes after cleanup** |

### 9.2 Post-Final-Fix Flutter Verification (`32ad3c6` — Final `ResetPasswordScreen._save()` Fix)

| Domain / Check | Exact Command (in `mobile/`) | Exit Code | Exact Output / Counts |
|---|---|---:|---|
| Flutter Static | `flutter analyze --fatal-infos` | `0` | `Analyzing mobile... No issues found! (ran in 3.8s)` |
| Targeted Flutter Suites | `flutter test test/features/w0_b3_account_isolation_and_secure_storage_test.dart test/features/m2_core_trio_test.dart test/features/english_m2_curriculum_test.dart test/features/lesson_session_persistence_test.dart test/features/auth_flow_test.dart` | `0` | **`+69: All tests passed!`** (`15/15` in `w0_b3_account_isolation_and_secure_storage_test.dart`, `0` failed) |
| Full Flutter Suite | `flutter test` | `0` | **`02:21 +514 ~2: All tests passed!`** (`514` passed, `2` pre-existing skips in `local_supabase_test.dart`, `0` failed) |

---

## 10. Independent Reviewer Verdicts

| Scope / Stage | Agent (`Conversation ID`) | Outcome | Resolution Details |
|---|---|---|---|
| **Task 1 (`bb65c3c`)** | `spec-reviewer` (`12a242a0-8042-4ea4-a9a1-53113e9f2dbe82`) | **`COMPLIANT`** | PostgreSQL `20261125000100`, `config.toml`, `supabase.mjs`, and `w0_b3_admin_and_session_regression.sql` verified against spec |
| **Task 1 (`bb65c3c`)** | `code-reviewer` (`bf8086b8-2a7c-43ab-b5b1-134953ecb0f6`) | **`APPROVED`** | `0` Critical, `0` Important, `3` Minor deferred |
| **Task 2 (`f4972ae` -> `8ab11ed`)** | `spec-reviewer` (`0a6dea03-a70f-4597-8578-4fec8f60c417`) | **`COMPLIANT`** | Web PKCE, `/reset-password` lock, `sessionReset`, and `AdminContentService.getUser()` compliant |
| **Task 2 (`f4972ae` -> `8ab11ed`)** | `code-reviewer` (`9bd1a397-49e3-4c24-abae-16b9ec05b7a4`) -> `re-reviewer` (`b0e57a13-aebe-4bb0-9802-f11ffb904b2d`) | **`WITH FIXES` -> `APPROVE`** | `0` Critical, `1` Important (cross-tab `updateUser()` unlock race) resolved in `8ab11ed` and approved |
| **Task 3 (`e221439`)** | `spec-reviewer` (`77e83062-6a53-430a-8772-667c49336f10`) | **`COMPLIANT`** | Canonical `uz.bilimyol.mobile`, `FlutterSecureStorage`, `allowBackup="false"`, and `verifyActiveSessionOrSignOut()` compliant |
| **Task 3 (`e221439`)** | `code-reviewer` (`9dd8b3aa-3c14-405a-acfb-e87ac15efdf3`) | **`APPROVED`** | `0` Critical, `0` Important, `4` Minor deferred |
| **Task 4 (`02435d2` -> `5e85b79`)** | `spec-reviewer` (`2e5629d3-3aa7-4c84-84fa-6f122635b3ca`) -> `re-reviewer` (`f07f4c3e-5a47-4737-a021-09ce74c5255b`) | **`ISSUES FOUND` -> `APPROVE`** | Post-logout re-login hydration race + 2 precision guards resolved in `5e85b79` and approved |
| **Task 4 (`02435d2` -> `5e85b79`)** | `code-reviewer` (`c1bc561e-6db7-4dc8-adc5-8572e9d6051a`) | **`APPROVED`** | `0` Critical, `0` Important, `4` Minor deferred |
| **Task 5 Whole-Branch (`935e9aa..5e85b79`)** | `spec-reviewer` (`31c91577-5630-4faa-b4ad-139f63385299`) | **`COMPLIANT`** | Full-branch compliance verified across SQL, Web, and Mobile |
| **Task 5 Whole-Branch (`935e9aa..5e85b79`)** | `teamwork_auditor` (`d57308b0-155e-44f4-b857-40e1149b32de`) | **`CLEAN`** | Forensic integrity & security audit: `0` violations |
| **Task 5 Whole-Branch (`935e9aa..5e85b79`)** | `final-reviewer` Pro (`9f5ddc48-8b91-4e89-b730-c4db84bc1725`) | **`APPROVED`** | `0` Critical, `0` Important |
| **Task 5 Whole-Branch (`935e9aa..5e85b79` -> `32ad3c6`)** | `code-reviewer` (`d0a468f4-05a4-4edf-8fee-6a1de6ad6248`) -> `re-reviewer` (`459fd74c-754c-4c25-aa8e-9831b6ced805`) | **`WITH FIXES` -> `APPROVE`** | `0` Critical, `1` Important UX (`ResetPasswordScreen._save()` confirmation across fail-closed `/login` redirect) resolved in `32ad3c6`, re-verified with `514` passed / `2` skipped & `flutter analyze --fatal-infos` clean |

---

## 11. Lockfile SHA-256 Hashes

| File | SHA-256 (`Get-FileHash -Algorithm SHA256`) | Status |
|---|---|---|
| `package.json` | `AC1B18EE7FB71E6F64B6DE51CF6C1FE9B7499D7A1B90D843966E673499C934A0` | **Exact Match (Unchanged)** |
| `package-lock.json` | `B8EA0991D28EB7FF1A485211D23C0B0A23627881B9AF46D4307608D21D9FAF1C` | **Exact Match (Unchanged)** |
| `mobile/pubspec.lock` | `A40D4802B41CA25B6541FC47D320FEDA27B7D0158EC988F9DAE8E594ABDBAA72` | **Updated Offline (`flutter_secure_storage 10.3.1` added via `flutter pub get --offline`)** |

---

## 12. Remaining Risks & Honesty Boundaries

1. **Hosted Supabase Cloud Dashboard (`UNVERIFIED`):** Local `supabase/config.toml` auth policies (`enable_confirmations`, `secure_password_change`, password strength, rate limits, TOTP MFA, session timeboxes, redirect allowlist) are hardened in-repo; live hosted Supabase Cloud Dashboard toggles and production SMTP/DNS configuration have not been inspected or modified.
2. **OS-Level HTTPS App Links / Universal Links (`BLOCKED` until `W0-B4` & `W6-B2`):** `SupabaseConfig.isAllowedAuthRedirectUri` enforces callback-parameterized `https://bilimyol.uz/reset-password` and `uz.bilimyol.mobile://auth/reset-password` inside the app, while server-hosted `/.well-known/assetlinks.json` and `/.well-known/apple-app-site-association` domain verification remain `BLOCKED` on production Android release keystore SHA-256 (`W0-B4`) and Apple `DEVELOPMENT_TEAM` (`W6-B2`).
3. **Offline Integration / Browser E2E & Native Device Builds:** `tests/e2e/supabase.mjs` passed `node --check` and `mobile/test/integration/local_supabase_test.dart` passed `dart analyze` (`~2` skipped in offline `flutter test`), as a live Docker/Supabase/Mailpit/Chrome stack and real Android/iOS Keystore/Keychain devices were not exercised in this local run.
4. **Staging / Production Deployment:** All `W0-B3` findings (`FIX-P0-25`, `FIX-P1-44`, `FIX-P1-48`) are strictly **`FIXED_LOCAL`**; zero items are claimed `VERIFIED_STAGING` or `VERIFIED_PRODUCTION`.

---

## 13. Cumulative Status & Next Step

- **Baseline Audit Score:** `49.28 / 100` (`NO-GO`) preserved until cross-wave remediation + staging/production verification.
- **Canonical Ledger (`121` total findings in [REMEDIATION_PROGRESS.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_0_critical_containment/docs/implementation/REMEDIATION_PROGRESS.md)):**
  - `FIXED_LOCAL`: **`7 / 121`** (`P0`: `4`, `P1`: `2`, `P2`: `1`, `P3`: `0`)
  - `OPEN`: **`114 / 121`** (`P0`: `24`, `P1`: `53`, `P2`: `29`, `P3`: `8`)
  - `VERIFIED_STAGING` / `VERIFIED_PRODUCTION`: **`0 / 121`**
- **Next Step:** **STOP here as instructed** (do not start `W0-B4`, push, or merge). Review `W0-B3` verification results and approve **`W0-B4`** (`FIX-P0-26`, `FIX-P2-11`) as the next atomic Wave 0 batch.
