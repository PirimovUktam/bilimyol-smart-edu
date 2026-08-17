-- ==============================================================================
-- BILIMYO‘L SMART EDU - PRODUCTION FIRST ADMIN & TEACHER SECURITY SYSTEM
-- Migration: 20260817000007_admin_bootstrap_system.sql
-- SECURE, SELF-CONTAINED, IDEMPOTENT, ZERO HARDCODED TOKENS
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. ENSURE ROLE & DISPLAY NAME COLUMNS EXIST ON PROFILES
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS display_name TEXT;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'student';

UPDATE public.profiles
SET role = 'student'
WHERE role IS NULL OR role NOT IN ('student', 'parent', 'teacher', 'admin');

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check CHECK (role IN ('student', 'parent', 'teacher', 'admin'));

CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- 2. CREATE TEACHER INVITATION CODES TABLE IF NOT EXISTS
CREATE TABLE IF NOT EXISTS public.teacher_invitation_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code_hash TEXT UNIQUE NOT NULL,
  code_prefix TEXT NOT NULL,
  school_name TEXT NOT NULL DEFAULT 'BilimYo‘l Smart School',
  school_id TEXT,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  max_uses INT NOT NULL DEFAULT 1,
  used_count INT NOT NULL DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '7 days'),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'revoked', 'exhausted')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_teacher_inv_code_hash ON public.teacher_invitation_codes(code_hash);
CREATE INDEX IF NOT EXISTS idx_teacher_inv_status ON public.teacher_invitation_codes(status);

ALTER TABLE public.teacher_invitation_codes ENABLE ROW LEVEL SECURITY;

-- 3. CREATE TEACHER INVITATION ATTEMPTS TABLE (RATE LIMITING)
CREATE TABLE IF NOT EXISTS public.teacher_invitation_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_success BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_teacher_inv_attempts_user ON public.teacher_invitation_attempts(user_id, attempted_at);

ALTER TABLE public.teacher_invitation_attempts ENABLE ROW LEVEL SECURITY;

-- 4. HELPER FUNCTION: CHECK IF CURRENT AUTHENTICATED CALLER IS ADMIN
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. PRIVILEGED SERVER-SIDE FUNCTION: PROMOTE USER TO ADMIN
CREATE OR REPLACE FUNCTION public.promote_user_to_admin(p_email TEXT)
RETURNS JSONB AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_target_id UUID;
  v_clean_email TEXT := LOWER(TRIM(p_email));
BEGIN
  -- If called from client RPC, caller MUST already be an admin
  IF v_caller_id IS NOT NULL AND NOT public.is_admin() THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Ruxsat etilmagan. Faqat platforma administratori boshqa foydalanuvchini admin qila oladi.'
    );
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. HARDEN TEACHER INVITATION RPCS: STRICTLY REQUIRE ADMIN ROLE
CREATE OR REPLACE FUNCTION public.create_teacher_invitation(
  p_school_name TEXT DEFAULT 'BilimYo‘l Smart School',
  p_max_uses INT DEFAULT 1,
  p_validity_days INT DEFAULT 7
)
RETURNS JSONB AS $$
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
  v_hash := encode(digest(v_plain_code, 'sha256'), 'hex');
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.list_teacher_invitations()
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_list JSONB;
BEGIN
  IF v_uid IS NULL OR NOT public.is_admin() THEN
    RETURN '[]'::JSONB;
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', id,
        'code_prefix', code_prefix,
        'school_name', school_name,
        'max_uses', max_uses,
        'used_count', used_count,
        'expires_at', expires_at,
        'status', CASE
          WHEN status = 'active' AND expires_at <= now() THEN 'expired'
          WHEN status = 'active' AND used_count >= max_uses THEN 'exhausted'
          ELSE status
        END,
        'created_at', created_at
      ) ORDER BY created_at DESC
    ),
    '[]'::JSONB
  ) INTO v_list
  FROM public.teacher_invitation_codes;

  RETURN v_list;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.revoke_teacher_invitation(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
  END IF;

  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'message', 'Faqat administratorlar kodni bekor qila oladi.');
  END IF;

  UPDATE public.teacher_invitation_codes
  SET status = 'revoked',
      updated_at = now()
  WHERE id = p_id;

  RETURN jsonb_build_object('success', true, 'message', 'Taklif kodi muvaffaqiyatli bekor qilindi.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. HARDENED RPC: REDEEM TEACHER INVITATION CODE
CREATE OR REPLACE FUNCTION public.redeem_teacher_invitation_code(p_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_clean_code TEXT := UPPER(TRIM(p_code));
  v_hash TEXT;
  v_inv RECORD;
  v_recent_fails INT := 0;
  v_new_used INT;
  v_new_status TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
  END IF;

  IF v_clean_code = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'O‘qituvchi tasdiqlash kodini kiriting.');
  END IF;

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

  v_hash := encode(digest(v_clean_code, 'sha256'), 'hex');

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

  UPDATE public.profiles
  SET role = 'teacher',
      updated_at = now()
  WHERE id = v_uid;

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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. UPDATE RLS ON teacher_invitation_codes
DROP POLICY IF EXISTS "Teacher invitation codes access control" ON public.teacher_invitation_codes;
DROP POLICY IF EXISTS "Admin exclusive teacher invitation access" ON public.teacher_invitation_codes;

CREATE POLICY "Admin exclusive teacher invitation access"
  ON public.teacher_invitation_codes
  FOR ALL
  TO authenticated
  USING (public.is_admin());

-- 9. PERMISSIONS & SECURITY LOCKDOWN
REVOKE ALL ON FUNCTION public.promote_user_to_admin(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.promote_user_to_admin(TEXT) TO postgres, service_role, authenticated;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_teacher_invitation(TEXT, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_teacher_invitations() TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_teacher_invitation(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_teacher_invitation_code(TEXT) TO authenticated;
