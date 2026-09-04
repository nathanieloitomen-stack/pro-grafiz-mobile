-- PG-007 pgTAP: pricing_rates / commercial_settings access control,
-- and the quote_requests.quantity constraint.
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(7);

select tests.build_fixtures();

-- Seed one pricing_rates row and one commercial_settings row directly
-- (as the table owner, bypassing RLS) purely to test read access below
-- — this is NOT a claim that these are real rates.
insert into pricing_rates (material_id, finish_id, material_rate_per_sqm_kobo)
select m.id, f.id, 500000
from materials m, finishes f
where m.code = 'TEST-MAT' and f.code = 'TEST-FIN';

insert into commercial_settings (key, value) values ('vat_percent', 7.5);

-- Super Admin and Accountant can read; everyone else gets zero rows.
select tests.authenticate_as(tests.fixture_id('super_admin'));
select is((select count(*) from pricing_rates)::int, 1, 'Super Admin can read pricing_rates');
select is((select count(*) from commercial_settings)::int, 1, 'Super Admin can read commercial_settings');

select tests.authenticate_as(tests.fixture_id('accountant'));
select is((select count(*) from pricing_rates)::int, 1, 'Accountant can read pricing_rates');

select tests.authenticate_as(tests.fixture_id('designer'));
select is((select count(*) from pricing_rates)::int, 0, 'Designer cannot read pricing_rates — not a finance role');

select tests.authenticate_as(tests.fixture_id('customer_1_auth'));
select is((select count(*) from pricing_rates)::int, 0, 'A customer cannot read pricing_rates at all');

-- Only Super Admin can write. RLS denial for a role with normal table
-- grants (no column-level REVOKE here, unlike profiles' role/branch
-- columns) means the row is simply not visible for UPDATE — 0 rows
-- affected, not a thrown permission error. This matches the pattern
-- used for jobs/payments in 30_role_write_restrictions.sql, not the
-- throws_ok pattern used for profiles' column-revoked fields in
-- 40_profiles_self_protection.sql.
select tests.authenticate_as(tests.fixture_id('accountant'));
select is(
  (with updated as (
    update pricing_rates set material_rate_per_sqm_kobo = 1 returning 1
  ) select count(*) from updated)::int,
  0,
  'Accountant can read pricing_rates but cannot write it — only Super Admin can'
);

-- quantity defaults to 1 and rejects non-positive values.
select tests.authenticate_as(tests.fixture_id('centre_manager_a'));
select throws_ok(
  $q$ update quote_requests set quantity = 0 $q$,
  '23514',
  null,
  'quote_requests.quantity rejects a non-positive value (check constraint)'
);

select * from finish();
rollback;
