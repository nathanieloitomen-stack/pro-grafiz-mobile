-- PG-013 pgTAP: notification security regression guarantees, plus the
-- one genuinely new RLS-adjacent mechanism this task adds at the
-- database level — the quote_request submission trigger. Every other
-- notification in this task is created from TypeScript service-role
-- functions and cannot be tested via pgTAP — same limitation as every
-- prior task's Edge Functions.
-- REQUIRES LIVE SUPABASE VERIFICATION — see 00_helpers.sql header.
begin;
select plan(6);

-- build_fixtures() inserts quote_requests directly (as table owner),
-- which fires trg_notify_branch_manager_of_new_quote_request for both
-- fixture requests — this is the actual mechanism under test here, not
-- a side effect to ignore.
select tests.build_fixtures();

-- Regression: notifications still has zero INSERT policy for any role.
select tests.authenticate_as(tests.fixture_id('super_admin'));
select is(
  (with inserted as (
    insert into notifications (recipient_user_id, type, title)
    values (tests.fixture_id('super_admin'), 'test', 'test')
    returning 1
  ) select count(*) from inserted)::int,
  0,
  'Even Super Admin cannot insert a notification directly — every notification in this codebase is system-generated'
);

-- The trigger: Centre Manager A should have a notification about
-- quote_request_1 (branch A); Centre Manager B should have one about
-- quote_request_2 (branch B).
select tests.authenticate_as(tests.fixture_id('centre_manager_a'));
select is(
  (select count(*) from notifications where type = 'quote_request.submitted')::int, 1,
  'Centre Manager A received exactly one new-quote-request notification (for branch A''s request)'
);

select tests.authenticate_as(tests.fixture_id('centre_manager_b'));
select is(
  (select count(*) from notifications where type = 'quote_request.submitted')::int, 1,
  'Centre Manager B received exactly one new-quote-request notification (for branch B''s request), not Centre Manager A''s'
);

-- Regression: notifications_select_own / notifications_update_own
-- (PG-005) still isolate correctly — a customer cannot see a staff
-- member's notification.
select tests.authenticate_as(tests.fixture_id('customer_1_auth'));
select is(
  (select count(*) from notifications where type = 'quote_request.submitted')::int, 0,
  'Customer 1 cannot see Centre Manager A''s notification'
);

-- Only read_at is client-writable (column-level grant, PG-005) —
-- confirm a Centre Manager can mark their own notification read but not
-- rewrite its title.
select tests.authenticate_as(tests.fixture_id('centre_manager_a'));
select lives_ok(
  $q$ update notifications set read_at = now() where type = 'quote_request.submitted' $q$,
  'Centre Manager A can mark their own notification read'
);
select throws_ok(
  $q$ update notifications set title = 'tampered' where type = 'quote_request.submitted' $q$,
  '42501',
  null,
  'Centre Manager A cannot rewrite a notification''s title — only read_at is a granted column'
);

select * from finish();
rollback;
