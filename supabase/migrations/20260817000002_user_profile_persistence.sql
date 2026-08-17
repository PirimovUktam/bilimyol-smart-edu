-- BilimYo‘l Smart Edu - Production User Profile Persistence & RLS Migration
-- Migration: 20260817000002_user_profile_persistence.sql

-- 1. Ensure display_name column exists on public.profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS display_name TEXT;

-- 2. Update RLS policies on public.profiles
DROP POLICY IF EXISTS "User can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "User can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "User can insert own profile" ON public.profiles;

CREATE POLICY "User can read own profile"
  ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "User can insert own profile"
  ON public.profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "User can update own profile"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 3. Production trigger for new auth user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_first_name TEXT;
  v_last_name TEXT;
  v_display_name TEXT;
BEGIN
  v_first_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), ''), 'Foydalanuvchi');
  v_last_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), ''), '');
  
  IF v_last_name <> '' THEN
    v_display_name := v_first_name || ' ' || v_last_name;
  ELSE
    v_display_name := v_first_name;
  END IF;

  INSERT INTO public.profiles (id, first_name, last_name, email, avatar_url, display_name, created_at, updated_at)
  VALUES (
    NEW.id,
    v_first_name,
    v_last_name,
    COALESCE(NEW.email, ''),
    NEW.raw_user_meta_data->>'avatar_url',
    v_display_name,
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    first_name = CASE WHEN public.profiles.first_name = 'Foydalanuvchi' AND EXCLUDED.first_name <> 'Foydalanuvchi' THEN EXCLUDED.first_name ELSE public.profiles.first_name END,
    last_name = CASE WHEN public.profiles.last_name = '' AND EXCLUDED.last_name <> '' THEN EXCLUDED.last_name ELSE public.profiles.last_name END,
    display_name = CASE WHEN public.profiles.display_name = 'Foydalanuvchi' AND EXCLUDED.display_name <> 'Foydalanuvchi' THEN EXCLUDED.display_name ELSE public.profiles.display_name END,
    email = EXCLUDED.email,
    updated_at = now();

  INSERT INTO public.learner_profiles (user_id, selected_course_id, goal, daily_minutes, initial_level, created_at, updated_at)
  VALUES (NEW.id, 'course_math_01', 'mastery', 15, 'intermediate', now(), now())
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.gamification_profiles (user_id, xp, streak_days, last_activity_date, created_at, updated_at)
  VALUES (NEW.id, 0, 1, CURRENT_DATE, now(), now())
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.user_preferences (user_id, dark_mode, notifications_enabled, language, updated_at)
  VALUES (NEW.id, false, true, 'uz', now())
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Idempotent profile provisioning function for existing users without profile rows
CREATE OR REPLACE FUNCTION public.provision_missing_profiles()
RETURNS void AS $$
BEGIN
  INSERT INTO public.profiles (id, first_name, last_name, email, avatar_url, display_name, created_at, updated_at)
  SELECT
    u.id,
    COALESCE(NULLIF(TRIM(u.raw_user_meta_data->>'first_name'), ''), 'Foydalanuvchi'),
    COALESCE(NULLIF(TRIM(u.raw_user_meta_data->>'last_name'), ''), ''),
    COALESCE(u.email, ''),
    u.raw_user_meta_data->>'avatar_url',
    COALESCE(
      NULLIF(TRIM(CONCAT(u.raw_user_meta_data->>'first_name', ' ', u.raw_user_meta_data->>'last_name')), ''),
      NULLIF(TRIM(u.raw_user_meta_data->>'first_name'), ''),
      'Foydalanuvchi'
    ),
    now(),
    now()
  FROM auth.users u
  LEFT JOIN public.profiles p ON u.id = p.id
  WHERE p.id IS NULL
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.learner_profiles (user_id, selected_course_id, goal, daily_minutes, initial_level, created_at, updated_at)
  SELECT u.id, 'course_math_01', 'mastery', 15, 'intermediate', now(), now()
  FROM auth.users u
  LEFT JOIN public.learner_profiles lp ON u.id = lp.user_id
  WHERE lp.user_id IS NULL
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.gamification_profiles (user_id, xp, streak_days, last_activity_date, created_at, updated_at)
  SELECT u.id, 0, 1, CURRENT_DATE, now(), now()
  FROM auth.users u
  LEFT JOIN public.gamification_profiles gp ON u.id = gp.user_id
  WHERE gp.user_id IS NULL
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.user_preferences (user_id, dark_mode, notifications_enabled, language, updated_at)
  SELECT u.id, false, true, 'uz', now()
  FROM auth.users u
  LEFT JOIN public.user_preferences up ON u.id = up.user_id
  WHERE up.user_id IS NULL
  ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Helper RPC to update current authenticated user's profile securely
CREATE OR REPLACE FUNCTION public.sync_profile(
  p_first_name TEXT,
  p_last_name TEXT DEFAULT '',
  p_avatar_url TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_display_name TEXT;
  v_result JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_first_name := COALESCE(NULLIF(TRIM(p_first_name), ''), 'Foydalanuvchi');
  v_last_name := COALESCE(NULLIF(TRIM(p_last_name), ''), '');
  
  IF v_last_name <> '' THEN
    v_display_name := v_first_name || ' ' || v_last_name;
  ELSE
    v_display_name := v_first_name;
  END IF;

  INSERT INTO public.profiles (id, first_name, last_name, display_name, avatar_url, updated_at)
  VALUES (v_uid, v_first_name, v_last_name, v_display_name, p_avatar_url, now())
  ON CONFLICT (id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    display_name = EXCLUDED.display_name,
    avatar_url = COALESCE(EXCLUDED.avatar_url, public.profiles.avatar_url),
    updated_at = now();

  SELECT to_jsonb(p) INTO v_result
  FROM public.profiles p
  WHERE p.id = v_uid;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.sync_profile(TEXT, TEXT, TEXT) TO authenticated;
