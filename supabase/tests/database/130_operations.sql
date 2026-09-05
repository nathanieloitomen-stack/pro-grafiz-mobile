-- PG-012 pgTAP: operations security regression guarantees. The actual
-- authority logic (Centre Manager own-branch / Super Admin only, per
-- _shared/staff_auth.ts) lives in TypeScript and cannot be tested via
-- pgTAP — same limitation as every prior task's service-role
-- functions. What's tested here is that the RLS foundation those four
-- new functions (hold/resume/cancel/reopen-job) and the newly-audited
-- decide-quote-request depend on remains exactly as PG-005 left it.
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(5);

select tests.build_fixtures();

-- Regression: jobs still has zero write policies for ANY role,
-- including Super Admin — hold-job/resume-job/cancel-job/reopen-job all
-- depend on this remaining the only path (via service-role).
select tests.authenticate_as(tests.fixture_id('super_admin'));
select is(
  (with updated as (
    update jobs set status = 'on_hold', hold_reason = 'test' where id = tests.fixture_id('job_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Even Super Admin cannot set a job on hold directly — hold-job remains the only path'
);

select tests.authenticate_as(tests.fixture_id('centre_manager_a'));
select is(
  (with updated as (
    update jobs set status = 'cancelled', cancel_reason = 'test' where id = tests.fixture_id('job_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Centre Manager A cannot cancel a job directly, even at their own branch — cancel-job remains the only path'
);

-- Regression: audit_events still has zero write policies for any
-- role — hold-job/resume-job/cancel-job/reopen-job/decide-quote-request
-- (PG-012) all depend on this remaining the only path (service-role).
select is(
  (with inserted as (
    insert into audit_events (actor_user_id, action, entity_type, entity_id)
    values (tests.fixture_id('centre_manager_a'), 'job.hold', 'job', tests.fixture_id('job_1'))
    returning 1
  ) select count(*) from inserted)::int,
  0,
  'Centre Manager A cannot write audit_events directly — every operational function''s service-role insert remains the only path'
);

select tests.authenticate_as(tests.fixture_id('super_admin'));
select is(
  (with inserted as (
    insert into audit_events (actor_user_id, action, entity_type, entity_id)
    values (tests.fixture_id('super_admin'), 'job.hold', 'job', tests.fixture_id('job_1'))
    returning 1
  ) select count(*) from inserted)::int,
  0,
  'Even Super Admin cannot write audit_events directly'
);

-- Regression: quote_requests still only allows staff decision-updates
-- per the exact branch-scoped rule from PG-005 (decide-quote-request
-- mirrors this, doesn't loosen it).
select tests.authenticate_as(tests.fixture_id('centre_manager_b'));
select is(
  (with updated as (
    update quote_requests set status = 'accepted'
    where id = (select id from quote_requests where customer_id = tests.fixture_id('customer_1'))
    returning 1
  ) select count(*) from updated)::int,
  0,
  'Centre Manager B (wrong branch) still cannot decide customer 1''s quote_request — unchanged from PG-005'
);

select * from finish();
rollback;
