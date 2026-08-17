-- BilimYo‘l Smart Edu - Parent + Teacher Learning Monitoring System Migration
-- Migration: 20260817000003_parent_teacher_monitoring.sql

-- 1. ADD ROLE TO PROFILES TABLE
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'parent', 'teacher'));

-- Update handle_new_user trigger to preserve role from metadata
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
    role = CASE WHEN public.profiles.role = 'student' AND EXCLUDED.role <> 'student' THEN EXCLUDED.role ELSE public.profiles.role END,
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

-- 2. PARENT-STUDENT RELATIONSHIPS
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

-- 3. CLASSES AND CLASS MEMBERS
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

-- 4. ACTIVE LEARNING SESSIONS
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

-- 5. DAILY LEARNING AGGREGATE STATS
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

-- 6. STUDENT ALERTS / PEDAGOGICAL SIGNALS
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

-- ============================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================
ALTER TABLE public.parent_student_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learning_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_learning_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_alerts ENABLE ROW LEVEL SECURITY;

-- Parent-Student Links RLS
CREATE POLICY "Parents can manage own links"
  ON public.parent_student_links
  FOR ALL
  USING (auth.uid() = parent_user_id)
  WITH CHECK (auth.uid() = parent_user_id);

CREATE POLICY "Students can read their pending and active links"
  ON public.parent_student_links
  FOR SELECT
  USING (auth.uid() = student_user_id OR status = 'pending');

CREATE POLICY "Students can update links assigned to them"
  ON public.parent_student_links
  FOR UPDATE
  USING (auth.uid() = student_user_id OR status = 'pending')
  WITH CHECK (auth.uid() = student_user_id);

-- Classes RLS
CREATE POLICY "Teachers can CRUD own classes"
  ON public.classes
  FOR ALL
  USING (auth.uid() = teacher_user_id)
  WITH CHECK (auth.uid() = teacher_user_id);

CREATE POLICY "Students can view classes they belong to"
  ON public.classes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.class_members
      WHERE class_members.class_id = classes.id
      AND class_members.student_user_id = auth.uid()
    )
  );

-- Class Members RLS
CREATE POLICY "Teachers can manage members in own classes"
  ON public.class_members
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.classes
      WHERE classes.id = class_members.class_id
      AND classes.teacher_user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.classes
      WHERE classes.id = class_members.class_id
      AND classes.teacher_user_id = auth.uid()
    )
  );

CREATE POLICY "Students can view and join classes"
  ON public.class_members
  FOR ALL
  USING (auth.uid() = student_user_id)
  WITH CHECK (auth.uid() = student_user_id);

-- Learning Sessions RLS
CREATE POLICY "Students can manage own sessions"
  ON public.learning_sessions
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Parents can view linked child sessions"
  ON public.learning_sessions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.parent_student_links
      WHERE parent_student_links.parent_user_id = auth.uid()
      AND parent_student_links.student_user_id = learning_sessions.user_id
      AND parent_student_links.status = 'active'
    )
  );

CREATE POLICY "Teachers can view class student sessions"
  ON public.learning_sessions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.class_members cm
      JOIN public.classes c ON cm.class_id = c.id
      WHERE c.teacher_user_id = auth.uid()
      AND cm.student_user_id = learning_sessions.user_id
      AND cm.status = 'active'
    )
  );

-- Daily Stats RLS
CREATE POLICY "Students can manage own daily stats"
  ON public.daily_learning_stats
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Parents can view child daily stats"
  ON public.daily_learning_stats
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.parent_student_links
      WHERE parent_student_links.parent_user_id = auth.uid()
      AND parent_student_links.student_user_id = daily_learning_stats.user_id
      AND parent_student_links.status = 'active'
    )
  );

CREATE POLICY "Teachers can view student daily stats"
  ON public.daily_learning_stats
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.class_members cm
      JOIN public.classes c ON cm.class_id = c.id
      WHERE c.teacher_user_id = auth.uid()
      AND cm.student_user_id = daily_learning_stats.user_id
      AND cm.status = 'active'
    )
  );

-- Student Alerts RLS
CREATE POLICY "Students can view own alerts"
  ON public.student_alerts
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Parents can view child alerts"
  ON public.student_alerts
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.parent_student_links
      WHERE parent_student_links.parent_user_id = auth.uid()
      AND parent_student_links.student_user_id = student_alerts.user_id
      AND parent_student_links.status = 'active'
    )
  );

CREATE POLICY "Teachers can view student alerts"
  ON public.student_alerts
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.class_members cm
      JOIN public.classes c ON cm.class_id = c.id
      WHERE c.teacher_user_id = auth.uid()
      AND cm.student_user_id = student_alerts.user_id
      AND cm.status = 'active'
    )
  );

-- Also allow parents & teachers to read student profiles and skill scores
CREATE POLICY "Parents can read linked child profile"
  ON public.profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.parent_student_links
      WHERE parent_student_links.parent_user_id = auth.uid()
      AND parent_student_links.student_user_id = profiles.id
      AND parent_student_links.status = 'active'
    )
  );

CREATE POLICY "Teachers can read enrolled student profile"
  ON public.profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.class_members cm
      JOIN public.classes c ON cm.class_id = c.id
      WHERE c.teacher_user_id = auth.uid()
      AND cm.student_user_id = profiles.id
      AND cm.status = 'active'
    )
  );

CREATE POLICY "Parents can read child skill scores"
  ON public.learner_skill_scores
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.parent_student_links
      WHERE parent_student_links.parent_user_id = auth.uid()
      AND parent_student_links.student_user_id = learner_skill_scores.user_id
      AND parent_student_links.status = 'active'
    )
  );

CREATE POLICY "Teachers can read student skill scores"
  ON public.learner_skill_scores
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.class_members cm
      JOIN public.classes c ON cm.class_id = c.id
      WHERE c.teacher_user_id = auth.uid()
      AND cm.student_user_id = learner_skill_scores.user_id
      AND cm.status = 'active'
    )
  );

-- ============================================================
-- RPC FUNCTIONS
-- ============================================================

-- 1. Generate 6-digit Parent Link Code
CREATE OR REPLACE FUNCTION public.create_parent_link_code()
RETURNS JSONB AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_code TEXT;
  v_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Generate 6 character alphanumeric code
  v_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));

  INSERT INTO public.parent_student_links (parent_user_id, link_code, status, expires_at)
  VALUES (v_uid, v_code, 'pending', now() + INTERVAL '24 hours')
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'id', v_id,
    'link_code', v_code,
    'expires_at', (now() + INTERVAL '24 hours')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Student Redeems Parent Link Code
CREATE OR REPLACE FUNCTION public.redeem_parent_link_code(p_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_student_id UUID := auth.uid();
  v_link RECORD;
  v_parent_profile RECORD;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_link
  FROM public.parent_student_links
  WHERE UPPER(TRIM(link_code)) = UPPER(TRIM(p_code))
    AND status = 'pending'
    AND expires_at > now()
  LIMIT 1;

  IF v_link.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yaroqsiz yoki muddati o‘tgan kod.');
  END IF;

  IF v_link.parent_user_id = v_student_id THEN
    RETURN jsonb_build_object('success', false, 'message', 'O‘z hisobingizga bog‘lana olmaysiz.');
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

-- 3. Teacher Creates Class
CREATE OR REPLACE FUNCTION public.create_teacher_class(
  p_name TEXT,
  p_subject TEXT DEFAULT 'Matematika',
  p_grade_level TEXT DEFAULT '7-sinf'
)
RETURNS JSONB AS $$
DECLARE
  v_teacher_id UUID := auth.uid();
  v_code TEXT;
  v_class RECORD;
BEGIN
  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || now()::TEXT) FROM 1 FOR 6));

  INSERT INTO public.classes (teacher_user_id, name, subject, grade_level, class_code)
  VALUES (v_teacher_id, p_name, p_subject, p_grade_level, v_code)
  RETURNING * INTO v_class;

  RETURN to_jsonb(v_class);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Student Joins Class
CREATE OR REPLACE FUNCTION public.join_class_by_code(p_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_student_id UUID := auth.uid();
  v_class RECORD;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_class
  FROM public.classes
  WHERE UPPER(TRIM(class_code)) = UPPER(TRIM(p_code))
  LIMIT 1;

  IF v_class.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bunday sinf kodi topilmadi.');
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

-- 5. Heartbeat & Active Learning Time Engine (Anti-Cheat Server Calculation)
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
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_session
  FROM public.learning_sessions
  WHERE id = p_session_id AND user_id = v_uid;

  IF v_session.id IS NULL THEN
    -- Initialize new session
    INSERT INTO public.learning_sessions (
      id, user_id, course_id, lesson_id, started_at, last_heartbeat_at, active_seconds, platform
    )
    VALUES (
      p_session_id, v_uid, p_course_id, p_lesson_id, v_now, v_now, 0, p_platform
    )
    RETURNING * INTO v_session;
  ELSE
    -- Calculate elapsed seconds since last heartbeat
    v_elapsed := EXTRACT(EPOCH FROM (v_now - v_session.last_heartbeat_at))::INT;

    -- Inactivity rule: If heartbeat gap is > 300s (5 min), do not count as active study
    IF v_elapsed > 0 AND v_elapsed <= 300 THEN
      -- Cap individual heartbeat pulse to maximum 60 seconds
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

  -- Upsert daily learning stats
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

GRANT EXECUTE ON FUNCTION public.create_parent_link_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_parent_link_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_teacher_class(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_class_by_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_session_heartbeat(UUID, TEXT, TEXT, TEXT) TO authenticated;
