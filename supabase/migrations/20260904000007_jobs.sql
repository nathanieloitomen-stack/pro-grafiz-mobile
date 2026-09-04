-- PG-003: Jobs and job lifecycle. Master Spec §7 and §9.

create sequence job_ref_seq start 1;
create or replace function generate_job_ref()
returns text
language sql
as $$
  select 'PG-' || lpad(nextval('job_ref_seq')::text, 6, '0');
$$;
comment on function generate_job_ref() is 'Format fixed by CLAUDE.md: PG-xxxx.';

create table jobs (
  id uuid primary key default gen_random_uuid(),
  job_ref text not null unique default generate_job_ref(),
  customer_id uuid not null references customers(id) on delete restrict,
  branch_id uuid not null references branches(id) on delete restrict,
  quote_id uuid not null references quotes(id) on delete restrict,
  source text not null default 'app',
  pattern_id uuid references patterns(id) on delete restrict,
  blend_id uuid references blends(id) on delete restrict,
  material_id uuid not null references materials(id) on delete restrict,
  thickness_mm numeric(6,2) not null,
  width_mm numeric(8,2) not null,
  height_mm numeric(8,2) not null,
  finish_id uuid not null references finishes(id) on delete restrict,
  current_stage job_stage_enum not null default 'SUBMITTED',
  stage_started_at timestamptz not null default timezone('utc', now()),
  status job_status_enum not null default 'active',
  hold_reason text,
  hold_note text,
  cancel_reason text,
  cancel_note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint chk_jobs_hold_reason_requires_hold
    check (status <> 'on_hold' or hold_reason is not null),
  constraint chk_jobs_cancel_reason_requires_cancel
    check (status <> 'cancelled' or cancel_reason is not null)
);
create index idx_jobs_customer_id on jobs(customer_id);
create index idx_jobs_branch_id on jobs(branch_id);
create index idx_jobs_current_stage on jobs(current_stage);
create index idx_jobs_status on jobs(status);

create trigger trg_jobs_updated_at
  before update on jobs
  for each row execute function set_updated_at();

comment on table jobs is
  'Master Spec §9: stage transitions must go through a server-side '
  'transition service, not arbitrary current_stage updates — that '
  'service is application/Edge Function logic (later PG task), not '
  'enforced by this migration alone. Every transition must also write a '
  'job_stage_history row and an audit_events row per CLAUDE.md.';

comment on column jobs.status is
  'active / on_hold / cancelled — inferred from the hold_*/cancel_* '
  'columns already present in the Master Spec schema (see enum comment '
  'in 20260904000002_enums.sql), not independently invented. Confirm '
  'with the product owner whether a distinct ''completed'' status is '
  'needed alongside current_stage = RELEASED.';

create table job_stage_history (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  stage job_stage_enum not null,
  entered_at timestamptz not null default timezone('utc', now()),
  exited_at timestamptz,
  advanced_by uuid references profiles(id) on delete set null,
  customer_action text,
  note text
);
create index idx_job_stage_history_job_id on job_stage_history(job_id);

comment on table job_stage_history is
  'Append-only. Master Spec §9: "Every transition must record actor, '
  'timestamp, previous/new stage, note where applicable and audit '
  'event." advanced_by is nullable to allow for system/webhook-driven '
  'transitions (e.g. payment confirmation via gateway webhook), which '
  'have no human actor.';

create table design_revisions (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  revision_no integer not null,
  requested_by uuid references profiles(id) on delete set null,
  request_note text,
  status text not null default 'open',
  created_at timestamptz not null default timezone('utc', now()),
  closed_at timestamptz,
  unique (job_id, revision_no)
);
create index idx_design_revisions_job_id on design_revisions(job_id);

comment on column design_revisions.status is
  'No fixed value list given in the source docs — plain text for now '
  '(open / resolved are plausible, not specified). Confirm before '
  'constraining.';

comment on column design_revisions.requested_by is
  'Nullable: Master Spec customer journey allows the customer to '
  'request a design change, and customers are not profiles rows '
  '(profiles is staff-oriented per §8 roles) — a customer-initiated '
  'revision request has no profiles.id to attach here. Confirm whether '
  'this should instead (or also) reference customers(id) once the '
  'customer-approval flow is designed in a later PG task.';
