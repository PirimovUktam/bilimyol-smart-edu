# Local persistence and access-control regressions

Run these SQL files **only on a disposable local Supabase database**, after all
migrations have been applied. Do not point the commands at production. Fixtures
use reserved test IDs and `example.invalid` emails; each script rolls back its
transaction. `ON_ERROR_STOP` is required so a failed assertion fails the check.

## Prerequisites

- Docker and Supabase CLI for the local Supabase stack.
- `psql` for plain PostgreSQL assertions; pgTAP is not required.
- `LOCAL_DB_URL` pointing to that disposable database, using a database owner
  connection able to insert Auth fixtures and `SET ROLE` for the API roles.

From the repository root, start the local stack and apply pending migrations:

```bash
supabase start
supabase migration up --local
supabase db lint --local --level error --fail-on error
psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/profile_bootstrap_regression.sql
psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/p1_persistence_regression.sql
```

If the database has already applied a different version of one of these
migrations, merely editing that migration does not update it. Rebuild a
**disposable** database from the complete migration chain before testing. A
non-disposable deployment needs a separately reviewed forward migration, not
an automatic reset.

## What is covered

- Signup trigger creates authoritative student, learner and gamification rows;
  privileged signup metadata cannot assign an administrator role.
- Existing profiles accept safe-column updates; conflict-ignore provisioning
  preserves identity; direct role and identity updates remain forbidden.
- Learner JSON is recursively sanitized; admin content is role-gated; read views
  are not a writable bypass. Catalogue, profile and settings reads have explicit
  API-role privileges rather than depending on default `GRANT ALL`.
- Placement validation, atomic persistence, idempotency, score read-back,
  fixed XP, reinforcement score preservation, lesson completion and parent
  consent boundaries.
- Service-role question/generated-content access needed by Edge persistence,
  with client-derived writes and anonymous profile access still forbidden.

Also verify the migration chain in both legacy-default-grant and default-revoked
environments when changing privileges. PostgreSQL-WASM can help verify SQL in
isolation, but Auth must be stubbed there: passing it does **not** prove real
Supabase Auth, PostgREST, Edge HTTP behavior, or concurrent transaction safety.

## Related application checks

```bash
npm test -- --run
npx tsc -p tsconfig.app.json --noEmit
npm run build
npm run lint
deno check supabase/functions/yolchi-tutor/index.ts
```

From `mobile/`:

```bash
flutter analyze
flutter test
```

The auth action tests use the real provider's public actions via server-side
rendering; startup effects and mounted browser auth-event races still need a
browser smoke check. Lesson-session tests use controlled asynchronous repository
boundaries to verify stale responses, completion prerequisites and retries.
