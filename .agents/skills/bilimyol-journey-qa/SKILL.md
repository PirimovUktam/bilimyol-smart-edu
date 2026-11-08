---
name: bilimyol-journey-qa
description: Verify BilimYo‘l learner journeys after changes to authentication, subject switching, onboarding, lesson progress, or Yo‘lchi AI in this repository.
---

Check the working tree, the deployed version, and the database migration history separately. The deployed clients may use an earlier schema even when the local clients and tests pass. Test unreleased clients against disposable Supabase with the matching migrations, seed data, and mail catcher. The setup and test entry points are in [Supabase tests](../../../supabase/tests/README.md).

Use `npm run test:e2e` to check browser navigation in explicit demo mode. Use `npm run test:e2e:supabase` to check real login, persistence, scoring, and isolation against loopback services. For changes to native flows, run the corresponding Flutter test and use `mobile/test/integration/local_supabase_test.dart` when the disposable backend and mailbox are running. Demo scoring and AI replies do not verify the hosted services.

When checking a lesson, confirm the actual course on the selected subject, path, lesson, and returned progress. Browser reading checkpoints must not stand in for answers or completion. Open and close contextual AI help before submitting an exercise to catch accidental lesson remounts. For new layout changes, capture matched mobile and desktop views and check those images before reporting the result.
