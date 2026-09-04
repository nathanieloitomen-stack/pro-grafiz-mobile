-- PG-005 pgTAP: DXF/hash column protection.
-- "Customer cannot access private DXF without authorization"
-- (CLAUDE.md negative test list).
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(5);

select tests.build_fixtures();

-- drafts.dxf_path is column-revoked from everyone, staff included —
-- see 20260904000020_rls_drafts_and_cad.sql for why.
select tests.authenticate_as(tests.fixture_id('designer'));
select throws_ok(
  $q$ select dxf_path from drafts where id = tests.fixture_id('draft_1') $q$,
  '42501',
  null,
  'Even a Designer cannot select drafts.dxf_path directly — must go through staff_get_draft_dxf_path()'
);

select lives_ok(
  $q$ select staff_get_draft_dxf_path(tests.fixture_id('draft_1')) $q$,
  'A Designer CAN fetch the DXF path via the authorized function'
);

select tests.authenticate_as(tests.fixture_id('customer_1_auth'));
select throws_like(
  $q$ select staff_get_draft_dxf_path(tests.fixture_id('draft_1')) $q$,
  '%Not authorized%',
  'A customer cannot fetch a draft''s DXF path even via the function — it checks the caller''s role, not just column privilege'
);

-- dxf_release_grants.release_code_hash is column-revoked from
-- everyone; column-privilege errors fire regardless of whether any row
-- would actually match, so no fixture row is needed for this check.
select tests.authenticate_as(tests.fixture_id('super_admin'));
select throws_ok(
  $q$ select release_code_hash from dxf_release_grants limit 1 $q$,
  '42501',
  null,
  'Even Super Admin cannot select dxf_release_grants.release_code_hash directly — nothing reads it except internal verification logic'
);

-- pattern_assets: a DXF-type row should not even be visible as a row
-- (not just a hidden column) to a customer — this is the row-level
-- exclusion described in 20260904000016_rls_reference_and_catalogue.sql.
select tests.authenticate_as(tests.fixture_id('customer_1_auth'));
select is(
  (select count(*) from pattern_assets where asset_type = 'dxf')::int,
  0,
  'A customer sees zero pattern_assets rows of type dxf, regardless of production_ready status'
);

select * from finish();
rollback;
