-- PG-003: Documents (PGJO/PGAO) and DXF governance. Master Spec §7, §14, §16.

create sequence pgjo_ref_seq start 1;
create sequence pgao_ref_seq start 1;

create or replace function set_document_ref()
returns trigger
language plpgsql
as $$
begin
  if new.document_ref is not null then
    return new;
  end if;

  if new.type = 'PGJO' then
    new.document_ref := 'PGJO-' || lpad(nextval('pgjo_ref_seq')::text, 6, '0');
  elsif new.type = 'PGAO' then
    new.document_ref := 'PGAO-' || lpad(nextval('pgao_ref_seq')::text, 6, '0');
  else
    raise exception 'Unknown document type: %', new.type;
  end if;

  return new;
end;
$$;
comment on function set_document_ref() is
  'document_ref format fixed by CLAUDE.md: PGJO-xxxx / PGAO-xxxx, '
  'chosen by document type. A trigger is required rather than a plain '
  'column DEFAULT because the prefix depends on another column (type) '
  'in the same row.';

create table documents (
  id uuid primary key default gen_random_uuid(),
  document_ref text unique,
  job_id uuid not null references jobs(id) on delete restrict,
  type document_type_enum not null,
  event_key text not null unique,
  storage_path text not null,
  issue_date timestamptz not null default timezone('utc', now()),
  authorised_by uuid references profiles(id) on delete set null,
  authorisation_type text,
  created_at timestamptz not null default timezone('utc', now())
);
create index idx_documents_job_id on documents(job_id);

create trigger trg_documents_set_ref
  before insert on documents
  for each row execute function set_document_ref();

comment on column documents.event_key is
  'Idempotency key — Master Spec §10: "PGJO and PGAO generation is '
  'idempotent." Application code should derive this deterministically '
  'from (job_id, type, triggering event) so a retried generation '
  'request hits this unique constraint instead of creating a duplicate '
  'document.';

create table dxf_release_grants (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete restrict,
  pattern_id uuid not null references patterns(id) on delete restrict,
  month_key text not null,
  expires_at timestamptz not null,
  issued_by uuid references profiles(id) on delete set null,
  release_code_hash text not null,
  used_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);
create index idx_dxf_release_grants_customer_id on dxf_release_grants(customer_id);
create index idx_dxf_release_grants_pattern_id on dxf_release_grants(pattern_id);

comment on table dxf_release_grants is
  'Master Spec §14: monthly release codes may remain as a licensing '
  'feature but must not be the sole security mechanism — pair with the '
  'signed-URL + backend authorization flow. release_code_hash is a '
  'hash, never the plaintext code, consistent with CLAUDE.md "Secrets".';

create table dxf_download_logs (
  id uuid primary key default gen_random_uuid(),
  grant_id uuid references dxf_release_grants(id) on delete set null,
  customer_id uuid not null references customers(id) on delete restrict,
  pattern_id uuid not null references patterns(id) on delete restrict,
  ip_hash text,
  user_agent text,
  downloaded_at timestamptz not null default timezone('utc', now())
);
create index idx_dxf_download_logs_customer_id on dxf_download_logs(customer_id);

comment on column dxf_download_logs.ip_hash is
  'Hash, not the raw IP — avoids storing directly identifying data in a '
  'long-lived audit-style log while still supporting abuse detection.';
