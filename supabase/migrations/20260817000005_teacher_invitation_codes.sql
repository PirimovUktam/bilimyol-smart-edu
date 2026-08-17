-- BilimYo‘l Smart Edu - Teacher Invitation Codes & Secure Role Activation Migration
-- Migration: 20260817000005_teacher_invitation_codes.sql

-- 1. CREATE TEACHER INVITATION CODES TABLE
CREATE TABLE IF NOT EXISTS public.teacher_invitation_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  school_name TEXT NOT NULL DEFAULT 'BilimYo‘l Smart School',
  max_uses INT NOT NULL DEFAULT 100,
  used_count INT NOT NULL DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '1 year'),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index on code for fast indexed lookup
CREATE INDEX IF NOT EXISTS idx_teacher_invitation_codes_code ON public.teacher_invitation_codes(code);

-- Enable RLS (Service/Admin and SECURITY DEFINER RPC only)
ALTER TABLE public.teacher_invitation_codes ENABLE ROW LEVEL SECURITY;

-- 2. SEED OFFICIAL TEACHER INVITATION CODES
INSERT INTO public.teacher_invitation_codes (code, school_name, max_uses, used_count, expires_at, is_active)
VALUES
  ('USTOZ-2026-ALPHA', 'BilimYo‘l Boshqaruv Markazi', 500, 0, now() + INTERVAL '2 years', true),
  ('BILIMYO-USTOZ-77', 'Toshkent IDUM №1', 200, 0, now() + INTERVAL '2 years', true),
  ('MAKTAB-MATH-2026', 'Prezident Ta’lim Muassasalari', 300, 0, now() + INTERVAL '2 years', true)
ON CONFLICT (code) DO NOTHING;

-- 3. HARDENED TRIGGER: PREVENT DIRECT SELF-ELEVATION TO TEACHER VIA SIGNUP
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_first_name TEXT;
  v_last_name TEXT;
  v_display_name TEXT;
  v_raw_role TEXT;
  v_assigned_role TEXT;
BEGIN
  v_first_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), ''), 'Foydalanuvchi');
  v_last_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), ''), '');
  v_raw_role := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'role'), ''), 'student');

  -- Security Rule: Direct signup only permits 'student' or 'parent'.
  -- Teacher role MUST be activated via redeem_teacher_invitation_code RPC.
  IF v_raw_role = 'parent' THEN
    v_assigned_role := 'parent';
  ELSE
    v_assigned_role := 'student';
  END IF;

  IF v_last_name <> '' THEN
    v_display_name := v_first_name || ' ' || v_last_name;
  ELSE
    v_display_name := v_first_name;
  END IF;

  INSERT INTO public.profiles (id, first_name, last_name, email, avatar_url, display_name, role, created_at, updated_at)
  VALUES (
    NEW.id,
    v_first_name,
    v_last_name,
    COALESCE(NEW.email, ''),
    NEW.raw_user_meta_data->>'avatar_url',
    v_display_name,
    v_assigned_role,
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    first_name = CASE WHEN public.profiles.first_name = 'Foydalanuvchi' AND EXCLUDED.first_name <> 'Foydalanuvchi' THEN EXCLUDED.first_name ELSE public.profiles.first_name END,
    last_name = CASE WHEN public.profiles.last_name = '' AND EXCLUDED.last_name <> '' THEN EXCLUDED.last_name ELSE public.profiles.last_name END,
    display_name = CASE WHEN public.profiles.display_name = 'Foydalanuvchi' AND EXCLUDED.display_name <> 'Foydalanuvchi' THEN EXCLUDED.display_name ELSE public.profiles.display_name END,
    email = EXCLUDED.email,
    updated_at = now();

  IF v_assigned_role = 'student' THEN
    INSERT INTO public.learner_profiles (user_id, selected_course_id, goal, daily_minutes, initial_level, created_at, updated_at)
    VALUES (NEW.id, 'course_math_01', 'mastery', 15, 'intermediate', now(), now())
    ON CONFLICT (user_id) DO NOTHING;

    INSERT INTO public.gamification_profiles (user_id, xp, streak_days, last_activity_date, created_at, updated_at)
    VALUES (NEW.id, 0, 1, CURRENT_DATE, now(), now())
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  INSERT INTO public.user_preferences (user_id, dark_mode, notifications_enabled, language, updated_at)
  VALUES (NEW.id, false, true, 'uz', now())
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. SECURE TEACHER INVITATION CODE REDEMPTION RPC
CREATE OR REPLACE FUNCTION public.redeem_teacher_invitation_code(p_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_clean_code TEXT := UPPER(TRIM(p_code));
  v_inv RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
  END IF;

  IF v_clean_code = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'O‘qituvchi tasdiqlash kodini kiriting.');
  END IF;

  -- Verify code existence, activity, expiration, and usage quota
  SELECT * INTO v_inv
  FROM public.teacher_invitation_codes
  WHERE UPPER(TRIM(code)) = v_clean_code
    AND is_active = true
    AND expires_at > now()
    AND used_count < max_uses
  LIMIT 1;

  IF v_inv.id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Kiritilgan tasdiqlash kodi yaroqsiz, muddati tugagan yoki limitiga yetgan.'
    );
  END IF;

  -- Upgrade authenticated user role to teacher in public.profiles
  UPDATE public.profiles
  SET role = 'teacher',
      updated_at = now()
  WHERE id = v_uid;

  -- Increment usage counter
  UPDATE public.teacher_invitation_codes
  SET used_count = used_count + 1,
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

GRANT EXECUTE ON FUNCTION public.redeem_teacher_invitation_code(TEXT) TO authenticated;
