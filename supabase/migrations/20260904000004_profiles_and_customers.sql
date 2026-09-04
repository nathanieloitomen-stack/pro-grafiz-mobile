-- PG-003: Staff/user profiles and customers. Master Spec §7.
--
-- No RLS policies are added here — Row Level Security is explicitly a
-- separate task (PG-005 Authorization/RLS per the Master Spec §17 task
-- sequence and CLAUDE.md). This migration creates structure only.

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  initials text,
  role role_enum not null,
  branch_id uuid references branches(id) on delete restrict,
  phone text,
  email text,
  pin_hash text, -- hash only, never plaintext — see CLAUDE.md "Secrets" and "Security is server-side"
  active boolean not null default true,
  first_login_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index idx_profiles_branch_id on profiles(branch_id);
create index idx_profiles_role on profiles(role);

create trigger trg_profiles_updated_at
  before update on profiles
  for each row execute function set_updated_at();

comment on column profiles.pin_hash is
  'Password/PIN hash only. Never store or log a plaintext PIN anywhere '
  '— CLAUDE.md "Secrets" is explicit on this. Hashing algorithm/parameters '
  'are a PG-004 (Authentication) decision, not fixed here.';

create table customers (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid references auth.users(id) on delete set null,
  customer_ref text not null unique,
  full_name text not null,
  phone text,
  email text,
  default_branch_id uuid references branches(id) on delete restrict,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index idx_customers_default_branch_id on customers(default_branch_id);
create index idx_customers_auth_user_id on customers(auth_user_id);

create trigger trg_customers_updated_at
  before update on customers
  for each row execute function set_updated_at();

comment on column customers.customer_ref is
  'Human-readable customer reference. CLAUDE.md''s reference-format list '
  '(PGLCxxxx, PGMXxxxx, QR-xxxx, PG-xxxx, PGJO-xxxx, PGAO-xxxx) does not '
  'cover customers — no auto-generator is wired up here; confirm a format '
  'with the product owner before relying on one. Enforced unique in the '
  'meantime as plain text.';
