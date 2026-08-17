-- ==============================================================================
-- BILIMYO‘L SMART EDU - PRODUCTION SCHEMA DIAGNOSTIC SCRIPT
-- Run this in Supabase SQL Editor to inspect your existing database tables & columns
-- ==============================================================================

-- 1. Check existing columns in public.profiles
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles'
ORDER BY ordinal_position;

-- 2. Check existing public tables
SELECT 
  table_name 
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY table_name;

-- 3. Check existing functions / RPCs
SELECT 
  routine_name, 
  routine_type, 
  security_type
FROM information_schema.routines
WHERE routine_schema = 'public'
ORDER BY routine_name;
