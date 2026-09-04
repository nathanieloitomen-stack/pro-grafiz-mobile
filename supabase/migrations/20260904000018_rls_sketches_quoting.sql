-- PG-005: RLS — sketches, quote_requests, quotes.

alter table sketches enable row level security;
alter table quote_requests enable row level security;
alter table quotes enable row level security;

-- sketches ----------------------------------------------------------

create policy sketches_select_own_or_staff on sketches
  for select using (
    (customer_id is not null and customer_id = current_customer_id())
    or is_active_staff()
  );
create policy sketches_insert_own_or_staff on sketches
  for insert with check (
    (customer_id is not null and customer_id = current_customer_id())
    or is_active_staff()
  );
create policy sketches_update_own_or_staff on sketches
  for update using (
    (customer_id is not null and customer_id = current_customer_id())
    or is_active_staff()
  )
  with check (
    (customer_id is not null and customer_id = current_customer_id())
    or is_active_staff()
  );

-- quote_requests ------------------------------------------------------
--
-- Decision requests (status/decision_reason/decided_by/decided_at) are
-- deliberately staff-only to change — customers create a request, staff
-- decide on it (Intake screen's Bill-and-open-job / Decline). No
-- customer UPDATE policy exists at all; a customer wanting to withdraw
-- a pending request is not a flow this schema/RLS pass provides for —
-- flagging as a gap rather than silently allowing customers to edit
-- their own decision fields.
--
-- Which specific central roles staff the Intake screen isn't stated
-- anywhere in the docs beyond "branch chips (unscoped roles)" — granting
-- all central staff (accountant/designer/production/inventory,
-- alongside Super Admin) read/decide access here is a judgment call,
-- not a specified rule. Narrow this once the actual staffing is
-- confirmed.

create policy quote_requests_select_own_or_staff on quote_requests
  for select using (
    customer_id = current_customer_id()
    or (is_centre_manager() and branch_id = current_staff_branch_id())
    or is_central_staff()
  );
create policy quote_requests_insert_own_or_staff on quote_requests
  for insert with check (
    customer_id = current_customer_id()
    or is_active_staff()
  );
create policy quote_requests_update_staff_only on quote_requests
  for update using (
    (is_centre_manager() and branch_id = current_staff_branch_id())
    or is_central_staff()
  )
  with check (
    (is_centre_manager() and branch_id = current_staff_branch_id())
    or is_central_staff()
  );

-- quotes --------------------------------------------------------------
--
-- No INSERT or UPDATE policy for authenticated/anon, full stop. Master
-- Spec §10 and CLAUDE.md are both explicit: "The backend quote engine
-- is authoritative... Never trust client-submitted totals" and "Issued
-- quotes retain immutable pricing snapshots." Quotes are created only
-- by a future server-side quote engine (PG-007) using the service_role
-- key, which bypasses RLS. This is the DB-level guarantee behind the
-- "Client cannot alter authoritative price" requirement.

create policy quotes_select_own_or_staff on quotes
  for select using (
    exists (
      select 1 from quote_requests qr
      where qr.id = quotes.quote_request_id
        and (
          qr.customer_id = current_customer_id()
          or (is_centre_manager() and qr.branch_id = current_staff_branch_id())
          or is_central_staff()
        )
    )
  );
