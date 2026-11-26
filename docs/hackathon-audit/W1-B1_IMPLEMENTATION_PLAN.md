# BilimYo‘l Smart Edu — Wave 1 · Batch `W1-B1` Implementation Plan

- **Repository:** `PirimovUktam/bilimyol-smart-edu`
- **Base Commit:** `1845f5096e0df4b0cf3c0603ac1184866905f6d2` (`fix/wave-0-b4-release-ci-tests`)
- **Feature Branch:** `fix/wave-1-b1-core-learning-integrity`
- **Worktree:** `C:\Users\user\.gemini\antigravity\worktrees\Bilimyol\fix_wave_1_b1_core_learning_integrity`
- **Target Findings:** `FIX-P0-24`, `FIX-P1-55`, `FIX-P2-23`

See canonical implementation plan: [docs/implementation/wave-1/W1-B1_IMPLEMENTATION_PLAN.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_1_b1_core_learning_integrity/docs/implementation/wave-1/W1-B1_IMPLEMENTATION_PLAN.md) and execution report: [docs/hackathon-audit/W1-B1_EXECUTION_REPORT.md](file:///C:/Users/user/.gemini/antigravity/worktrees/Bilimyol/fix_wave_1_b1_core_learning_integrity/docs/hackathon-audit/W1-B1_EXECUTION_REPORT.md).

## Scope Summary

1. **`FIX-P0-24` (Learning answer idempotency):** Per-attempt RFC 4122 v4 UUIDs for every logical click across Web & Mobile lesson and reinforcement flows, exact UUID reuse on transport retry, `pg_advisory_xact_lock` + `ON CONFLICT` serialization, `selected_answer` replay validation, non-spoiler replay explanations, and `Correct → Wrong → Correct` completion parity (`0` `42501` errors).
2. **`FIX-P1-55` (Learning state recovery):** User-scoped durable pending attempt + `answeredQuestionIds` / `_passedQuestionIds` persistence across timeouts, partial completion failures, `F5` reloads, and app restarts; safe step clamping past answered interactive steps; half-signed-up `/register` session recovery without `422`; offline/unconfigured `signOut` guaranteed local cleanup.
3. **`FIX-P2-23` (Data constraints & daily statistics):** `<=128` idempotency key and `<=4000` answer text bounds (`0` `54000` B-tree crashes), domain `CHECK` constraints across 10 tables, widened `roadmap_nodes.order_index NUMERIC(8,2)`, `<=60/hr` session creation cap, and `(user_id, activity_date, question_id)` daily question statistics deduplication across PostgreSQL, Web `InMemoryLearnerRepository.ts`, and Mobile `in_memory_learner_repository.dart`.
