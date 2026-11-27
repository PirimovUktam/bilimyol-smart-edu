# BilimYo‘l Smart Edu — Wave 1 · Batch `W1-B3` Implementation Plan

- **Repository:** `PirimovUktam/bilimyol-smart-edu`
- **Base Commit:** `5c8ff7fa6b385564450f0829253e484b183950b3` (`fix/wave-1-b2-cefr-sql-grading-parity`)
- **Feature Branch:** `fix/wave-1-b3-placement-priors-prereqs`
- **Worktree:** `C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_1_b3_placement_priors_prereqs`
- **Target Findings:** `FIX-P0-02`, `FIX-P0-11`, `FIX-P1-07`, `FIX-P1-09`, `FIX-P1-14`, `FIX-P1-16`, `FIX-P1-46`, `FIX-P2-09`

---

## 1. Root Cause Summary

1. **`FIX-P0-02` — Unseeded Canonical English Placement Bank, Ephemeral CEFR Result & `placement_test` Mastery Contamination:**
   - Live PostgreSQL (`supabase/migrations/20261124000100_p1_closure_security_and_persistence.sql` & earlier seed migrations) still serves the legacy 12-question `q_live_eng_*` bank instead of the canonical 12-question CEFR-tagged `q_eng_place_*` bank (`content/english/placement-questions.json`), lacking `cefr_level`, `text_ru`, `explanation_ru`, and `media` on `public.questions`.
   - `public.learner_profiles` persists `placement_completed_by_course`, `unlocked_cefr_by_course`, and `weakest_skill_by_course`, but drops `placement_score_by_course`, `placement_cefr_by_course`, and `placement_skill_scores_by_course`, losing the assessed CEFR band and diagnostic breakdown across sessions/devices.
   - `recalculate_course_skill_scores_for_user` mixes `'placement_test'` rows directly into `course_eng_01` `learner_skill_scores` instead of treating placement as an empirical Bayesian prior for downstream lesson mastery.

2. **`FIX-P0-11` — Over-Awarding CEFR `B1` Without B1 Evidence:**
   - `course_eng_01` placement starts at `'easy'` (`A1`) instead of adaptive `'medium'` (`A2`), and awards `'B1'` on raw percentage without requiring actual B1 (`hard`) evidence (`b1Total >= 2 && b1Acc >= 0.5`).

3. **`FIX-P1-07` — Unchained A1 English Curriculum & False Orthogonal IT/Logic Prerequisites:**
   - Multiple A1 English roadmap nodes (`node_eng_a1_m1_speaking`, `node_eng_gram`, `node_eng_vocab`, `node_eng_read`, etc.) omit sequential prerequisites, leaving `node_eng_a1_exit` without the full 14-node A1 ancestor chain, while orthogonal `course_it_01` (`node_it_web`) and `course_logic_01` (`node_logic_patterns`) lock independent domains behind artificial prerequisites at Day 0.

4. **`FIX-P1-09` — Uncalibrated Skill Priors & Single-Attempt Mastery Inflation:**
   - A `0%` placement diagnostic followed by `1` correct starter exercise inflates skill scores above `25%`, `1/1` single-item accuracy reaches `'mastered'` without minimum evidence (`attemptCount >= 4`), and spoiled choice-mode retries receive full `1.0` weight instead of a `0.75` retry discount.

5. **`FIX-P1-14` — Web vs Mobile/SQL Adaptive Selector Drift:**
   - Web `AdaptiveQuestionSelector.ts` inspects a 2-answer streak window (`skillHistory.slice(-2)`), diverging from the 1-step Markov transition (`skillHistory.at(-1)`) implemented in Mobile `adaptive_question_selector.dart` and SQL `next_placement_question`.

6. **`FIX-P1-16` — Unweighted Placement Credit, Unconditional `isWeakestFocus`, & First-Wins Deduplication:**
   - Placement skill scoring treats `easy`, `medium`, and `hard` items identically instead of difficulty-weighting credit (`easy: 0.75, medium: 1.0, hard: 1.25`, missed denominator `Math.min(w, 1.0)`), flags `isWeakestFocus = true` even when all skills score `>= 80%`, and Mobile `computePlacementScores` deduplicates repeated `questionId` answers via first-wins instead of last-wins.

7. **`FIX-P1-46` — Day-1 Placement Misses Dragging Down Day-2 Retake Scores:**
   - Retaking placement (`p_restart => true`) leaves prior `'placement_test'` misses active in score recalculation so an `8/8 (100%)` Day-2 retake cannot reach `100%` (`>= 70%`) across skills.

8. **`FIX-P2-09` — Conflated `assessedCefr` vs `unlockedCefrFloor` & Hidden Skill Confidence:**
   - Reassessing placement with `0/8` after unlocking `'A2'` via `node_eng_a1_exit` overwrites or conflates the diagnostic `assessedCefr` (`'Pre-A1'`) with the curriculum `unlockedCefrFloor` (`'A2'`), and Knowledge Map omits `ConfidenceLevel` (`low` / `medium` / `high`) badges on skill cards.

---

## 2. Scoped Changes

### 2.1 Curriculum & Validator (`content/english/` & `scripts/`)
- Chain all `15` A1 English roadmap nodes sequentially (`order: 1..15`, Unit 1–4 checkpoints feeding into `node_eng_a1_exit` with `14` transitive ancestors; only `node_eng_a1_m1_greetings` has `prerequisites: []`) across `content/english/a1-curriculum.json`, `src/data/datasources/roadmaps.ts`, `mobile/lib/data/datasources/english/a1_roadmap_data.dart`, `mobile/lib/data/datasources/english/a1_lessons_data.dart`, and `scripts/validate-english-curriculum.mjs`.
- Clear false prerequisites (`prerequisites: []`) on orthogonal `node_it_web` (`course_it_01`) and `node_logic_patterns` (`course_logic_01`) across Web, Mobile, and SQL.

### 2.2 PostgreSQL Forward Migration (`supabase/migrations/20261128000100_w1_b3_placement_cefr_priors_and_prereqs.sql`)
- Add `cefr_level`, `text_ru`, `explanation_ru`, and `media` to `public.questions`; seed all `12` canonical `q_eng_place_*` items with deterministic FNV-1a option permutation matching Web/Mobile; retire `12` legacy `q_live_eng_*` IDs into `bilimyol_private.demo_placement_question_ids`.
- Add `placement_score_by_course`, `placement_cefr_by_course`, and `placement_skill_scores_by_course` to `public.learner_profiles`, guarded against direct `authenticated`/`anon` tampering by `BEFORE INSERT OR UPDATE` trigger `trg_guard_learner_profile_derived_placement` (`42501`).
- Update `next_placement_question`, `advance_placement`, `submit_placement_diagnostic`, and `recalculate_course_skill_scores_for_user` for `'medium'` (`A2`) English start, 1-step Markov transitions, difficulty-weighted placement scoring, `< 80` weakest-skill gating, `b1Total >= 2 && b1Acc >= 0.5` B1 evidence rule, `assessedCefr` vs `unlockedCefrFloor` separation, Day-2 retake session superseding, and calibrated Bayesian priors (`priorWeight = 4`, `starterOnlyMaxScore = 55`, starter weight `0.5`, spoiled retry `0.75`, `attemptCount >= 4` for `'mastered'`).
- Sync sequential A1 `roadmap_nodes` and `lessons` prerequisites plus `node_it_web` and `node_logic_patterns` `prerequisites = '{}'::TEXT[]`.

### 2.3 Web (`src/`) & Flutter Mobile (`mobile/`)
- Align `AdaptiveQuestionSelector`, `EnglishCefrPlacement` (`evaluateEnglishPlacementCefr`), `SkillScoringEngine`, `SubmitPlacementTestUseCase`, `InMemoryLearnerRepository`, `SupabaseLearnerRepository`, `SupabaseCourseRepository` (Mobile), `usePlacementStore` / `PlacementStateNotifier`, `KnowledgeMapView` / `KnowledgeMapScreen` (`ConfidenceLevel` badges), and `PlacementTestView` / `PlacementTestScreen` (`assessedCefr` + `unlockedCefrFloor` note) across Web and Flutter.

---

## 3. Verification Gates (TDD `RED` → `GREEN`)

1. `node scripts/validate-english-curriculum.mjs` (`[OK schema+curriculum]`).
2. Disposable PostgreSQL `17.11` (`Cloud-Default` & `Legacy-Grant`): all `31` migrations + `2x` idempotency re-run of `20261128000100` + all `12/12` SQL regression suites (`24/24` runs, including `supabase/tests/w1_b3_placement_cefr_priors_and_prereqs_regression.sql`) + 8-session concurrency race on `advance_placement` and `submit_answer_attempt`.
3. Web & Deno: `npm run typecheck`, `npm run typecheck:tests`, `npm run lint`, `npm test` (`W1B3PlacementCefrPriorsAndPrereqs.test.tsx` + full Vitest), `npm run build` + `W0B2BundleAnswerKeyIsolation.test.ts`, `npm run test:e2e`, and `deno check supabase/functions/yolchi-tutor/*.ts`.
4. Flutter Mobile: `flutter analyze --no-pub --fatal-infos`, `flutter test --no-pub test/features/w1_b3_placement_cefr_priors_and_prereqs_test.dart`, and full `flutter test --no-pub`.
