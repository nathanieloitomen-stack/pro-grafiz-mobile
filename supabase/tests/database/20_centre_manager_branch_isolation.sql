-- PG-005 pgTAP: Centre Manager branch isolation.
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(6);

select tests.build_fixtures();

-- Centre Manager A (branch A) should see branch A's job/customer, not branch B's.
select tests.authenticate_as(tests.fixture_id('centre_manager_a'));

select is(
  (select count(*) from jobs where id = tests.fixture_id('job_1'))::int, 1,
  'Centre Manager A sees the job at their own branch (A)'
);
select is(
  (select count(*) from jobs where id = tests.fixture_id('job_2'))::int, 0,
  'Centre Manager A cannot see the job at branch B'
);
select is(
  (select count(*) from customers where id = tests.fixture_id('customer_2'))::int, 0,
  'Centre Manager A cannot see a customer whose only activity is at branch B'
);

-- Centre Manager B (branch B) — the mirror image.
select tests.authenticate_as(tests.fixture_id('centre_manager_b'));

select is(
  (select count(*) from jobs where id = tests.fixture_id('job_2'))::int, 1,
  'Centre Manager B sees the job at their own branch (B)'
);
select is(
  (select count(*) from jobs where id = tests.fixture_id('job_1'))::int, 0,
  'Centre Manager B cannot see the job at branch A'
);

-- Central staff (Super Admin) should see both branches — this is the
-- contrast case proving the restriction above is Centre-Manager-specific,
-- not a blanket branch filter that would also (wrongly) limit Super Admin.
select tests.authenticate_as(tests.fixture_id('super_admin'));

select is(
  (select count(*) from jobs where id in (tests.fixture_id('job_1'), tests.fixture_id('job_2')))::int, 2,
  'Super Admin sees jobs at both branches'
);

select * from finish();
rollback;
