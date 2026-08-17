-- ==============================================================================
-- BILIMYO‘L SMART EDU - COMPLETE PRODUCTION PENDING MIGRATION
-- File: supabase/PRODUCTION_DEPLOY_ALL_PENDING.sql
-- 
-- Safe, Idempotent, Non-Destructive, Dependency-Ordered
-- Covers:
-- 1. Extensions (pgcrypto)
-- 2. public.profiles (role, display_name, constraint)
-- 3. Registration Trigger (handle_new_user)
-- 4. Parent-Student Links (parent_student_links)
-- 5. Classes & Class Members (classes, class_members)
-- 6. Active Learning Sessions & Heartbeats (learning_sessions)
-- 7. Daily Learning Stats (daily_learning_stats)
-- 8. Student Pedagogical Alerts (student_alerts)
-- 9. Teacher Invitation System (teacher_invitation_codes, teacher_invitation_attempts)
-- 10. Row Level Security Policies (Idempotent DROP + CREATE)
-- 11. Security Definer RPCs (admin authorization, anti-tamper, rate-limiting)
-- 12. Strict Permissions & Revokes
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 1. PROFILES ROLE & DISPLAY NAME SUPPORT
-- ==============================================================================

ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS display_name TEXT;

ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'student';

-- Ensure existing records have a valid role before adding constraint
UPDATE public.profiles 
SET role = 'student' 
WHERE role IS NULL OR role NOT IN ('student', 'parent', 'teacher', 'admin');

ALTER TABLE public.profiles 
  DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles 
  ADD CONSTRAINT profiles_role_check CHECK (role IN ('student', 'parent', 'teacher', 'admin'));

CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- ==============================================================================
-- 2. SECURE AUTH REGISTRATION TRIGGER (PRODUCTION HARDENED)
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

-- Rebind trigger safely
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 3. PARENT + TEACHER MONITORING TABLES
-- ==============================================================================

-- 3.1 PARENT-STUDENT RELATIONSHIPS
CREATE TABLE IF NOT EXISTS public.parent_student_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  student_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  link_code TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'revoked', 'expired')),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '24 hours'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_parent_student_parent ON public.parent_student_links(parent_user_id);
CREATE INDEX IF NOT EXISTS idx_parent_student_student ON public.parent_student_links(student_user_id);
CREATE INDEX IF NOT EXISTS idx_parent_student_code ON public.parent_student_links(link_code, status);

-- 3.2 CLASSES AND CLASS MEMBERS
CREATE TABLE IF NOT EXISTS public.classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  subject TEXT NOT NULL DEFAULT 'Matematika',
  grade_level TEXT NOT NULL DEFAULT '7-sinf',
  class_code TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_classes_teacher ON public.classes(teacher_user_id);
CREATE INDEX IF NOT EXISTS idx_classes_code ON public.classes(class_code);

CREATE TABLE IF NOT EXISTS public.class_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  student_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived', 'left')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (class_id, student_user_id)
);

CREATE INDEX IF NOT EXISTS idx_class_members_class ON public.class_members(class_id);
CREATE INDEX IF NOT EXISTS idx_class_members_student ON public.class_members(student_user_id);

-- 3.3 ACTIVE LEARNING SESSIONS & HEARTBEATS
CREATE TABLE IF NOT EXISTS public.learning_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  course_id TEXT NOT NULL DEFAULT 'course_math_01',
  lesson_id TEXT,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ,
  active_seconds INT NOT NULL DEFAULT 0,
  platform TEXT NOT NULL DEFAULT 'web' CHECK (platform IN ('web', 'android', 'ios')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON public.learning_sessions(user_id, started_at DESC);

-- 3.4 DAILY LEARNING AGGREGATE STATS
CREATE TABLE IF NOT EXISTS public.daily_learning_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_date DATE NOT NULL DEFAULT CURRENT_DATE,
  active_seconds INT NOT NULL DEFAULT 0,
  lessons_completed INT NOT NULL DEFAULT 0,
  questions_answered INT NOT NULL DEFAULT 0,
  correct_answers INT NOT NULL DEFAULT 0,
  accuracy_percent INT NOT NULL DEFAULT 0,
  xp_earned INT NOT NULL DEFAULT 0,
  overall_score INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, activity_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_stats_user_date ON public.daily_learning_stats(user_id, activity_date DESC);

-- 3.5 STUDENT PEDAGOGICAL ALERTS
CREATE TABLE IF NOT EXISTS public.student_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  alert_type TEXT NOT NULL CHECK (alert_type IN ('inactivity', 'weak_topic', 'score_drop', 'goal_achieved', 'streak_milestone')),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_resolved BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_student_alerts_user ON public.student_alerts(user_id, created_at DESC);

-- ==============================================================================
-- 4. TEACHER INVITATION SYSTEM TABLES (NO HARDCODED SEEDS)
-- ==============================================================================

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

CREATE TABLE IF NOT EXISTS public.teacher_invitation_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_success BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_teacher_inv_attempts_user ON public.teacher_invitation_attempts(user_id, attempted_at);

-- ==============================================================================
-- 5. ROW LEVEL SECURITY (RLS) & HELPER FUNCTIONS (RECURSION-FREE)
-- ==============================================================================

-- 5.1 SECURITY DEFINER AUTHORIZATION HELPER FUNCTIONS
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_student_in_class(p_class_id UUID, p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.class_members
    WHERE class_id = p_class_id
      AND student_user_id = p_student_id
      AND status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_teacher_of_class(p_class_id UUID, p_teacher_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.classes
    WHERE id = p_class_id
      AND teacher_user_id = p_teacher_id
  );
$$;

CREATE OR REPLACE FUNCTION public.is_teacher_of_student(p_teacher_id UUID, p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.classes c
    INNER JOIN public.class_members cm ON cm.class_id = c.id
    WHERE c.teacher_user_id = p_teacher_id
      AND cm.student_user_id = p_student_id
      AND cm.status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_parent_of_student(p_parent_id UUID, p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.parent_student_links
    WHERE parent_user_id = p_parent_id
      AND student_user_id = p_student_id
      AND status = 'active'
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_student_in_class(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_teacher_of_class(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_teacher_of_student(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_parent_of_student(UUID, UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, postgres, service_role;
GRANT EXECUTE ON FUNCTION public.is_student_in_class(UUID, UUID) TO authenticated, postgres, service_role;
GRANT EXECUTE ON FUNCTION public.is_teacher_of_class(UUID, UUID) TO authenticated, postgres, service_role;
GRANT EXECUTE ON FUNCTION public.is_teacher_of_student(UUID, UUID) TO authenticated, postgres, service_role;
GRANT EXECUTE ON FUNCTION public.is_parent_of_student(UUID, UUID) TO authenticated, postgres, service_role;

-- 5.2 PROFILES POLICIES (Zero table-recursion)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "User can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "User can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "User can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admin can read all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Parents can read linked child profile" ON public.profiles;
DROP POLICY IF EXISTS "Teachers can read enrolled student profile" ON public.profiles;
DROP POLICY IF EXISTS "Profiles self read" ON public.profiles;
DROP POLICY IF EXISTS "Profiles self update" ON public.profiles;
DROP POLICY IF EXISTS "Profiles self insert" ON public.profiles;
DROP POLICY IF EXISTS "Profiles admin read all" ON public.profiles;
DROP POLICY IF EXISTS "Profiles parent read linked child" ON public.profiles;
DROP POLICY IF EXISTS "Profiles teacher read enrolled student" ON public.profiles;

CREATE POLICY "Profiles self read"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

CREATE POLICY "Profiles self update"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY "Profiles self insert"
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

CREATE POLICY "Profiles admin read all"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "Profiles parent read linked child"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (public.is_parent_of_student(auth.uid(), id));

CREATE POLICY "Profiles teacher read enrolled student"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (public.is_teacher_of_student(auth.uid(), id));

-- 5.3 CLASSES POLICIES
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Teachers can CRUD own classes" ON public.classes;
DROP POLICY IF EXISTS "Students can view classes they belong to" ON public.classes;
DROP POLICY IF EXISTS "Classes teacher management" ON public.classes;
DROP POLICY IF EXISTS "Classes student view" ON public.classes;

CREATE POLICY "Classes teacher management"
  ON public.classes
  FOR ALL
  TO authenticated
  USING (teacher_user_id = auth.uid() OR public.is_admin())
  WITH CHECK (teacher_user_id = auth.uid() OR public.is_admin());

CREATE POLICY "Classes student view"
  ON public.classes
  FOR SELECT
  TO authenticated
  USING (public.is_student_in_class(id, auth.uid()));

-- 5.4 CLASS MEMBERS POLICIES
ALTER TABLE public.class_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Teachers can manage members in own classes" ON public.class_members;
DROP POLICY IF EXISTS "Students can view and join classes" ON public.class_members;
DROP POLICY IF EXISTS "Class members student access" ON public.class_members;
DROP POLICY IF EXISTS "Class members teacher management" ON public.class_members;

CREATE POLICY "Class members student access"
  ON public.class_members
  FOR ALL
  TO authenticated
  USING (student_user_id = auth.uid())
  WITH CHECK (student_user_id = auth.uid());

CREATE POLICY "Class members teacher management"
  ON public.class_members
  FOR ALL
  TO authenticated
  USING (public.is_teacher_of_class(class_id, auth.uid()) OR public.is_admin())
  WITH CHECK (public.is_teacher_of_class(class_id, auth.uid()) OR public.is_admin());

-- 5.5 PARENT STUDENT LINKS POLICIES
ALTER TABLE public.parent_student_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Parents can manage own links" ON public.parent_student_links;
DROP POLICY IF EXISTS "Students can read their pending and active links" ON public.parent_student_links;
DROP POLICY IF EXISTS "Students can update links assigned to them" ON public.parent_student_links;
DROP POLICY IF EXISTS "Parent links parent management" ON public.parent_student_links;
DROP POLICY IF EXISTS "Parent links student view" ON public.parent_student_links;
DROP POLICY IF EXISTS "Parent links student update" ON public.parent_student_links;

CREATE POLICY "Parent links parent management"
  ON public.parent_student_links
  FOR ALL
  TO authenticated
  USING (parent_user_id = auth.uid() OR public.is_admin())
  WITH CHECK (parent_user_id = auth.uid() OR public.is_admin());

CREATE POLICY "Parent links student view"
  ON public.parent_student_links
  FOR SELECT
  TO authenticated
  USING (student_user_id = auth.uid() OR status = 'pending');

CREATE POLICY "Parent links student update"
  ON public.parent_student_links
  FOR UPDATE
  TO authenticated
  USING (student_user_id = auth.uid() OR status = 'pending')
  WITH CHECK (student_user_id = auth.uid());

-- 5.6 LEARNING SESSIONS POLICIES
ALTER TABLE public.learning_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Students can manage own sessions" ON public.learning_sessions;
DROP POLICY IF EXISTS "Parents can view linked child sessions" ON public.learning_sessions;
DROP POLICY IF EXISTS "Teachers can view class student sessions" ON public.learning_sessions;
DROP POLICY IF EXISTS "Sessions self management" ON public.learning_sessions;
DROP POLICY IF EXISTS "Sessions parent read child" ON public.learning_sessions;
DROP POLICY IF EXISTS "Sessions teacher read student" ON public.learning_sessions;

CREATE POLICY "Sessions self management"
  ON public.learning_sessions
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Sessions parent read child"
  ON public.learning_sessions
  FOR SELECT
  TO authenticated
  USING (public.is_parent_of_student(auth.uid(), user_id));

CREATE POLICY "Sessions teacher read student"
  ON public.learning_sessions
  FOR SELECT
  TO authenticated
  USING (public.is_teacher_of_student(auth.uid(), user_id));

-- 5.7 DAILY STATS POLICIES
ALTER TABLE public.daily_learning_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Students can manage own daily stats" ON public.daily_learning_stats;
DROP POLICY IF EXISTS "Parents can view child daily stats" ON public.daily_learning_stats;
DROP POLICY IF EXISTS "Teachers can view student daily stats" ON public.daily_learning_stats;
DROP POLICY IF EXISTS "Daily stats self management" ON public.daily_learning_stats;
DROP POLICY IF EXISTS "Daily stats parent read child" ON public.daily_learning_stats;
DROP POLICY IF EXISTS "Daily stats teacher read student" ON public.daily_learning_stats;

CREATE POLICY "Daily stats self management"
  ON public.daily_learning_stats
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Daily stats parent read child"
  ON public.daily_learning_stats
  FOR SELECT
  TO authenticated
  USING (public.is_parent_of_student(auth.uid(), user_id));

CREATE POLICY "Daily stats teacher read student"
  ON public.daily_learning_stats
  FOR SELECT
  TO authenticated
  USING (public.is_teacher_of_student(auth.uid(), user_id));

-- 5.8 STUDENT ALERTS POLICIES
ALTER TABLE public.student_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Students can view own alerts" ON public.student_alerts;
DROP POLICY IF EXISTS "Parents can view child alerts" ON public.student_alerts;
DROP POLICY IF EXISTS "Teachers can view student alerts" ON public.student_alerts;
DROP POLICY IF EXISTS "Alerts self view" ON public.student_alerts;
DROP POLICY IF EXISTS "Alerts parent read child" ON public.student_alerts;
DROP POLICY IF EXISTS "Alerts teacher read student" ON public.student_alerts;

CREATE POLICY "Alerts self view"
  ON public.student_alerts
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Alerts parent read child"
  ON public.student_alerts
  FOR SELECT
  TO authenticated
  USING (public.is_parent_of_student(auth.uid(), user_id));

CREATE POLICY "Alerts teacher read student"
  ON public.student_alerts
  FOR SELECT
  TO authenticated
  USING (public.is_teacher_of_student(auth.uid(), user_id));

-- 5.9 LEARNER SKILL SCORES POLICIES
ALTER TABLE public.learner_skill_scores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Parents can read child skill scores" ON public.learner_skill_scores;
DROP POLICY IF EXISTS "Teachers can read student skill scores" ON public.learner_skill_scores;
DROP POLICY IF EXISTS "Skill scores self view" ON public.learner_skill_scores;
DROP POLICY IF EXISTS "Skill scores parent read child" ON public.learner_skill_scores;
DROP POLICY IF EXISTS "Skill scores teacher read student" ON public.learner_skill_scores;

CREATE POLICY "Skill scores self view"
  ON public.learner_skill_scores
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Skill scores parent read child"
  ON public.learner_skill_scores
  FOR SELECT
  TO authenticated
  USING (public.is_parent_of_student(auth.uid(), user_id));

CREATE POLICY "Skill scores teacher read student"
  ON public.learner_skill_scores
  FOR SELECT
  TO authenticated
  USING (public.is_teacher_of_student(auth.uid(), user_id));

-- 5.10 TEACHER INVITATION CODES POLICIES
ALTER TABLE public.teacher_invitation_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Teacher invitation codes access control" ON public.teacher_invitation_codes;
DROP POLICY IF EXISTS "Admin exclusive teacher invitation access" ON public.teacher_invitation_codes;

CREATE POLICY "Admin exclusive teacher invitation access"
  ON public.teacher_invitation_codes
  FOR ALL
  TO authenticated
  USING (public.is_admin());

-- ==============================================================================
-- 6. SECURITY DEFINER RPCS
-- ==============================================================================

-- 6.1 PRIVILEGED ADMIN PROMOTION (SQL Editor or Existing Admin ONLY)
CREATE OR REPLACE FUNCTION public.promote_user_to_admin(p_email TEXT)
RETURNS JSONB AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_target_id UUID;
  v_clean_email TEXT := LOWER(TRIM(p_email));
BEGIN
  -- Strict caller verification: If called via client RPC, caller MUST be an admin
  IF v_caller_id IS NOT NULL AND NOT public.is_admin() THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Ruxsat etilmagan. Faqat platforma administratori boshqa foydalanuvchini admin qila oladi.'
    );
  END IF;

  IF v_clean_email = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Email manzili kiritilishi shart.');
  END IF;

  -- Look up in auth.users
  SELECT id INTO v_target_id
  FROM auth.users
  WHERE LOWER(email) = v_clean_email;

  -- Fallback check in public.profiles
  IF v_target_id IS NULL THEN
    SELECT id INTO v_target_id
    FROM public.profiles
    WHERE LOWER(email) = v_clean_email;
  END IF;

  IF v_target_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Ko‘rsatilgan email (' || v_clean_email || ') bilan foydalanuvchi topilmadi. Avval platformada ro‘yxatdan o‘ting.'
    );
  END IF;

  -- Elevate role in public.profiles
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

-- 6.2 CREATE TEACHER INVITATION (Admin only)
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

-- 6.3 LIST TEACHER INVITATIONS (Admin only)
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

-- 6.4 REVOKE TEACHER INVITATION (Admin only)
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

-- 6.5 REDEEM TEACHER INVITATION CODE
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

  -- Upgrade role in public.profiles
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

-- 6.6 CREATE PARENT LINK CODE
CREATE OR REPLACE FUNCTION public.create_parent_link_code()
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_code TEXT;
  v_id UUID;
  v_attempts INT := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
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

-- 6.7 REDEEM PARENT LINK CODE
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

-- 6.8 CREATE TEACHER CLASS
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

  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = v_teacher_id;

  -- Require teacher or admin role
  IF v_role NOT IN ('teacher', 'admin') THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Faqat tasdiqlangan o‘qituvchilar yoki administratorlar sinf yarata oladi.'
    );
  END IF;

  IF TRIM(p_name) = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Sinf nomi bo‘sh bo‘lishi mumkin emas.');
  END IF;

  LOOP
    v_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || clock_timestamp()::TEXT) FROM 1 FOR 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.classes WHERE class_code = v_code);
    v_attempts := v_attempts + 1;
    IF v_attempts > 10 THEN
      RETURN jsonb_build_object('success', false, 'message', 'Sinf kodini generatsiya qilishda xatolik.');
    END IF;
  END LOOP;

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

-- 6.9 JOIN CLASS BY CODE
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

-- 6.10 RECORD SESSION HEARTBEAT
CREATE OR REPLACE FUNCTION public.record_session_heartbeat(
  p_session_id UUID,
  p_course_id TEXT DEFAULT 'course_math_01',
  p_lesson_id TEXT DEFAULT NULL,
  p_platform TEXT DEFAULT 'web'
)
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_session RECORD;
  v_elapsed INT;
  v_added_active INT := 0;
  v_now TIMESTAMPTZ := now();
  v_today DATE := CURRENT_DATE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Autentifikatsiyadan o‘tilmagan.');
  END IF;

  SELECT * INTO v_session
  FROM public.learning_sessions
  WHERE id = p_session_id AND user_id = v_uid;

  IF v_session.id IS NULL THEN
    INSERT INTO public.learning_sessions (
      id, user_id, course_id, lesson_id, started_at, last_heartbeat_at, active_seconds, platform
    )
    VALUES (
      p_session_id, v_uid, p_course_id, p_lesson_id, v_now, v_now, 0, p_platform
    )
    RETURNING * INTO v_session;
  ELSE
    v_elapsed := EXTRACT(EPOCH FROM (v_now - v_session.last_heartbeat_at))::INT;

    IF v_elapsed > 0 AND v_elapsed <= 300 THEN
      v_added_active := LEAST(60, v_elapsed);
    ELSE
      v_added_active := 0;
    END IF;

    UPDATE public.learning_sessions
    SET last_heartbeat_at = v_now,
        active_seconds = active_seconds + v_added_active,
        lesson_id = COALESCE(p_lesson_id, lesson_id)
    WHERE id = p_session_id;
  END IF;

  INSERT INTO public.daily_learning_stats (
    user_id, activity_date, active_seconds, updated_at
  )
  VALUES (
    v_uid, v_today, v_added_active, v_now
  )
  ON CONFLICT (user_id, activity_date) DO UPDATE SET
    active_seconds = daily_learning_stats.active_seconds + v_added_active,
    updated_at = v_now;

  RETURN jsonb_build_object(
    'session_id', p_session_id,
    'added_active_seconds', v_added_active,
    'total_session_active_seconds', v_session.active_seconds + v_added_active
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 7. PERMISSIONS LOCKDOWN & GRANTS
-- ==============================================================================

REVOKE ALL ON FUNCTION public.promote_user_to_admin(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.promote_user_to_admin(TEXT) TO postgres, service_role, authenticated;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_teacher_invitation(TEXT, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_teacher_invitations() TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_teacher_invitation(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_teacher_invitation_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_parent_link_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_parent_link_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_teacher_class(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_class_by_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_session_heartbeat(UUID, TEXT, TEXT, TEXT) TO authenticated;
