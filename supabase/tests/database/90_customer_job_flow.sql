-- PG-008 pgTAP: regression guarantees the new Edge Functions depend on,
-- plus the one genuinely new RLS-testable path (customer-authored
-- design_revisions).
--
-- Most of PG-008's actual logic (stage-transition validity, the
-- accept/decline state machine) lives in decide-quote-request and
-- respond-to-design (TypeScript, service-role) — not expressible as
-- pgTAP against RLS, since jobs/quotes still have zero client write
-- policies BY DESIGN (PG-005). What's tested here is that this
-- remains true: if a future migration accidentally added a jobs or
-- quotes write policy, both Edge Functions' security model (and this
-- comment's claim) would silently become wrong.
--
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(4);

select tests.build_fixtures();

-- Regression guarantee: jobs still has no write policy for anyone,
-- including Super Admin — decide-quote-request and respond-to-design
-- both rely on this remaining the ONLY way a job is created or
-- advanced.
select tests.authenticate_as(tests.fixture_id('super_admin'));
select is(
  (with updated as (
    update jobs set current_stage = 'IN_PRODUCTION' where id = tests.fixture_id('job_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'jobs still has zero write policies for any role — decide-quote-request/respond-to-design remain the only path'
);

-- Regression guarantee: quotes still has no write policy for anyone.
select is(
  (with updated as (
    update quotes set total_kobo = 1 where id = tests.fixture_id('quote_1') returning 1
  ) select count(*) from updated)::int,
  0,
  'quotes still has zero write policies for any role — decide-quote-request/issue-quote remain the only path'
);

-- New, genuinely RLS-testable path: a customer requesting a design
-- change on their own job.
select tests.authenticate_as(tests.fixture_id('customer_1_auth'));
select lives_ok(
  $q$ insert into design_revisions (job_id, revision_no, request_note, requested_by)
      values ((select id from tests.fixture_ids where key = 'job_1'), 1, 'Please make the border thicker', null) $q$,
  'Customer 1 can request a design change on their own job (requested_by null, per the PG-003 attribution gap)'
);

select tests.authenticate_as(tests.fixture_id('customer_2_auth'));
select throws_ok(
  $q$ insert into design_revisions (job_id, revision_no, request_note, requested_by)
      values (
        (select id from tests.fixture_ids where key = 'job_1'), 2,
        'Trying to edit someone else''s job', null
      ) $q$,
  '42501',
  null,
  'Customer 2 cannot request a design change on customer 1''s job — the WITH CHECK requires ownership, enforced by RLS itself, not a pre-filter in this test'
);

select * from finish();
rollback;
