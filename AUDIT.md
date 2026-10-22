# BilimYo'l Smart Edu — Audit & Prioritized Backlog

**Product intent (source of truth, `Bilimga yo'l.pdf`):** "Darslik emas — shaxsiy ta'lim yo'li." Adaptive loop: daraja testi → bo'shliq aniqlash → individual yo'l → adaptiv mashq → analitika. Yo'lchi AI is a mentor that tracks, analyzes and rebuilds the path. B2C freemium, learners 5–11 grade + abituriyentlar.

**Baseline (verified this session):** `typecheck` ✓ clean · `lint` warnings only (unused imports in PitchShowcaseView, react-refresh in AuthContext) · `test` **226/226 pass** (34 files) · `build` ✓ but **1.03 MB single JS chunk** (no code-splitting).

**Repo shape:** React 19 + TS + Vite + Tailwind 4 + Zustand + framer-motion + lucide + Supabase + Gemini (Edge `yolchi-tutor`). Layers respected: app / core / data / domain / presentation / features. InMemory ↔ Supabase repositories switch on `isDemoRuntimeActive() || !isSupabaseConfigured` — consistently applied. `mobile/` Flutter app present, out of scope (mapped, untouched).

---

## Architecture map (what actually exists)

- **Auth:** `AuthContext` — Supabase-first, race-safe (operation tokens), profile role read from `public.profiles` (authoritative). Demo mode only when explicitly enabled via `setDemoUser` / hosted-demo guard. Solid.
- **Routing:** `AppRouter` — custom view-state router (no react-router). Views: pitch, demo, course-selection, onboarding, placement, knowledge-map, roadmap, lesson, dashboard, ai-tutor, progress, login, register, forgot-password, profile, admin.
- **Stores:** course, learner, lesson, placement, roadmap — all use operation/session tokens for race safety. Well-guarded.
- **AI:** `GeminiAITutorService` → Edge `yolchi-tutor` (CORS allowlist, rate limit, answer-key stripping). `DemoAITutorService` fallback gated behind demo/unconfigured.
- **Persistence:** `learner_lessons` / `learner_questions` safe views (answer keys stripped), `submit_answer_attempt`, `complete_lesson`, `complete_reinforcement`, `evaluate_placement_answer`, `award_xp`, `record_learning_activity` RPCs — server-authoritative scoring & anti-cheat.

---

## Findings (severity · file:line · evidence · impact · fix · verify)

### BLOCKER
1. **Password reset is dead-end.** `AuthContext.resetPassword` (l.605) emails a link to `/reset-password`, but that route **does not exist** in `AppView` / `AppRouter` and nothing calls `supabase.auth.updateUser`. A user who resets their password can never set a new one. → **Fix:** add a `reset-password` view that consumes the recovery session and calls `updateUser({ password })`. **Verify:** manual link flow; typecheck.

### HIGH
2. **`.env` and `.env.local` are committed to git** (`git ls-files` shows both). `.env.local` contains `VERCEL_OIDC_TOKEN` plus Supabase keys. → **Fix:** `git rm --cached .env .env.local`, rotate the OIDC + anon keys, keep `.env.example`. **Verify:** `git ls-files` clean; new deploy env.

3. **Cross-course content isolation depends on hardcoded ids.** `COURSE_TARGET_SKILLS` in `usePlacementStore.ts:37` hardcodes `course_math_01` / `course_eng_01` → IT & Logic placement gets no skill targeting (falls back to all). `isMath` in `InteractiveLessonView.tsx:132` hardcodes `course_math_01`. → **Fix:** derive target skills from `activeCourseSkills`; badge by `course.subject`, not id. **Verify:** placement for a non-math course asks targeted questions.

4. **`isMath` badge uses wrong id.** `Badge variant={isMath ? 'blue':'teal'}` — any non-math course shows teal; driven by a magic string. → derive from `currentLesson.courseId` subject via `activeCourse.subject`.

### MEDIUM
5. **Dashboard "Dars mavjud" path can route to empty course.** When `activeCourse` has no roadmap nodes and `lessons.length===0`, hero shows "Darslar tayyorlanmoqda" + AI-generate button, but `targetLessonId` may still be `activeCourse.lessons[0]` (a bare id string), so "Davom etish" can fire a nonexistent lesson id. → gate continue on a resolved lesson id only.

6. **Placement target skills not driven by course.** Non-math/non-english courses (it, logic, other) get `targetSkills = all skillIds` — acceptable, but placement copy says "har bir ko'nikma uchun 2 savol" while bank may be thin. Ensure IT/logic seed questions exist; verify against `learner_questions`.

7. **Single 1 MB bundle.** All routes + pitch/demo (2.7k lines) + admin bundled in one chunk. → route-level `React.lazy` + a `?view=` prefetch map; move pitch/demo to lazy.

8. **AI debris / unused assets.** `src/assets/vite.svg`, `react.svg` imported nowhere; `PitchShowcaseView` 10 unused icon imports (lint warnings); `index.html` may still reference vite icon. → remove dead imports/assets.

9. **Emoji-as-icon violations** (brief forbids emoji as icons): Dashboard `🔒` (l.774), `🎯` (l.466), `👋` (l.456), `🔥` streak (l.507); ProgressView badge icons `🏆🎯⭐🤖🔒` (l.98-101, 407) & `🔥✨` (l.197,209); Navbar `🎓⚡` (l.139,145); LoginView `✨` (l.137); ProfileView `⚡🎓` (l.84); YolchiAIChatView quick-prompts `💡✍️🎯📐`. → replace with lucide icons.

10. **Demo/leak edge: `console.log` in production.** `supabase.ts:38` logs config fingerprint every load → demote to `console.debug`/gate on `import.meta.env.DEV`.

### NIT
11. `resolveContinuationLessonId` returns `activeCourse.lessons[0]` (string id) but lessons are only ids — relies on repository fetch; fine, but continuation silently no-ops when repo lacks it.
12. Pitch/Demo public pages reachable without auth — intended (marketing), but they ship in the learner bundle; lazy-split (see #7).
13. `AdminContentService` keeps mutable module-level `inMemory*` arrays seeded from `SEED_*` — admin edits in demo mode mutate shared module state; acceptable for demo, flag for real admin RLS.
14. Footer shows `authProfile.email` — fine, but demo user email `guest@bilimyol.uz` leaks through footer on hosted demo; cosmetic.

---

## Prioritized backlog

**P0 (blocker / security):**
- #1 password-reset completion flow
- #2 un-commit `.env`/`.env.local` + rotate secrets
- #3 derive placement target skills + subject-driven badge (kill `course_math_01` magic strings)

**P1 (journey defects):**
- #4 subject-driven lesson badge
- #5 gate "Davom etish" on a resolved lesson id
- #9 replace all emoji-as-icon with lucide
- #10 gate config console.log to DEV
- #6 verify IT/logic placement bank (data check, not code)

**P2 (UX/UI redesign — Phase D):**
- Design tokens already partially present (indigo/cyan, Plus Jakarta Sans). **Direction chosen:** "Yoʻl / Journey" — deep-space indigo hero surfaces + crisp white learning cards, teal→emerald progress accents, amber gamification (XP/streak), rounded-3xl soft cards, motion only for feedback. Rationale: matches existing brand + PDF's "yol" motif; keeps mascot & hero art.
- Redesign remaining surfaces coherently: consistent top nav, hero "continue" pattern, knowledge-map & progress polish.

**P3 (architecture / polish):**
- #7 route-level code-splitting (bundle <500 kB/chunk)
- #8 remove unused imports/assets
- #13 admin demo-state note; #11 continuation hardening; #12 lazy marketing pages

**Discrepancies (PDF ↔ code) to log:** PDF sells "Yo'lchi AI rebuilds the path" — implemented via roadmap nodes + reinforcement, verified. Freemium/premium (59 900 so'm) is PDF-only; no paywall code exists (correct for MVP — not a defect).
