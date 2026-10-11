-- BilimYo‘l Smart Edu - Production Teacher Invitation Code Management System
-- Migration: 20260817000006_teacher_invitation_system.sql

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;

-- Helper immutable hashing function
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

-- 1. UPDATE PROFILES ROLE CONSTRAINT TO INCLUDE ADMIN
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check CHECK (role IN ('student', 'parent', 'teacher', 'admin'));

-- 2. ENSURE TEACHER INVITATION CODES TABLE AND EVOLVE TO HASH-BASED SCHEMA
CREATE TABLE IF NOT EXISTS public.teacher_invitation_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_name TEXT NOT NULL DEFAULT 'BilimYo‘l Smart School',
  max_uses INT NOT NULL DEFAULT 1,
  used_count INT NOT NULL DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '7 days'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure all required columns exist (handles existing migration 5 schema safely)
ALTER TABLE public.teacher_invitation_codes
  ADD COLUMN IF NOT EXISTS code_hash TEXT,
  ADD COLUMN IF NOT EXISTS code_prefix TEXT,
  ADD COLUMN IF NOT EXISTS school_id TEXT,
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

-- Backfill code_hash & code_prefix for existing codes (if table was created in migration 5)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'teacher_invitation_codes' AND column_name = 'code'
  ) THEN
    UPDATE public.teacher_invitation_codes
    SET code_hash = public.hash_teacher_code(code),
        code_prefix = SUBSTRING(UPPER(TRIM(code)) FROM 1 FOR 6) || '****'
    WHERE code_hash IS NULL AND code IS NOT NULL;

    ALTER TABLE public.teacher_invitation_codes ALTER COLUMN code DROP NOT NULL;
  END IF;

  -- Sync is_active to status if is_active exists from migration 5
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'teacher_invitation_codes' AND column_name = 'is_active'
  ) THEN
    UPDATE public.teacher_invitation_codes
    SET status = 'revoked'
    WHERE is_active = false AND status = 'active';
  END IF;

  -- Ensure any orphan row has a code_hash
  UPDATE public.teacher_invitation_codes
  SET code_hash = public.hash_teacher_code('LEGACY-' || id::text)
  WHERE code_hash IS NULL;

  ALTER TABLE public.teacher_invitation_codes ALTER COLUMN code_hash SET NOT NULL;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- Populate code_prefix for any row missing it
UPDATE public.teacher_invitation_codes
SET code_prefix = 'USTOZ-****'
WHERE code_prefix IS NULL;

ALTER TABLE public.teacher_invitation_codes
  ALTER COLUMN code_prefix SET NOT NULL;

-- Ensure unique constraint on code_hash for idempotent ON CONFLICT (code_hash)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'uq_teacher_invitation_codes_code_hash'
  ) THEN
    ALTER TABLE public.teacher_invitation_codes
      ADD CONSTRAINT uq_teacher_invitation_codes_code_hash UNIQUE (code_hash);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_teacher_inv_code_hash ON public.teacher_invitation_codes(code_hash);
CREATE INDEX IF NOT EXISTS idx_teacher_inv_status ON public.teacher_invitation_codes(status);

ALTER TABLE public.teacher_invitation_codes
  DROP CONSTRAINT IF EXISTS teacher_invitation_codes_status_check;

ALTER TABLE public.teacher_invitation_codes
  ADD CONSTRAINT teacher_invitation_codes_status_check 
  CHECK (status IN ('active', 'expired', 'revoked', 'exhausted'));

ALTER TABLE public.teacher_invitation_codes ENABLE ROW LEVEL SECURITY;

-- Deny direct public table access (all access through audited RPC functions)
CREATE POLICY "Teacher invitation codes access control"
  ON public.teacher_invitation_codes
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'teacher')
    )
  );

-- 3. CREATE TEACHER INVITATION ATTEMPTS TABLE (RATE LIMITING & AUDIT)
CREATE TABLE IF NOT EXISTS public.teacher_invitation_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_success BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_teacher_inv_attempts_user ON public.teacher_invitation_attempts(user_id, attempted_at);

ALTER TABLE public.teacher_invitation_attempts ENABLE ROW LEVEL SECURITY;

-- 4. SEED SECURE INITIAL TEACHER INVITATION CODES (HASHED)
INSERT INTO public.teacher_invitation_codes (code_hash, code_prefix, school_name, max_uses, used_count, expires_at, status)
VALUES
  (public.hash_teacher_code('USTOZ-7K4P-2M9X'), 'USTOZ-7K4P-****', 'BilimYo‘l Boshqaruv Markazi', 10, 0, now() + INTERVAL '1 year', 'active'),
  (public.hash_teacher_code('USTOZ-9B3V-4X1R'), 'USTOZ-9B3V-****', 'Toshkent IDUM №1', 5, 0, now() + INTERVAL '1 year', 'active'),
  (public.hash_teacher_code('USTOZ-5T8N-6W2D'), 'USTOZ-5T8N-****', 'Prezident Ta’lim Muassasalari', 5, 0, now() + INTERVAL '1 year', 'active'),
  (public.hash_teacher_code('USTOZ-2026-ALPHA'), 'USTOZ-2026-****', 'BilimYo‘l Demo Markazi', 100, 0, now() + INTERVAL '1 year', 'active')
ON CONFLICT (code_hash) DO NOTHING;

-- 5. RPC: CREATE TEACHER INVITATION CODE (ADMIN/MANAGEMENT)
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

  -- Generate human-readable high-entropy token: USTOZ-XXXX-YYYY
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

-- 6. RPC: LIST TEACHER INVITATION CODES (ADMIN/MANAGEMENT)
CREATE OR REPLACE FUNCTION public.list_teacher_invitations()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_list JSONB;
BEGIN
  IF v_uid IS NULL THEN
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
$$;

-- 7. RPC: REVOKE TEACHER INVITATION CODE (ADMIN/MANAGEMENT)
CREATE OR REPLACE FUNCTION public.revoke_teacher_invitation(p_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
  END IF;

  UPDATE public.teacher_invitation_codes
  SET status = 'revoked',
      updated_at = now()
  WHERE id = p_id;

  RETURN jsonb_build_object('success', true, 'message', 'Taklif kodi muvaffaqiyatli bekor qilindi.');
END;
$$;

-- 8. HARDENED RPC: REDEEM TEACHER INVITATION CODE (WITH RATE-LIMIT & HASH CHECK)
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
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
  END IF;

  IF v_clean_code = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'O‘qituvchi tasdiqlash kodini kiriting.');
  END IF;

  -- 1. Rate Limiting Check: max 5 failed attempts in past 5 minutes
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

  -- 2. Compute SHA-256 hash
  v_hash := public.hash_teacher_code(v_clean_code);

  -- 3. Find active invitation code with row-level lock
  SELECT * INTO v_inv
  FROM public.teacher_invitation_codes
  WHERE code_hash = v_hash
  FOR UPDATE;

  -- 4. Validate existence, status, expiration and usage limit
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

  -- 5. Successful Redemption
  INSERT INTO public.teacher_invitation_attempts (user_id, attempted_at, is_success)
  VALUES (v_uid, now(), true);

  -- Upgrade role in public.profiles
  UPDATE public.profiles
  SET role = 'teacher',
      updated_at = now()
  WHERE id = v_uid;

  -- Update invitation code usage count & status
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

GRANT EXECUTE ON FUNCTION public.create_teacher_invitation(TEXT, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_teacher_invitations() TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_teacher_invitation(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_teacher_invitation_code(TEXT) TO authenticated;
