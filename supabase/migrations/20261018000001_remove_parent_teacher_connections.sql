-- ============================================================================
-- BilimYo'l Smart Edu - remove retired Parent/Teacher relationship features
-- Migration: 20261018000001_remove_parent_teacher_connections.sql
--
-- This is a forward-only schema change. Back up any target database and review
-- the data-retention impact before applying it outside a disposable database.
-- Historical migrations are intentionally left immutable.
--
-- Retired objects:
--   parent/student links, classes/class members, teacher invitations, and
--   student-alert monitoring storage. Learner sessions and daily learning
--   statistics remain because the active learner progress and heartbeat paths
--   still use them.
-- ============================================================================

BEGIN;

-- --------------------------------------------------------------------------
-- 1. Remove relationship-dependent policies from shared learner tables.
-- --------------------------------------------------------------------------

DROP POLICY IF EXISTS "Parents can read linked child profile" ON public.profiles;
DROP POLICY IF EXISTS "Teachers can read enrolled student profile" ON public.profiles;
DROP POLICY IF EXISTS "Profiles parent read linked child" ON public.profiles;
DROP POLICY IF EXISTS "Profiles teacher read enrolled student" ON public.profiles;

DROP POLICY IF EXISTS "Parents can read child skill scores" ON public.learner_skill_scores;
DROP POLICY IF EXISTS "Teachers can read student skill scores" ON public.learner_skill_scores;
DROP POLICY IF EXISTS "Skill scores parent read child" ON public.learner_skill_scores;
DROP POLICY IF EXISTS "Skill scores teacher read student" ON public.learner_skill_scores;

DROP POLICY IF EXISTS "Parents can view linked child sessions" ON public.learning_sessions;
DROP POLICY IF EXISTS "Teachers can view class student sessions" ON public.learning_sessions;
DROP POLICY IF EXISTS "Sessions parent read child" ON public.learning_sessions;
DROP POLICY IF EXISTS "Sessions teacher read student" ON public.learning_sessions;

DROP POLICY IF EXISTS "Parents can view child daily stats" ON public.daily_learning_stats;
DROP POLICY IF EXISTS "Teachers can view student daily stats" ON public.daily_learning_stats;
DROP POLICY IF EXISTS "Daily stats parent read child" ON public.daily_learning_stats;
DROP POLICY IF EXISTS "Daily stats teacher read student" ON public.daily_learning_stats;

-- Policies on the retired relations are removed first so their helper-function
-- dependencies do not prevent the subsequent DROP FUNCTION statements.
DROP POLICY IF EXISTS "Parents can manage own links" ON public.parent_student_links;
DROP POLICY IF EXISTS "Students can read their pending and active links" ON public.parent_student_links;
DROP POLICY IF EXISTS "Students can update links assigned to them" ON public.parent_student_links;
DROP POLICY IF EXISTS "Parent links parent management" ON public.parent_student_links;
DROP POLICY IF EXISTS "Parent links student view" ON public.parent_student_links;
DROP POLICY IF EXISTS "Parent links student update" ON public.parent_student_links;
DROP POLICY IF EXISTS "Linked students can read own parent links" ON public.parent_student_links;

DROP POLICY IF EXISTS "Teachers can CRUD own classes" ON public.classes;
DROP POLICY IF EXISTS "Students can view classes they belong to" ON public.classes;
DROP POLICY IF EXISTS "Classes teacher management" ON public.classes;
DROP POLICY IF EXISTS "Classes student view" ON public.classes;
DROP POLICY IF EXISTS "Verified teachers manage own classes" ON public.classes;

DROP POLICY IF EXISTS "Teachers can manage members in own classes" ON public.class_members;
DROP POLICY IF EXISTS "Students can view and join classes" ON public.class_members;
DROP POLICY IF EXISTS "Class members student access" ON public.class_members;
DROP POLICY IF EXISTS "Class members teacher management" ON public.class_members;
DROP POLICY IF EXISTS "Verified teachers manage class members" ON public.class_members;

DROP POLICY IF EXISTS "Teacher invitation codes access control" ON public.teacher_invitation_codes;
DROP POLICY IF EXISTS "Admin exclusive teacher invitation access" ON public.teacher_invitation_codes;

DROP POLICY IF EXISTS "Students can view own alerts" ON public.student_alerts;
DROP POLICY IF EXISTS "Parents can view child alerts" ON public.student_alerts;
DROP POLICY IF EXISTS "Teachers can view student alerts" ON public.student_alerts;
DROP POLICY IF EXISTS "Alerts self view" ON public.student_alerts;
DROP POLICY IF EXISTS "Alerts parent read child" ON public.student_alerts;
DROP POLICY IF EXISTS "Alerts teacher read student" ON public.student_alerts;

-- --------------------------------------------------------------------------
-- 2. Remove RPCs and authorization helpers that only served the retired
--    relationship, class, or invitation flows.
-- --------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.create_parent_link_code();
DROP FUNCTION IF EXISTS public.redeem_parent_link_code(TEXT);
DROP FUNCTION IF EXISTS public.create_teacher_class(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.join_class_by_code(TEXT);

DROP FUNCTION IF EXISTS public.create_teacher_invitation(TEXT, INT, INT);
DROP FUNCTION IF EXISTS public.list_teacher_invitations();
DROP FUNCTION IF EXISTS public.revoke_teacher_invitation(UUID);
DROP FUNCTION IF EXISTS public.redeem_teacher_invitation_code(TEXT);
DROP FUNCTION IF EXISTS public.hash_teacher_code(TEXT);

DROP FUNCTION IF EXISTS public.is_student_in_class(UUID, UUID);
DROP FUNCTION IF EXISTS public.is_teacher_of_class(UUID, UUID);
DROP FUNCTION IF EXISTS public.is_teacher_of_student(UUID, UUID);
DROP FUNCTION IF EXISTS public.is_parent_of_student(UUID, UUID);
DROP FUNCTION IF EXISTS public.is_teacher_or_admin(UUID);

-- --------------------------------------------------------------------------
-- 3. Convert retired role rows to the remaining learner role before narrowing
--    the profile constraint. The transaction-local flag is the same guarded
--    mechanism used by the existing role-management RPCs.
-- --------------------------------------------------------------------------

SELECT set_config('bilimyol.authorized_role_change', 'true', true);

UPDATE public.profiles
SET role = 'student',
    updated_at = now()
WHERE role IS NULL OR role NOT IN ('student', 'admin');

SELECT set_config('bilimyol.authorized_role_change', 'false', true);

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check CHECK (role IN ('student', 'admin'));

-- New accounts remain learners; administrator elevation is still an explicit
-- server-side operation and signup metadata is never treated as authority.
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
  v_valid_course_id TEXT;
BEGIN
  v_first_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), ''), 'Foydalanuvchi');
  v_last_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), ''), '');
  v_display_name := CASE
    WHEN v_last_name <> '' THEN v_first_name || ' ' || v_last_name
    ELSE v_first_name
  END;

  INSERT INTO public.profiles (
    id, first_name, last_name, email, avatar_url, display_name, role, created_at, updated_at
  )
  VALUES (
    NEW.id,
    v_first_name,
    v_last_name,
    COALESCE(NEW.email, ''),
    NEW.raw_user_meta_data->>'avatar_url',
    v_display_name,
    'student',
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    first_name = CASE
      WHEN public.profiles.first_name = 'Foydalanuvchi'
        AND EXCLUDED.first_name <> 'Foydalanuvchi'
      THEN EXCLUDED.first_name
      ELSE public.profiles.first_name
    END,
    last_name = CASE
      WHEN public.profiles.last_name = '' AND EXCLUDED.last_name <> ''
      THEN EXCLUDED.last_name
      ELSE public.profiles.last_name
    END,
    display_name = CASE
      WHEN public.profiles.display_name = 'Foydalanuvchi'
        AND EXCLUDED.display_name <> 'Foydalanuvchi'
      THEN EXCLUDED.display_name
      ELSE public.profiles.display_name
    END,
    email = EXCLUDED.email,
    updated_at = now();

  BEGIN
    SELECT id INTO v_valid_course_id
    FROM public.courses
    WHERE id = 'course_math_01'
    LIMIT 1;

    INSERT INTO public.learner_profiles (
      user_id, selected_course_id, goal, daily_minutes, initial_level, created_at, updated_at
    )
    VALUES (
      NEW.id, v_valid_course_id, 'mastery', 15, 'intermediate', now(), now()
    )
    ON CONFLICT (user_id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: learner_profiles insert warning: %', SQLERRM;
  END;

  BEGIN
    INSERT INTO public.gamification_profiles (
      user_id, xp, streak_days, last_activity_date, updated_at
    )
    VALUES (
      NEW.id, 0, 1, (now() AT TIME ZONE 'Asia/Tashkent')::date, now()
    )
    ON CONFLICT (user_id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: gamification_profiles insert warning: %', SQLERRM;
  END;

  BEGIN
    INSERT INTO public.user_preferences (
      user_id, dark_mode, notifications_enabled, language, updated_at
    )
    VALUES (NEW.id, false, true, 'uz', now())
    ON CONFLICT (user_id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: user_preferences insert warning: %', SQLERRM;
  END;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_new_user FATAL: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Keep the administrative role-management API, but make its accepted role set
-- match the reduced product surface.
CREATE OR REPLACE FUNCTION public.admin_update_user_role(
  p_user_id UUID,
  p_new_role TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_clean_role TEXT := LOWER(TRIM(p_new_role));
BEGIN
  IF v_caller_id IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Ruxsat etilmagan: Faqat platforma administratori foydalanuvchi rolini o‘zgartira oladi.'
    );
  END IF;

  IF v_clean_role NOT IN ('student', 'admin') THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Noto‘g‘ri rol kiritildi. Ruxsat etilgan rollar: student, admin.'
    );
  END IF;

  PERFORM set_config('bilimyol.authorized_role_change', 'true', true);

  UPDATE public.profiles
  SET role = v_clean_role,
      updated_at = now()
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Foydalanuvchi topilmadi.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', p_user_id,
    'role', v_clean_role,
    'message', 'Foydalanuvchi roli muvaffaqiyatli yangilandi.'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_user_role(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_user_role(UUID, TEXT) TO authenticated, postgres, service_role;

COMMENT ON FUNCTION public.admin_update_user_role(UUID, TEXT) IS
  'Authorized administrative RPC for the remaining student and admin roles.';

-- --------------------------------------------------------------------------
-- 4. Drop feature-only storage. No CASCADE is used so an unexpected external
--    dependency fails the migration instead of being removed implicitly.
-- --------------------------------------------------------------------------

DROP TABLE IF EXISTS public.class_members;
DROP TABLE IF EXISTS public.classes;
DROP TABLE IF EXISTS public.parent_student_links;
DROP TABLE IF EXISTS public.teacher_invitation_attempts;
DROP TABLE IF EXISTS public.teacher_invitation_codes;
DROP TABLE IF EXISTS public.student_alerts;

-- learning_sessions and daily_learning_stats intentionally remain in place:
-- ActiveLearningTracker and learner progress use their learner-owned paths.

COMMIT;
