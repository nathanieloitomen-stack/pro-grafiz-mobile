-- PG-003: Drafts and CAD mandatory checks. Master Spec §7 and §11; CLAUDE.md "CAD RULES".

create table drafts (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  revision_id uuid references design_revisions(id) on delete set null,
  source text not null default 'designer',
  pattern_id uuid references patterns(id) on delete restrict,
  material_id uuid not null references materials(id) on delete restrict,
  panel_width_mm numeric(8,2),
  panel_height_mm numeric(8,2),
  sheet_count integer,
  waste_percent numeric(5,2),
  cut_length_mm numeric(10,2),
  cut_time_seconds integer,
  dxf_path text,
  preview_path text,
  version integer not null default 1,
  release_status text not null default 'pending',
  override_reason text,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (job_id, version)
);
create index idx_drafts_job_id on drafts(job_id);

comment on table drafts is
  'dxf_path/preview_path point into private Supabase Storage — never a '
  'public URL. CLAUDE.md "CAD RULES": any mandatory draft_checks failure '
  'blocks release; a designer override requires override_reason to be '
  'set. That gate is enforced in application/Edge Function logic (later '
  'PG task) — this migration only gives override_reason somewhere to '
  'live, it does not itself block anything.';

comment on column drafts.release_status is
  'No fixed value list given in the source docs — plain text for now '
  '(pending / blocked / released are plausible, directly implied by '
  'CLAUDE.md''s CAD rules, but not given as an exact enum). Confirm '
  'before constraining.';

create table draft_checks (
  id uuid primary key default gen_random_uuid(),
  draft_id uuid not null references drafts(id) on delete cascade,
  check_key text not null,
  result check_result_enum not null,
  value jsonb,
  message text,
  checked_at timestamptz not null default timezone('utc', now())
);
create index idx_draft_checks_draft_id on draft_checks(draft_id);

comment on column draft_checks.check_key is
  'Master Spec §11 names five mandatory checks: minimum_bridge_width, '
  'thickness_floor, closed_cut_paths, fixing_positions, '
  'nesting_efficiency. Left as free text rather than an enum so a later '
  'PG task can add checks without a migration, but application code '
  'implementing PG-010/PG-015 should treat those five as the mandatory '
  'set per CLAUDE.md: "Any mandatory failure blocks release."';
