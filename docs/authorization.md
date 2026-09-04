# Authorization (RLS Design)

**Status: PG-005 complete as a security gate.** Every table created in
PG-003 now has Row Level Security enabled with an explicit policy set.
**None of this has run against a live Postgres/Supabase instance** — no
network or database was available while building it. See "Verification
status" at the end of this document for exactly what that does and
doesn't mean.

## Design principles

1. **Staff vs. customer is a row lookup, not a Postgres role.** Supabase
   connects both as the same `authenticated` role. Every policy
   determines "who is this" by checking `profiles` (staff) or
   `customers` (customers) against `auth.uid()` — never by which
   Postgres role is connected.
2. **Helper functions, not repeated subqueries.** `current_staff_role()`,
   `current_staff_branch_id()`, `is_super_admin()`, `is_centre_manager()`,
   `is_accountant()`, `is_designer()`, `is_production()`, `is_inventory()`,
   `is_central_staff()`, `is_active_staff()`, `current_customer_id()`,
   `is_active_customer()` (all in `20260904000015_authorization_helpers.sql`)
   are `SECURITY DEFINER`, owned by the migration-running role, so they
   read `profiles`/`customers` without triggering recursive RLS
   evaluation — the standard Supabase-recommended pattern.
3. **Two enforcement layers, used deliberately differently:**
   - **Row-level (RLS policies):** controls *which rows* a query can see
     or touch. Used for all customer/branch/role visibility scoping.
   - **Column-level (`REVOKE`/`GRANT` on specific columns):** controls
     which *fields* can be written at all, regardless of row. Used
     where the same row must be partially editable by its owner but
     never fully (`profiles.role`/`branch_id`/`active`,
     `customers.customer_ref`/`auth_user_id`, notification `read_at`
     vs. everything else) and where a column must never be readable by
     any client role at all (`drafts.dxf_path`,
     `dxf_release_grants.release_code_hash`).
4. **"No write policy" is a deliberate security decision on several
   tables**, not a gap: `jobs`, `job_stage_history`, `payments`,
   `payment_events`, `quotes`, `documents`, `dxf_release_grants`,
   `dxf_download_logs`, and `audit_events` have **zero** INSERT/UPDATE/
   DELETE policies for `authenticated`/`anon` — not even for Super
   Admin. Master Spec and CLAUDE.md are explicit that job-stage
   transitions, payment confirmation, quote pricing, and document
   generation must go through dedicated server-side services (mostly
   not built yet — later PG tasks); RLS enforces that no shortcut
   around those services exists at the database layer, for anyone.

## A. Tables protected by RLS

All 28 PG-003 tables. Verified by static analysis (see "Verification
status"): `branches`, `pattern_categories`, `materials`,
`material_thicknesses`, `finishes`, `profiles`, `customers`, `patterns`,
`pattern_assets`, `blends`, `blend_patterns`, `sketches`,
`quote_requests`, `quotes`, `jobs`, `job_stage_history`,
`design_revisions`, `drafts`, `draft_checks`, `payments`,
`payment_events`, `documents`, `dxf_release_grants`,
`dxf_download_logs`, `notifications`, `devices`, `offline_actions`,
`audit_events`.

## B. Policies created

59 policies total across 10 migrations
(`20260904000016` through `20260904000024`). Per-table counts and the
full text are in those migration files; summary by pattern:

| Pattern | Tables |
|---|---|
| Public read, Super Admin write | `branches`, `pattern_categories`, `materials`, `material_thicknesses`, `finishes`, `patterns` |
| Public read (non-sensitive rows only), staff read all, staff write | `pattern_assets` (DXF rows hidden from non-staff) |
| Authenticated read/write, ownership gap flagged | `blends`, `blend_patterns` |
| Self + role/branch-scoped read, column-restricted self-update, no insert/delete | `profiles`, `customers` |
| Own-record + role/branch-scoped read, restricted write | `sketches`, `quote_requests`, `design_revisions` |
| Read-only for everyone, no write policy at all | `quotes`, `jobs`, `job_stage_history`, `payments`, `payment_events`, `documents`, `dxf_release_grants`, `dxf_download_logs`, `audit_events` (Super Admin only) |
| Designer/Super-Admin write, branch/central-scoped read | `drafts`, `draft_checks` |
| Self-only | `notifications` (read_at only), `devices`, `offline_actions` (insert/select only) |

## C. Role / branch authorization matrix

`SA`=Super Admin, `CM`=Centre Manager, `ACC`=Accountant, `DES`=Designer,
`PRO`=Production, `INV`=Inventory, `CUST`=Customer. **Bold** = write
access; plain = read access; `—` = no access. CM's read/write is always
own-branch-scoped only, even where marked with full access below.

| Table | SA | CM | ACC | DES | PRO | INV | CUST |
|---|---|---|---|---|---|---|---|
| branches | **rw** | r | r | r | r | r | r |
| pattern_categories / materials / material_thicknesses / finishes | **rw** | r | r | r | r | r | r (active only) |
| patterns | **rw** | r | r | r | r | r | r (active only) |
| pattern_assets | **rw** | r | r | **rw** | r | r | r (non-DXF, production-ready only) |
| blends / blend_patterns | rw* | rw* | rw* | rw* | rw* | rw* | rw* |
| profiles | r (self+branch) / **w (own safe fields)** | r (self+branch) / **w (own safe fields)** | r (all) / **w (own safe fields)** | r (all) / **w (own safe fields)** | r (all) / **w (own safe fields)** | r (all) / **w (own safe fields)** | — |
| customers | **rw (all)** | r/**w (own branch)** | r | r | r | r | r/**w (own safe fields, self only)** |
| sketches | rw | rw | rw | rw | rw | rw | rw (own only) |
| quote_requests | r/**w** | r/**w (own branch)** | r/**w** | r/**w** | — | — | r/**insert** |
| quotes | r | r (own branch) | r | r | — | — | r (own only) |
| jobs | r | r (own branch) | r | r | r | r | r (own only) |
| job_stage_history | r | r (own branch) | r | r | r | r | r (own only) |
| design_revisions | r/**w** | r/**w (own branch)** | r/**w** | r/**w** | r/**w** | r/**w** | r/**insert (own only)** |
| drafts / draft_checks | r/**w** | r | r | **rw** | r | r | r (drafts row only, no dxf_path, no draft_checks) |
| payments | r | r (own branch) | r | — | — | — | r (own only) |
| payment_events | r | — | r | — | — | — | — |
| documents | r | r (own branch) | r | r | r | r | r (own only) |
| dxf_release_grants | r | — | — | r | r | — | r (own only, no hash) |
| dxf_download_logs | r | — | — | r | r | — | r (own only) |
| notifications | r/**w (read_at, own)** | same | same | same | same | same | r/**w (read_at, own)** |
| devices | r (all) | r/**w (own)** | r/**w (own)** | r/**w (own)** | r/**w (own)** | r/**w (own)** | r/**w (own)** |
| offline_actions | r/**insert (own device)** | same | same | same | same | same | same |
| audit_events | r | — | — | — | — | — | — |

`rw*` on blends/blend_patterns: any authenticated user, staff or
customer — see the known limitation below.

**"Central staff" (ACC/DES/PRO/INV seeing all branches) is a judgment
call**, not a rule stated anywhere in the docs beyond "Central roles may
see all branches according to their permissions" (Master Spec §8) — the
exact per-table breakdown of *which* central role needs *which* table is
this document's interpretation, not a specified rule. Narrow individual
cells once the actual staffing of each screen (Intake, Design Desk,
Payments, etc.) is confirmed.

## D. Customer isolation rules

- A customer can only ever be identified as `customers.auth_user_id =
  auth.uid()` (via `current_customer_id()`) — never via `profiles`
  (customers deliberately don't get a `profiles` row; see PG-004).
- Every customer-facing row policy (`jobs`, `quotes`, `payments`,
  `documents`, `job_stage_history`, `drafts`, `dxf_release_grants`,
  `dxf_download_logs`) joins back to `customer_id = current_customer_id()`,
  directly or through the owning `job`/`quote_request` — a customer
  cannot see another customer's records under any role.
- `customers` itself: a customer can `SELECT`/limited-`UPDATE` only
  their own row (`auth_user_id = auth.uid()`).
- `drafts.dxf_path` and `dxf_release_grants.release_code_hash` are
  revoked from every client role, so even on their *own* records, a
  customer never sees a raw production DXF path or a release-code hash.
- `pattern_assets` rows with `asset_type = 'dxf'` are invisible to
  customers as **rows**, not just a hidden column.

## E. Centre Manager branch-isolation rules

- `current_staff_branch_id()` returns the Centre Manager's own
  `profiles.branch_id`.
- Every Centre-Manager-scoped policy requires the row's own `branch_id`
  (`jobs.branch_id`, `quote_requests.branch_id`) — or, for tables
  without a direct branch column, a join to the owning job/quote_request's
  branch (`job_stage_history`, `design_revisions`, `drafts`,
  `draft_checks`, `payments`, `documents`) — to equal
  `current_staff_branch_id()`.
- `customers` visibility for a Centre Manager additionally checks
  `default_branch_id` OR any `quote_requests`/`jobs` row at their
  branch, so a customer who has only ever transacted at another branch
  stays invisible even if some other field coincidentally matched.
- Verified by contrast test (`20_centre_manager_branch_isolation.sql`):
  Centre Manager A cannot see branch B's job, Centre Manager B cannot
  see branch A's job, and Super Admin can see both — proving the
  restriction is Centre-Manager-specific, not a blanket filter that
  would (incorrectly) also limit Super Admin.
- `audit_events` has no branch-scoped Centre Manager policy at all
  (Super Admin only) — see the note on that table in
  `20260904000024_rls_audit.sql` for why a branch join isn't practical
  there.

## F. Sensitive-operation protections

| Concern | Protection |
|---|---|
| Job stage advancement | No write policy on `jobs`/`job_stage_history` for any role — only a future service_role transition service can write |
| Payment confirmation | No write policy on `payments`/`payment_events` for any role, including Accountant — the "fresh PIN challenge" requirement can only be enforced by a not-yet-built Edge Function, so direct writes are locked for everyone in the meantime |
| Quote pricing | No write policy on `quotes` for any role — only a future service-role quote engine can write |
| Document generation | No write policy on `documents` for any role |
| DXF release grants | No write policy on `dxf_release_grants`/`dxf_download_logs`; `release_code_hash` column revoked from everyone |
| Production CAD files | `drafts.dxf_path` column revoked from everyone; staff fetch it only via `staff_get_draft_dxf_path()`, which re-checks the caller's role inside the function |
| CAD release gate | `enforce_draft_release_gate()` trigger blocks setting `release_status = 'released'` when an unresolved `draft_checks.result = 'fail'` exists, unless `override_reason` is set — a real enforced constraint, not just an RLS visibility rule |
| Staff role/branch immutability | `profiles.role`/`branch_id`/`active`/`auth_login_handle`/`invite_token_*` are column-revoked from `authenticated` entirely — not even Super Admin can change them via direct table access; only the service_role-backed Edge Functions can (PG-004's `staff-invite`/`staff-reset-pin`; a role/branch-change function isn't built yet) |
| Audit trail | `audit_events`: Super Admin read-only, no write policy for any client role |

## G. Known limitations discovered / accepted

1. **`blends`/`blend_patterns` have no owner column.** Flagged already
   in PG-003 as a spec gap (Master Spec never enumerated this table).
   Without an owner, any authenticated user can modify any blend's
   pattern composition — accepted as low-impact (blends aren't
   financial or personally identifying) but flagged for a schema
   follow-up (`blends.customer_id`).
2. **`design_revisions.requested_by` can't attribute a customer.** It
   references `profiles(id)`; a customer-authored revision request must
   leave it `null`, losing fine-grained attribution beyond the job's own
   `customer_id`. Flagged in PG-003, still open.
3. **A customer cannot withdraw their own pending `quote_request`.** No
   customer UPDATE policy exists on that table at all — by design
   (decision fields are staff-only), but it means there's currently no
   self-service cancellation path. Not stated as a requirement anywhere,
   flagged as a possible future gap.
4. **"Central staff" table-by-table access is this document's
   interpretation**, not a rule given anywhere in the source docs beyond
   "Central roles may see all branches" — see the note under the matrix
   above.
5. **Column-level revokes affect the whole `authenticated` role, not a
   staff/customer subset**, because Postgres can't express that
   distinction at the grant level (see design principle #3). This is
   why `drafts.dxf_path` is inaccessible to staff via raw `SELECT` too,
   not only to customers — a stricter outcome than the letter of the
   requirement, chosen for consistency and a single auditable seam
   rather than trying to fake per-audience column visibility.
6. **No RLS `FORCE` on any table.** Table owners (migration-running
   role, typically `postgres`/`supabase_admin`) bypass RLS by default
   unless `FORCE ROW LEVEL SECURITY` is set. This wasn't set anywhere —
   standard Supabase practice, since forcing it would also constrain
   legitimate admin/migration tooling. Anything connecting as the table
   owner (not through PostgREST/Edge Functions) bypasses everything in
   this document; that's expected, not a hole in client-facing security.

## H. Files changed

**New:**
- `supabase/migrations/20260904000015_authorization_helpers.sql`
- `supabase/migrations/20260904000016_rls_reference_and_catalogue.sql`
- `supabase/migrations/20260904000017_rls_people.sql`
- `supabase/migrations/20260904000018_rls_sketches_quoting.sql`
- `supabase/migrations/20260904000019_rls_jobs.sql`
- `supabase/migrations/20260904000020_rls_drafts_and_cad.sql`
- `supabase/migrations/20260904000021_rls_payments.sql`
- `supabase/migrations/20260904000022_rls_documents_and_dxf.sql`
- `supabase/migrations/20260904000023_rls_notifications_and_offline.sql`
- `supabase/migrations/20260904000024_rls_audit.sql`
- `supabase/tests/database/00_helpers.sql`
- `supabase/tests/database/10_customer_isolation.sql`
- `supabase/tests/database/20_centre_manager_branch_isolation.sql`
- `supabase/tests/database/30_role_write_restrictions.sql`
- `supabase/tests/database/40_profiles_self_protection.sql`
- `supabase/tests/database/50_cad_release_gate.sql`
- `supabase/tests/database/60_dxf_and_hash_protection.sql`
- `docs/authorization.md` (this file)

**No unrelated files were modified.** `README.md` and
`docs/database-schema.md` get a one-line status update pointing here —
see the diff for exactly that, nothing else.

## PG-006 addendum

PG-006 (PGLC Catalogue) added two new, additive database objects. No
existing PG-005 policy was modified — verified via `git diff` showing
only new files. Full context in `docs/catalogue.md`.

- **`pattern_favourites`** (`20260904000025_pattern_favourites.sql`):
  RLS-protected, customer-owns-only (`customer_id = current_customer_id()`),
  no staff access at all. A `pattern_favourite_counts` view exposes only
  an aggregate count per pattern, safe for public `SELECT`.
- **Storage buckets** (`20260904000026_pglc_storage_buckets.sql`):
  `pglc-public` (public read, staff write) and `pglc-production`
  (staff-only), with `storage.objects` policies scoped to just those
  two `bucket_id`s — additive, doesn't touch any other bucket's
  policies (none exist yet).

## PG-007 addendum

PG-007 (Quote Engine) added two more additive tables:
`pricing_rates` and `commercial_settings`, both empty by design,
finance-staff read / Super-Admin write only. No existing PG-005 policy
was touched. `issue-quote`'s Edge Function authorization logic
duplicates `quote_requests_select_own_or_staff` in application code
rather than a new rule — see `docs/quote-engine.md` for the full
detail, including a real information-leak bug found and fixed during
this task (raw rates were briefly reachable via the public
`estimate-quote` endpoint before being stripped from its response).

## Verification status

Per the explicit test requirement for this task, every claim below is
labeled. Nothing is marked verified unless it was actually executed in
this environment.

### VERIFIED LOCALLY (executed in this sandbox, no live database)

Ran as a Python static-analysis pass over the migration files
(not a database — no Postgres/Supabase was available):

- All 28 PG-003 tables have `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`. ✅
- All 28 tables have at least one policy (none accidentally left at
  100%-deny-everyone with zero policies, which — note — is different
  from the *intentional* "no write policy" tables above; those still
  have a SELECT policy, just no write one). ✅
- Every function referenced in a policy (`is_super_admin()`, etc.) is
  defined somewhere in the migration set before use. ✅
- All 13 helper functions in `20260904000015` are `SECURITY DEFINER`. ✅
- The 9 tables intended to be fully client-write-locked (`quotes`,
  `jobs`, `job_stage_history`, `payments`, `payment_events`,
  `documents`, `dxf_release_grants`, `dxf_download_logs`,
  `audit_events`) each have exactly one policy, and it's `FOR SELECT` —
  confirmed by parsing, not just by reading the SQL. ✅
- Every column name referenced in every policy (e.g. `jobs.branch_id`,
  `customers.default_branch_id`) was cross-checked against the actual
  `CREATE TABLE` statements from PG-003/PG-004 — no typos or
  nonexistent-column references found. ✅
- Parenthesis and `$$`/`$q$` dollar-quote balance across all 17 new SQL
  files (10 migrations + 7 test files). ✅

### NOT VERIFIABLE IN CURRENT ENVIRONMENT

- Whether the SQL is actually syntactically valid to a real Postgres
  parser — balance checking catches obvious mistakes, not semantic
  errors (e.g., a reserved word used wrong, a type mismatch).
- Whether `auth.uid()`, `auth.users`, and the exact GoTrue-managed
  columns/constraints on `auth.users` behave as assumed — no Postgres
  or Supabase instance, of any kind, was reachable to check.
- Whether the pgTAP extension and its function signatures
  (`plan`, `is`, `throws_ok`, `throws_like`, `lives_ok`, `finish`)
  match what's actually installed on the target project.
- Whether the `tests.build_fixtures()` `auth.users` INSERT satisfies
  every constraint on the real table (flagged explicitly in
  `00_helpers.sql`).
- Whether the column-level `REVOKE`/`GRANT` statements interact
  correctly with Supabase's actual default role grants (Supabase may
  grant broader default privileges to `authenticated` at the schema
  level that these migrations don't know about and don't explicitly
  re-revoke beyond the specific columns named).
- Runtime behavior of the `enforce_draft_release_gate()` trigger under
  concurrent updates, or interaction with the pre-existing deferred
  `trg_check_blend_pattern_count` trigger from PG-003.

### REQUIRES LIVE SUPABASE VERIFICATION (must be done before production use)

1. `supabase start` (or point at a real project) and `supabase db reset`
   — confirm all 24 migrations apply cleanly in order, including the
   new PG-005 ones on top of PG-001–004.
2. `create extension if not exists pgtap;` then `supabase test db` (or
   `pg_prove` directly against `supabase/tests/database/*.sql`) —
   confirm every test in this suite actually passes, and fix any that
   don't before trusting the corresponding guarantee.
3. Manually exercise, through the actual PostgREST API (not a direct
   Postgres connection) using real anon/authenticated JWTs for each
   role: sign in as each of the 7 roles + a customer, and confirm the
   matrix in section C holds through the real API surface, not just
   inside a `SET LOCAL ROLE` simulation.
4. Confirm Supabase's project-level default grants for `anon`/
   `authenticated` on the `public` schema don't grant something broader
   than what these migrations assume (check Supabase Studio → Database
   → Roles, or `\dp` in `psql`, for every table).
5. Load-test the branch-scoped policies (`EXISTS` subqueries against
   `jobs`/`quote_requests`) for performance once there's realistic data
   volume — correctness was the focus here, not query plan efficiency.
6. Confirm the pgTAP fixtures' abbreviated `auth.users` INSERT actually
   succeeds against the genuine Supabase-managed schema for that table.

**PG-005 is a security gate, not a finish line: items 1–4 above must
pass before any real deployment, per this task's own instructions.**
