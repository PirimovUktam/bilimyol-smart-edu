-- ==============================================================================
-- BILIMYO‘L SMART EDU - PRIVILEGED ADMIN PROVISIONING SCRIPT
-- Execute this single command in the Supabase SQL Editor as database owner.
-- ==============================================================================
-- Step 1: Register normally on the BilimYo‘l web app with your email (e.g. your_email@example.com).
-- Step 2: Replace 'YOUR_EMAIL_HERE' below with your registered email and click RUN.
-- ==============================================================================

SELECT public.promote_user_to_admin('YOUR_EMAIL_HERE');
