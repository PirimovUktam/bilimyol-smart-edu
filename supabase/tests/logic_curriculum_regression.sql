BEGIN;

INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES ('00000000-0000-0000-0000-000000000681', 'logic-curriculum@example.invalid', '{}');

SET LOCAL ROLE authenticated;

DO $$
DECLARE
  lesson jsonb;
  result jsonb;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000681', true);
  IF (SELECT count(*) FROM public.learner_lessons WHERE course_id = 'course_logic') <> 12
    OR (SELECT count(*) FROM public.roadmap_nodes WHERE course_id = 'course_logic' AND is_active) <> 12 THEN
    RAISE EXCEPTION 'The 12 lessons and roadmap nodes must all be visible';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.roadmap_nodes
    WHERE id = 'node_logic_patterns' AND prerequisites = '["node_logic_evidence"]'::jsonb) THEN
    RAISE EXCEPTION 'The legacy pattern node must remain connected to the new path';
  END IF;
  SELECT steps INTO lesson FROM public.learner_lessons WHERE id = 'lesson_logic_starter';
  IF lesson->1->'media'->>'source' IS DISTINCT FROM '/lesson-media/logic/truth.png'
    OR lesson::text ~ 'correctIndex|correct_index|explanation' THEN
    RAISE EXCEPTION 'The learner view must serve the diagram without answer keys';
  END IF;
  result := public.submit_answer_attempt(auth.uid(), 'course_logic', 'skill_logic_puzzles',
    'lesson_logic_starter', 'q_lesson_logic_starter_v2_1', 1, 'B', 'logic-curriculum-application');
  IF result->>'is_correct' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'The server must grade the authored choice by index';
  END IF;
END $$;

ROLLBACK;
