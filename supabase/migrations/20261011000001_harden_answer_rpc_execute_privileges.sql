-- BilimYo‘l Smart Edu: harden answer scoring RPC execution privileges.
-- PostgreSQL grants EXECUTE on newly-created functions to PUBLIC by default.
-- Revoke that implicit privilege so anonymous callers cannot submit scoring attempts.
-- Authenticated users and the trusted service_role retain the explicitly required access.

BEGIN;

REVOKE ALL PRIVILEGES
  ON FUNCTION public.submit_answer_attempt(UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT)
  FROM PUBLIC, anon;

GRANT EXECUTE
  ON FUNCTION public.submit_answer_attempt(UUID, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT)
  TO authenticated, service_role;

COMMIT;
