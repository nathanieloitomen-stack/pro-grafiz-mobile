-- PG-005 pgTAP: "Failed CAD check blocks release" (CLAUDE.md CAD RULES).
-- Tests the enforce_draft_release_gate() trigger from
-- 20260904000020_rls_drafts_and_cad.sql, not RLS policies directly —
-- included here because it's the concrete DB-level backing for one of
-- CLAUDE.md's named negative tests.
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(2);

select tests.build_fixtures();

-- draft_1 has one draft_checks row with result = 'fail' (thickness_floor).
select tests.authenticate_as(tests.fixture_id('designer'));

select throws_like(
  $q$ update drafts set release_status = 'released' where id = tests.fixture_id('draft_1') $q$,
  '%release is blocked%',
  'A draft with a failing mandatory check cannot be released without an override_reason'
);

select lives_ok(
  $q$ update drafts set release_status = 'released', override_reason = 'Manually verified acceptable by senior designer' where id = tests.fixture_id('draft_1') $q$,
  'The same draft CAN be released once a designer provides an override_reason'
);

select * from finish();
rollback;
