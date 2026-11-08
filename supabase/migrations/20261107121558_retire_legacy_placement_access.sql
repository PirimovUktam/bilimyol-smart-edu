BEGIN;

-- Apply after both clients have moved to advance_placement. The existing
-- saver stays available inside the trusted finalization transaction.
REVOKE ALL ON FUNCTION public.evaluate_placement_answer(TEXT, TEXT, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.save_placement_attempt(TEXT, JSONB, TEXT) FROM PUBLIC, anon, authenticated;
ALTER POLICY "Authenticated learners can read questions" ON public.questions USING (NOT is_placement);

NOTIFY pgrst, 'reload schema';
COMMIT;
