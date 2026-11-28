# BilimYo‘l Smart Edu — Wave 1 · Batch `W1-B4` Implementation Plan

- **Repository:** `PirimovUktam/bilimyol-smart-edu`
- **Base Commit:** `da10196cc2a3376163136b515b827ac086bb285d` (`fix/wave-1-b3-placement-priors-prereqs`)
- **Feature Branch:** `fix/wave-1-b4-roadmap-reinf-xai`
- **Worktree:** `C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_1_b4_roadmap_reinf_xai`
- **Target Findings:** `FIX-P0-03`, `FIX-P0-12`, `FIX-P1-01`, `FIX-P1-08`, `FIX-P1-17`, `FIX-P1-18`, `FIX-P1-19`

---

## 1. Root Cause Summary

1. **`FIX-P0-03` — Flagship 5-Step Adaptive Cycle & 6-Input Explainable AI Missing on Live Math Pilot & Flutter Mobile:**
   - Web `DashboardView`, `RoadmapView`, `ProgressView`, and `KnowledgeMapView` short-circuit (`if (mathPilot) return null` / `!policy`), hiding the 5-Step Adaptive Cycle, 6-Input Explainable AI panel, and Adaptive Effectiveness card on the flagship Live Math Pilot (`course_math_01`), while `AdaptiveCycleEngine` reads empty `skillScores` instead of server `node.mastery`.
   - Flutter Mobile lacks `AdaptiveCycleEngine` and `AdaptiveCycleCard` altogether (`0%` parity with Web).

2. **`FIX-P0-12` — Web `reinf_*` Missing `targetLessonId` Misroutes Shared-`skillId` A2/B1 English Reinforcements to A1:**
   - Web `RouteEngine.adaptRoadmap` constructs `reinf_${baseNode.id}` without copying `targetLessonId: baseNode.targetLessonId`, causing `RoadmapView` (`getLessonByCourseAndSkill`) to load the first A1 lesson sharing `skillId` (e.g., `lesson_eng_grammar_01`) instead of `lesson_eng_b1_m1_travel` and leaving `reinf_node_eng_b1_m1_travel` unresolved.

3. **`FIX-P1-01` — `AdaptiveCycleEngine` Step 4/5 Inversion, Synthetic `+55%` Zero-Lesson Growth, Broken `micro_reinf`, & Disconnected `goal` / `dailyMinutes`:**
   - `hasProgressMeasured` evaluates `true` before any lesson/reinforcement practice (`completedLessonsCount === 0`), marking Step `05` complete while Step `04` stays active.
   - `buildAdaptiveEffectivenessSnapshot` fabricates baselines via `{25, 45, 65}` or `current - 22` instead of `placementScoreByCourse` / `placementSkillScoresByCourse`, displaying `+55%` growth at `0` completed lessons.
   - `buildDailyMicroTasks` hardcodes `targetNodeId: reinf_${activeNode.id}` even when the active node has no `reinf_*`, and `goal` / `dailyMinutes` are ignored by `RouteEngine` and task sizing.

4. **`FIX-P1-08` — 3-Way Post-Placement `>= 80%` Roadmap Split (Web vs Mobile vs SQL):**
   - Mobile `RouteEngine` marks unstudied `>= 80%` diagnostic skills as `completed` (leaving `0` `available` lessons after a `100%` placement), Web unlocks `0` downstream nodes outside CEFR, and SQL `bilimyol_private.math_progression` ignores `placement_skill_scores_by_course` on foundation nodes (`node_math_addition`, `node_math_multiplication`).

5. **`FIX-P1-17` — Day-8 Spaced-Review Slip Re-Locks Mastered Downstream Chapters & Static `7 days` Interval:**
   - SQL `bilimyol_private.math_progression` gates child eligibility strictly on `parent.mastered`, so a Day-8 review slip on Node 1 (`review_due` / `learning`) cascade re-locks already-mastered downstream chapters (`status = 'locked'` alongside `mastery_state = 'mastered'`).
   - `review_interval` remains static at `'7 days'::interval` instead of expanding (`7d -> 14d -> 30d`) across multi-day retrieval passes.

6. **`FIX-P1-18` — Mobile `SubmitReinforcementUseCase` Drops `placementCefrTier` & `RoadmapScreen` Replays Full Lesson:**
   - Mobile `SubmitReinforcementUseCase` omits `placementCefrTier` across all 3 `RouteEngine.adaptRoadmap` calls, re-locking A2/B1 English roadmaps upon reinforcement submission.
   - Mobile `RoadmapScreen` launches the full `/lesson` route from Step 1 on `reinf_*` nodes instead of opening a standalone 5-minute `ReinforcementSheet` modal.

7. **`FIX-P1-19` — Returning-Learner `< 50%` `reinf_*` Suppressed, Web/Mobile `activeNodeId` Inversion, Dropped Completed `reinf_*`, & `canStartNode(reinf_*)` Blocked:**
   - `!isCompleted` suppresses `reinf_*` injection when a previously completed skill decays below `50%`; Web prioritizes `< 50%` A1 `reinf_*` ahead of an uncompleted placed A2/B1 entry lesson while Mobile prioritizes the entry lesson; Mobile drops completed `reinf_*` nodes once score rises `>= 50%`; and Web `RouteEngine.canStartNode(reinf_*)` returns `false` because `reinfNode.prerequisites` is set to `[baseNode.id]` while `baseNode` is not `completed`.

---

## 2. Scoped Changes

### 2.1 PostgreSQL Forward Migration (`supabase/migrations/20261129000100_w1_b4_roadmap_unlock_and_spaced_review.sql`)
- Purge any residual `'placement_test'`-only `public.learner_skill_scores` rows on `course_eng_01` idempotently (`FIX-P1-19`).
- Upgrade `bilimyol_private.math_progression(UUID)` in place (preserving the 19-column `RETURNS TABLE` signature):
  - Read `placement_skill_scores_by_course->'course_math_01'` (with fallback to `compute_placement_skill_scores` on latest `placement_attempts`) to set `placement_mastered` on foundation nodes (`node_math_addition`, `node_math_multiplication`) when score `>= required_score` (`80`) without `>= 2` lesson mistakes (`FIX-P1-08`).
  - Decouple Day-8 review slips from downstream chapter re-locking via `(parent.mastered OR parent.previously_completed OR parent.ever_mastered OR parent.placement_mastered)` and keep already-mastered/completed nodes `eligible = true` (`FIX-P1-17`).
  - Expand `effective_review_interval` (`7d -> 14d -> 30d`) across distinct UTC days of correct retrieval attempts strictly after the last wrong attempt (`FIX-P1-17`).

### 2.2 Web (`src/`)
- Unify `RouteEngine.ts`, `GetRoadmapUseCase.ts`, `SubmitReinforcementUseCase.ts`, `RecommendationEngine.ts`, `lessonResolution.ts`, and `reinforcementNodeId.ts` (`targetLessonId: baseNode.targetLessonId`, `prerequisites: baseNode.prerequisites`, `unlockedViaDiagnostic` / `isPlacementUnlocked` / `isPlacementRecommended`, returning-learner `needsPractice || isReinforcementCompleted`, unified `activeNodeId` & `goal` ordering, `strippedId`-first base node resolution).
- Upgrade `AdaptiveCycleEngine.ts` + `DashboardView.tsx`, `RoadmapView.tsx`, `ProgressView.tsx`, and `KnowledgeMapView.tsx` (Live Math Pilot `node.mastery` mapping, `hasProgressMeasured` gated on `hasPracticeActivity`, real diagnostic `baselineScore`/`growthDelta` with localized `"Diagnostika topshirilmagan"` fallback, weakest-skill `micro_reinf` resolution, `dailyMinutes` task sizing).

### 2.3 Flutter Mobile (`mobile/`)
- Unify `learning_path_node.dart`, `route_engine.dart`, `learning_start.dart`, `get_roadmap_use_case.dart`, `submit_reinforcement_use_case.dart`, `providers.dart`, `reinforcement_sheet.dart`, and `roadmap_screen.dart` (1:1 `RouteEngine` parity, `placementCefrTier` + `goal` + `dailyMinutes` passed on all `adaptRoadmap` calls, standalone `ReinforcementSheet` modal on `RoadmapScreen` via `submitStandaloneReinforcement`).
- Implement `adaptive_cycle_engine.dart` and responsive `adaptive_cycle_card.dart` (`uz`/`ru`, WCAG AA, `2.0x` text scale safe) mounted on `DashboardScreen`.

---

## 3. Verification Gates (TDD `RED` → `GREEN`)

1. `node scripts/validate-english-curriculum.mjs` (`[OK schema+curriculum]`).
2. Disposable PostgreSQL `17.11` (`Cloud-Default` & `Legacy-Grant`): pre-migration `RED` check + all `32` migrations + `2x` idempotency re-run of `20261129000100` + all `13/13` SQL regression suites (`26/26` runs, including `supabase/tests/w1_b4_roadmap_unlock_and_spaced_review_regression.sql` and owned updates in `supabase/tests/math_mastery_pilot_regression.sql`) + 8-worker `READ COMMITTED` concurrency test on Day-8 review slip.
3. Web & Deno: `npm run typecheck`, `npm run typecheck:tests`, `npm run lint`, `npm test` (`W1B4RoadmapReinforcementAndXai.test.tsx` + full Vitest), `npm run build` + `W0B2BundleAnswerKeyIsolation.test.ts`, `npm run test:e2e`, and `deno check supabase/functions/yolchi-tutor/*.ts`.
4. Flutter Mobile: `flutter analyze --no-pub --fatal-infos`, `flutter test --no-pub test/features/w1_b4_roadmap_reinforcement_and_xai_test.dart`, and full `flutter test --no-pub`.
