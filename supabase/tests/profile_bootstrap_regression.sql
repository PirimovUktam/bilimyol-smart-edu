-- Disposable/local PostgreSQL only, after all migrations. Fixtures roll back.
BEGIN;
CREATE FUNCTION pg_temp.assert_profile(value BOOLEAN, message TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF value IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %', message; END IF;
END;
$$;

INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES (
  '00000000-0000-0000-0000-000000000201', 'profile-test@example.invalid',
  '{"first_name":"Ali","last_name":"Valiyev","role":"admin"}'
);
SELECT pg_temp.assert_profile((SELECT role = 'student' AND first_name = 'Ali'
  FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000201'),
  'signup creates authoritative student profile, ignoring role metadata');
SELECT pg_temp.assert_profile((SELECT count(*) = 1 FROM public.gamification_profiles
  WHERE user_id = '00000000-0000-0000-0000-000000000201'),
  'signup creates gamification row without a swallowed schema error');
SELECT pg_temp.assert_profile((SELECT count(*) = 1 FROM public.learner_profiles
  WHERE user_id = '00000000-0000-0000-0000-000000000201'), 'signup creates learner row');

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);
SET LOCAL ROLE authenticated;
-- The clients use safe UPDATE for an existing profile, never upsert id/email.
UPDATE public.profiles SET first_name = 'Vali', last_name = 'Aliyev',
  display_name = 'Vali Aliyev', avatar_url = '', updated_at = now()
WHERE id = auth.uid();
SELECT pg_temp.assert_profile((SELECT first_name = 'Vali' AND role = 'student'
  FROM public.profiles WHERE id = auth.uid()), 'safe profile update succeeds without role escalation');
-- Concurrent self-provisioning may lose to the signup trigger; DO NOTHING
-- must preserve the existing identity and require no forbidden UPDATE grant.
INSERT INTO public.profiles (id, first_name, last_name, display_name, email)
VALUES (auth.uid(), 'stale', '', 'stale', 'profile-test@example.invalid')
ON CONFLICT (id) DO NOTHING;
SELECT pg_temp.assert_profile((SELECT first_name = 'Vali' FROM public.profiles WHERE id = auth.uid()),
  'idempotent provisioning preserves existing profile');
DO $$ BEGIN
  BEGIN
    UPDATE public.profiles SET role = 'admin' WHERE id = auth.uid();
    RAISE EXCEPTION 'ASSERT: role update accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END; $$;
RESET ROLE;
ROLLBACK;
