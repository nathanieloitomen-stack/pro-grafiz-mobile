# Database Schema

**Status: not started. Owned by PG-003.**

No migrations exist yet (`supabase/migrations/` is empty). This document
will hold, once PG-003 lands:

- Entity-relationship overview
- Table-by-table reference (columns, types, constraints, indexes)
- RLS policy summary per table (cross-referenced with PG-005)
- Naming conventions for human-readable business references
  (`PGLCxxxx`, `PGMXxxxx`, `QR-xxxx`, `PG-xxxx`, `PGJO-xxxx`, `PGAO-xxxx`)

The authoritative table list (26 tables: `branches`, `profiles`,
`pattern_categories`, `patterns`, `pattern_assets`, `materials`,
`material_thicknesses`, `finishes`, `customers`, `sketches`,
`quote_requests`, `quotes`, `jobs`, `job_stage_history`,
`design_revisions`, `drafts`, `draft_checks`, `payments`,
`payment_events`, `documents`, `dxf_release_grants`,
`dxf_download_logs`, `notifications`, `devices`, `offline_actions`,
`audit_events`) is defined in `PRO_GRAFIZ_MASTER_SPEC.md`, Section 7.
Treat that section as authoritative until this document is populated by
PG-003; do not hand-edit production schema outside a migration.
