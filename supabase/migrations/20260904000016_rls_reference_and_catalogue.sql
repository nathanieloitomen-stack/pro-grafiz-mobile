-- PG-005: RLS — reference/lookup and catalogue tables.
-- branches, pattern_categories, materials, material_thicknesses,
-- finishes, patterns, pattern_assets, blends, blend_patterns.

alter table branches enable row level security;
alter table pattern_categories enable row level security;
alter table materials enable row level security;
alter table material_thicknesses enable row level security;
alter table finishes enable row level security;
alter table patterns enable row level security;
alter table pattern_assets enable row level security;
alter table blends enable row level security;
alter table blend_patterns enable row level security;

-- branches: names/addresses are not sensitive; the customer app needs
-- them for branch selection and the doc viewer ("verify at the Idu
-- centre"). Read is public; write is Super Admin only (branch
-- creation/renaming is an admin operation, not specified elsewhere).
create policy branches_select_all on branches
  for select using (true);
create policy branches_write_super_admin on branches
  for all using (is_super_admin()) with check (is_super_admin());

-- pattern_categories / materials / material_thicknesses / finishes:
-- same shape — active rows are public (needed for catalogue browsing
-- and the quote builder's material/thickness/finish pickers before a
-- customer necessarily has an account), inactive rows are staff-only,
-- writes are Super Admin only (Master Spec §6 V1 scope: "Catalogue
-- administration" is a staff/admin feature).
create policy pattern_categories_select on pattern_categories
  for select using (active or is_active_staff());
create policy pattern_categories_write_super_admin on pattern_categories
  for all using (is_super_admin()) with check (is_super_admin());

create policy materials_select on materials
  for select using (active or is_active_staff());
create policy materials_write_super_admin on materials
  for all using (is_super_admin()) with check (is_super_admin());

create policy material_thicknesses_select on material_thicknesses
  for select using (active or is_active_staff());
create policy material_thicknesses_write_super_admin on material_thicknesses
  for all using (is_super_admin()) with check (is_super_admin());

create policy finishes_select on finishes
  for select using (active or is_active_staff());
create policy finishes_write_super_admin on finishes
  for all using (is_super_admin()) with check (is_super_admin());

-- patterns: active patterns are the public catalogue. Inactive/draft
-- patterns are staff-only (so half-finished catalogue entries don't
-- leak). Writes: Super Admin only, per the same V1 scope note above —
-- if Designer should also be able to edit pattern metadata directly,
-- that's a narrower grant to add later; defaulting to the stricter
-- single-role write here.
create policy patterns_select on patterns
  for select using (active or is_active_staff());
create policy patterns_write_super_admin on patterns
  for all using (is_super_admin()) with check (is_super_admin());

-- pattern_assets: this is the one place in the catalogue tables that
-- needs a genuine security boundary. DXF is production geometry — per
-- CLAUDE.md, "Never expose private production DXF files without
-- backend authorization." Non-DXF, production-ready assets (previews,
-- thumbnails, SVGs used for on-screen rendering) are public. DXF rows,
-- and anything not yet production_ready, are staff-only — and even for
-- staff, this is row visibility only; it does not itself implement the
-- signed-URL download flow Master Spec §14 describes for actually
-- fetching the file content from Storage. That's a later PG task.
create policy pattern_assets_select_public on pattern_assets
  for select using (
    production_ready and asset_type <> 'dxf'
  );
create policy pattern_assets_select_staff on pattern_assets
  for select using (is_active_staff());
create policy pattern_assets_write_staff on pattern_assets
  for all using (is_super_admin() or is_designer())
  with check (is_super_admin() or is_designer());

-- blends: composed of public patterns, contain no pricing/customer
-- data by themselves (pricing happens at the quote_request/quote level,
-- which IS properly customer-scoped — see 20260904000018). Readable by
-- anyone authenticated. Creatable by anyone authenticated: staff attach
-- their own profile id, customers must leave created_by null.
--
-- KNOWN LIMITATION: blends has no customer/owner column (see
-- 20260904000005_catalogue.sql's gap-fill note — the Master Spec never
-- enumerated this table, so its shape is provisional). Without an
-- owner column, blend_patterns cannot be strictly ownership-scoped in
-- this pass: any authenticated user can modify any blend's pattern
-- list. This is an accepted interim gap, not an oversight — flagged
-- here for a schema follow-up (adding blends.customer_id) rather than
-- silently working around it. Blends are not financial or personally
-- identifying, which limits the real-world impact while this is open.
create policy blends_select_authenticated on blends
  for select using (auth.uid() is not null);
create policy blends_insert_authenticated on blends
  for insert with check (
    auth.uid() is not null
    and (created_by is null or created_by = auth.uid())
  );

create policy blend_patterns_select_authenticated on blend_patterns
  for select using (auth.uid() is not null);
create policy blend_patterns_write_authenticated on blend_patterns
  for all using (auth.uid() is not null) with check (auth.uid() is not null);
