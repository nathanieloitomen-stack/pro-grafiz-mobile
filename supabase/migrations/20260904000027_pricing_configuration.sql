-- PG-007: Configurable commercial rates.
--
-- Master Spec §12: "All commercial rates must be configurable data, not
-- source-code constants." These two tables are that configurable data.
-- They are created EMPTY and stay empty in this migration — no seed
-- data, no placeholder numbers. Populating real rates is a commercial
-- decision for the product owner, not something to guess at here (see
-- docs/quote-engine.md for the full list of what's still needed).
--
-- Deliberately staff-only, no customer access at all: rate cards are
-- competitively sensitive business data, unlike the public catalogue
-- reference tables (materials, finishes) from PG-003/PG-005.

create table pricing_rates (
  id uuid primary key default gen_random_uuid(),
  material_id uuid not null references materials(id) on delete restrict,
  finish_id uuid not null references finishes(id) on delete restrict,
  -- Per-square-metre rates. Cutting and finishing are billed by AREA
  -- here, not true cut length — that would need real nesting/geometry
  -- data, which is explicitly V2 scope (Master Spec §6: "Nest/sheet
  -- estimation" is a V2 item, yet §12 lists sheet count and cut time as
  -- V1 quote engine outputs — a real conflict between those two
  -- sections). Area-based billing is a common simplification for
  -- laser-cutting shops before real nesting exists; flagged in
  -- docs/quote-engine.md as a decision needing confirmation, not
  -- presented as obviously correct.
  material_rate_per_sqm_kobo bigint,
  cutting_rate_per_sqm_kobo bigint,
  finishing_rate_per_sqm_kobo bigint,
  -- Flat per-job rate, not area-scaled — labour here means job
  -- handling/setup, not cutting time.
  labour_rate_kobo bigint,
  wastage_percent numeric(5,2),
  active boolean not null default true,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (material_id, finish_id)
);

create trigger trg_pricing_rates_updated_at
  before update on pricing_rates
  for each row execute function set_updated_at();

alter table pricing_rates enable row level security;

create policy pricing_rates_select_finance_staff on pricing_rates
  for select using (is_super_admin() or is_accountant());
create policy pricing_rates_write_super_admin on pricing_rates
  for all using (is_super_admin()) with check (is_super_admin());

comment on table pricing_rates is
  'Empty by design — see this migration''s header comment and '
  'docs/quote-engine.md. A quote cannot be issued for a material/finish '
  'combination until a Super Admin adds a row here.';

-- Global commercial terms that aren't specific to a material/finish
-- pairing: VAT, deposit percentage, delivery/installation flat fees,
-- and the sheet-size/cutting-speed assumptions used for the V1
-- area-based sheet-count/cut-time estimate. Key-value rather than fixed
-- columns so adding a new global term later doesn't need a migration.
create table commercial_settings (
  key text primary key,
  value numeric not null,
  description text,
  updated_by uuid references profiles(id) on delete set null,
  updated_at timestamptz not null default timezone('utc', now())
);

alter table commercial_settings enable row level security;

create policy commercial_settings_select_finance_staff on commercial_settings
  for select using (is_super_admin() or is_accountant());
create policy commercial_settings_write_super_admin on commercial_settings
  for all using (is_super_admin()) with check (is_super_admin());

comment on table commercial_settings is
  'Empty by design. Expected keys (all optional — the quote engine '
  'treats a missing key as "not configured", never as zero): '
  'vat_percent, deposit_percent, delivery_flat_kobo, '
  'installation_flat_kobo, standard_sheet_width_mm, '
  'standard_sheet_height_mm, cutting_speed_sqm_per_minute. See '
  'docs/quote-engine.md for what each affects and what is still an '
  'open decision.';
