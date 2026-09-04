-- PG-003: Payments. Master Spec §7 and §13; CLAUDE.md "PAYMENT RULES".

create table payments (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete restrict,
  payment_ref text not null unique,
  gateway_ref text,
  bank_reference text,
  kind text not null,
  amount_kobo bigint not null,
  status payment_status_enum not null default 'pending',
  matched_at timestamptz,
  confirmed_by uuid references profiles(id) on delete set null,
  confirmed_at timestamptz,
  gateway_payload jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  constraint chk_payments_no_match_not_auto_confirmed
    check (not (status = 'no_match' and confirmed_by is null and confirmed_at is not null))
);
create index idx_payments_job_id on payments(job_id);
create index idx_payments_status on payments(status);

comment on table payments is
  'CLAUDE.md "PAYMENT RULES": NO MATCH cannot be confirmed '
  'automatically; accountant confirmation requires a fresh challenge '
  '(PIN re-entry — an application-layer flow, not something a database '
  'constraint can enforce); payment screenshots never confirm payment. '
  'The check constraint here is a narrow defense-in-depth guard against '
  'a NO MATCH row acquiring confirmed_at with no confirmed_by actor — it '
  'does not by itself guarantee the fresh-challenge rule, which belongs '
  'in the payment confirmation service (PG-009).';

comment on column payments.payment_ref is
  'No prefix format given for payments in CLAUDE.md''s reference list — '
  'plain unique text, no auto-generator wired up. Confirm format before '
  'relying on one.';

comment on column payments.kind is
  'No fixed value list given in the source docs. quotes.deposit_kobo / '
  'quotes.balance_kobo (Master Spec §7) suggest ''deposit'' and '
  '''balance'' are likely values, but that''s an inference from an '
  'adjacent table, not a specified enum — left as text, confirm before '
  'constraining.';

create table payment_events (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references payments(id) on delete cascade,
  provider text not null,
  event_type text not null,
  provider_event_id text not null unique,
  payload jsonb not null,
  received_at timestamptz not null default timezone('utc', now())
);
create index idx_payment_events_payment_id on payment_events(payment_id);

comment on column payment_events.provider_event_id is
  'UNIQUE by design — this is the idempotency key for webhook '
  'processing. CLAUDE.md "Idempotency": "Provider event IDs and '
  'business operations must be idempotent." A duplicate webhook '
  'delivery should fail this unique constraint (or be checked '
  'beforehand) rather than reprocess.';
