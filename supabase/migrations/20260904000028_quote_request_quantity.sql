-- PG-007: quote_requests.quantity — schema gap fix.
--
-- Master Spec §12 explicitly names "quantity" as an authoritative quote
-- engine input, but no column for it exists anywhere in PG-003's
-- quote_requests table. Unlike the pricing formula itself, this is not
-- a business decision — "how many of this item" is an unambiguous,
-- structurally necessary field regardless of what the eventual pricing
-- formula looks like. Defaulting to 1 preserves every existing
-- assumption elsewhere in the schema (nothing else was multiplying by
-- quantity before now).
--
-- "Urgency" and "customer type" are also named in §12's input list and
-- have the same gap — NOT added here. Unlike quantity, their valid
-- value sets are genuine open business decisions (what tiers? what
-- values?), so adding a column would mean inventing a categorization
-- scheme. See docs/quote-engine.md — both are accepted as optional,
-- unvalidated metadata by the quote engine functions and stored only in
-- the pricing_snapshot for now, not given a schema column.

alter table quote_requests
  add column quantity integer not null default 1
  constraint chk_quote_requests_quantity_positive check (quantity >= 1);
