-- Disposable/local PostgreSQL only, after all migrations. Fixtures roll back.
BEGIN;

CREATE FUNCTION pg_temp.assert_absent(value BOOLEAN, message TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF value IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %', message; END IF;
END;
$$;

SELECT pg_temp.assert_absent(
  to_regclass('public.parent_student_links') IS NULL
    AND to_regclass('public.classes') IS NULL
    AND to_regclass('public.class_members') IS NULL
    AND to_regclass('public.teacher_invitation_codes') IS NULL
    AND to_regclass('public.teacher_invitation_attempts') IS NULL
    AND to_regclass('public.student_alerts') IS NULL,
  'retired relationship, invitation, and alert tables are absent'
);

SELECT pg_temp.assert_absent(
  to_regprocedure('public.create_parent_link_code()') IS NULL
    AND to_regprocedure('public.redeem_parent_link_code(text)') IS NULL
    AND to_regprocedure('public.create_teacher_class(text,text,text)') IS NULL
    AND to_regprocedure('public.join_class_by_code(text)') IS NULL
    AND to_regprocedure('public.create_teacher_invitation(text,integer,integer)') IS NULL
    AND to_regprocedure('public.list_teacher_invitations()') IS NULL
    AND to_regprocedure('public.revoke_teacher_invitation(uuid)') IS NULL
    AND to_regprocedure('public.redeem_teacher_invitation_code(text)') IS NULL,
  'retired relationship and invitation RPCs are absent'
);

SELECT pg_temp.assert_absent(
  to_regclass('public.learning_sessions') IS NOT NULL
    AND to_regclass('public.daily_learning_stats') IS NOT NULL
    AND to_regprocedure('public.record_session_heartbeat(uuid,text,text,text)') IS NOT NULL,
  'learner heartbeat and daily-stat persistence remain available'
);

SELECT pg_temp.assert_absent(
  EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.profiles'::regclass
      AND conname = 'profiles_role_check'
      AND lower(pg_get_constraintdef(oid)) LIKE '%student%'
      AND lower(pg_get_constraintdef(oid)) LIKE '%admin%'
      AND lower(pg_get_constraintdef(oid)) NOT LIKE '%parent%'
      AND lower(pg_get_constraintdef(oid)) NOT LIKE '%teacher%'
  ),
  'profiles accepts only student and admin roles'
);

ROLLBACK;
