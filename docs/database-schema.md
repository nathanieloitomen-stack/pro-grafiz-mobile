# Database Schema

**Status: PG-003 (schema) and PG-005 (RLS) complete.** 28 tables across
24 migrations in `supabase/migrations/`. RLS is enabled on every table
with explicit policies — see [`docs/authorization.md`](./authorization.md)
for the full design and, critically, which claims are verified locally
vs. still require a live Supabase project. This migration set was
authored without a live Postgres instance or the Supabase CLI (no
network access) — see "Verification" below before trusting it applies
cleanly.

## Migration order

| File | Contents |
|---|---|
| `20260904000001_extensions_and_functions.sql` | `pgcrypto`, shared `set_updated_at()` trigger |
| `20260904000002_enums.sql` | `role_enum`, `job_stage_enum`, `job_status_enum`, `payment_status_enum`, `document_type_enum`, `asset_type_enum`, `check_result_enum` |
| `20260904000003_lookup_tables.sql` | `branches`, `pattern_categories`, `materials`, `material_thicknesses`, `finishes` |
| `20260904000004_profiles_and_customers.sql` | `profiles`, `customers` |
| `20260904000005_catalogue.sql` | `patterns`, `pattern_assets`, **`blends`, `blend_patterns`** (see Gap-fill below) |
| `20260904000006_sketches_and_quoting.sql` | `sketches`, `quote_requests`, `quotes` |
| `20260904000007_jobs.sql` | `jobs`, `job_stage_history`, `design_revisions` |
| `20260904000008_drafts_and_cad.sql` | `drafts`, `draft_checks` |
| `20260904000009_payments.sql` | `payments`, `payment_events` |
| `20260904000010_documents_and_dxf.sql` | `documents`, `dxf_release_grants`, `dxf_download_logs` |
| `20260904000011_notifications_and_offline.sql` | `notifications`, `devices`, `offline_actions` |
| `20260904000012_audit.sql` | `audit_events` |
| `20260904000013_staff_authentication.sql` | Drops `profiles.pin_hash`; adds `auth_login_handle`, `invite_token_hash`, `invite_token_expires_at`; invite-token crypto helpers |
| `20260904000014_customer_authentication.sql` | Provisional `customer_ref` generator; `auth.users` trigger auto-provisioning `customers` on phone signup |
| `20260904000015_authorization_helpers.sql` | SECURITY DEFINER role/branch-check functions (PG-005) |
| `20260904000016`–`20260904000024` | RLS policies for all 28 tables (PG-005) — see `docs/authorization.md` |
| `20260904000025_pattern_favourites.sql` | `pattern_favourites` table + `pattern_favourite_counts` view (PG-006 gap-fill) |
| `20260904000026_pglc_storage_buckets.sql` | `pglc-public`/`pglc-production` Storage buckets (PG-006) |
| `20260904000027_pricing_configuration.sql` | `pricing_rates`, `commercial_settings` — empty, configurable rate tables (PG-007) |
| `20260904000028_quote_request_quantity.sql` | `quote_requests.quantity` column (PG-007 gap fix) |
| `20260904000029_quote_ref_provisional.sql` | Provisional `quote_ref` generator (PG-007) |
| `20260904000030_payment_ref_provisional.sql` | Provisional `payment_ref` generator (PG-009) |
| `20260904000031_job_drafts_storage_and_dxf_gate.sql` | `job-drafts` Storage bucket; `staff_get_draft_dxf_path()` refined for Production role (PG-010) |
| `20260904000032_job_documents_storage.sql` | `job-documents` Storage bucket (PG-011) |
| `20260904000033_quote_request_notification_trigger.sql` | Notify branch Centre Manager on new `quote_request` (PG-013) |

All 26 tables from `PRO_GRAFIZ_MASTER_SPEC.md` §7 exist, plus two
gap-fill tables (below). UUID primary keys (`gen_random_uuid()`,
built into Postgres 13+, no extension needed), foreign keys, indexes on
every FK column, and `timestamptz` timestamps defaulting to
`timezone('utc', now())` throughout, per the Master Spec's general
schema conventions.

## Gap-fill: `blends` and `blend_patterns`

Master Spec §7 does not enumerate a `blends` table, but
`quote_requests.blend_id` and `jobs.blend_id` — both defined in that
same section — clearly reference one, and `CLAUDE.md`'s business rules
independently state: "Blends contain 2–3 patterns; order is
significant." Two tables were added to satisfy that:

- `blends` — minimal header row
- `blend_patterns` — join table with an ordered `position` (1–3), plus a
  deferred constraint trigger (`trg_check_blend_pattern_count`) enforcing
  the 2–3 count at transaction commit

This fills a structural gap using a rule already stated elsewhere in the
provided docs, not an invented one — but it wasn't in the enumerated
table list, so treat the exact shape as provisional until the product
owner confirms it.

## Human-readable references

`CLAUDE.md` fixes four prefix formats explicitly: `PGLCxxxx` (patterns),
`QR-xxxx` (quote requests), `PG-xxxx` (jobs), `PGJO-xxxx` / `PGAO-xxxx`
(documents, by type). All four are implemented as sequence-backed
generator functions with column defaults (or a `BEFORE INSERT` trigger
for documents, since the prefix depends on the row's own `type` column).

Three reference-like columns exist in the schema with **no format given
anywhere in the provided docs**: `quotes.quote_ref`, `payments.payment_ref`,
and `customers.customer_ref` — the last of these now has a **provisional**
generator (`CUST-xxxxxx`) added in PG-004 to unblock customer signup;
see `docs/authentication.md`. `PGMXxxxx`, listed in `CLAUDE.md` but not
mapped to any specific table in the Master Spec's §7 list, is still
unaddressed.

## Columns left as plain `text` instead of an enum

Per `CLAUDE.md`: "Never invent business rules just to keep coding."
Enums were only created where the source docs give an explicit, closed
value list. Everywhere a status-like column exists without one, it's
`text` with a comment in the migration explaining what's known and what
isn't:

- `sketches.status`, `quote_requests.status`, `quotes.status`,
  `design_revisions.status`, `drafts.release_status`,
  `devices.sync_state`, `offline_actions.status`, `payments.kind`,
  `notifications.type`

`jobs.status` (`active` / `on_hold` / `cancelled`) is the one exception
made an enum despite no explicit list — it's a direct structural
inference from the `hold_reason`/`cancel_reason` columns the Master Spec
itself already defines, not new logic. Flagged in the migration comment
regardless.

## Two open modeling questions, flagged rather than guessed

- `design_revisions.requested_by` references `profiles(id)`, but the
  customer-approval flow (Master Spec's customer journey) implies a
  customer can request a change, and customers aren't `profiles` rows.
  May need a second nullable FK to `customers(id)` once that flow is
  designed.
- `notifications.recipient_user_id` and `devices.user_id` reference
  `auth.users(id)` directly (rather than `profiles` or `customers`)
  since a recipient/device can be either staff or a customer — `auth.users`
  is the one table both sides join back to.

## Verification

Not run against a live database — there was no Postgres instance or
Supabase CLI available while authoring this. Every file was checked by
hand for parenthesis/quote balance and reviewed for referential order
(each migration only references tables created in the same or an
earlier file). Before relying on this:

```bash
supabase start        # or point at a real Postgres instance
supabase db reset      # applies all migrations, then supabase/seed/
```

Confirm it applies cleanly end-to-end and fix forward with a new
migration file if anything doesn't — don't hand-edit an already-applied
migration, per `CLAUDE.md`: "Every schema change requires a migration."
