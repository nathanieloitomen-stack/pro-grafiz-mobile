-- PG-003: Sketches, quote requests, and quotes. Master Spec §7 and §12.

create table sketches (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references customers(id) on delete set null,
  capture_path text,
  traced_outline_path text,
  description text,
  created_by uuid references profiles(id) on delete set null,
  status text not null default 'captured',
  created_at timestamptz not null default timezone('utc', now())
);
create index idx_sketches_customer_id on sketches(customer_id);

comment on column sketches.status is
  'No fixed value list given in the source docs — plain text for now. '
  'Master Spec §11 flow (Pattern → SVG → ... → Production) and V2 scope '
  '("sketch-to-vector assistance") suggest something like captured / '
  'traced / matched / rejected, but that is an inference, not a '
  'specified enum — confirm before constraining.';

create sequence quote_request_ref_seq start 1;
create or replace function generate_quote_request_ref()
returns text
language sql
as $$
  select 'QR-' || lpad(nextval('quote_request_ref_seq')::text, 6, '0');
$$;
comment on function generate_quote_request_ref() is
  'Format fixed by CLAUDE.md: QR-xxxx.';

create table quote_requests (
  id uuid primary key default gen_random_uuid(),
  request_ref text not null unique default generate_quote_request_ref(),
  customer_id uuid not null references customers(id) on delete restrict,
  branch_id uuid not null references branches(id) on delete restrict,
  source text not null default 'app',
  pattern_id uuid references patterns(id) on delete restrict,
  blend_id uuid references blends(id) on delete restrict,
  sketch_id uuid references sketches(id) on delete set null,
  material_id uuid not null references materials(id) on delete restrict,
  thickness_mm numeric(6,2) not null,
  width_mm numeric(8,2) not null,
  height_mm numeric(8,2) not null,
  finish_id uuid not null references finishes(id) on delete restrict,
  customer_note text,
  status text not null default 'pending',
  decision_reason text,
  decided_by uuid references profiles(id) on delete set null,
  decided_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint chk_quote_request_pattern_or_blend_or_sketch
    check (
      (pattern_id is not null)::int
      + (blend_id is not null)::int
      + (sketch_id is not null)::int >= 1
    )
);
create index idx_quote_requests_customer_id on quote_requests(customer_id);
create index idx_quote_requests_branch_id on quote_requests(branch_id);
create index idx_quote_requests_status on quote_requests(status);

create trigger trg_quote_requests_updated_at
  before update on quote_requests
  for each row execute function set_updated_at();

comment on column quote_requests.status is
  'No fixed value list given in the source docs — plain text for now. '
  'Confirm the exact states (e.g. pending / quoted / accepted / '
  'rejected / expired / cancelled) with the product owner; do not '
  'hardcode a guess into application logic ahead of that.';

comment on constraint chk_quote_request_pattern_or_blend_or_sketch on quote_requests is
  'A request must be based on something (pattern, blend, or sketch) — '
  'structural sanity check, not a business-rule invention.';

create table quotes (
  id uuid primary key default gen_random_uuid(),
  quote_ref text not null unique,
  quote_request_id uuid not null references quote_requests(id) on delete restrict,
  version integer not null default 1,
  material_cost_kobo bigint not null default 0,
  cutting_cost_kobo bigint not null default 0,
  finishing_cost_kobo bigint not null default 0,
  labour_cost_kobo bigint not null default 0,
  wastage_cost_kobo bigint not null default 0,
  delivery_cost_kobo bigint not null default 0,
  installation_cost_kobo bigint not null default 0,
  discount_kobo bigint not null default 0,
  vat_kobo bigint not null default 0,
  subtotal_kobo bigint not null default 0,
  total_kobo bigint not null default 0,
  deposit_kobo bigint not null default 0,
  balance_kobo bigint not null default 0,
  sheet_count integer,
  estimated_cut_minutes numeric(8,2),
  lead_time_days integer,
  pricing_snapshot jsonb not null,
  status text not null default 'issued',
  created_at timestamptz not null default timezone('utc', now()),
  unique (quote_request_id, version)
);
create index idx_quotes_quote_request_id on quotes(quote_request_id);

comment on column quotes.quote_ref is
  'No prefix format given for quotes in CLAUDE.md''s reference list — '
  'plain unique text, no auto-generator wired up. Confirm format before '
  'relying on one.';

comment on column quotes.pricing_snapshot is
  'Immutable snapshot of the rates/inputs used to compute this quote '
  '— Master Spec §10: "Issued quotes retain immutable pricing '
  'snapshots." Application code must never mutate a quote row''s '
  'commercial fields after issue; a price change means a new version.';

comment on column quotes.status is
  'No fixed value list given in the source docs — plain text for now '
  '(e.g. issued / accepted / expired / superseded are plausible, not '
  'specified). Confirm before constraining.';
