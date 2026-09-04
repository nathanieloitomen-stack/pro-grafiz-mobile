-- PG-005 pgTAP: "No user can change their own role or branch" (Master Spec §8).
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(4);

select tests.build_fixtures();

select tests.authenticate_as(tests.fixture_id('centre_manager_a'));

-- Column-level REVOKE means this isn't just "0 rows visible" (RLS-style
-- silent filtering) — it's an actual Postgres permission error, because
-- `authenticated` was never granted UPDATE on profiles.role at all.
select throws_ok(
  $q$ update profiles set role = 'super_admin' where id = auth.uid() $q$,
  '42501',
  null,
  'A Centre Manager cannot change their own role — blocked at the column-privilege level, not just RLS'
);

select throws_ok(
  $q$ update profiles set branch_id = null where id = auth.uid() $q$,
  '42501',
  null,
  'A Centre Manager cannot change their own branch_id — same column-privilege block'
);

select throws_ok(
  $q$ update profiles set active = false where id = auth.uid() $q$,
  '42501',
  null,
  'A Centre Manager cannot deactivate their own account'
);

-- Contrast: the explicitly granted "safe" columns DO work, proving the
-- errors above are a deliberate narrow allow-list, not a table
-- misconfigured to reject all writes.
select lives_ok(
  $q$ update profiles set full_name = 'Updated Fixture Name' where id = auth.uid() $q$,
  'A staff member CAN update their own full_name — proves the column grant is a narrow allow-list, not a blanket lock'
);

select * from finish();
rollback;
