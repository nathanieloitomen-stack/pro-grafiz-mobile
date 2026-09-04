-- PG-006 pgTAP: pattern_favourites isolation and the public aggregate view.
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(5);

select tests.build_fixtures();

-- Need a second pattern to favourite (fixtures give us one from
-- build_fixtures via patterns; reuse the category created there).
select tests.clear_authentication();
insert into pattern_favourites (customer_id, pattern_id)
select tests.fixture_id('customer_1'), id from patterns limit 1;

select tests.authenticate_as(tests.fixture_id('customer_1_auth'));
select is(
  (select count(*) from pattern_favourites)::int, 1,
  'customer 1 sees their own favourite'
);

select tests.authenticate_as(tests.fixture_id('customer_2_auth'));
select is(
  (select count(*) from pattern_favourites)::int, 0,
  'customer 2 cannot see customer 1''s favourite row'
);

-- Staff should have NO access to the raw table at all — unlike almost
-- every other customer-owned table in this schema, favourites has no
-- legitimate staff read path.
select tests.authenticate_as(tests.fixture_id('super_admin'));
select is(
  (select count(*) from pattern_favourites)::int, 0,
  'Even Super Admin sees zero rows in pattern_favourites directly — no staff policy exists on this table'
);

-- The aggregate view, in contrast, IS visible to everyone — this is
-- the point of the view existing at all (public "saved count").
select tests.authenticate_as(tests.fixture_id('customer_2_auth'));
select is(
  (select count(*) from pattern_favourite_counts)::int, 1,
  'customer 2 (who has no favourites) can still see the aggregate count row for the pattern customer 1 favourited'
);

select tests.authenticate_as_anon();
select is(
  (select count(*) from pattern_favourite_counts)::int, 1,
  'An anonymous, signed-out caller can also see the aggregate count — proves the view does not require a session, only the underlying table does'
);

select * from finish();
rollback;
