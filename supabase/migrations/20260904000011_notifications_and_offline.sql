-- PG-003: Notifications, devices, offline sync queue. Master Spec §7, §15, §16.

create table notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  entity_type text,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);
create index idx_notifications_recipient_user_id on notifications(recipient_user_id);

comment on column notifications.recipient_user_id is
  'References auth.users directly rather than profiles or customers, '
  'since a recipient may be staff (profiles.id = auth.users.id) or a '
  'customer with an account (customers.auth_user_id = auth.users.id) — '
  'auth.users is the one table both can be joined back to.';

comment on column notifications.type is
  'Master Spec §16 lists the triggering events (quote submitted/ready, '
  'payment requested/confirmed, design ready, approval requested, '
  'design change requested, stage changes, hold, ready, dispatch, '
  'release) but not a fixed enum of type values — left as text, '
  'application code should use a consistent internal vocabulary.';

create table devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_name text,
  platform text,
  last_seen_at timestamptz,
  sync_state text not null default 'synced',
  queued_action_count integer not null default 0
);
create index idx_devices_user_id on devices(user_id);

comment on column devices.sync_state is
  'No fixed value list given in the source docs — plain text for now '
  '(e.g. synced / pending / conflict are plausible, not specified). '
  'Confirm before constraining.';

create table offline_actions (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references devices(id) on delete cascade,
  idempotency_key text not null unique,
  action_type text not null,
  payload jsonb not null,
  status text not null default 'queued',
  created_at timestamptz not null default timezone('utc', now()),
  synced_at timestamptz
);
create index idx_offline_actions_device_id on offline_actions(device_id);

comment on table offline_actions is
  'Master Spec §15: staff operational actions may be queued locally; '
  'each mutation needs an idempotency key, enforced here as a unique '
  'constraint. CLAUDE.md: offline payment confirmation is disabled by '
  'default — that restriction is enforced in application/Edge Function '
  'logic (a later PG task), not by this table shape alone.';

comment on column offline_actions.status is
  'No fixed value list given in the source docs — plain text for now '
  '(e.g. queued / syncing / synced / failed / conflict are plausible, '
  'not specified). Confirm before constraining.';
