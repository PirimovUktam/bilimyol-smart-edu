-- Wave 1 · Batch W1-B4: Unified Roadmap Unlock Policy & Math Pilot Spaced-Review Hardening
-- Covers:
--   * FIX-P1-08: Honor >= 80% diagnostic placement mastery on Math Pilot foundation nodes
--                (node_math_addition, node_math_multiplication) so strong learners unlock
--                lesson_math_expressions_intro directly while keeping completedCount = 0.
--   * FIX-P1-17: Decouple Day-8 spaced-review slips from downstream chapter re-locking
--                ((parent.mastered OR parent.previously_completed OR parent.ever_mastered))
--                and expand retrieval review intervals (7d -> 14d -> 30d) across multi-day passes.
--   * FIX-P1-19: Idempotent cleanup of any residual placement_test-only skill score rows on course_eng_01.

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Purge any residual placement-only rows from public.learner_skill_scores
--    on course_eng_01 (FIX-P1-19 defense-in-depth alongside 20261128000100).
-- ----------------------------------------------------------------------------
DELETE FROM public.learner_skill_scores lss
WHERE lss.course_id = 'course_eng_01'
  AND NOT EXISTS (
    SELECT 1
    FROM public.answer_attempts aa
    WHERE aa.user_id = lss.user_id
      AND aa.course_id = 'course_eng_01'
      AND aa.skill_id = lss.skill_id
      AND aa.lesson_id <> 'placement_test'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.reinforcement_attempts ra
    WHERE ra.user_id = lss.user_id
      AND ra.course_id = 'course_eng_01'
      AND ra.skill_id = lss.skill_id
      AND ra.is_correct = true
  );

-- ----------------------------------------------------------------------------
-- 2. Upgrade bilimyol_private.math_progression(UUID) in place (preserving exact
--    19-column signature for unlocked_math_lesson_ids & learner_lessons view).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION bilimyol_private.math_progression(p_uid UUID)
RETURNS TABLE (
  id TEXT,
  course_id TEXT,
  skill_id TEXT,
  title TEXT,
  description TEXT,
  prerequisites JSONB,
  target_lesson_id TEXT,
  estimated_minutes INT,
  order_index NUMERIC,
  status TEXT,
  mastery_state TEXT,
  answered INT,
  correct INT,
  required_items INT,
  required_score INT,
  passed_checkpoints INT,
  required_checkpoints INT,
  review_due BOOLEAN,
  is_optional BOOLEAN
)
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  WITH RECURSIVE objectives AS MATERIALIZED (
    SELECT * FROM bilimyol_private.math_pilot_objectives
  ),
  dependencies AS (
    SELECT n.id AS target_id, parent.id AS ancestor_id
    FROM objectives n
    CROSS JOIN LATERAL pg_catalog.jsonb_array_elements_text(n.prerequisites) AS parent(id)
    UNION
    SELECT d.target_id, parent.id
    FROM dependencies d
    JOIN objectives n ON n.id = d.ancestor_id
    CROSS JOIN LATERAL pg_catalog.jsonb_array_elements_text(n.prerequisites) AS parent(id)
  ),
  placement_context AS MATERIALIZED (
    SELECT
      CASE
        WHEN p_uid IS NULL THEN '{}'::pg_catalog.jsonb
        WHEN lp.placement_skill_scores_by_course IS NOT NULL
          AND lp.placement_skill_scores_by_course ? 'course_math_01'
          AND pg_catalog.jsonb_typeof(lp.placement_skill_scores_by_course->'course_math_01') = 'object'
          AND (lp.placement_skill_scores_by_course->'course_math_01') <> '{}'::pg_catalog.jsonb
        THEN lp.placement_skill_scores_by_course->'course_math_01'
        WHEN latest_plc.id IS NOT NULL THEN COALESCE(
          (bilimyol_private.compute_placement_skill_scores(
            'course_math_01',
            COALESCE(
              (
                SELECT pg_catalog.jsonb_agg(
                  pg_catalog.jsonb_build_object(
                    'question_id', ans.question_id,
                    'selected_index', ans.selected_index
                  )
                  ORDER BY ans.created_at ASC, ans.id ASC
                )
                FROM public.placement_answers ans
                WHERE ans.attempt_id = latest_plc.id
              ),
              '[]'::pg_catalog.jsonb
            )
          ))->'skill_scores',
          '{}'::pg_catalog.jsonb
        )
        ELSE '{}'::pg_catalog.jsonb
      END AS scores
    FROM (SELECT 1) seed
    LEFT JOIN public.learner_profiles lp ON lp.user_id = p_uid
    LEFT JOIN LATERAL (
      SELECT pa.id
      FROM public.placement_attempts pa
      WHERE p_uid IS NOT NULL
        AND pa.user_id = p_uid
        AND pa.course_id = 'course_math_01'
      ORDER BY pa.completed_at DESC, pa.id DESC
      LIMIT 1
    ) latest_plc ON true
  ),
  evidence AS (
    SELECT
      item.lesson_id,
      count(a.id)::INT AS answered,
      count(a.id) FILTER (WHERE a.is_correct)::INT AS correct,
      count(DISTINCT item.checkpoint) FILTER (WHERE a.is_correct)::INT AS checkpoints,
      min(a.created_at) FILTER (WHERE item.checkpoint = 'retrieval') AS last_retrieval
    FROM bilimyol_private.math_pilot_items item
    LEFT JOIN LATERAL (
      SELECT attempt.id, attempt.is_correct, attempt.created_at
      FROM public.answer_attempts attempt
      WHERE p_uid IS NOT NULL
        AND attempt.user_id = p_uid
        AND attempt.course_id = 'course_math_01'
        AND attempt.skill_id = item.skill_id
        AND attempt.lesson_id = item.lesson_id
        AND attempt.question_id = item.question_id
      ORDER BY attempt.created_at DESC, attempt.id DESC
      LIMIT 1
    ) a ON true
    GROUP BY item.lesson_id
  ),
  historical_evidence AS (
    SELECT
      item.lesson_id,
      count(DISTINCT item.question_id) FILTER (WHERE h.ever_attempted)::INT AS hist_answered,
      count(DISTINCT item.question_id) FILTER (WHERE h.ever_correct)::INT AS hist_correct,
      count(DISTINCT item.checkpoint) FILTER (WHERE h.ever_correct)::INT AS hist_checkpoints
    FROM bilimyol_private.math_pilot_items item
    LEFT JOIN LATERAL (
      SELECT
        count(attempt.id) > 0 AS ever_attempted,
        COALESCE(bool_or(attempt.is_correct), false) AS ever_correct
      FROM public.answer_attempts attempt
      WHERE p_uid IS NOT NULL
        AND attempt.user_id = p_uid
        AND attempt.course_id = 'course_math_01'
        AND attempt.skill_id = item.skill_id
        AND attempt.lesson_id = item.lesson_id
        AND attempt.question_id = item.question_id
    ) h ON true
    GROUP BY item.lesson_id
  ),
  retrieval_srs AS (
    SELECT
      r_item.lesson_id,
      COALESCE(min(r_item.item_streak), 0)::INT AS min_retrieval_streak
    FROM (
      SELECT
        item.lesson_id,
        item.question_id,
        (
          SELECT count(DISTINCT pg_catalog.date_trunc('day', attempt.created_at AT TIME ZONE 'UTC'))::INT
          FROM public.answer_attempts attempt
          WHERE p_uid IS NOT NULL
            AND attempt.user_id = p_uid
            AND attempt.course_id = 'course_math_01'
            AND attempt.skill_id = item.skill_id
            AND attempt.lesson_id = item.lesson_id
            AND attempt.question_id = item.question_id
            AND attempt.is_correct = true
            AND (
              last_wrong.id IS NULL
              OR (attempt.created_at, attempt.id::TEXT) > (last_wrong.created_at, last_wrong.id::TEXT)
            )
        ) AS item_streak
      FROM bilimyol_private.math_pilot_items item
      LEFT JOIN LATERAL (
        SELECT attempt.id, attempt.created_at
        FROM public.answer_attempts attempt
        WHERE p_uid IS NOT NULL
          AND attempt.user_id = p_uid
          AND attempt.course_id = 'course_math_01'
          AND attempt.skill_id = item.skill_id
          AND attempt.lesson_id = item.lesson_id
          AND attempt.question_id = item.question_id
          AND attempt.is_correct IS DISTINCT FROM true
        ORDER BY attempt.created_at DESC, attempt.id DESC
        LIMIT 1
      ) last_wrong ON true
      WHERE item.checkpoint = 'retrieval'
    ) r_item
    GROUP BY r_item.lesson_id
  ),
  evaluated AS MATERIALIZED (
    SELECT
      n.*,
      COALESCE(e.answered, 0) AS answered,
      COALESCE(e.correct, 0) AS correct,
      COALESCE(e.checkpoints, 0) AS checkpoints,
      e.last_retrieval,
      p.min_items,
      p.min_accuracy,
      p.min_checkpoints,
      CASE
        WHEN COALESCE(rs.min_retrieval_streak, 0) >= 3 THEN INTERVAL '30 days'
        WHEN COALESCE(rs.min_retrieval_streak, 0) = 2 THEN INTERVAL '14 days'
        ELSE p.review_interval
      END AS effective_review_interval,
      COALESCE(
        e.answered >= p.min_items
          AND 100 * e.correct >= p.min_accuracy * e.answered
          AND e.checkpoints >= p.min_checkpoints,
        false
      ) AS mastered,
      EXISTS (
        SELECT 1
        FROM public.lesson_progress lp
        WHERE p_uid IS NOT NULL
          AND lp.user_id = p_uid
          AND lp.course_id = n.course_id
          AND lp.lesson_id = n.target_lesson_id
          AND lp.status = 'completed'
      ) AS previously_completed,
      COALESCE(
        he.hist_answered >= p.min_items
          AND 100 * he.hist_correct >= p.min_accuracy * he.hist_answered
          AND he.hist_checkpoints >= p.min_checkpoints,
        false
      ) AS ever_mastered,
      (
        n.id IN ('node_math_addition', 'node_math_multiplication')
        AND (COALESCE(e.answered, 0) - COALESCE(e.correct, 0) < 2)
        AND pg_catalog.jsonb_typeof(plc.scores->n.skill_id->'score') = 'number'
        AND ((plc.scores->n.skill_id->>'score')::NUMERIC >= n.required_score)
      ) AS placement_mastered
    FROM objectives n
    CROSS JOIN bilimyol_private.math_pilot_policy p
    CROSS JOIN placement_context plc
    LEFT JOIN evidence e ON e.lesson_id = n.target_lesson_id
    LEFT JOIN historical_evidence he ON he.lesson_id = n.target_lesson_id
    LEFT JOIN retrieval_srs rs ON rs.lesson_id = n.target_lesson_id
  ),
  resolved AS (
    SELECT
      n.*,
      (
        n.mastered
        OR n.previously_completed
        OR n.ever_mastered
        OR NOT EXISTS (
          SELECT 1
          FROM dependencies d
          LEFT JOIN evaluated parent ON parent.id = d.ancestor_id
          WHERE d.target_id = n.id
            AND (
              NOT COALESCE(
                parent.mastered
                  OR (parent.previously_completed AND parent.answered > 0)
                  OR parent.ever_mastered
                  OR parent.placement_mastered,
                false
              )
              OR parent.order_index >= n.order_index
            )
        )
      ) AS eligible,
      NOT n.mastered AND (
        n.answered - n.correct >= 2
        OR n.previously_completed
        OR n.ever_mastered
      ) AS needs_review
    FROM evaluated n
  )
  SELECT
    n.id,
    n.course_id,
    n.skill_id,
    n.title,
    n.description,
    n.prerequisites,
    n.target_lesson_id,
    n.estimated_minutes,
    n.order_index,
    CASE
      WHEN NOT n.eligible THEN 'locked'
      WHEN n.mastered THEN 'completed'
      WHEN n.needs_review THEN 'reinforcement'
      WHEN n.answered > 0 THEN 'in_progress'
      ELSE 'available'
    END,
    CASE
      WHEN n.mastered THEN 'mastered'
      WHEN n.needs_review THEN 'needs_review'
      WHEN n.answered > 0 THEN 'practicing'
      ELSE 'not_started'
    END,
    n.answered,
    n.correct,
    n.min_items,
    n.min_accuracy,
    n.checkpoints,
    n.min_checkpoints,
    COALESCE(
      n.eligible
        AND n.mastered
        AND n.last_retrieval <= now() - n.effective_review_interval,
      false
    ),
    n.is_optional
  FROM resolved n
  ORDER BY n.order_index;
$$;

REVOKE ALL ON FUNCTION bilimyol_private.math_progression(UUID)
  FROM PUBLIC, anon, authenticated;

COMMIT;
