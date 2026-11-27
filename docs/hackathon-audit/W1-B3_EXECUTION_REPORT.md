# BilimYo‘l Smart Edu — Wave 1 · Batch `W1-B3` Execution Report

- **Repository:** `PirimovUktam/bilimyol-smart-edu`
- **Branch:** `fix/wave-1-b3-placement-priors-prereqs` (based on `5c8ff7fa6b385564450f0829253e484b183950b3`)
- **Audit Baseline (`READ-ONLY`, untouched):** `5c22343b2246dedcee7866cd11931c48346cf65c` (`49.28 / 100`, `121` total findings)
- **Remediated Findings (`FIXED_LOCAL`):**
  - `FIX-P0-02` — Canonical 12-item `q_eng_place_*` SQL seeding with `cefr_level`/`text_ru`/`explanation_ru`/`media` & deterministic option permutation, retirement of `q_live_eng_*`, `placement_score_by_course`/`placement_cefr_by_course`/`placement_skill_scores_by_course` server persistence behind `trg_guard_learner_profile_derived_placement` (`42501`), and `placement_test` isolation from `course_eng_01` `learner_skill_scores` (`FIXED_LOCAL`; staging/production `UNVERIFIED`)
  - `FIX-P0-11` — `course_eng_01` placement starting at `'medium'` (`A2`) across Web, Mobile, and SQL, requiring `b1Total >= 2 && b1Acc >= 0.5` before awarding `'B1'` (`FIXED_LOCAL`; staging/production `UNVERIFIED`)
  - `FIX-P1-07` — Sequential 15-node A1 English chain (`1..15`, `14` ancestors into `node_eng_a1_exit`) and `prerequisites: []` on orthogonal `node_it_web` & `node_logic_patterns` across Web, Mobile, and SQL (`FIXED_LOCAL`; staging/production `UNVERIFIED`)
  - `FIX-P1-09` — Calibrated Bayesian skill scoring (`priorWeight = 4`, `starterOnlyMaxScore = 55`, starter weight `0.5`, spoiled retry `0.75`, `attemptCount >= 4` for `'mastered'`; `0%` placement + `1` starter = `11% <= 25%`) across Web, Mobile, and SQL (`FIXED_LOCAL`; staging/production `UNVERIFIED`)
  - `FIX-P1-14` — Web `AdaptiveQuestionSelector.ts` 1-step Markov transition parity (`skillHistory.at(-1)`) with Mobile and SQL (`FIXED_LOCAL`; staging/production `UNVERIFIED`)
  - `FIX-P1-16` — Difficulty-weighted placement credit (`0.75 / 1.0 / 1.25`), `< 80` weakest-skill gating, and `last wins` deduplication across Web, Mobile, and SQL (`FIXED_LOCAL`; staging/production `UNVERIFIED`)
  - `FIX-P1-46` — Day-2 placement retake session superseding (`8/8` retake yields `100%` without stale Day-1 misses) across Web, Mobile, and SQL (`FIXED_LOCAL`; staging/production `UNVERIFIED`)
  - `FIX-P2-09` — `assessedCefr` vs `unlockedCefrFloor` separation on placement completion/reassessment and `ConfidenceLevel` (`low`/`medium`/`high`) badges on Knowledge Map (`FIXED_LOCAL`; staging/production `UNVERIFIED`)

Full detailed engineering & test verification report: [docs/implementation/wave-1/W1-B3_REPORT.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_1_b3_placement_priors_prereqs/docs/implementation/wave-1/W1-B3_REPORT.md).

## Verification Summary

- **Curriculum & PostgreSQL `17.11` (Disposable Local Cluster):**
  - `node scripts/validate-english-curriculum.mjs` (`EXIT=0`, `[OK schema+curriculum]`).
  - All `31` migrations applied cleanly + `2x` idempotency verified under both `Cloud-Default` and `Legacy-Grant` postures.
  - All `12/12` SQL regression suites passed on both postures (`24/24` runs), including `supabase/tests/w1_b3_placement_cefr_priors_and_prereqs_regression.sql` and updated `supabase/tests/p1_persistence_regression.sql` & `supabase/tests/placement_sessions_regression.sql`.
  - 8-session concurrent `advance_placement` + `submit_answer_attempt` race verified (`attempts:xp:score = 1:2:55`, `0` deadlocks).
- **Web & Deno:**
  - `npm run typecheck` (`EXIT=0`), `npm run typecheck:tests` (`EXIT=0`), `npm run lint` (`0` errors), `npm test` (`62/62` files, `370/370` tests, `5/5` `W1B3PlacementCefrPriorsAndPrereqs.test.tsx`), `npm run build` (`2382` modules, `0` warnings, `W0-B2` `6/6` bundle answer-key isolation preserved), `npm run test:e2e` (`EXIT=0`), `deno check supabase/functions/yolchi-tutor/index.ts supabase/functions/yolchi-tutor/math-pilot.ts` (`EXIT=0`).
- **Flutter Mobile:**
  - `flutter analyze --no-pub --fatal-infos` (`EXIT=0`, `0` issues), `flutter test --no-pub test/features/w1_b3_placement_cefr_priors_and_prereqs_test.dart` (`6/6` passed), full `flutter test --no-pub` (`538` passed, `2` env-gated skips, `0` failed).
