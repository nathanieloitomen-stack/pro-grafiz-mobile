-- PG-011 pgTAP: document security regression guarantees. The actual
-- generation logic (generateDocument(), idempotency-by-event_key,
-- authoritative-data queries) lives in TypeScript (service-role) and
-- cannot be tested via pgTAP — same limitation as every prior task's
-- Edge Functions. What's tested here is that the RLS foundation those
-- functions and get-document-url depend on remains exactly as PG-005
-- left it.
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(5);

select tests.build_fixtures();

-- Regression: documents still has zero write policies for any role.
select tests.authenticate_as(tests.fixture_id('super_admin'));
select is(
  (with inserted as (
    insert into documents (job_id, type, event_key, storage_path)
    values (tests.fixture_id('job_1'), 'PGJO', 'test-event-key', 'pgjo/test.html')
    returning 1
  ) select count(*) from inserted)::int,
  0,
  'Even Super Admin cannot insert a document directly — generateDocument()''s service-role path remains the only way'
);

-- Seed one document directly (as table owner, bypassing RLS) to test
-- read visibility.
select tests.clear_authentication();
insert into documents (job_id, type, event_key, storage_path)
values (tests.fixture_id('job_1'), 'PGJO', 'fixture-pgjo', 'pgjo/fixture.html');

select tests.authenticate_as(tests.fixture_id('customer_1_auth'));
select is(
  (select count(*) from documents where job_id = tests.fixture_id('job_1'))::int, 1,
  'customer 1 can see the PGJO document on their own job'
);

select tests.authenticate_as(tests.fixture_id('customer_2_auth'));
select is(
  (select count(*) from documents where job_id = tests.fixture_id('job_1'))::int, 0,
  'customer 2 cannot see customer 1''s document'
);

select tests.authenticate_as(tests.fixture_id('centre_manager_b'));
select is(
  (select count(*) from documents where job_id = tests.fixture_id('job_1'))::int, 0,
  'Centre Manager B cannot see a document on branch A''s job'
);

select tests.authenticate_as(tests.fixture_id('designer'));
select is(
  (select count(*) from documents where job_id = tests.fixture_id('job_1'))::int, 1,
  'Central staff (Designer) can see the document, matching documents_select_own_or_staff'
);

select * from finish();
rollback;
