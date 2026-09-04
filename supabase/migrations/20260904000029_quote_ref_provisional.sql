-- PG-007: quotes.quote_ref — provisional generator.
--
-- Flagged in PG-003's docs/database-schema.md: no format was given
-- anywhere in the docs for quote_ref, unlike patterns/quote_requests/
-- jobs/documents which CLAUDE.md fixes explicitly. Same treatment as
-- customers.customer_ref's provisional CUST- prefix from PG-004: a
-- placeholder needed to satisfy the NOT NULL UNIQUE constraint so
-- issue-quote can actually create rows, not a confirmed final format.
-- Confirm the real format with the product owner before production.

create sequence quote_ref_provisional_seq start 1;

create or replace function generate_quote_ref_provisional()
returns text
language sql
as $$
  select 'QT-' || lpad(nextval('quote_ref_provisional_seq')::text, 6, '0');
$$;
comment on function generate_quote_ref_provisional() is
  'PROVISIONAL prefix (QT-) — not specified anywhere in the docs. '
  'Confirm the real format with the product owner before production.';
