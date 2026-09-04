-- PG-005 pgTAP: role write restrictions — the CLAUDE.md negative tests.
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(7);

select tests.build_fixtures();

-- "Accountant cannot advance production": jobs has NO update policy for
-- ANY role, so this holds for every staff role, not just accountant —
-- tested here for both accountant and (as the stronger contrast) Super
-- Admin, proving it's a deliberate blanket lock, not an oversight that
-- happens to exclude one role.
select tests.authenticate_as(tests.fixture_id('accountant'));
select is(
  (with updated as (
    update jobs set current_stage = 'PAYMENT_CONFIRMED' where id = tests.fixture_id('job_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Accountant cannot advance a job''s current_stage directly'
);

select tests.authenticate_as(tests.fixture_id('super_admin'));
select is(
  (with updated as (
    update jobs set current_stage = 'PAYMENT_CONFIRMED' where id = tests.fixture_id('job_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Even Super Admin cannot advance a job''s current_stage via direct table UPDATE — only a future service_role transition service can'
);

-- "Designer cannot confirm payments": payments has NO update policy for
-- any role either.
select tests.authenticate_as(tests.fixture_id('designer'));
select is(
  (with updated as (
    update payments set status = 'confirmed', confirmed_by = tests.fixture_id('designer'), confirmed_at = now()
    where id = tests.fixture_id('payment_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Designer cannot confirm a payment directly'
);

select tests.authenticate_as(tests.fixture_id('accountant'));
select is(
  (with updated as (
    update payments set status = 'confirmed', confirmed_by = tests.fixture_id('accountant'), confirmed_at = now()
    where id = tests.fixture_id('payment_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Even the Accountant cannot confirm a payment via direct table UPDATE — the fresh-PIN-challenge requirement can only be enforced by a (not-yet-built) Edge Function, so direct writes are locked for everyone'
);

-- "Client cannot alter authoritative price": quotes has no write policy
-- for any role.
select tests.authenticate_as(tests.fixture_id('super_admin'));
select is(
  (with updated as (
    update quotes set total_kobo = 1 where id = tests.fixture_id('quote_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'No role can alter a quote''s pricing fields via direct table UPDATE'
);

-- Contrast case: quote_requests DOES have a legitimate staff write path
-- (Intake's decide/bill-and-open-job action), scoped to Centre
-- Manager's own branch and central staff — proving the locks above are
-- deliberate per-table decisions, not a blanket "nothing works" bug.
select tests.authenticate_as(tests.fixture_id('customer_1_auth'));
select is(
  (with updated as (
    update quote_requests set status = 'accepted' where id = (select id from quote_requests where customer_id = tests.fixture_id('customer_1'))
    returning 1
  ) select count(*) from updated)::int,
  0,
  'A customer cannot decide their own quote_request (no customer UPDATE policy exists on this table)'
);

select tests.authenticate_as(tests.fixture_id('centre_manager_a'));
select is(
  (with updated as (
    update quote_requests set status = 'accepted' where id = (select id from quote_requests where customer_id = tests.fixture_id('customer_1'))
    returning 1
  ) select count(*) from updated)::int,
  1,
  'Centre Manager A CAN decide a quote_request at their own branch — confirms the write lock elsewhere is deliberate, not a global RLS misconfiguration'
);

select * from finish();
rollback;
