-- PG-006: pattern_favourites — gap-fill table.
--
-- Master Spec §6 V1 scope names "favourites" explicitly ("Home,
-- catalogue, categories, search and favourites"), and the approved
-- design (Patterns screen, handoff README screen #2: "saved count...
-- heart overlay top-right") requires per-customer favouriting plus a
-- per-pattern saved-count shown to everyone. No table for this exists
-- anywhere in Master Spec §7's enumerated schema — same situation as
-- the `blends` gap-fill in PG-003 (20260904000005_catalogue.sql):
-- filling a structural gap the spec's own feature list requires, not
-- inventing a new feature.
--
-- This migration only ADDS a new table with its own fresh RLS policies
-- — it does not modify, weaken, or touch any existing PG-005 policy on
-- any other table.

create table pattern_favourites (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade,
  pattern_id uuid not null references patterns(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  unique (customer_id, pattern_id)
);
create index idx_pattern_favourites_customer_id on pattern_favourites(customer_id);
create index idx_pattern_favourites_pattern_id on pattern_favourites(pattern_id);

alter table pattern_favourites enable row level security;

-- A customer manages only their own favourites. Staff get no special
-- access here at all — there is no legitimate staff reason to read or
-- write another person's saved-patterns list, unlike most other
-- customer-owned tables in this schema.
create policy pattern_favourites_select_own on pattern_favourites
  for select using (customer_id = current_customer_id());
create policy pattern_favourites_insert_own on pattern_favourites
  for insert with check (customer_id = current_customer_id());
create policy pattern_favourites_delete_own on pattern_favourites
  for delete using (customer_id = current_customer_id());

-- Deliberately no UPDATE policy — a favourite is either present or
-- absent (insert/delete), never edited in place.

-- The Patterns screen shows an aggregate "saved count" per pattern to
-- EVERYONE, without revealing who favourited it. A plain view over a
-- table with row-owner-only RLS does not itself leak individual rows:
-- Postgres views default to the view OWNER's privileges (not the
-- querying user's) unless created with security_invoker, so this
-- aggregate resolves correctly for any caller while the underlying
-- table's per-row RLS still fully applies to any direct query against
-- pattern_favourites itself.
create view pattern_favourite_counts as
  select pattern_id, count(*) as favourite_count
  from pattern_favourites
  group by pattern_id;

grant select on pattern_favourite_counts to anon, authenticated;
