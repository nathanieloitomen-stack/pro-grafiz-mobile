-- PG-003: PGLC catalogue. Master Spec §7 and §11.

create sequence pglc_code_seq start 1;
create or replace function generate_pglc_code()
returns text
language sql
as $$
  select 'PGLC' || lpad(nextval('pglc_code_seq')::text, 4, '0');
$$;
comment on function generate_pglc_code() is
  'Human-readable pattern code, format fixed by CLAUDE.md: PGLCxxxx.';

create table patterns (
  id uuid primary key default gen_random_uuid(),
  pglc_code text not null unique default generate_pglc_code(),
  name text not null,
  category_id uuid references pattern_categories(id) on delete restrict,
  geometry_family text,
  density text,
  typical_uses text,
  engineering_note text,
  active boolean not null default true,
  version integer not null default 1,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index idx_patterns_category_id on patterns(category_id);

create trigger trg_patterns_updated_at
  before update on patterns
  for each row execute function set_updated_at();

comment on table patterns is
  'Production catalogue patterns. Per CLAUDE.md "PGLC CATALOGUE": do not '
  'populate this table with invented geometry — real assets are sourced '
  'as a separate content workstream, dev seed rows must be clearly '
  'marked (see supabase/seed).';

create table pattern_assets (
  id uuid primary key default gen_random_uuid(),
  pattern_id uuid not null references patterns(id) on delete cascade,
  asset_type asset_type_enum not null,
  storage_path text not null,
  checksum text,
  file_size bigint,
  production_ready boolean not null default false,
  version integer not null default 1,
  created_at timestamptz not null default timezone('utc', now()),
  unique (pattern_id, asset_type, version)
);
create index idx_pattern_assets_pattern_id on pattern_assets(pattern_id);

comment on table pattern_assets is
  'Per-pattern files (png/preview/svg/dxf/thumbnail). storage_path points '
  'into a private Supabase Storage bucket, never a public URL — see '
  'CLAUDE.md "DXF": never expose private production DXF without backend '
  'authorization.';

-- ---------------------------------------------------------------------
-- Gap-fill: `blends` and `blend_patterns`.
--
-- Master Spec §7 does not enumerate a `blends` table, but
-- quote_requests.blend_id and jobs.blend_id (both defined in §7) clearly
-- reference one, and CLAUDE.md's "CRITICAL BUSINESS RULES" independently
-- states: "Blends contain 2–3 patterns; order is significant." Adding
-- this table is filling an apparent spec gap using a rule already given
-- elsewhere in the provided docs, not inventing new business logic —
-- but it wasn't in the enumerated table list, so it's called out here
-- explicitly rather than silently. Confirm with the product owner that
-- this shape is right before treating it as final.
-- ---------------------------------------------------------------------

create table blends (
  id uuid primary key default gen_random_uuid(),
  name text,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now())
);
comment on table blends is
  'Gap-fill table — see migration comment. 2–3 patterns per blend, '
  'ordered; enforced by blend_patterns + trg_check_blend_pattern_count.';

create table blend_patterns (
  id uuid primary key default gen_random_uuid(),
  blend_id uuid not null references blends(id) on delete cascade,
  pattern_id uuid not null references patterns(id) on delete restrict,
  position smallint not null check (position between 1 and 3),
  created_at timestamptz not null default timezone('utc', now()),
  unique (blend_id, position),
  unique (blend_id, pattern_id)
);
create index idx_blend_patterns_blend_id on blend_patterns(blend_id);

-- A blend must have between 2 and 3 patterns. This can't be a simple
-- CHECK (constraints see one row at a time), so it's a deferred
-- constraint trigger checked once per transaction instead of after
-- every individual row insert — otherwise inserting a blend's patterns
-- one row at a time would fail on the first row.
create or replace function check_blend_pattern_count()
returns trigger
language plpgsql
as $$
declare
  affected_blend_id uuid;
  pattern_count integer;
begin
  affected_blend_id := coalesce(new.blend_id, old.blend_id);

  select count(*) into pattern_count
  from blend_patterns
  where blend_id = affected_blend_id;

  if pattern_count < 2 or pattern_count > 3 then
    raise exception
      'Blend % has % pattern(s); blends must contain 2–3 patterns (CLAUDE.md business rule).',
      affected_blend_id, pattern_count;
  end if;

  return null;
end;
$$;

create constraint trigger trg_check_blend_pattern_count
  after insert or update or delete on blend_patterns
  deferrable initially deferred
  for each row execute function check_blend_pattern_count();
