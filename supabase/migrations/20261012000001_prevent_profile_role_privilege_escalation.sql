-- ==============================================================================
-- BILIMYO‘L SMART EDU - MIGRATION 20261012000001
-- File: supabase/migrations/20261012000001_prevent_profile_role_privilege_escalation.sql
--
-- P0 PRIVILEGE ESCALATION FIX FOR PUBLIC.PROFILES.ROLE
-- 
-- 1. REVOKES general table-level UPDATE and INSERT on public.profiles from authenticated, anon, PUBLIC.
-- 2. GRANTS column-level UPDATE strictly on user-editable profile columns:
--    (first_name, last_name, display_name, avatar_url, updated_at).
--    Excludes 'role', 'id', 'created_at'.
-- 3. GRANTS column-level INSERT strictly on safe profile creation columns:
--    (id, first_name, last_name, display_name, email, avatar_url, created_at, updated_at).
--    Excludes 'role' (ensures default 'student' is applied).
-- 4. ADDS SECURE AUTHORIZATION TRIGGER:
--    Blocks unauthorized direct role changes completely.
--    Allows role updates ONLY if explicit transaction-local authorization flag
--    (current_setting('bilimyol.authorized_role_change', true) = 'true') is set by vetted server RPCs.
--    Eliminates all bypasses (auth.uid() IS NULL, CURRENT_USER = 'postgres', etc.).
-- 5. CREATES ADMIN RPC: public.admin_update_user_role(p_user_id UUID, p_new_role TEXT)
--    Revoked from PUBLIC/anon. Strictly checks public.is_admin().
-- 6. HARDENS redeem_teacher_invitation_code(TEXT):
--    Revoked from PUBLIC/anon. Atomically validates invitation code and applies authorized role flag.
-- 7. HARDENS promote_user_to_admin(TEXT):
--    Revoked from PUBLIC/anon. Requires admin caller or superuser session and applies authorized role flag.
-- ==============================================================================

-- 1. Table-level REVOKE
REVOKE UPDATE, INSERT ON public.profiles FROM authenticated, anon, PUBLIC;

-- 2. Column-level GRANT UPDATE for authenticated users
-- Only non-privilege profile fields can be updated by clients
GRANT UPDATE (first_name, last_name, display_name, avatar_url, updated_at)
  ON public.profiles TO authenticated;

-- 3. Column-level GRANT INSERT for authenticated users (client self-provisioning if needed)
-- Excludes 'role' so any client insert defaults strictly to 'student'
GRANT INSERT (id, first_name, last_name, display_name, email, avatar_url, created_at, updated_at)
  ON public.profiles TO authenticated;

-- Ensure service_role and postgres retain full privileges
GRANT ALL ON public.profiles TO postgres, service_role;

-- 4. Secure Defense-in-Depth Trigger (SECURITY INVOKER)
CREATE OR REPLACE FUNCTION public.enforce_profile_role_protection()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  -- If role column is unchanged, proceed normally without interference
  IF NEW.role IS NOT DISTINCT FROM OLD.role THEN
    RETURN NEW;
  END IF;

  -- Allow transactions explicitly marked as authorized by vetted server RPCs.
  -- This eliminates any bypass via:
  -- - Anonymous client requests without JWT session
  -- - Direct table updates from authenticated users (including admins)
  -- - Unintended side-effects from arbitrary SECURITY DEFINER functions
  IF current_setting('bilimyol.authorized_role_change', true) = 'true' THEN
    RETURN NEW;
  END IF;

  -- Otherwise, block unauthorized role alteration
  RAISE EXCEPTION 'Ruxsat etilmagan: Profil rolini to‘g‘ridan-to‘g‘ri o‘zgartirish taqiqlangan.'
    USING ERRCODE = '42501';
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_profile_role_protection ON public.profiles;
CREATE TRIGGER trg_enforce_profile_role_protection
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_profile_role_protection();

-- 5. Privileged RPC: Admin Update User Role
CREATE OR REPLACE FUNCTION public.admin_update_user_role(
  p_user_id UUID,
  p_new_role TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_clean_role TEXT := LOWER(TRIM(p_new_role));
BEGIN
  -- Caller must be authenticated and must be an administrator
  IF v_caller_id IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Ruxsat etilmagan: Faqat platforma administratori foydalanuvchi rolini o‘zgartira oladi.'
    );
  END IF;

  -- Validate allowed roles
  IF v_clean_role NOT IN ('student', 'parent', 'teacher', 'admin') THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Noto‘g‘ri rol kiritildi. Ruxsat etilgan rollar: student, parent, teacher, admin.'
    );
  END IF;

  -- Set transaction-local authorization flag
  PERFORM set_config('bilimyol.authorized_role_change', 'true', true);

  UPDATE public.profiles
  SET role = v_clean_role,
      updated_at = now()
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Foydalanuvchi topilmadi.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', p_user_id,
    'role', v_clean_role,
    'message', 'Foydalanuvchi roli muvaffaqiyatli yangilandi.'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_user_role(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_user_role(UUID, TEXT) TO authenticated, postgres, service_role;

-- 6. Harden redeem_teacher_invitation_code with transaction-local authorized role change flag
CREATE OR REPLACE FUNCTION public.redeem_teacher_invitation_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_clean_code TEXT := UPPER(TRIM(p_code));
  v_hash TEXT;
  v_inv RECORD;
  v_recent_fails INT := 0;
  v_new_used INT;
  v_new_status TEXT;
  v_caller_email TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
  END IF;

  IF v_clean_code = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'O‘qituvchi tasdiqlash kodini kiriting.');
  END IF;

  -- Rate Limiting: max 5 failed attempts in past 5 minutes
  SELECT COUNT(*) INTO v_recent_fails
  FROM public.teacher_invitation_attempts
  WHERE user_id = v_uid
    AND is_success = false
    AND attempted_at > (now() - INTERVAL '5 minutes');

  IF v_recent_fails >= 5 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Ko‘p marotaba noto‘g‘ri kod kiritildi. Iltimos, 5 daqiqadan so‘ng qayta urinib ko‘ring.'
    );
  END IF;

  v_hash := public.hash_teacher_code(v_clean_code);

  SELECT * INTO v_inv
  FROM public.teacher_invitation_codes
  WHERE code_hash = v_hash
  FOR UPDATE;

  IF v_inv.id IS NULL
     OR v_inv.status <> 'active'
     OR v_inv.expires_at <= now()
     OR v_inv.used_count >= v_inv.max_uses THEN

    INSERT INTO public.teacher_invitation_attempts (user_id, attempted_at, is_success)
    VALUES (v_uid, now(), false);

    RETURN jsonb_build_object(
      'success', false,
      'message', 'Kiritilgan tasdiqlash kodi yaroqsiz yoki muddati tugagan.'
    );
  END IF;

  INSERT INTO public.teacher_invitation_attempts (user_id, attempted_at, is_success)
  VALUES (v_uid, now(), true);

  -- Set transaction-local authorization flag for trigger compatibility
  PERFORM set_config('bilimyol.authorized_role_change', 'true', true);

  -- Ensure profile exists and atomically upgrade to 'teacher'
  SELECT email INTO v_caller_email FROM auth.users WHERE id = v_uid;

  INSERT INTO public.profiles (id, first_name, last_name, email, display_name, role, created_at, updated_at)
  VALUES (
    v_uid,
    COALESCE(SPLIT_PART(v_caller_email, '@', 1), 'O‘qituvchi'),
    '',
    COALESCE(v_caller_email, ''),
    COALESCE(SPLIT_PART(v_caller_email, '@', 1), 'O‘qituvchi'),
    'teacher',
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    role = 'teacher',
    updated_at = now();

  v_new_used := v_inv.used_count + 1;
  IF v_new_used >= v_inv.max_uses THEN
    v_new_status := 'exhausted';
  ELSE
    v_new_status := 'active';
  END IF;

  UPDATE public.teacher_invitation_codes
  SET used_count = v_new_used,
      status = v_new_status,
      updated_at = now()
  WHERE id = v_inv.id;

  RETURN jsonb_build_object(
    'success', true,
    'role', 'teacher',
    'school_name', v_inv.school_name,
    'message', 'O‘qituvchi hisobi muvaffaqiyatli faollashtirildi!'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.redeem_teacher_invitation_code(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_teacher_invitation_code(TEXT) TO authenticated, postgres, service_role;

-- 7. Harden promote_user_to_admin with authorized role flag & strict caller check
CREATE OR REPLACE FUNCTION public.promote_user_to_admin(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_target_id UUID;
  v_clean_email TEXT := LOWER(TRIM(p_email));
BEGIN
  -- If called via PostgREST / RPC by an authenticated user, caller MUST already be an admin
  IF v_caller_id IS NOT NULL THEN
    IF NOT public.is_admin() THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Ruxsat etilmagan. Faqat platforma administratori boshqa foydalanuvchini admin qila oladi.'
      );
    END IF;
  ELSE
    -- If called without an auth.uid() context (direct SQL console / bootstrap),
    -- verify that the database session user is postgres or service_role
    IF SESSION_USER NOT IN ('postgres', 'service_role') THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Ruxsat etilmagan seans.'
      );
    END IF;
  END IF;

  IF v_clean_email = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Email manzili kiritilishi shart.');
  END IF;

  SELECT id INTO v_target_id
  FROM auth.users
  WHERE LOWER(email) = v_clean_email;

  IF v_target_id IS NULL THEN
    SELECT id INTO v_target_id
    FROM public.profiles
    WHERE LOWER(email) = v_clean_email;
  END IF;

  IF v_target_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Ko‘rsatilgan email (' || v_clean_email || ') bilan foydalanuvchi topilmadi. Avval ro‘yxatdan o‘ting.'
    );
  END IF;

  -- Set transaction-local authorization flag for trigger compatibility
  PERFORM set_config('bilimyol.authorized_role_change', 'true', true);

  UPDATE public.profiles
  SET role = 'admin',
      updated_at = now()
  WHERE id = v_target_id;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_target_id,
    'email', v_clean_email,
    'role', 'admin',
    'message', 'Foydalanuvchi (' || v_clean_email || ') muvaffaqiyatli Admin roliga o‘tkazildi.'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.promote_user_to_admin(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.promote_user_to_admin(TEXT) TO postgres, service_role, authenticated;

-- 8. Comments & Documentation for DB Inspectors
COMMENT ON FUNCTION public.enforce_profile_role_protection() IS 
  'Enforces strict authorization on public.profiles.role. Blocks direct client modifications while preserving administrator and invitation RPCs.';
COMMENT ON FUNCTION public.admin_update_user_role(UUID, TEXT) IS 
  'Authorized administrative RPC for updating user roles. Strictly requires public.is_admin().';
COMMENT ON FUNCTION public.redeem_teacher_invitation_code(TEXT) IS 
  'Authorized teacher code redemption RPC. Atomically promotes student to teacher role.';
COMMENT ON FUNCTION public.promote_user_to_admin(TEXT) IS 
  'Privileged admin promotion RPC. Strictly requires admin privileges or superuser bootstrap session.';

