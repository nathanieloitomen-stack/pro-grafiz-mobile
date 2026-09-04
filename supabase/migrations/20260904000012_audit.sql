-- PG-003: Audit trail. Master Spec §7; CLAUDE.md "Sensitive actions create immutable audit events."

create table audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_type text not null default 'user',
  action text not null,
  entity_type text not null,
  entity_id uuid not null,
  before_state jsonb,
  after_state jsonb,
  reason text,
  ip_hash text,
  created_at timestamptz not null default timezone('utc', now())
);
create index idx_audit_events_entity on audit_events(entity_type, entity_id);
create index idx_audit_events_actor_user_id on audit_events(actor_user_id);
create index idx_audit_events_created_at on audit_events(created_at);

comment on table audit_events is
  'Append-only by convention — no UPDATE/DELETE grants are defined here '
  '(that''s enforced via RLS/role grants in PG-005, not by this '
  'migration). actor_user_id is nullable to allow system/webhook-driven '
  'events with no human actor (e.g. a payment webhook confirming a job '
  'stage transition). actor_type distinguishes ''user'' from ''system'' '
  'in that case — no fixed enum given in the source docs, left as text.';

comment on column audit_events.entity_id is
  'Deliberately not a foreign key: audit_events must survive the '
  'entity it describes being deleted or its table changing shape, and '
  'entity_type varies across every other table in this schema — a '
  'single polymorphic FK isn''t expressible cleanly in Postgres. '
  'Referential integrity here is an application-level responsibility.';
