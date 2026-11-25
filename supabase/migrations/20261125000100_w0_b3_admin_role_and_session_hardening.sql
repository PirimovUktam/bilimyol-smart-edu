-- ============================================================================
-- BILIMYO'L SMART EDU - WAVE 0 · BATCH W0-B3
-- Migration: 20261125000100_w0_b3_admin_role_and_session_hardening.sql
-- Scope: FIX-P1-48
--   * bilimyol_private.admin_audit_log (RLS enabled, all API privileges revoked,
--     no RESTRICT FK to auth.users)
--   * public.is_admin() conditional MFA step-up (requires aal2 when caller has
--     a verified factor in auth.mfa_factors; preserves W0-B1 grant posture)
--   * public.admin_update_user_role(UUID, TEXT) advisory + FOR UPDATE row lock,
--     post-lock is_admin() re-check, self/last-admin demotion protection,
--     confirmed-email requirement on admin promotion, and audit logging
--   * public.promote_user_to_admin(TEXT) confirmed-email + profiles existence
--     check (IF NOT FOUND), audit logging, and W0-B1 postgres-only execute grant
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Private Admin Role Mutation Audit Log
-- ----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS bilimyol_private;
REVOKE ALL ON SCHEMA bilimyol_private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS bilimyol_private.admin_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id UUID,
  actor_session_user TEXT NOT NULL,
  target_user_id UUID NOT NULL,
  action TEXT NOT NULL,
  previous_role TEXT,
  new_role TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_target_created
  ON bilimyol_private.admin_audit_log (target_user_id, created_at DESC);

ALTER TABLE bilimyol_private.admin_audit_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE bilimyol_private.admin_audit_log
  FROM PUBLIC, anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. public.is_admin() with Conditional MFA aal2 Step-Up
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_has_verified_mfa BOOLEAN := false;
  v_aal TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN false;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = v_uid
      AND p.role = 'admin'
  ) THEN
    RETURN false;
  END IF;

  IF pg_catalog.to_regclass('auth.mfa_factors') IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM auth.mfa_factors mf
      WHERE mf.user_id = v_uid
        AND mf.status::TEXT = 'verified'
    )
    INTO v_has_verified_mfa;

    IF v_has_verified_mfa THEN
      v_aal := COALESCE(
        NULLIF(pg_catalog.current_setting('request.jwt.claim.aal', true), ''),
        (NULLIF(pg_catalog.current_setting('request.jwt.claims', true), '')::pg_catalog.jsonb ->> 'aal'),
        'aal1'
      );
      IF v_aal IS DISTINCT FROM 'aal2' THEN
        RETURN false;
      END IF;
    END IF;
  END IF;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Concurrency-Safe public.admin_update_user_role(UUID, TEXT)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_update_user_role(
  p_user_id UUID,
  p_new_role TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_clean_role TEXT := pg_catalog.lower(pg_catalog.btrim(COALESCE(p_new_role, '')));
  v_prev_role TEXT;
  v_remaining_admins INT := 0;
BEGIN
  IF v_caller_id IS NULL OR NOT public.is_admin() THEN
    RETURN pg_catalog.jsonb_build_object(
      'success', false,
      'message', 'Ruxsat etilmagan: Faqat platforma administratori foydalanuvchi rolini o‘zgartira oladi.'
    );
  END IF;

  IF p_user_id IS NULL THEN
    RETURN pg_catalog.jsonb_build_object(
      'success', false,
      'message', 'Foydalanuvchi topilmadi.'
    );
  END IF;

  IF v_clean_role NOT IN ('student', 'admin') THEN
    RETURN pg_catalog.jsonb_build_object(
      'success', false,
      'message', 'Noto‘g‘ri rol kiritildi. Ruxsat etilgan rollar: student, admin.'
    );
  END IF;

  IF p_user_id = v_caller_id AND v_clean_role <> 'admin' THEN
    RETURN pg_catalog.jsonb_build_object(
      'success', false,
      'message', 'Administrator o‘z rolini pasaytira olmaydi.'
    );
  END IF;

  -- Serialize all admin role mutations across concurrent transactions
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('bilimyol:admin_role_mutation', 0)
  );

  -- Lock caller, target, and all current admin rows in deterministic order
  PERFORM 1
  FROM public.profiles p
  WHERE p.id IN (v_caller_id, p_user_id)
     OR p.role = 'admin'
  ORDER BY p.id
  FOR UPDATE;

  -- Re-verify caller admin authority after acquiring locks (READ COMMITTED race guard)
  IF NOT public.is_admin() THEN
    RETURN pg_catalog.jsonb_build_object(
      'success', false,
      'message', 'Ruxsat etilmagan: Administrator huquqi bekor qilingan.'
    );
  END IF;

  SELECT p.role
  INTO v_prev_role
  FROM public.profiles p
  WHERE p.id = p_user_id;

  IF NOT FOUND THEN
    RETURN pg_catalog.jsonb_build_object(
      'success', false,
      'message', 'Foydalanuvchi topilmadi.'
    );
  END IF;

  IF v_prev_role = 'admin' AND v_clean_role <> 'admin' THEN
    IF p_user_id = v_caller_id THEN
      RETURN pg_catalog.jsonb_build_object(
        'success', false,
        'message', 'Administrator o‘z rolini pasaytira olmaydi.'
      );
    END IF;

    SELECT pg_catalog.count(*)::INT
    INTO v_remaining_admins
    FROM public.profiles p
    WHERE p.role = 'admin'
      AND p.id <> p_user_id;

    IF v_remaining_admins < 1 THEN
      RETURN pg_catalog.jsonb_build_object(
        'success', false,
        'message', 'Kamida bitta faol administrator qolishi shart.'
      );
    END IF;
  END IF;

  IF v_clean_role = 'admin' AND v_prev_role IS DISTINCT FROM 'admin' THEN
    IF NOT EXISTS (
      SELECT 1
      FROM auth.users u
      WHERE u.id = p_user_id
        AND u.email_confirmed_at IS NOT NULL
    ) THEN
      RETURN pg_catalog.jsonb_build_object(
        'success', false,
        'message', 'Foydalanuvchi email manzili tasdiqlanmagan.'
      );
    END IF;
  END IF;

  IF v_prev_role IS DISTINCT FROM v_clean_role THEN
    PERFORM pg_catalog.set_config('bilimyol.authorized_role_change', 'true', true);

    UPDATE public.profiles
    SET role = v_clean_role,
        updated_at = pg_catalog.now()
    WHERE id = p_user_id;

    INSERT INTO bilimyol_private.admin_audit_log (
      actor_user_id,
      actor_session_user,
      target_user_id,
      action,
      previous_role,
      new_role
    )
    VALUES (
      v_caller_id,
      SESSION_USER,
      p_user_id,
      'admin_update_user_role',
      v_prev_role,
      v_clean_role
    );
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'success', true,
    'user_id', p_user_id,
    'role', v_clean_role,
    'message', 'Foydalanuvchi roli muvaffaqiyatli yangilandi.'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_user_role(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_user_role(UUID, TEXT) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Hardened public.promote_user_to_admin(TEXT) (W0-B1 Postgres-Only Posture)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.promote_user_to_admin(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_target_id UUID;
  v_confirmed_at TIMESTAMPTZ;
  v_prev_role TEXT;
  v_clean_email TEXT := pg_catalog.lower(pg_catalog.btrim(COALESCE(p_email, '')));
BEGIN
  IF v_caller_id IS NOT NULL THEN
    IF NOT public.is_admin() THEN
      RETURN pg_catalog.jsonb_build_object(
        'success', false,
        'message', 'Ruxsat etilmagan. Faqat platforma administratori boshqa foydalanuvchini admin qila oladi.'
      );
    END IF;
  ELSE
    IF SESSION_USER NOT IN ('postgres', 'service_role') THEN
      RETURN pg_catalog.jsonb_build_object(
        'success', false,
        'message', 'Ruxsat etilmagan seans.'
      );
    END IF;
  END IF;

  IF v_clean_email = '' THEN
    RETURN pg_catalog.jsonb_build_object(
      'success', false,
      'message', 'Email manzili kiritilishi shart.'
    );
  END IF;

  SELECT u.id, u.email_confirmed_at
  INTO v_target_id, v_confirmed_at
  FROM auth.users u
  WHERE pg_catalog.lower(u.email) = v_clean_email
  LIMIT 1;

  IF v_target_id IS NULL THEN
    RETURN pg_catalog.jsonb_build_object(
      'success', false,
      'message', 'Ko‘rsatilgan email (' || v_clean_email || ') bilan foydalanuvchi topilmadi. Avval ro‘yxatdan o‘ting.'
    );
  END IF;

  IF v_confirmed_at IS NULL THEN
    RETURN pg_catalog.jsonb_build_object(
      'success', false,
      'message', 'Foydalanuvchi email manzili tasdiqlanmagan.'
    );
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('bilimyol:admin_role_mutation', 0)
  );

  SELECT p.role
  INTO v_prev_role
  FROM public.profiles p
  WHERE p.id = v_target_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN pg_catalog.jsonb_build_object(
      'success', false,
      'message', 'Foydalanuvchi profili topilmadi.'
    );
  END IF;

  PERFORM pg_catalog.set_config('bilimyol.authorized_role_change', 'true', true);

  UPDATE public.profiles
  SET role = 'admin',
      updated_at = pg_catalog.now()
  WHERE id = v_target_id;

  INSERT INTO bilimyol_private.admin_audit_log (
    actor_user_id,
    actor_session_user,
    target_user_id,
    action,
    previous_role,
    new_role
  )
  VALUES (
    v_caller_id,
    SESSION_USER,
    v_target_id,
    'promote_user_to_admin',
    v_prev_role,
    'admin'
  );

  RETURN pg_catalog.jsonb_build_object(
    'success', true,
    'user_id', v_target_id,
    'email', v_clean_email,
    'role', 'admin',
    'message', 'Foydalanuvchi (' || v_clean_email || ') muvaffaqiyatli Admin roliga o‘tkazildi.'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.promote_user_to_admin(TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.promote_user_to_admin(TEXT) TO postgres;

COMMENT ON TABLE bilimyol_private.admin_audit_log IS
  'Private audit log of admin role transitions; inaccessible to API roles.';
COMMENT ON FUNCTION public.is_admin() IS
  'Checks admin role on public.profiles and enforces JWT aal2 when the user has a verified MFA factor.';
COMMENT ON FUNCTION public.admin_update_user_role(UUID, TEXT) IS
  'Concurrency-safe administrative role RPC with self/last-admin demotion guards, confirmed-email check, and audit logging.';
COMMENT ON FUNCTION public.promote_user_to_admin(TEXT) IS
  'Database-owner bootstrap admin promotion RPC requiring confirmed email, existing profile, and audit logging.';

NOTIFY pgrst, 'reload schema';

COMMIT;
