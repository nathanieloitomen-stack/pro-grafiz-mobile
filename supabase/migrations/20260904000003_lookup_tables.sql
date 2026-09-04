-- PG-003: Reference/lookup tables. Master Spec §7.

create table branches (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  address text,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);
comment on table branches is 'Pro_Grafiz customer centres (Master Spec §7).';

create table pattern_categories (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  min_thickness_mm numeric(6,2),
  allowed_materials jsonb not null default '[]'::jsonb,
  active boolean not null default true
);
comment on table pattern_categories is
  'Category → material/thickness envelope guidance (Master Spec §11).';

create table materials (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  active boolean not null default true
);

create table material_thicknesses (
  id uuid primary key default gen_random_uuid(),
  material_id uuid not null references materials(id) on delete restrict,
  thickness_mm numeric(6,2) not null,
  active boolean not null default true,
  unique (material_id, thickness_mm)
);
create index idx_material_thicknesses_material_id on material_thicknesses(material_id);

create table finishes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  pricing_multiplier numeric(6,3) not null default 1.0,
  active boolean not null default true
);
