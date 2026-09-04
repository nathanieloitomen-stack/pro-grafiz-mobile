-- PG-005 test helpers — NOT a pgTAP test itself. Loaded before every
-- other file in this directory (pgTAP/`supabase test db` runs files in
-- alphabetical order, hence the `00_` prefix).
--
-- REQUIRES LIVE SUPABASE VERIFICATION: everything in this directory was
-- written without a live Postgres/Supabase instance, network, or the
-- pgTAP extension available in the authoring environment. It has never
-- been executed. Treat it as a well-structured starting point to run
-- and debug against a real `supabase start` project, not as proof that
-- RLS works.
--
-- Requires: `create extension if not exists pgtap;` (Supabase's local
-- dev stack includes this; enable it if testing against a bare
-- Postgres instance instead).

create schema if not exists tests;

-- Simulates "signed in as this auth.users.id" for the rest of the
-- current transaction. Supabase's real auth.uid() is implemented as
-- `nullif(current_setting('request.jwt.claim.sub', true), '')::uuid`,
-- which is what this relies on — setting that GUC plus dropping the
-- session's effective role to `authenticated` is what actually makes
-- RLS policies AND the column-level GRANT/REVOKE restrictions from the
-- PG-005 migrations apply. Without `set local role`, tests would run as
-- the table-owning role, which bypasses RLS entirely regardless of
-- auth.uid().
create or replace function tests.authenticate_as(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user_id::text, true);
  execute 'set local role authenticated';
end;
$$;

create or replace function tests.authenticate_as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  execute 'set local role anon';
end;
$$;

-- Returns to the table-owning role with no simulated auth.uid() — use
-- between test cases when fixture setup needs to bypass RLS again.
create or replace function tests.clear_authentication()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  execute 'reset role';
end;
$$;

-- Fixture builder. Run once per test file (as the table-owning role,
-- i.e. before calling authenticate_as) to get a small, consistent
-- dataset: two branches, one staff profile per role at branch A (plus
-- a second Centre Manager at branch B for isolation tests), two
-- customers, one pattern, one job + quote per customer, one payment,
-- one draft with one failing check. Returns nothing — subsequent test
-- files query fixed, well-known values via the tests.fixture_id()
-- lookup helper below rather than hardcoding UUIDs.
create table if not exists tests.fixture_ids (
  key text primary key,
  id uuid not null
);

-- Test-only infrastructure, not production data — granted broadly so
-- tests.fixture_id() still works after a test switches to the
-- `authenticated` role via tests.authenticate_as(). Without this grant,
-- every fixture lookup after the first authenticate_as() call would
-- fail with a permission error, since plain (non-SECURITY-DEFINER)
-- functions run with the CALLING role's privileges.
grant select, insert, update on tests.fixture_ids to authenticated, anon;

create or replace function tests.fixture_id(p_key text)
returns uuid
language sql stable
as $$
  select id from tests.fixture_ids where key = p_key;
$$;

create or replace function tests.set_fixture_id(p_key text, p_id uuid)
returns void
language sql
as $$
  insert into tests.fixture_ids (key, id) values (p_key, p_id)
  on conflict (key) do update set id = excluded.id;
$$;

create or replace function tests.build_fixtures()
returns void
language plpgsql
as $$
-- CAVEAT (cannot be resolved without a live instance): the auth.users
-- INSERT below supplies only the columns this test suite actually
-- needs. Real Supabase auth.users has additional columns (aud, role,
-- instance_id, confirmation_token, etc.) managed by GoTrue — this
-- environment has no way to inspect the exact current schema for the
-- target Supabase Postgres version to confirm every other column
-- tolerates being left at its default/null. If this INSERT fails
-- against a real project, that's the first thing to fix — it is not a
-- sign the RLS policies themselves are wrong.
declare
  v_branch_a uuid := gen_random_uuid();
  v_branch_b uuid := gen_random_uuid();
  v_material uuid;
  v_finish uuid;
  v_category uuid;
  v_pattern uuid;
  v_super_admin uuid := gen_random_uuid();
  v_centre_manager_a uuid := gen_random_uuid();
  v_centre_manager_b uuid := gen_random_uuid();
  v_accountant uuid := gen_random_uuid();
  v_designer uuid := gen_random_uuid();
  v_production uuid := gen_random_uuid();
  v_customer_1_auth uuid := gen_random_uuid();
  v_customer_2_auth uuid := gen_random_uuid();
  v_customer_1 uuid;
  v_customer_2 uuid;
  v_quote_request_1 uuid;
  v_quote_1 uuid;
  v_job_1 uuid; -- customer 1's job, at branch A
  v_draft_1 uuid;
  v_payment_1 uuid;
  v_quote_request_2 uuid;
  v_quote_2 uuid;
  v_job_2 uuid; -- customer 2's job, at branch B
begin
  -- auth.users rows: real Supabase projects populate this via GoTrue;
  -- for local pgTAP testing we insert directly, matching common
  -- Supabase testing practice.
  insert into auth.users (id, email, phone, encrypted_password, email_confirmed_at)
  values
    (v_super_admin, 'super-admin-fixture@staff.pro-grafiz.internal', null, 'x', now()),
    (v_centre_manager_a, 'cm-a-fixture@staff.pro-grafiz.internal', null, 'x', now()),
    (v_centre_manager_b, 'cm-b-fixture@staff.pro-grafiz.internal', null, 'x', now()),
    (v_accountant, 'accountant-fixture@staff.pro-grafiz.internal', null, 'x', now()),
    (v_designer, 'designer-fixture@staff.pro-grafiz.internal', null, 'x', now()),
    (v_production, 'production-fixture@staff.pro-grafiz.internal', null, 'x', now()),
    (v_customer_1_auth, null, '+2340000000001', 'x', now()),
    (v_customer_2_auth, null, '+2340000000002', 'x', now())
  on conflict (id) do nothing;

  insert into branches (id, code, name, active) values
    (v_branch_a, 'TEST-BR-A', 'Test Branch A', true),
    (v_branch_b, 'TEST-BR-B', 'Test Branch B', true)
  on conflict (id) do nothing;

  insert into profiles (id, full_name, role, branch_id, active, auth_login_handle)
  values
    (v_super_admin, 'Fixture Super Admin', 'super_admin', null, true, 'super-admin-fixture@staff.pro-grafiz.internal'),
    (v_centre_manager_a, 'Fixture CM A', 'centre_manager', v_branch_a, true, 'cm-a-fixture@staff.pro-grafiz.internal'),
    (v_centre_manager_b, 'Fixture CM B', 'centre_manager', v_branch_b, true, 'cm-b-fixture@staff.pro-grafiz.internal'),
    (v_accountant, 'Fixture Accountant', 'accountant', null, true, 'accountant-fixture@staff.pro-grafiz.internal'),
    (v_designer, 'Fixture Designer', 'designer', null, true, 'designer-fixture@staff.pro-grafiz.internal'),
    (v_production, 'Fixture Production', 'production', null, true, 'production-fixture@staff.pro-grafiz.internal')
  on conflict (id) do nothing;

  insert into materials (code, name, active) values ('TEST-MAT', 'Test Material', true)
    on conflict (code) do nothing;
  select id into v_material from materials where code = 'TEST-MAT';

  insert into finishes (code, name, active) values ('TEST-FIN', 'Test Finish', true)
    on conflict (code) do nothing;
  select id into v_finish from finishes where code = 'TEST-FIN';

  insert into pattern_categories (code, name, active) values ('TEST-CAT', 'Test Category', true)
    on conflict (code) do nothing;
  select id into v_category from pattern_categories where code = 'TEST-CAT';

  insert into patterns (name, category_id, active) values ('Test Pattern', v_category, true)
    returning id into v_pattern;

  insert into customers (auth_user_id, customer_ref, full_name, phone, default_branch_id, active)
  values (v_customer_1_auth, 'TEST-CUST-0001', 'Test Customer One', '+2340000000001', v_branch_a, true)
  returning id into v_customer_1;

  insert into customers (auth_user_id, customer_ref, full_name, phone, default_branch_id, active)
  values (v_customer_2_auth, 'TEST-CUST-0002', 'Test Customer Two', '+2340000000002', v_branch_b, true)
  returning id into v_customer_2;

  insert into quote_requests (customer_id, branch_id, pattern_id, material_id, thickness_mm, width_mm, height_mm, finish_id)
  values (v_customer_1, v_branch_a, v_pattern, v_material, 2.0, 600, 600, v_finish)
  returning id into v_quote_request_1;

  insert into quotes (quote_ref, quote_request_id, pricing_snapshot)
  values ('TEST-QUOTE-0001', v_quote_request_1, '{}'::jsonb)
  returning id into v_quote_1;

  insert into jobs (customer_id, branch_id, quote_id, material_id, thickness_mm, width_mm, height_mm, finish_id)
  values (v_customer_1, v_branch_a, v_quote_1, v_material, 2.0, 600, 600, v_finish)
  returning id into v_job_1;

  insert into drafts (job_id, material_id, release_status, created_by)
  values (v_job_1, v_material, 'pending', v_designer)
  returning id into v_draft_1;

  insert into draft_checks (draft_id, check_key, result)
  values (v_draft_1, 'thickness_floor', 'fail');

  insert into payments (job_id, payment_ref, kind, amount_kobo)
  values (v_job_1, 'TEST-PAY-0001', 'deposit', 100000)
  returning id into v_payment_1;

  -- Customer 2's job, at branch B — the counterpart used to prove
  -- isolation (customer 1 must not see this; Centre Manager A must not
  -- see this; Centre Manager B must).
  insert into quote_requests (customer_id, branch_id, pattern_id, material_id, thickness_mm, width_mm, height_mm, finish_id)
  values (v_customer_2, v_branch_b, v_pattern, v_material, 2.0, 600, 600, v_finish)
  returning id into v_quote_request_2;

  insert into quotes (quote_ref, quote_request_id, pricing_snapshot)
  values ('TEST-QUOTE-0002', v_quote_request_2, '{}'::jsonb)
  returning id into v_quote_2;

  insert into jobs (customer_id, branch_id, quote_id, material_id, thickness_mm, width_mm, height_mm, finish_id)
  values (v_customer_2, v_branch_b, v_quote_2, v_material, 2.0, 600, 600, v_finish)
  returning id into v_job_2;

  perform tests.set_fixture_id('branch_a', v_branch_a);
  perform tests.set_fixture_id('branch_b', v_branch_b);
  perform tests.set_fixture_id('super_admin', v_super_admin);
  perform tests.set_fixture_id('centre_manager_a', v_centre_manager_a);
  perform tests.set_fixture_id('centre_manager_b', v_centre_manager_b);
  perform tests.set_fixture_id('accountant', v_accountant);
  perform tests.set_fixture_id('designer', v_designer);
  perform tests.set_fixture_id('production', v_production);
  perform tests.set_fixture_id('customer_1_auth', v_customer_1_auth);
  perform tests.set_fixture_id('customer_2_auth', v_customer_2_auth);
  perform tests.set_fixture_id('customer_1', v_customer_1);
  perform tests.set_fixture_id('customer_2', v_customer_2);
  perform tests.set_fixture_id('job_1', v_job_1);
  perform tests.set_fixture_id('quote_1', v_quote_1);
  perform tests.set_fixture_id('draft_1', v_draft_1);
  perform tests.set_fixture_id('payment_1', v_payment_1);
  perform tests.set_fixture_id('job_2', v_job_2);
  perform tests.set_fixture_id('quote_2', v_quote_2);
end;
$$;
