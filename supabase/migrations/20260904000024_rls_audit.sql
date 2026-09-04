-- PG-005: RLS — audit_events.
--
-- Most restrictive table in the schema, deliberately: Super Admin read
-- only, no client write path at all. CLAUDE.md: "Sensitive actions
-- create immutable audit events" — those events will be written by
-- service_role from triggers/Edge Functions as the corresponding
-- features are built (job transitions, payment confirmations, staff
-- invite/reset actions, etc. — most of that logic doesn't exist yet as
-- of PG-005). Locking this down now, before anything writes to it,
-- means there's no window where audit data is client-writable.
--
-- No Centre Manager branch-scoped read policy is added even though
-- that's the pattern used elsewhere: audit_events has no branch_id
-- column (see PG-003's note on why entity_id is deliberately not a
-- typed foreign key), and joining out to every possible entity_type to
-- derive a branch isn't practical in a single policy. Defaulting to
-- Super-Admin-only until there's a concrete need to widen it is the
-- safer choice for an audit trail specifically.

alter table audit_events enable row level security;

create policy audit_events_select_super_admin on audit_events
  for select using (is_super_admin());

-- Deliberately no INSERT/UPDATE/DELETE policy for authenticated/anon.
