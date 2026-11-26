# BilimYo‘l Smart Edu — Wave 1 · Batch `W1-B2` Execution Report

- **Repository:** `PirimovUktam/bilimyol-smart-edu`
- **Branch:** `fix/wave-1-b2-cefr-sql-grading-parity` (based on `5376a0cf4f0cef005c7e28ab13bf518318e6fed8`)
- **Audit Baseline (`READ-ONLY`, untouched):** `5c22343b2246dedcee7866cd11931c48346cf65c` (`49.28 / 100`, `121` total findings)
- **Remediated Findings (`FIXED_LOCAL`):**
  - `FIX-P0-01` — 33-lesson CEFR SQL seeding, `learner_lessons` single-CTE rewrite, rich answer-key sanitization, 9-mode + `alternate_exercise` server grading, and Mobile 14-column roadmap node parity (`FIXED_LOCAL`; staging/production `UNVERIFIED`)
  - `FIX-P1-40` — Cross-platform JSON `p_selected_text` wire parity, multi-skill step & `alternate_exercise` lesson completion, non-MCQ + Mobile reinforcement mistake feedback, and `<28% → >=50%` reinforcement clearance (`FIXED_LOCAL`; staging/production `UNVERIFIED`)

Full detailed engineering & test verification report: [docs/implementation/wave-1/W1-B2_REPORT.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_1_b2_cefr_sql_grading_parity/docs/implementation/wave-1/W1-B2_REPORT.md).

## Verification Summary

- **PostgreSQL `17.11` (Disposable Local Cluster):**
  - All `30` migrations applied cleanly + `2x` idempotency verified under both `Cloud-Default` and `Legacy-Grant` postures; `EXPLAIN (COSTS OFF)` on `public.learner_lessons` confirmed a single `Hash Right Join` over `unlocked_math_lesson_ids` (`0` lateral subplans, `0` `OFFSET 0`).
  - All `11/11` SQL regression suites passed on both postures (`22/22` runs), including `supabase/tests/w1_b2_cefr_sql_and_grading_parity_regression.sql` and updated `supabase/tests/beginner_learning_start_regression.sql`.
- **Web & Deno:**
  - `npm run typecheck` (`EXIT=0`), `npm run typecheck:tests` (`EXIT=0`), `npm run lint` (`0` errors), `npm test` (`61/61` files, `364/364` tests), `npm run build` (`2382` modules, `0` warnings, `W0-B2` zero preloaded answer keys preserved), `npm run test:e2e` (`EXIT=0`), `deno check supabase/functions/yolchi-tutor/*.ts` (`EXIT=0`, `4/4` files).
- **Flutter Mobile:**
  - `flutter analyze --no-pub --fatal-infos` (`EXIT=0`, `0` issues), `flutter test --no-pub test/features/w1_b2_cefr_sql_and_grading_parity_test.dart` (`4/4` passed), full `flutter test --no-pub` (`532` passed, `2` env-gated skips, `0` failed).
