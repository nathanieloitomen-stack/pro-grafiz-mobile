-- PG-005: RLS — notifications, devices, offline_actions.

alter table notifications enable row level security;
alter table devices enable row level security;
alter table offline_actions enable row level security;

-- notifications -------------------------------------------------------
--
-- recipient_user_id references auth.users directly (see PG-003's
-- comment on that column) precisely so this one check works uniformly
-- for both staff and customers. Only read_at is client-writable
-- (marking a notification read) — everything else about a notification
-- is system-generated.

revoke update on notifications from authenticated;
grant update (read_at) on notifications to authenticated;

create policy notifications_select_own on notifications
  for select using (recipient_user_id = auth.uid());
create policy notifications_update_own on notifications
  for update using (recipient_user_id = auth.uid()) with check (recipient_user_id = auth.uid());

-- Deliberately no INSERT/DELETE policy — notifications are created by
-- the (not-yet-built) notification-sending service.

-- devices ---------------------------------------------------------------
--
-- Self-service device management is low-risk (a device registering or
-- updating its own sync state), so this is one of the more permissive
-- tables. Super Admin additionally sees all devices for the Admin
-- screen's device list.

create policy devices_all_own on devices
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy devices_select_super_admin on devices
  for select using (is_super_admin());

-- offline_actions ---------------------------------------------------------
--
-- A device can queue its own actions and see its own queue. Marking an
-- action synced/failed is deliberately NOT client-writable — Master
-- Spec §15's idempotent-sync design assumes the sync processor (not the
-- device reporting on itself) is the source of truth for whether
-- something actually synced; allowing a device to self-report "synced"
-- would undermine that. That processor doesn't exist yet (later PG
-- task) — until then, queued actions simply accumulate, which is safe,
-- if not yet useful.

create policy offline_actions_select_own_device on offline_actions
  for select using (
    exists (select 1 from devices d where d.id = offline_actions.device_id and d.user_id = auth.uid())
  );
create policy offline_actions_insert_own_device on offline_actions
  for insert with check (
    exists (select 1 from devices d where d.id = offline_actions.device_id and d.user_id = auth.uid())
  );

-- Deliberately no UPDATE/DELETE policy — see header comment.
