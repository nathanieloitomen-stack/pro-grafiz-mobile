-- PG-006: Storage buckets for PGLC catalogue assets.
--
-- pattern_assets rows have existed since PG-003, but no actual Storage
-- bucket has ever been created for them to point at — the catalogue
-- can't serve a single image without one. Master Spec §3 says storage
-- is "private Supabase Storage buckets" generically, but §14's DXF
-- governance section specifically contrasts DXF (private, signed-URL,
-- backend-authorized) against preview/PNG/SVG assets (meant to be
-- publicly browsable in the catalogue). Treating every asset type as
-- equally private would make Browse/Search (this task's whole point)
-- impossible without a signed-URL round trip per thumbnail — so two
-- buckets, matching the split already encoded in pattern_assets' RLS
-- (20260904000016_rls_reference_and_catalogue.sql):
--
--   pglc-public      — preview/thumbnail/svg assets, public read
--   pglc-production   — dxf assets, private, staff-only via Storage RLS
--                        (this is bucket-level access only; the actual
--                        signed-URL issuance flow Master Spec §14
--                        describes is not built yet — later PG task)
--
-- This is an infrastructure decision made to unblock PG-006, not
-- something dictated verbatim by the docs — flagged plainly. It adds
-- new Storage policies only; no existing table RLS is touched.

insert into storage.buckets (id, name, public)
values ('pglc-public', 'pglc-public', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('pglc-production', 'pglc-production', false)
on conflict (id) do nothing;

-- storage.objects already has RLS enabled by Supabase itself on every
-- project — these policies are additive, scoped to just these two
-- bucket_ids, and don't touch any policy Supabase or a later PG task
-- adds for other buckets.

create policy pglc_public_read on storage.objects
  for select using (bucket_id = 'pglc-public');

create policy pglc_public_write_staff on storage.objects
  for insert with check (bucket_id = 'pglc-public' and (is_super_admin() or is_designer()));
create policy pglc_public_update_staff on storage.objects
  for update using (bucket_id = 'pglc-public' and (is_super_admin() or is_designer()));
create policy pglc_public_delete_staff on storage.objects
  for delete using (bucket_id = 'pglc-public' and (is_super_admin() or is_designer()));

-- pglc-production (DXF): staff-only for everything, no public policy at
-- all. Row visibility for pattern_assets metadata is already handled
-- at the table level; this is the matching bucket-level restriction so
-- the actual file bytes get the same treatment.
create policy pglc_production_staff_only on storage.objects
  for all using (bucket_id = 'pglc-production' and is_active_staff())
  with check (bucket_id = 'pglc-production' and (is_super_admin() or is_designer() or is_production()));
