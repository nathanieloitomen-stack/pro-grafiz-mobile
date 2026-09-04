-- PG-005: RLS — profiles (staff) and customers.
--
-- Master Spec §8: "No user can change their own role or branch." This
-- is enforced at the strongest available level: column-level REVOKE
-- means NO client — not even a Super Admin acting through the normal
-- API — can write profiles.role, profiles.branch_id, profiles.active,
-- profiles.auth_login_handle, or the invite_token_* columns via direct
-- table access. Those changes require the service_role key, i.e. a
-- purpose-built Edge Function with its own explicit checks (staff-invite
-- and staff-reset-pin already work this way, per PG-004; a
-- "staff-update-role"-style function for legitimate role/branch changes
-- is not built yet — that's later PG task work, tracked in
-- docs/authorization.md).

alter table profiles enable row level security;
alter table customers enable row level security;

revoke update on profiles from authenticated;
grant update (full_name, initials, phone, email) on profiles to authenticated;

create policy profiles_select_self on profiles
  for select using (id = auth.uid());
create policy profiles_select_super_admin on profiles
  for select using (is_super_admin());
create policy profiles_select_centre_manager_own_branch on profiles
  for select using (is_centre_manager() and branch_id = current_staff_branch_id());
create policy profiles_select_central_staff on profiles
  for select using (is_central_staff());

create policy profiles_update_self_safe_columns on profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- Deliberately no INSERT or DELETE policy for authenticated/anon —
-- accounts are created only via the staff-invite Edge Function
-- (service_role, bypasses RLS entirely). Default-deny is correct here.

-- customers -------------------------------------------------------

revoke update on customers from authenticated;
grant update (full_name, phone, email) on customers to authenticated;

create policy customers_select_self on customers
  for select using (auth_user_id = auth.uid());
create policy customers_select_super_admin on customers
  for select using (is_super_admin());
create policy customers_select_central_staff on customers
  for select using (is_central_staff());
create policy customers_select_centre_manager_branch_scoped on customers
  for select using (
    is_centre_manager()
    and (
      default_branch_id = current_staff_branch_id()
      or exists (
        select 1 from quote_requests qr
        where qr.customer_id = customers.id and qr.branch_id = current_staff_branch_id()
      )
      or exists (
        select 1 from jobs j
        where j.customer_id = customers.id and j.branch_id = current_staff_branch_id()
      )
    )
  );

create policy customers_update_self on customers
  for update using (auth_user_id = auth.uid()) with check (auth_user_id = auth.uid());
create policy customers_update_super_admin on customers
  for update using (is_super_admin()) with check (is_super_admin());
create policy customers_update_centre_manager_branch_scoped on customers
  for update using (
    is_centre_manager()
    and (
      default_branch_id = current_staff_branch_id()
      or exists (
        select 1 from quote_requests qr
        where qr.customer_id = customers.id and qr.branch_id = current_staff_branch_id()
      )
      or exists (
        select 1 from jobs j
        where j.customer_id = customers.id and j.branch_id = current_staff_branch_id()
      )
    )
  )
  with check (
    is_centre_manager()
    and (
      default_branch_id = current_staff_branch_id()
      or exists (
        select 1 from quote_requests qr
        where qr.customer_id = customers.id and qr.branch_id = current_staff_branch_id()
      )
      or exists (
        select 1 from jobs j
        where j.customer_id = customers.id and j.branch_id = current_staff_branch_id()
      )
    )
  );

-- Deliberately no INSERT policy — new customer rows are created only by
-- the handle_new_customer_signup() trigger (PG-004), which runs
-- SECURITY DEFINER as the table owner and bypasses RLS. Deliberately no
-- DELETE policy — customer records are not client-deletable.
