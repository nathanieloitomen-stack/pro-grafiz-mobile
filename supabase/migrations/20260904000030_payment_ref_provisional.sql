-- PG-009: payments.payment_ref — provisional generator.
--
-- Same treatment as customers.customer_ref (PG-004) and quotes.quote_ref
-- (PG-007): no format was ever given anywhere in the docs for
-- payment_ref, flagged since PG-003. A placeholder to satisfy the NOT
-- NULL UNIQUE constraint, not a confirmed final format.

create sequence payment_ref_provisional_seq start 1;

create or replace function generate_payment_ref_provisional()
returns text
language sql
as $$
  select 'PMT-' || lpad(nextval('payment_ref_provisional_seq')::text, 6, '0');
$$;
comment on function generate_payment_ref_provisional() is
  'PROVISIONAL prefix (PMT-) — not specified anywhere in the docs. '
  'Confirm the real format with the product owner before production.';
