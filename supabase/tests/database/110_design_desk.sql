-- PG-010 pgTAP: Design Desk RLS regressions and the staff_get_draft_dxf_path()
-- refinement (Production role requires a released draft; Designer/Super
-- Admin unchanged). Job-stage transitions (start-design, release-draft)
-- live in Edge Functions and cannot be tested via pgTAP — same
-- limitation as every prior task's service-role functions.
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(7);

select tests.build_fixtures();

-- Regression: jobs still has zero write policies — start-design and
-- release-draft both depend on this remaining the only path.
select tests.authenticate_as(tests.fixture_id('designer'));
select is(
  (with updated as (
    update jobs set current_stage = 'DESIGN_IN_PROGRESS' where id = tests.fixture_id('job_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Designer still cannot advance a job''s stage directly — start-design remains the only path'
);

-- Regression: a Designer CAN write drafts/draft_checks directly (no
-- Edge Function needed for these two, per docs/design-desk.md).
select lives_ok(
  $q$ update drafts set preview_path = 'preview/test/updated.png' where id = tests.fixture_id('draft_1') $q$,
  'A Designer can update a draft directly via RLS (drafts_write_designer_or_super_admin)'
);

-- A Centre Manager cannot write drafts at all.
select tests.authenticate_as(tests.fixture_id('centre_manager_a'));
select is(
  (with updated as (
    update drafts set preview_path = 'preview/test/hacked.png' where id = tests.fixture_id('draft_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Centre Manager cannot write drafts — Designer/Super Admin only, per PG-005, unchanged'
);

-- staff_get_draft_dxf_path(): the fixture draft has a fail-result check
-- and release_status defaults to 'pending' (not released).
select tests.authenticate_as(tests.fixture_id('designer'));
select lives_ok(
  $q$ select staff_get_draft_dxf_path(tests.fixture_id('draft_1')) $q$,
  'A Designer can fetch a pre-release draft''s DXF path — needed to do the review work itself'
);

select tests.authenticate_as(tests.fixture_id('production'));
select throws_like(
  $q$ select staff_get_draft_dxf_path(tests.fixture_id('draft_1')) $q$,
  '%has not been released%',
  'PG-010 refinement: Production cannot fetch an unreleased draft''s DXF path — only Designer/Super Admin may, until release'
);

-- Once released, Production CAN fetch it — set release_status directly
-- as table owner (bypassing RLS/trigger here on purpose: this test is
-- about the function's role/status check, not the release gate trigger,
-- which is already covered in PG-005's own test suite).
select tests.clear_authentication();
update drafts set release_status = 'released', override_reason = 'test fixture override' where id = tests.fixture_id('draft_1');

select tests.authenticate_as(tests.fixture_id('production'));
select lives_ok(
  $q$ select staff_get_draft_dxf_path(tests.fixture_id('draft_1')) $q$,
  'Once released, Production CAN fetch the draft''s DXF path'
);

select tests.authenticate_as(tests.fixture_id('customer_1_auth'));
select throws_ok(
  $q$ select staff_get_draft_dxf_path(tests.fixture_id('draft_1')) $q$,
  'P0001',
  null,
  'A customer can never fetch a draft''s DXF path, released or not'
);

select * from finish();
rollback;
