-- Disposable/local PostgreSQL only, after all migrations. Every fixture rolls back.
-- Regression suite for Wave 0 · Batch W0-B3 (FIX-P1-48):
--   1. Sole-admin / self-demotion guard & >= 1 active admin invariant
--   2. Multi-admin serialization, bilimyol_private.admin_audit_log recording & privilege lockdown,
--      and demoted caller rejection after role loss
--   3. promote_user_to_admin confirmed-email + profile existence guards & W0-B1 privilege matrix
--   4. is_admin() conditional MFA step-up (aal2 required when verified factor exists)
BEGIN;

CREATE FUNCTION pg_temp.assert_w0b3(ok BOOLEAN, label TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF ok IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'ASSERT [W0-B3]: %', label;
  END IF;
END;
$$;

-- Ensure fixtures run deterministically even if local dev DB had extra test admins
DELETE FROM public.profiles WHERE role = 'admin';

INSERT INTO auth.users (id, email, email_confirmed_at, raw_user_meta_data) VALUES
  ('00000000-0000-0000-0000-000000000801', 'w0b3-admin-a@example.invalid', now(), '{}'),
  ('00000000-0000-0000-0000-000000000802', 'w0b3-student-b@example.invalid', now(), '{}'),
  ('00000000-0000-0000-0000-000000000803', 'w0b3-unconfirmed-c@example.invalid', NULL, '{}'),
  ('00000000-0000-0000-0000-000000000804', 'w0b3-noprofile-d@example.invalid', now(), '{}');

-- Simulate an auth.users account missing a public.profiles row
DELETE FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000804';

-- Bootstrap Admin A as the sole initial administrator without touching audit log
SELECT set_config('bilimyol.authorized_role_change', 'true', true);
UPDATE public.profiles
SET role = 'admin'
WHERE id = '00000000-0000-0000-0000-000000000801';
SELECT set_config('bilimyol.authorized_role_change', '', true);

-- ============================================================================
-- Check 1: Sole admin cannot self-demote (0-admin lockout prevention)
-- ============================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000801', true);
SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000801","aal":"aal1"}', true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_res JSONB;
BEGIN
  v_res := public.admin_update_user_role(auth.uid(), 'student');
  PERFORM pg_temp.assert_w0b3(
    COALESCE((v_res->>'success')::BOOLEAN, true) = false,
    'Check 1: sole_admin_self_demote must return success=false'
  );
END;
$$;

RESET ROLE;

SELECT pg_temp.assert_w0b3(
  (SELECT count(*) FROM public.profiles WHERE role = 'admin') = 1,
  'Check 1: admin count stays 1 after sole admin self-demotion attempt'
);

-- ============================================================================
-- Check 2: Multi-admin promotion/demotion, audit log, demoted caller & grants
-- ============================================================================
SELECT pg_temp.assert_w0b3(
  to_regclass('bilimyol_private.admin_audit_log') IS NOT NULL,
  'Check 2: bilimyol_private.admin_audit_log table exists'
);

SELECT pg_temp.assert_w0b3(
  NOT has_table_privilege('anon', 'bilimyol_private.admin_audit_log', 'SELECT')
    AND NOT has_table_privilege('anon', 'bilimyol_private.admin_audit_log', 'INSERT')
    AND NOT has_table_privilege('anon', 'bilimyol_private.admin_audit_log', 'UPDATE')
    AND NOT has_table_privilege('anon', 'bilimyol_private.admin_audit_log', 'DELETE')
    AND NOT has_table_privilege('authenticated', 'bilimyol_private.admin_audit_log', 'SELECT')
    AND NOT has_table_privilege('authenticated', 'bilimyol_private.admin_audit_log', 'INSERT')
    AND NOT has_table_privilege('authenticated', 'bilimyol_private.admin_audit_log', 'UPDATE')
    AND NOT has_table_privilege('authenticated', 'bilimyol_private.admin_audit_log', 'DELETE')
    AND NOT has_table_privilege('service_role', 'bilimyol_private.admin_audit_log', 'SELECT'),
  'Check 2: anon, authenticated, and service_role hold 0 privileges on bilimyol_private.admin_audit_log'
);

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000801', true);
SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000801","aal":"aal1"}', true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_promote JSONB;
  v_demote JSONB;
  v_unconfirmed JSONB;
  v_self_while_two JSONB;
BEGIN
  -- Promoting unconfirmed user via admin_update_user_role is rejected
  v_unconfirmed := public.admin_update_user_role('00000000-0000-0000-0000-000000000803', 'admin');
  PERFORM pg_temp.assert_w0b3(
    COALESCE((v_unconfirmed->>'success')::BOOLEAN, true) = false,
    'Check 2: admin_update_user_role rejects unconfirmed email promotion'
  );

  -- Admin A promotes confirmed Student B to admin
  v_promote := public.admin_update_user_role('00000000-0000-0000-0000-000000000802', 'admin');
  PERFORM pg_temp.assert_w0b3(
    COALESCE((v_promote->>'success')::BOOLEAN, false) = true
      AND v_promote->>'role' = 'admin',
    'Check 2: Admin A promotes confirmed Student B to admin'
  );

  -- Even when 2 admins exist, self-demotion remains blocked
  v_self_while_two := public.admin_update_user_role(auth.uid(), 'student');
  PERFORM pg_temp.assert_w0b3(
    COALESCE((v_self_while_two->>'success')::BOOLEAN, true) = false,
    'Check 2: Admin A cannot self-demote even when another admin exists'
  );

  -- Admin A demotes Admin B back to student
  v_demote := public.admin_update_user_role('00000000-0000-0000-0000-000000000802', 'student');
  PERFORM pg_temp.assert_w0b3(
    COALESCE((v_demote->>'success')::BOOLEAN, false) = true
      AND v_demote->>'role' = 'student',
    'Check 2: Admin A demotes Admin B back to student'
  );
END;
$$;

RESET ROLE;

SELECT pg_temp.assert_w0b3(
  (SELECT count(*) FROM bilimyol_private.admin_audit_log
   WHERE actor_user_id = '00000000-0000-0000-0000-000000000801'
     AND target_user_id = '00000000-0000-0000-0000-000000000802') = 2,
  'Check 2: exactly 2 audit rows written for Admin B promote + demote'
);

-- Demoted caller B attempting admin_update_user_role is rejected
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000802', true);
SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000802","aal":"aal1"}', true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_demoted_attempt JSONB;
BEGIN
  v_demoted_attempt := public.admin_update_user_role('00000000-0000-0000-0000-000000000801', 'student');
  PERFORM pg_temp.assert_w0b3(
    COALESCE((v_demoted_attempt->>'success')::BOOLEAN, true) = false,
    'Check 2: demoted caller B is rejected from updating roles'
  );
END;
$$;

RESET ROLE;

SELECT pg_temp.assert_w0b3(
  (SELECT role FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000801') = 'admin',
  'Check 2: Admin A remains admin after demoted caller attempt'
);

-- ============================================================================
-- Check 3: promote_user_to_admin confirmed-email + profile checks & W0-B1 grants
-- ============================================================================
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT set_config('request.jwt.claims', '', true);

DO $$
DECLARE
  v_unconf JSONB;
  v_noprof JSONB;
  v_ok JSONB;
BEGIN
  v_unconf := public.promote_user_to_admin('w0b3-unconfirmed-c@example.invalid');
  PERFORM pg_temp.assert_w0b3(
    COALESCE((v_unconf->>'success')::BOOLEAN, true) = false,
    'Check 3: promote_user_to_admin rejects unconfirmed email'
  );

  v_noprof := public.promote_user_to_admin('w0b3-noprofile-d@example.invalid');
  PERFORM pg_temp.assert_w0b3(
    COALESCE((v_noprof->>'success')::BOOLEAN, true) = false,
    'Check 3: promote_user_to_admin rejects user without public.profiles row'
  );

  PERFORM pg_temp.assert_w0b3(
    NOT EXISTS (
      SELECT 1 FROM bilimyol_private.admin_audit_log
      WHERE target_user_id IN (
        '00000000-0000-0000-0000-000000000803',
        '00000000-0000-0000-0000-000000000804'
      )
    ),
    'Check 3: rejected promote_user_to_admin calls write 0 false audit rows'
  );

  v_ok := public.promote_user_to_admin('w0b3-student-b@example.invalid');
  PERFORM pg_temp.assert_w0b3(
    COALESCE((v_ok->>'success')::BOOLEAN, false) = true
      AND v_ok->>'role' = 'admin',
    'Check 3: promote_user_to_admin succeeds for confirmed user with profile'
  );
END;
$$;

SELECT pg_temp.assert_w0b3(
  EXISTS (
    SELECT 1 FROM bilimyol_private.admin_audit_log
    WHERE target_user_id = '00000000-0000-0000-0000-000000000802'
      AND action = 'promote_user_to_admin'
      AND previous_role = 'student'
      AND new_role = 'admin'
  ),
  'Check 3: successful promote_user_to_admin writes audit row'
);

SELECT pg_temp.assert_w0b3(
  NOT has_function_privilege('authenticated', 'public.promote_user_to_admin(text)', 'execute')
    AND NOT has_function_privilege('anon', 'public.promote_user_to_admin(text)', 'execute')
    AND NOT has_function_privilege('service_role', 'public.promote_user_to_admin(text)', 'execute')
    AND NOT has_function_privilege('anon', 'public.is_admin()', 'execute')
    AND has_function_privilege('authenticated', 'public.is_admin()', 'execute')
    AND has_function_privilege('service_role', 'public.is_admin()', 'execute')
    AND NOT has_function_privilege('anon', 'public.admin_update_user_role(uuid,text)', 'execute')
    AND has_function_privilege('authenticated', 'public.admin_update_user_role(uuid,text)', 'execute'),
  'Check 3: W0-B1 REVOKE/GRANT function privilege invariants preserved'
);

-- ============================================================================
-- Check 4: is_admin() conditional MFA step-up (aal2 when verified factor exists)
-- ============================================================================
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000801', true);
SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000801","aal":"aal1"}', true);
SET LOCAL ROLE authenticated;

SELECT pg_temp.assert_w0b3(
  public.is_admin() = true,
  'Check 4: is_admin() returns true at aal1 when admin has 0 verified MFA factors'
);

RESET ROLE;

-- Unverified factor alone must not require aal2
INSERT INTO auth.mfa_factors (id, user_id, factor_type, status, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000890',
  '00000000-0000-0000-0000-000000000801',
  'totp',
  'unverified',
  now(),
  now()
);

SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_w0b3(
  public.is_admin() = true,
  'Check 4: is_admin() returns true at aal1 when only unverified MFA factor exists'
);
RESET ROLE;

-- Verified MFA factor requires aal2
INSERT INTO auth.mfa_factors (id, user_id, factor_type, status, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000891',
  '00000000-0000-0000-0000-000000000801',
  'totp',
  'verified',
  now(),
  now()
);

SET LOCAL ROLE authenticated;

SELECT pg_temp.assert_w0b3(
  public.is_admin() = false,
  'Check 4: is_admin() returns false at aal1 when verified MFA factor exists'
);

SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000801"}', true);
SELECT pg_temp.assert_w0b3(
  public.is_admin() = false,
  'Check 4: is_admin() returns false when aal claim omitted and verified MFA factor exists'
);

SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000801","aal":"aal2"}', true);
SELECT pg_temp.assert_w0b3(
  public.is_admin() = true,
  'Check 4: is_admin() returns true when request.jwt.claims carries aal=aal2'
);

RESET ROLE;
ROLLBACK;
