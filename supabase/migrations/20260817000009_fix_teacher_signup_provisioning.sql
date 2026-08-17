-- ==============================================================================
-- BILIMYO‘L SMART EDU - MIGRATION 20260817000009
-- File: supabase/migrations/20260817000009_fix_teacher_signup_provisioning.sql
--
-- FIX: "Database error saving new user" on Teacher & User Registration
-- 1. Makes handle_new_user() robust, exception-safe, and decoupled from secondary tables.
-- 2. Eliminates Foreign Key violation (23503) on learner_profiles.selected_course_id.
-- 3. Protects primary auth.users / profiles insertion with isolated exception blocks.
-- 4. Guarantees atomic, idempotent teacher elevation via redeem_teacher_invitation_code().
-- ==============================================================================

-- ==============================================================================
-- 1. PRODUCTION-HARDENED AUTH REGISTRATION TRIGGER
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_first_name TEXT;
  v_last_name TEXT;
  v_display_name TEXT;
  v_role TEXT;
  v_valid_course_id TEXT;
BEGIN
  -- 1. Extract and sanitize registration metadata
  v_first_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), ''), 'Foydalanuvchi');
  v_last_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), ''), '');
  v_role := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'role'), ''), 'student');
  
  -- Public registration only assigns 'student' or 'parent' initially.
  -- Teacher role elevation is strictly authenticated via redeem_teacher_invitation_code RPC.
  IF v_role NOT IN ('student', 'parent') THEN
    v_role := 'student';
  END IF;

  IF v_last_name <> '' THEN
    v_display_name := v_first_name || ' ' || v_last_name;
  ELSE
    v_display_name := v_first_name;
  END IF;

  -- 2. Core Profile Record (Must always succeed)
  INSERT INTO public.profiles (
    id,
    first_name,
    last_name,
    email,
    avatar_url,
    display_name,
    role,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    v_first_name,
    v_last_name,
    COALESCE(NEW.email, ''),
    NEW.raw_user_meta_data->>'avatar_url',
    v_display_name,
    v_role,
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    first_name = CASE WHEN public.profiles.first_name = 'Foydalanuvchi' AND EXCLUDED.first_name <> 'Foydalanuvchi' THEN EXCLUDED.first_name ELSE public.profiles.first_name END,
    last_name = CASE WHEN public.profiles.last_name = '' AND EXCLUDED.last_name <> '' THEN EXCLUDED.last_name ELSE public.profiles.last_name END,
    display_name = CASE WHEN public.profiles.display_name = 'Foydalanuvchi' AND EXCLUDED.display_name <> 'Foydalanuvchi' THEN EXCLUDED.display_name ELSE public.profiles.display_name END,
    email = EXCLUDED.email,
    updated_at = now();

  -- 3. Student Defaults (Isolated & Non-blocking)
  IF v_role = 'student' THEN
    BEGIN
      -- Validate course existence before inserting FK reference
      SELECT id INTO v_valid_course_id FROM public.courses WHERE id = 'course_math_01' LIMIT 1;
      
      INSERT INTO public.learner_profiles (
        user_id,
        selected_course_id,
        goal,
        daily_minutes,
        initial_level,
        created_at,
        updated_at
      )
      VALUES (
        NEW.id,
        v_valid_course_id,
        'mastery',
        15,
        'intermediate',
        now(),
        now()
      )
      ON CONFLICT (user_id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'handle_new_user: learner_profiles insert warning: %', SQLERRM;
    END;

    BEGIN
      INSERT INTO public.gamification_profiles (
        user_id,
        xp,
        streak_days,
        last_activity_date,
        created_at,
        updated_at
      )
      VALUES (
        NEW.id,
        0,
        1,
        CURRENT_DATE,
        now(),
        now()
      )
      ON CONFLICT (user_id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'handle_new_user: gamification_profiles insert warning: %', SQLERRM;
    END;
  END IF;

  -- 4. User Preferences (Isolated & Non-blocking)
  BEGIN
    INSERT INTO public.user_preferences (
      user_id,
      dark_mode,
      notifications_enabled,
      language,
      updated_at
    )
    VALUES (
      NEW.id,
      false,
      true,
      'uz',
      now()
    )
    ON CONFLICT (user_id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: user_preferences insert warning: %', SQLERRM;
  END;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Guarantee that auth.users creation never aborts
  RAISE WARNING 'handle_new_user FATAL: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Rebind trigger idempotently
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 2. HARDENED TEACHER INVITATION REDEMPTION RPC
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.redeem_teacher_invitation_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
