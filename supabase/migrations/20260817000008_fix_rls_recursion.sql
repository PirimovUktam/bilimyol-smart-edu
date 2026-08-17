-- ==============================================================================
-- BILIMYO‘L SMART EDU - MIGRATION 20260817000008
-- File: supabase/migrations/20260817000008_fix_rls_recursion.sql
--
-- FIX: PostgreSQL 42P17 Infinite Recursion in RLS Policies
-- Eliminates circular dependencies between public.classes, public.class_members,
-- public.profiles, public.parent_student_links, and related tables.
--
-- Uses STABLE SECURITY DEFINER helper functions with search_path = public, pg_temp
-- to decouple cross-table relationship authorization from direct policy subqueries.
-- ==============================================================================

-- ==============================================================================
-- 1. SECURITY DEFINER AUTHORIZATION HELPER FUNCTIONS (RECURSION-FREE)
-- ==============================================================================

-- 1.1 Administrator Check
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

-- 1.2 Student Class Membership Check
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

-- 1.3 Teacher Class Ownership Check
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

-- 1.4 Teacher Student Relationship Check (Decoupled cross-table lookup)
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

-- 1.5 Parent Student Relationship Check
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

-- Grant execute permissions to authenticated and service roles
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

-- ==============================================================================
-- 2. RECURSION-FREE RLS POLICIES FOR PUBLIC.PROFILES
-- ==============================================================================

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

-- 2.1 Self read (100% direct, zero dependencies, zero recursion)
CREATE POLICY "Profiles self read"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- 2.2 Self update
CREATE POLICY "Profiles self update"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- 2.3 Self insert
CREATE POLICY "Profiles self insert"
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

-- 2.4 Admin read all
CREATE POLICY "Profiles admin read all"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (public.is_admin());

-- 2.5 Parent read linked child (uses helper function)
CREATE POLICY "Profiles parent read linked child"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (public.is_parent_of_student(auth.uid(), id));

-- 2.6 Teacher read enrolled student (uses helper function)
CREATE POLICY "Profiles teacher read enrolled student"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (public.is_teacher_of_student(auth.uid(), id));

-- ==============================================================================
-- 3. RECURSION-FREE RLS POLICIES FOR PUBLIC.CLASSES
-- ==============================================================================

ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Teachers can CRUD own classes" ON public.classes;
DROP POLICY IF EXISTS "Students can view classes they belong to" ON public.classes;
DROP POLICY IF EXISTS "Classes teacher management" ON public.classes;
DROP POLICY IF EXISTS "Classes student view" ON public.classes;

-- 3.1 Teacher management (or admin)
CREATE POLICY "Classes teacher management"
  ON public.classes
  FOR ALL
  TO authenticated
  USING (teacher_user_id = auth.uid() OR public.is_admin())
  WITH CHECK (teacher_user_id = auth.uid() OR public.is_admin());

-- 3.2 Student view (uses helper function -> eliminates class_members recursion)
CREATE POLICY "Classes student view"
  ON public.classes
  FOR SELECT
  TO authenticated
  USING (public.is_student_in_class(id, auth.uid()));

-- ==============================================================================
-- 4. RECURSION-FREE RLS POLICIES FOR PUBLIC.CLASS_MEMBERS
-- ==============================================================================

ALTER TABLE public.class_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Teachers can manage members in own classes" ON public.class_members;
DROP POLICY IF EXISTS "Students can view and join classes" ON public.class_members;
DROP POLICY IF EXISTS "Class members student access" ON public.class_members;
DROP POLICY IF EXISTS "Class members teacher management" ON public.class_members;

-- 4.1 Student access (own row only)
CREATE POLICY "Class members student access"
  ON public.class_members
  FOR ALL
  TO authenticated
  USING (student_user_id = auth.uid())
  WITH CHECK (student_user_id = auth.uid());

-- 4.2 Teacher management (uses helper function -> eliminates classes recursion)
CREATE POLICY "Class members teacher management"
  ON public.class_members
  FOR ALL
  TO authenticated
  USING (public.is_teacher_of_class(class_id, auth.uid()) OR public.is_admin())
  WITH CHECK (public.is_teacher_of_class(class_id, auth.uid()) OR public.is_admin());

-- ==============================================================================
-- 5. RECURSION-FREE RLS POLICIES FOR PUBLIC.PARENT_STUDENT_LINKS
-- ==============================================================================

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

-- ==============================================================================
-- 6. RECURSION-FREE RLS POLICIES FOR LEARNING SESSIONS
-- ==============================================================================

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

-- ==============================================================================
-- 7. RECURSION-FREE RLS POLICIES FOR DAILY STATS
-- ==============================================================================

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

-- ==============================================================================
-- 8. RECURSION-FREE RLS POLICIES FOR STUDENT ALERTS
-- ==============================================================================

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

-- ==============================================================================
-- 9. RECURSION-FREE RLS POLICIES FOR LEARNER SKILL SCORES
-- ==============================================================================

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

-- ==============================================================================
-- 10. TEACHER INVITATION ACCESS CONTROL
-- ==============================================================================

ALTER TABLE public.teacher_invitation_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Teacher invitation codes access control" ON public.teacher_invitation_codes;
DROP POLICY IF EXISTS "Admin exclusive teacher invitation access" ON public.teacher_invitation_codes;

CREATE POLICY "Admin exclusive teacher invitation access"
  ON public.teacher_invitation_codes
  FOR ALL
  TO authenticated
  USING (public.is_admin());
