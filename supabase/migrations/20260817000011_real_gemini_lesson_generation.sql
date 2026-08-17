-- ==============================================================================
-- BILIMYO‘L SMART EDU - MIGRATION 20260817000011
-- File: supabase/migrations/20260817000011_real_gemini_lesson_generation.sql
--
-- REAL GEMINI LESSON GENERATION & CACHING PERSISTENCE
-- 1. Creates generated_lessons table for caching AI-generated lesson materials.
-- 2. Enables RLS and establishes secure read/write policies.
-- 3. Adds compound index for fast cache hits on topic, skill, and difficulty.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.generated_lessons (
  id TEXT PRIMARY KEY,
  course_id TEXT NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  skill_id TEXT NOT NULL REFERENCES public.skills(id) ON DELETE CASCADE,
  topic TEXT NOT NULL,
  level TEXT NOT NULL DEFAULT 'intermediate',
  difficulty TEXT NOT NULL DEFAULT 'medium',
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  objective TEXT NOT NULL,
  estimated_minutes INT NOT NULL DEFAULT 15,
  steps JSONB NOT NULL DEFAULT '[]',
  questions JSONB NOT NULL DEFAULT '[]',
  generation_model TEXT NOT NULL DEFAULT 'gemini-3.6-flash',
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Fast caching lookup index
CREATE INDEX IF NOT EXISTS idx_gen_lessons_cache_lookup 
  ON public.generated_lessons(course_id, skill_id, topic, level, difficulty);

-- Enable RLS
ALTER TABLE public.generated_lessons ENABLE ROW LEVEL SECURITY;

-- 1. Authenticated users can view generated lessons
DROP POLICY IF EXISTS "Authenticated users can read generated lessons" ON public.generated_lessons;
CREATE POLICY "Authenticated users can read generated lessons"
  ON public.generated_lessons
  FOR SELECT
  TO authenticated
  USING (true);

-- 2. Authenticated users or Service Role can insert generated lessons
DROP POLICY IF EXISTS "Authenticated users can create generated lessons" ON public.generated_lessons;
CREATE POLICY "Authenticated users can create generated lessons"
  ON public.generated_lessons
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

-- 3. Admins can manage all generated lessons
DROP POLICY IF EXISTS "Admins can manage generated lessons" ON public.generated_lessons;
CREATE POLICY "Admins can manage generated lessons"
  ON public.generated_lessons
  FOR ALL
  TO authenticated
  USING (public.is_admin());
