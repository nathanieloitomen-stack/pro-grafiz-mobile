-- PG-009 pgTAP: payment security regression guarantees and RLS
-- visibility. Most of PG-009's actual logic (fresh-challenge
-- verification, the accept/decline-style state checks) lives in
-- create-payment-request/triage-payment/confirm-payment (TypeScript,
-- service-role) — not expressible as pgTAP against RLS, for the same
-- reason as PG-008's Edge Functions. What's tested here is that the
-- RLS foundation those functions depend on remains exactly as PG-005
-- left it.
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(6);

select tests.build_fixtures();

-- Regression guarantee: payments still has zero write policies for
-- ANY role, including Accountant and Super Admin — confirm-payment and
-- triage-payment both rely on this remaining the ONLY path to change a
-- payment's status.
select tests.authenticate_as(tests.fixture_id('accountant'));
select is(
  (with updated as (
    update payments set status = 'confirmed', confirmed_by = tests.fixture_id('accountant'), confirmed_at = now()
    where id = tests.fixture_id('payment_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Accountant still cannot update payments directly — confirm-payment remains the only path'
);

select tests.authenticate_as(tests.fixture_id('super_admin'));
select is(
  (with updated as (
    update payments set status = 'matched' where id = tests.fixture_id('payment_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Even Super Admin cannot update payments directly'
);

-- Visibility: Accountant and Super Admin see the fixture payment;
-- Designer does not (payments RLS is deliberately narrower than the
-- general central-staff pattern — see 20260904000021_rls_payments.sql).
select tests.authenticate_as(tests.fixture_id('accountant'));
select is((select count(*) from payments where id = tests.fixture_id('payment_1'))::int, 1, 'Accountant can see the fixture payment');

select tests.authenticate_as(tests.fixture_id('designer'));
select is((select count(*) from payments where id = tests.fixture_id('payment_1'))::int, 0, 'Designer cannot see any payment — not a finance role');

-- Centre Manager sees payments on jobs at their own branch only.
select tests.authenticate_as(tests.fixture_id('centre_manager_a'));
select is((select count(*) from payments where id = tests.fixture_id('payment_1'))::int, 1, 'Centre Manager A sees the payment on job_1 (their own branch)');

select tests.authenticate_as(tests.fixture_id('centre_manager_b'));
select is((select count(*) from payments where id = tests.fixture_id('payment_1'))::int, 0, 'Centre Manager B cannot see a payment on branch A''s job');

select * from finish();
rollback;
