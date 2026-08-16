-- BilimYo‘l Smart Edu - Initial PostgreSQL Schema with RLS
-- Migration: 20260816000001_initial_schema.sql

-- 1. PROFILES
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. COURSES
CREATE TABLE IF NOT EXISTS public.courses (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  icon_name TEXT NOT NULL,
  primary_color_hex TEXT NOT NULL,
  secondary_color_hex TEXT NOT NULL,
  total_students_estimate INT NOT NULL DEFAULT 1000,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. SKILLS
CREATE TABLE IF NOT EXISTS public.skills (
  id TEXT PRIMARY KEY,
  course_id TEXT NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT NOT NULL,
  description TEXT NOT NULL,
  order_index INT NOT NULL,
  icon_name TEXT NOT NULL
);

-- 4. QUESTIONS
CREATE TABLE IF NOT EXISTS public.questions (
  id TEXT PRIMARY KEY,
  course_id TEXT NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  skill_id TEXT NOT NULL REFERENCES public.skills(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  context_snippet TEXT,
  options JSONB NOT NULL,
  correct_index INT NOT NULL,
  difficulty TEXT NOT NULL,
  explanation TEXT NOT NULL,
  formula_latex TEXT,
  audio_sim_text TEXT,
  audio_sim_speaker TEXT,
  is_placement BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. LEARNER PROFILES
CREATE TABLE IF NOT EXISTS public.learner_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  selected_course_id TEXT REFERENCES public.courses(id),
  goal TEXT NOT NULL DEFAULT 'mastery',
  daily_minutes INT NOT NULL DEFAULT 15,
  initial_level TEXT NOT NULL DEFAULT 'intermediate',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. LEARNER SKILL SCORES
CREATE TABLE IF NOT EXISTS public.learner_skill_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  course_id TEXT NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  skill_id TEXT NOT NULL REFERENCES public.skills(id) ON DELETE CASCADE,
  score INT NOT NULL CHECK (score >= 0 AND score <= 100),
  mastery_level TEXT NOT NULL,
  is_weakest_focus BOOLEAN NOT NULL DEFAULT false,
  confidence NUMERIC(3,2) NOT NULL DEFAULT 0.85,
  attempt_count INT NOT NULL DEFAULT 1,
  last_updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_learner_course_skill UNIQUE(user_id, course_id, skill_id)
);

-- 7. PLACEMENT ATTEMPTS
CREATE TABLE IF NOT EXISTS public.placement_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  course_id TEXT NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  score INT NOT NULL,
  weakest_skill_id TEXT REFERENCES public.skills(id),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. PLACEMENT ANSWERS
CREATE TABLE IF NOT EXISTS public.placement_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id UUID NOT NULL REFERENCES public.placement_attempts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  question_id TEXT NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
  selected_index INT NOT NULL,
  is_correct BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. ROADMAP NODES
CREATE TABLE IF NOT EXISTS public.roadmap_nodes (
  id TEXT PRIMARY KEY,
  course_id TEXT NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  skill_id TEXT NOT NULL REFERENCES public.skills(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  prerequisites JSONB NOT NULL DEFAULT '[]',
  required_score INT NOT NULL DEFAULT 50,
  is_reinforcement BOOLEAN NOT NULL DEFAULT false,
  target_lesson_id TEXT,
  estimated_minutes INT NOT NULL DEFAULT 15,
  order_index NUMERIC(4,1) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true
);

-- 10. LESSON PROGRESS
CREATE TABLE IF NOT EXISTS public.lesson_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id TEXT NOT NULL,
  course_id TEXT NOT NULL REFERENCES public.courses(id),
  status TEXT NOT NULL DEFAULT 'in_progress',
  progress_percent INT NOT NULL DEFAULT 0,
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_user_lesson UNIQUE(user_id, lesson_id)
);

-- 11. LESSON ATTEMPTS
CREATE TABLE IF NOT EXISTS public.lesson_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id TEXT NOT NULL,
  step_number INT NOT NULL,
  time_spent_seconds INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 12. ANSWER ATTEMPTS
CREATE TABLE IF NOT EXISTS public.answer_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id TEXT NOT NULL,
  question_id TEXT NOT NULL,
  selected_index INT NOT NULL,
  selected_answer TEXT NOT NULL,
  is_correct BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 13. AI RECOMMENDATIONS
CREATE TABLE IF NOT EXISTS public.ai_recommendations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  course_id TEXT NOT NULL REFERENCES public.courses(id),
  skill_id TEXT NOT NULL REFERENCES public.skills(id),
  title TEXT NOT NULL,
  reason TEXT NOT NULL,
  recommendation JSONB NOT NULL,
  ai_generated BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 14. REINFORCEMENT ATTEMPTS
CREATE TABLE IF NOT EXISTS public.reinforcement_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  course_id TEXT NOT NULL REFERENCES public.courses(id),
  skill_id TEXT NOT NULL REFERENCES public.skills(id),
  reinforcement_node_id TEXT NOT NULL,
  before_score INT NOT NULL,
  after_score INT NOT NULL,
  is_correct BOOLEAN NOT NULL,
  xp_awarded INT NOT NULL DEFAULT 30,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_user_reinforcement UNIQUE(user_id, reinforcement_node_id)
);

-- 15. GAMIFICATION PROFILES
CREATE TABLE IF NOT EXISTS public.gamification_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  xp INT NOT NULL DEFAULT 0,
  streak_days INT NOT NULL DEFAULT 0,
  last_activity_date DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 16. DAILY ACTIVITY
CREATE TABLE IF NOT EXISTS public.daily_activity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_date DATE NOT NULL,
  xp_earned INT NOT NULL DEFAULT 0,
  lessons_completed INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_user_activity_date UNIQUE(user_id, activity_date)
);

-- 17. USER PREFERENCES
CREATE TABLE IF NOT EXISTS public.user_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  dark_mode BOOLEAN NOT NULL DEFAULT false,
  notifications_enabled BOOLEAN NOT NULL DEFAULT true,
  language TEXT NOT NULL DEFAULT 'uz',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learner_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learner_skill_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.placement_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.placement_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roadmap_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.answer_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reinforcement_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gamification_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

-- Public read-only tables for active learners
CREATE POLICY "Allow public read on courses" ON public.courses FOR SELECT USING (is_active = true);
CREATE POLICY "Allow public read on skills" ON public.skills FOR SELECT USING (true);
CREATE POLICY "Allow public read on questions" ON public.questions FOR SELECT USING (true);
CREATE POLICY "Allow public read on roadmap_nodes" ON public.roadmap_nodes FOR SELECT USING (is_active = true);

-- User-isolated policies
CREATE POLICY "User can read own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "User can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "User can CRUD own learner profile" ON public.learner_profiles FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "User can CRUD own skill scores" ON public.learner_skill_scores FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "User can CRUD own placement attempts" ON public.placement_attempts FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "User can CRUD own placement answers" ON public.placement_answers FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "User can CRUD own lesson progress" ON public.lesson_progress FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "User can CRUD own lesson attempts" ON public.lesson_attempts FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "User can CRUD own answer attempts" ON public.answer_attempts FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "User can CRUD own AI recommendations" ON public.ai_recommendations FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "User can CRUD own reinforcement attempts" ON public.reinforcement_attempts FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "User can CRUD own gamification profile" ON public.gamification_profiles FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "User can CRUD own daily activity" ON public.daily_activity FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "User can CRUD own preferences" ON public.user_preferences FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- AUTH USER TRIGGER (Automatic profile & gamification creation)
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, first_name, last_name, email, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'first_name', 'O‘quvchi'),
    COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
    NEW.email,
    NEW.raw_user_meta_data->>'avatar_url'
  );

  INSERT INTO public.learner_profiles (user_id, selected_course_id, goal, daily_minutes, initial_level)
  VALUES (NEW.id, 'course_math_01', 'mastery', 15, 'intermediate');

  INSERT INTO public.gamification_profiles (user_id, xp, streak_days, last_activity_date)
  VALUES (NEW.id, 0, 1, CURRENT_DATE);

  INSERT INTO public.user_preferences (user_id, dark_mode, notifications_enabled, language)
  VALUES (NEW.id, false, true, 'uz');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
