-- PG-015 pgTAP: regression guarantees for the RLS foundation the three
-- new transition functions (mark-ready-for-dispatch, dispatch-job,
-- release-job) depend on. No new migration was added in PG-015 — these
-- confirm nothing was weakened, not that anything new was added.
--
-- The actual PG-015 logic (role/branch checks, the atomic
-- compare-and-swap preventing double-advancement or stage-skipping,
-- balance enforcement) lives entirely in TypeScript and cannot be
-- exercised via pgTAP — same limitation stated in every prior task.
-- Positive/negative cases 1-14 from the task brief require live
-- Supabase + Deno function execution; none were run here.
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(5);

select tests.build_fixtures();

-- Regression: jobs still has zero write policies for any role,
-- including Super Admin — this is the entire reason all three new
-- PG-015 functions must use service-role, and why no client can skip a
-- stage or double-advance a job by writing current_stage directly.
select tests.authenticate_as(tests.fixture_id('super_admin'));
select is(
  (with updated as (
    update jobs set current_stage = 'RELEASED' where id = tests.fixture_id('job_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Even Super Admin cannot set a job to RELEASED directly — release-job remains the only path'
);

select is(
  (with updated as (
    update jobs set current_stage = 'DISPATCHED' where id = tests.fixture_id('job_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'No role can skip directly to DISPATCHED via a raw UPDATE — confirms stage-skipping is impossible at the RLS layer regardless of the atomic-update logic in the Edge Functions'
);

-- Regression: audit_events still has zero write policies — all three
-- new functions depend on this remaining the only path for their audit
-- rows too.
select is(
  (with inserted as (
    insert into audit_events (actor_user_id, action, entity_type, entity_id)
    values (tests.fixture_id('super_admin'), 'job.release', 'job', tests.fixture_id('job_1'))
    returning 1
  ) select count(*) from inserted)::int,
  0,
  'audit_events still has zero write policies for any role — unchanged by PG-015'
);

-- Sanity check on the schema release-job's balance check depends on:
-- quotes.balance_kobo and payments.kind/status are queryable exactly as
-- assumed (this doesn't test the Edge Function logic, only that the
-- columns it reads exist and behave as expected under normal RLS read
-- access for a role authorized to see them).
select tests.authenticate_as(tests.fixture_id('accountant'));
select is(
  (select balance_kobo >= 0 from quotes where id = tests.fixture_id('quote_1'))::boolean,
  true,
  'quotes.balance_kobo is readable and non-null for the fixture quote, as release-job assumes'
);

select tests.authenticate_as(tests.fixture_id('centre_manager_a'));
select is(
  (select count(*) from payments where job_id = tests.fixture_id('job_1') and kind = 'deposit')::int,
  1,
  'payments.kind is queryable as release-job assumes (fixture has one deposit payment)'
);

select * from finish();
rollback;
