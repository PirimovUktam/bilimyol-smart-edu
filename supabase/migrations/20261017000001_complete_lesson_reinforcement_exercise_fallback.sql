-- ==============================================================================
-- complete_lesson(): fall back to reinforcement_exercise->>'id' when no
-- interactiveQuestion step carries an id. Seed lessons store their interactive
-- assessment in `reinforcement_exercise` (which already carries the questions.id
-- the learner answered via submit_answer_attempt), while generated lessons and
-- inline interactiveQuestion steps carry `id` inside the step object.
--
-- Before this patch, complete_lesson() raised 'Darsning baholanadigan savollari
-- topilmadi.' for every lesson whose interactive question lived only in
-- reinforcement_exercise (i.e. the seed lessons). This widens the question-id
-- derivation so those lessons can complete server-side.
-- ==============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.complete_lesson(p_lesson_id TEXT, p_course_id TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_course TEXT;
  v_skill TEXT;
  v_questions TEXT[];
  v_question TEXT;
  v_award JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autentifikatsiya talab qilinadi.' USING ERRCODE = '42501';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('learning:' || v_uid::TEXT, 0));

  SELECT l.course_id, l.skill_id, ARRAY(
    SELECT COALESCE(step->'interactiveQuestion', step->'interactive_question')->>'id'
    FROM jsonb_array_elements(l.steps) AS step
    WHERE NULLIF(COALESCE(step->'interactiveQuestion', step->'interactive_question')->>'id', '') IS NOT NULL
  ) INTO v_course, v_skill, v_questions
  FROM public.lessons l WHERE l.id = p_lesson_id AND l.is_published AND NOT l.is_archived;

  -- Seed lessons keep the interactive assessment in `reinforcement_exercise`
  -- rather than inside a step's `interactiveQuestion` object. When no step
  -- carries an id, fall back to the reinforcement exercise's question id, which
  -- is the same questions.id the learner answers via submit_answer_attempt.
  IF v_course IS NOT NULL AND COALESCE(cardinality(v_questions), 0) = 0 THEN
    SELECT ARRAY[l.reinforcement_exercise->>'id']
      INTO v_questions
      FROM public.lessons l
      WHERE l.id = p_lesson_id
        AND NULLIF(l.reinforcement_exercise->>'id', '') IS NOT NULL;
  END IF;

  IF v_course IS NULL THEN
    -- The generated lesson renderer currently delivers the first cached
    -- question as its interactive assessment on both clients.
    SELECT course_id, skill_id, ARRAY[questions->0->>'id']
    INTO v_course, v_skill, v_questions
    FROM public.generated_lessons WHERE id = p_lesson_id;
  END IF;
  IF v_course IS NULL OR v_course IS DISTINCT FROM p_course_id THEN
    RAISE EXCEPTION 'Dars kursda topilmadi.' USING ERRCODE = '22023';
  END IF;
  IF COALESCE(cardinality(v_questions), 0) = 0 THEN
    RAISE EXCEPTION 'Darsning baholanadigan savollari topilmadi.' USING ERRCODE = '22023';
  END IF;
  FOREACH v_question IN ARRAY v_questions LOOP
    IF v_question IS NULL OR NOT COALESCE((
      SELECT is_correct FROM public.answer_attempts
      WHERE user_id = v_uid AND course_id = v_course AND skill_id = v_skill
        AND lesson_id = p_lesson_id AND question_id = v_question
      ORDER BY created_at DESC, id DESC LIMIT 1
    ), false) THEN
      RAISE EXCEPTION 'Dars javoblari serverda tasdiqlanmagan.' USING ERRCODE = '42501';
    END IF;
  END LOOP;

  INSERT INTO public.lesson_progress (
    user_id, lesson_id, course_id, status, progress_percent, completed_at, updated_at
  ) VALUES (v_uid, p_lesson_id, v_course, 'completed', 100, now(), now())
  ON CONFLICT (user_id, lesson_id) DO UPDATE SET
    status = 'completed', progress_percent = 100,
    completed_at = COALESCE(lesson_progress.completed_at, now()), updated_at = now();
  v_award := public.award_xp(20, 'lesson_completed_' || p_lesson_id);
  PERFORM public.record_learning_activity();
  RETURN jsonb_build_object('completed', true, 'xp_awarded',
    CASE WHEN (v_award->>'awarded')::BOOLEAN THEN 20 ELSE 0 END);
END;
$$;

COMMIT;
