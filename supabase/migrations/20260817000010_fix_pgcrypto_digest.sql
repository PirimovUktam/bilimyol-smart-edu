-- ==============================================================================
-- BILIMYO‘L SMART EDU - MIGRATION 20260817000010
-- File: supabase/migrations/20260817000010_fix_pgcrypto_digest.sql
--
-- FIX: "function digest(text, unknown) does not exist"
-- 1. Ensures pgcrypto extension is active in extensions schema.
-- 2. Creates schema-qualified public.hash_teacher_code(p_code TEXT) helper function.
-- 3. Sets search_path = public, extensions, pg_temp on all hashing functions.
-- 4. Updates create_teacher_invitation and redeem_teacher_invitation_code RPCs.
-- ==============================================================================

-- 1. Ensure pgcrypto is installed in extensions schema
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;

-- 2. Schema-qualified, immutable hashing helper
CREATE OR REPLACE FUNCTION public.hash_teacher_code(p_code TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
  SELECT encode(extensions.digest(convert_to(UPPER(TRIM(p_code)), 'UTF8'), 'sha256'), 'hex');
$$;

REVOKE ALL ON FUNCTION public.hash_teacher_code(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hash_teacher_code(TEXT) TO authenticated, postgres, service_role;

-- 3. Updated create_teacher_invitation RPC
CREATE OR REPLACE FUNCTION public.create_teacher_invitation(
  p_school_name TEXT DEFAULT 'BilimYo‘l Smart School',
  p_max_uses INT DEFAULT 1,
  p_validity_days INT DEFAULT 7
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_part1 TEXT;
  v_part2 TEXT;
  v_plain_code TEXT;
  v_hash TEXT;
  v_prefix TEXT;
  v_expires_at TIMESTAMPTZ;
  v_max_uses INT := GREATEST(1, LEAST(100, COALESCE(p_max_uses, 1)));
  v_days INT := GREATEST(1, LEAST(365, COALESCE(p_validity_days, 7)));
  v_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
  END IF;

  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'message', 'Faqat administratorlar taklif kodi yarata oladi.');
  END IF;

  v_part1 := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || clock_timestamp()::TEXT) FROM 1 FOR 4));
  v_part2 := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || clock_timestamp()::TEXT) FROM 5 FOR 4));
  v_plain_code := 'USTOZ-' || v_part1 || '-' || v_part2;
  v_prefix := 'USTOZ-' || v_part1 || '-****';
  v_hash := public.hash_teacher_code(v_plain_code);
  v_expires_at := now() + (v_days || ' days')::INTERVAL;

  INSERT INTO public.teacher_invitation_codes (
    code_hash,
    code_prefix,
    school_name,
    created_by,
    max_uses,
    used_count,
    expires_at,
    status,
    created_at,
    updated_at
  )
  VALUES (
    v_hash,
    v_prefix,
    COALESCE(NULLIF(TRIM(p_school_name), ''), 'BilimYo‘l Smart School'),
    v_uid,
    v_max_uses,
    0,
    v_expires_at,
    'active',
    now(),
    now()
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'success', true,
    'id', v_id,
    'plain_code', v_plain_code,
    'code_prefix', v_prefix,
    'school_name', COALESCE(NULLIF(TRIM(p_school_name), ''), 'BilimYo‘l Smart School'),
    'max_uses', v_max_uses,
    'expires_at', v_expires_at,
    'message', 'O‘qituvchi taklif kodi muvaffaqiyatli yaratildi. Ushbu kodni hozir nusxalab oling!'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_teacher_invitation(TEXT, INT, INT) TO authenticated, postgres, service_role;

-- 4. Updated redeem_teacher_invitation_code RPC
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
    'message', 'O‘qituvchi hisobi muvaffaqiyatli tasdiqlandi va faollashtirildi!'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_teacher_invitation_code(TEXT) TO authenticated, postgres, service_role;
