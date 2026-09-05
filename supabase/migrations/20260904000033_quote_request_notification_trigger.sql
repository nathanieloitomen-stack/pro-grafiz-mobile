-- PG-013: notify a branch's Centre Manager when a new quote_request
-- arrives — Master Spec §16's "quote submitted" event.
--
-- Unlike every other notification in this task (created from
-- service-role Edge Functions), quote_requests can be inserted directly
-- by a customer via existing RLS (quote_requests_insert_own_or_staff,
-- PG-005) — there is no Edge Function call to hook a notification into.
-- A trigger is the only mechanism available here, matching the existing
-- precedent (handle_new_customer_signup, PG-004).
--
-- SECURITY DEFINER: needed to insert into notifications regardless of
-- the inserting session's own privileges (a customer session has no
-- INSERT policy on notifications, correctly) — same justification as
-- handle_new_customer_signup's own comment.
--
-- RECIPIENT DECISION (flagged, not specified anywhere): notifies only
-- that branch's Centre Manager, if one is currently assigned and
-- active. Not central staff broadly — Master Spec doesn't say who
-- staffs Intake, and a single, obvious recipient (the branch's own
-- manager) is a more conservative choice than guessing which of
-- several central roles should also be notified. If no Centre Manager
-- is currently assigned to the branch, no notification is sent — a
-- branch without an assigned manager is a valid (if incomplete) state,
-- not an error condition this trigger should raise on.

create or replace function notify_branch_manager_of_new_quote_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_manager_id uuid;
begin
  select id into v_manager_id
  from profiles
  where role = 'centre_manager' and branch_id = new.branch_id and active
  limit 1;

  if v_manager_id is not null then
    insert into notifications (recipient_user_id, type, title, body, entity_type, entity_id)
    values (
      v_manager_id,
      'quote_request.submitted',
      'New quote request',
      'A new request has been submitted for your centre.',
      'quote_request',
      new.id
    );
  end if;

  return new;
end;
$$;

comment on function notify_branch_manager_of_new_quote_request() is
  'security definer: runs as the function owner so it can insert into '
  'notifications regardless of the inserting session''s own privileges '
  '(a customer session correctly has no notifications INSERT policy).';

create trigger trg_notify_branch_manager_of_new_quote_request
  after insert on quote_requests
  for each row execute function notify_branch_manager_of_new_quote_request();
