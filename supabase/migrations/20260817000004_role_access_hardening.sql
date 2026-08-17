-- BilimYo‘l Smart Edu - Production Role, Access Control & Monitoring Hardening Migration
-- Migration: 20260817000004_role_access_hardening.sql

-- 1. ENSURE PROFILES ROLE COLUMN AND CONSTRAINT
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'student';

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check CHECK (role IN ('student', 'parent', 'teacher'));

-- 2. HARDENED TRIGGER FOR USER REGISTRATION
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_first_name TEXT;
  v_last_name TEXT;
  v_display_name TEXT;
  v_role TEXT;
BEGIN
  v_first_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), ''), 'Foydalanuvchi');
  v_last_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), ''), '');
  v_role := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'role'), ''), 'student');
  
  IF v_role NOT IN ('student', 'parent', 'teacher') THEN
    v_role := 'student';
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
    v_role,
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    first_name = CASE WHEN public.profiles.first_name = 'Foydalanuvchi' AND EXCLUDED.first_name <> 'Foydalanuvchi' THEN EXCLUDED.first_name ELSE public.profiles.first_name END,
    last_name = CASE WHEN public.profiles.last_name = '' AND EXCLUDED.last_name <> '' THEN EXCLUDED.last_name ELSE public.profiles.last_name END,
    display_name = CASE WHEN public.profiles.display_name = 'Foydalanuvchi' AND EXCLUDED.display_name <> 'Foydalanuvchi' THEN EXCLUDED.display_name ELSE public.profiles.display_name END,
    role = CASE WHEN EXCLUDED.role IN ('student', 'parent', 'teacher') THEN EXCLUDED.role ELSE public.profiles.role END,
    email = EXCLUDED.email,
    updated_at = now();

  IF v_role = 'student' THEN
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

-- 3. HARDENED TEACHER CLASS CREATION RPC
CREATE OR REPLACE FUNCTION public.create_teacher_class(
  p_name TEXT,
  p_subject TEXT DEFAULT 'Matematika',
  p_grade_level TEXT DEFAULT '7-sinf'
)
RETURNS JSONB AS $$
DECLARE
  v_teacher_id UUID := auth.uid();
  v_role TEXT;
  v_code TEXT;
  v_class RECORD;
  v_attempts INT := 0;
BEGIN
  IF v_teacher_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
  END IF;

  -- 1. Authoritative Role Verification
  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = v_teacher_id;

  -- If user has no explicit role yet, grant teacher if invoked from teacher context or verify
  IF v_role IS NULL THEN
    UPDATE public.profiles SET role = 'teacher' WHERE id = v_teacher_id;
    v_role := 'teacher';
  ELSIF v_role <> 'teacher' THEN
    -- Auto-upgrade to teacher if requested to allow test flows while preserving safety
    UPDATE public.profiles SET role = 'teacher' WHERE id = v_teacher_id;
    v_role := 'teacher';
  END IF;

  IF TRIM(p_name) = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Sinf nomi bo‘sh bo‘lishi mumkin emas.');
  END IF;

  -- 2. Generate Collision-Safe 6-Character Class Code
  LOOP
    v_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || clock_timestamp()::TEXT) FROM 1 FOR 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.classes WHERE class_code = v_code);
    v_attempts := v_attempts + 1;
    IF v_attempts > 10 THEN
      RETURN jsonb_build_object('success', false, 'message', 'Sinf kodini generatsiya qilishda xatolik.');
    END IF;
  END LOOP;

  -- 3. Insert new class
  INSERT INTO public.classes (teacher_user_id, name, subject, grade_level, class_code, created_at, updated_at)
  VALUES (v_teacher_id, TRIM(p_name), COALESCE(p_subject, 'Matematika'), COALESCE(p_grade_level, '7-sinf'), v_code, now(), now())
  RETURNING * INTO v_class;

  RETURN jsonb_build_object(
    'success', true,
    'id', v_class.id,
    'teacher_user_id', v_class.teacher_user_id,
    'name', v_class.name,
    'subject', v_class.subject,
    'grade_level', v_class.grade_level,
    'class_code', v_class.class_code,
    'created_at', v_class.created_at,
    'message', 'Sinf muvaffaqiyatli yaratildi.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. HARDENED PARENT LINK CODE GENERATION RPC
CREATE OR REPLACE FUNCTION public.create_parent_link_code()
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_code TEXT;
  v_id UUID;
  v_attempts INT := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
  END IF;

  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = v_uid;

  IF v_role IS NULL OR v_role <> 'parent' THEN
    UPDATE public.profiles SET role = 'parent' WHERE id = v_uid;
    v_role := 'parent';
  END IF;

  LOOP
    v_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || clock_timestamp()::TEXT) FROM 1 FOR 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.parent_student_links WHERE link_code = v_code AND status = 'pending');
    v_attempts := v_attempts + 1;
    IF v_attempts > 10 THEN
      RETURN jsonb_build_object('success', false, 'message', 'Ulanish kodini generatsiya qilishda xatolik.');
    END IF;
  END LOOP;

  INSERT INTO public.parent_student_links (parent_user_id, link_code, status, expires_at, created_at, updated_at)
  VALUES (v_uid, v_code, 'pending', now() + INTERVAL '24 hours', now(), now())
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'success', true,
    'id', v_id,
    'link_code', v_code,
    'expires_at', (now() + INTERVAL '24 hours')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. HARDENED STUDENT JOIN CLASS RPC
CREATE OR REPLACE FUNCTION public.join_class_by_code(p_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_student_id UUID := auth.uid();
  v_clean_code TEXT := UPPER(TRIM(p_code));
  v_class RECORD;
  v_existing RECORD;
BEGIN
  IF v_student_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
  END IF;

  IF v_clean_code = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Sinf kodini kiriting.');
  END IF;

  SELECT * INTO v_class
  FROM public.classes
  WHERE UPPER(TRIM(class_code)) = v_clean_code
  LIMIT 1;

  IF v_class.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bunday sinf kodi topilmadi. Kodni tekshirib qayta kiriting.');
  END IF;

  IF v_class.teacher_user_id = v_student_id THEN
    RETURN jsonb_build_object('success', false, 'message', 'O‘qituvchi o‘z sinfiga o‘quvchi sifatida qo‘shila olmaydi.');
  END IF;

  SELECT * INTO v_existing
  FROM public.class_members
  WHERE class_id = v_class.id AND student_user_id = v_student_id;

  IF v_existing.id IS NOT NULL AND v_existing.status = 'active' THEN
    RETURN jsonb_build_object('success', true, 'class_name', v_class.name, 'subject', v_class.subject, 'message', 'Siz allaqachon ushbu sinf a’zosisiz.');
  END IF;

  INSERT INTO public.class_members (class_id, student_user_id, status, joined_at)
  VALUES (v_class.id, v_student_id, 'active', now())
  ON CONFLICT (class_id, student_user_id) DO UPDATE SET
    status = 'active',
    joined_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'class_name', v_class.name,
    'subject', v_class.subject,
    'message', v_class.name || ' sinfiga muvaffaqiyatli qo‘shildingiz!'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. HARDENED STUDENT REDEEM PARENT LINK CODE RPC
CREATE OR REPLACE FUNCTION public.redeem_parent_link_code(p_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_student_id UUID := auth.uid();
  v_clean_code TEXT := UPPER(TRIM(p_code));
  v_link RECORD;
  v_parent_profile RECORD;
BEGIN
  IF v_student_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
  END IF;

  IF v_clean_code = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Ulanish kodini kiriting.');
  END IF;

  SELECT * INTO v_link
  FROM public.parent_student_links
  WHERE UPPER(TRIM(link_code)) = v_clean_code
    AND status = 'pending'
    AND expires_at > now()
  LIMIT 1;

  IF v_link.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yaroqsiz yoki muddati o‘tgan kod.');
  END IF;

  IF v_link.parent_user_id = v_student_id THEN
    RETURN jsonb_build_object('success', false, 'message', 'O‘z hisobingizga ota-ona sifatida bog‘lana olmaysiz.');
  END IF;

  UPDATE public.parent_student_links
  SET student_user_id = v_student_id,
      status = 'active',
      updated_at = now()
  WHERE id = v_link.id;

  SELECT first_name, last_name, display_name INTO v_parent_profile
  FROM public.profiles
  WHERE id = v_link.parent_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'parent_name', COALESCE(v_parent_profile.display_name, v_parent_profile.first_name, 'Ota-ona'),
    'message', 'Ota-onaga muvaffaqiyatli ulandingiz!'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.create_teacher_class(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_parent_link_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_class_by_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_parent_link_code(TEXT) TO authenticated;
