-- Development-only seed data. NOT for production.
--
-- Per CLAUDE.md ("PGLC CATALOGUE"): "Development seed assets must be
-- clearly marked as development data." Every row here uses a DEV-
-- prefixed code/reference so it's obviously non-production, and this
-- script only covers lookup/reference and catalogue tables — no
-- customers, quotes, jobs, or payments, since fabricating those would
-- mean inventing business scenarios rather than just enabling local
-- development against the schema.
--
-- storage_path values below point at paths that do not exist in any
-- real bucket — they exist only so pattern_assets rows have something
-- to point at locally. Do not treat them as real files.

insert into branches (code, name, address, active) values
  ('DEV-BR1', 'Dev Branch One', '123 Development Way', true),
  ('DEV-BR2', 'Dev Branch Two', '456 Development Way', true);

insert into pattern_categories (code, name, description, min_thickness_mm, allowed_materials, active) values
  ('DEV-CAT1', 'Dev Category One', 'Development-only category for local testing.', 1.0, '["mild_steel", "stainless"]'::jsonb, true),
  ('DEV-CAT2', 'Dev Category Two', 'Development-only category for local testing.', 2.0, '["aluminium"]'::jsonb, true);

insert into materials (code, name, active) values
  ('DEV-MS', 'Dev Mild Steel', true),
  ('DEV-SS', 'Dev Stainless Steel', true);

insert into material_thicknesses (material_id, thickness_mm, active)
select id, t, true
from materials, unnest(array[1.5, 2.0, 3.0]) as t
where code in ('DEV-MS', 'DEV-SS');

insert into finishes (code, name, pricing_multiplier, active) values
  ('DEV-RAW', 'Dev Raw Finish', 1.0, true),
  ('DEV-PWD', 'Dev Powder Coat', 1.2, true);

insert into patterns (name, category_id, geometry_family, density, typical_uses, engineering_note, active)
select
  'Dev Pattern One',
  id,
  'geometric',
  'medium',
  'Local development and UI testing only.',
  'Not production-ready — placeholder geometry.',
  true
from pattern_categories where code = 'DEV-CAT1';

insert into pattern_assets (pattern_id, asset_type, storage_path, production_ready, version)
select id, 'preview', 'dev-seed/patterns/dev-pattern-one/preview.png', false, 1
from patterns where name = 'Dev Pattern One';
