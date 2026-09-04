-- PG-005 pgTAP: customer isolation.
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(9);

select tests.build_fixtures();

-- Customer 1 signs in.
select tests.authenticate_as(tests.fixture_id('customer_1_auth'));

select is(
  (select count(*) from jobs)::int, 1,
  'customer 1 sees exactly one job (their own)'
);
select is(
  (select customer_id from jobs limit 1), tests.fixture_id('customer_1'),
  'the job customer 1 sees is their own'
);
select is(
  (select count(*) from jobs where id = tests.fixture_id('job_2'))::int, 0,
  'customer 1 cannot see customer 2''s job'
);
select is(
  (select count(*) from customers)::int, 1,
  'customer 1 sees exactly one customer row (their own)'
);
select is(
  (select count(*) from customers where id = tests.fixture_id('customer_2'))::int, 0,
  'customer 1 cannot see customer 2''s customer row'
);
select is(
  (select count(*) from payments)::int, 1,
  'customer 1 sees exactly one payment (on their own job)'
);
select is(
  (select count(*) from quotes)::int, 1,
  'customer 1 sees exactly one quote (their own)'
);

-- Customer 2 signs in — the mirror image.
select tests.authenticate_as(tests.fixture_id('customer_2_auth'));

select is(
  (select count(*) from jobs where id = tests.fixture_id('job_1'))::int, 0,
  'customer 2 cannot see customer 1''s job'
);
select is(
  (select count(*) from payments)::int, 0,
  'customer 2 sees no payments (their job has none in this fixture set)'
);

select * from finish();
rollback;
