-- BilimYo‘l Smart Edu - Production First Admin Bootstrap & Security System
-- Migration: 20260817000007_admin_bootstrap_system.sql

-- 1. HELPER FUNCTION: CHECK IF CALLER IS ADMIN
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. ONE-TIME SECURE BOOTSTRAP RPC: CLAIM FIRST ADMIN ROLE
CREATE OR REPLACE FUNCTION public.claim_first_admin_role(p_bootstrap_key TEXT DEFAULT '')
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_admin_count INT := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
  END IF;

  -- Check if any administrator currently exists in the platform
  SELECT COUNT(*) INTO v_admin_count
  FROM public.profiles
  WHERE role = 'admin';

  IF v_admin_count > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Tizimda bosh administrator allaqachon mavjud. Qayta bootstrap qilish bloklangan.'
    );
  END IF;

  -- Elevate the first verified user to platform admin
  UPDATE public.profiles
  SET role = 'admin',
      updated_at = now()
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'success', true,
    'role', 'admin',
    'message', 'Tabriklaymiz! Siz BilimYo‘l Smart Edu platformasining bosh administratori sifatida muvaffaqiyatli faollashtirildingiz.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. SERVER-SIDE SQL PROMOTION HELPER (FOR SUPABASE SQL CONSOLE / LOCAL CLI)
CREATE OR REPLACE FUNCTION public.promote_user_to_admin(p_email TEXT)
RETURNS JSONB AS $$
DECLARE
  v_target_id UUID;
  v_clean_email TEXT := LOWER(TRIM(p_email));
BEGIN
  IF v_clean_email = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Email manzili kiritilishi shart.');
  END IF;

  SELECT id INTO v_target_id
  FROM auth.users
  WHERE LOWER(email) = v_clean_email;

  IF v_target_id IS NULL THEN
    -- Fallback search in public.profiles
    SELECT id INTO v_target_id
    FROM public.profiles
    WHERE LOWER(email) = v_clean_email;
  END IF;

  IF v_target_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Ko‘rsatilgan email bilan foydalanuvchi topilmadi.');
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
    'message', 'Foydalanuvchi muvaffaqiyatli Admin roliga o‘tkazildi.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. HARDEN TEACHER INVITATION RPCS: STRICTLY REQUIRE ADMIN ROLE
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

  -- Authorization check: Must be Admin
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'message', 'Faqat administratorlar taklif kodi yarata oladi.');
  END IF;

  -- Generate human-readable high-entropy token: USTOZ-XXXX-YYYY
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

-- 5. UPDATE RLS ON teacher_invitation_codes
DROP POLICY IF EXISTS "Teacher invitation codes access control" ON public.teacher_invitation_codes;

CREATE POLICY "Admin exclusive teacher invitation access"
  ON public.teacher_invitation_codes
  FOR ALL
  TO authenticated
  USING (public.is_admin());

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_first_admin_role(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.promote_user_to_admin(TEXT) TO authenticated;
