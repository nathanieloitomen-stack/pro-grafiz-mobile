-- PG-017 pgTAP: regression guarantees for the RLS foundation the nine
-- remediated functions depend on, plus a schema sanity check for the
-- new audit_events action values. The actual concurrency fix (atomic
-- compare-and-swap under a genuine simultaneous request) and the
-- audit-event content cannot be exercised via pgTAP — that requires two
-- real, concurrent HTTP calls against a live Supabase project and Deno
-- runtime, neither of which is available in this environment. This file
-- proves nothing about the race itself; it proves the fix didn't
-- accidentally weaken anything it depends on.
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header and
-- docs/pg017-concurrency-audit-remediation.md for the exact live
-- concurrency test procedure.
begin;
select plan(6);

select tests.build_fixtures();

-- Regression: jobs still has zero write policies for any role — every
-- one of the nine remediated functions' atomic UPDATE still depends
-- entirely on this remaining the only path (service-role).
select tests.authenticate_as(tests.fixture_id('super_admin'));
select is(
  (with updated as (
    update jobs set current_stage = 'DESIGN_IN_PROGRESS' where id = tests.fixture_id('job_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Even Super Admin cannot write current_stage directly — PG-017''s atomic updates still rely entirely on service-role being the only path'
);

-- Regression: payments still has zero write policies — confirm-payment's
-- new atomic compare-and-swap and its new audit_events insert both still
-- depend on this.
select is(
  (with updated as (
    update payments set status = 'confirmed' where job_id = tests.fixture_id('job_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Even Super Admin cannot confirm a payment directly — confirm-payment remains the only path'
);

-- Regression: quote_requests still only allows the exact staff
-- write rule from PG-005 — decide-quote-request's new atomic claim
-- doesn't loosen this.
select tests.authenticate_as(tests.fixture_id('centre_manager_b'));
select is(
  (with updated as (
    update quote_requests set status = 'accepted'
    where id = (select id from quote_requests where customer_id = tests.fixture_id('customer_1'))
    returning 1
  ) select count(*) from updated)::int,
  0,
  'Centre Manager B (wrong branch) still cannot claim customer 1''s quote_request directly — unchanged from PG-005'
);

-- Regression: drafts still only allows Designer/Super Admin writes —
-- release-draft's new atomic .neq('release_status','released') guard
-- doesn't loosen this.
select tests.authenticate_as(tests.fixture_id('centre_manager_a'));
select is(
  (with updated as (
    update drafts set release_status = 'released' where id = tests.fixture_id('draft_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'Centre Manager A still cannot release a draft directly — unchanged from PG-005'
);

-- Regression: audit_events still has zero write policies for any role
-- — all nine remediated functions' audit inserts (five pre-existing,
-- four newly added by PG-017) depend on this remaining the only path.
select tests.authenticate_as(tests.fixture_id('super_admin'));
select is(
  (with inserted as (
    insert into audit_events (actor_user_id, action, entity_type, entity_id)
    values (tests.fixture_id('super_admin'), 'payment.confirm', 'payment', tests.fixture_id('job_1'))
    returning 1
  ) select count(*) from inserted)::int,
  0,
  'Even Super Admin cannot write audit_events directly — confirm-payment''s new audit insert remains service-role only'
);

-- Schema sanity: audit_events.action is free text (no enum, PG-003) —
-- the five new action values this task introduces
-- (payment.confirm, job.start_design, draft.release,
-- job.approve_design, job.request_design_change) require no migration,
-- confirmed by inserting one as the table owner (bypassing RLS on
-- purpose, to test the COLUMN TYPE, not authorization).
select tests.clear_authentication();
select lives_ok(
  $q$ insert into audit_events (actor_user_id, action, entity_type, entity_id)
      values (tests.fixture_id('super_admin'), 'payment.confirm', 'payment', tests.fixture_id('job_1')) $q$,
  'audit_events.action accepts PG-017''s new action strings with no schema change required'
);

select * from finish();
rollback;
