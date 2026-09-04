# Customer Job Flow (PG-008)

**Status: PG-008 complete as scoped.** Per your standing instructions,
this document reports every judgment call made rather than presenting
any of them as settled. None involve inventing pricing/commercial rules
— those remain exactly as closed as PG-007 left them (see "What was
deliberately NOT touched" below).

## Scope, per Master Spec and the task list

CLAUDE.md/Master Spec name PG-008 only as "Customer Job Flow" — no
further breakdown is given anywhere. The V1 bullet list has these
related-but-separate items:

- Quote request/intake
- Eight-stage job tracking
- Customer design approval/request-change
- (separately) Real payment integration → **PG-009**
- (separately) Intake, queue, payments and design desk → likely **PG-012 Operations**

## A task-boundary decision, flagged rather than assumed

**"Quote request/intake" and "Eight-stage job tracking" and "Customer
design approval/request-change" are treated as PG-008's scope; the
staff side of "intake" (deciding on a request) is treated as
infrastructure only, with no staff UI screen built.**

Reasoning: without *some* way to turn an accepted quote request into a
job, "job tracking" has nothing to track — but the approved design's
only screen for that decision (Intake, #12) is staff-facing mobile UI
grouped under a different V1 bullet ("Intake, queue, payments and
design desk"), which most naturally maps to **PG-012 Operations**, not
this task. Building a lookalike screen now risks conflicting with "Do
not redesign the product" if PG-012's actual design differs. The
resolution: build the **server-side decision logic** (`decide-quote-request`)
so the flow is genuinely complete and testable end-to-end, but leave
the actual Intake screen for whichever task legitimately owns it. This
is a task-boundary interpretation, not a business-rule invention — flag
if you'd rather see it handled differently.

## What was built

### Server-side (Edge Functions)

- **`decide-quote-request`** (staff-only) — accepts or declines a
  `quote_request`. Authorization mirrors
  `quote_requests_update_staff_only` (PG-005) exactly — Centre Manager
  scoped to their own branch, or any central staff role. Accepting
  internally calls the same calculation logic as PG-007's `issue-quote`
  (issues a `quotes` row) and then creates the `jobs` row — **requires
  real `pricing_rates`/`commercial_settings` to be configured**, with
  the exact same honest refusal as PG-007 otherwise. `quote_requests.status`
  uses `'accepted'`/`'declined'` — plain values (that column has no
  fixed list anywhere in the docs, same situation as `jobs.status`'s
  `active`/`on_hold`/`cancelled` inference from PG-003), chosen only to
  distinguish "decided" from "pending," with zero effect on any
  commercial calculation.
- **`respond-to-design`** (customer-only) — "Approve" or "Request a
  change" from the approval card on screen #7. This is the specific
  server-side transition service Master Spec §9 requires for these two
  transitions:
  - Approve: `DESIGN_SENT_FOR_APPROVAL` → `IN_PRODUCTION`, only if the
    job has a `drafts` row with `release_status = 'released'` (an
    integrity check against PG-005's existing CAD release-gate
    trigger).
  - Request a change: creates a `design_revisions` row and reverts
    `DESIGN_SENT_FOR_APPROVAL` → `DESIGN_IN_PROGRESS`.

  Both stage names and their order come directly from Master Spec §9 —
  implementing the specified state machine, not inventing one. Which
  direction "request a change" reverts to (back to
  `DESIGN_IN_PROGRESS`, the design-work stage) is this function's own
  reasonable reading, not stated verbatim anywhere — flagged, not
  presented as certain.

### Database

**No schema changes at all.** Everything PG-008 needed
(`quote_requests`, `quotes`, `jobs`, `job_stage_history`,
`design_revisions`) already existed from PG-003/PG-005.

### UI (mobile, customer-facing)

- `ConfigureScreen`'s "Send to Pro_Grafiz" button is **now real** — it
  inserts a `quote_requests` row using the customer's own
  `customers.default_branch_id` and the screen's configured spec, via
  the existing RLS `quote_requests_insert_own_or_staff` policy (PG-005)
  — no new Edge Function needed for submission itself. This is the
  exact button PG-006/007 correctly kept inert, now unlocked because
  "Customer Job Flow" is the designated task those reviews deferred it
  to.
- `JobsScreen` / `JobDetailScreen` — the customer's own jobs, stage
  timeline (all 8 stages, current position highlighted), hold/cancelled
  banners (read-only), and the approval card (Approve / Request a
  change) wired to `respond-to-design`.
- **Deliberately absent:** the payment card (needs PG-009) and the
  documents list (needs PG-011). Both tables already have correct
  customer-read RLS from PG-005 — `JobRepository` queries them and
  gracefully shows nothing if empty, rather than faking data or
  blocking on those tasks.
- A new job list will legitimately be **empty** until a staff member
  (or a direct API/pgTAP call, in the absence of a UI) calls
  `decide-quote-request` with `decision: 'accept'` — and that will
  itself fail honestly until real `pricing_rates`/`commercial_settings`
  exist, exactly as PG-007 designed it to.

## What was deliberately NOT touched (per your explicit instructions)

- No pricing, VAT, deposit, discount, urgency, customer-type, delivery,
  labour, material, cutting, or finishing rate was invented, assumed,
  or hardcoded anywhere in this task.
- The "60/40 deposit" figure remains explicitly not-a-rule, exactly as
  corrected in the PG-007 report.
- `pricing_rates`/`commercial_settings` remain empty — this task added
  no rows and no seed data.
- The `estimate-quote` public-endpoint protection (stripping raw rates
  from the response) is untouched — verified by inspection, not
  modified in this task.
- All seven PG-007 decisions remain open, unresolved, tracked in
  `docs/quote-engine.md`.
- The V1/V2 sheet-count/cut-time conflict was not resolved here either
  — `decide-quote-request` calls the same `calculateQuote()` that
  already handles it (null unless specific settings are configured),
  unchanged.

## RLS/security implications

- **No existing PG-005 policy was modified.** Confirmed via `git status`
  before committing — zero migration files touched.
- `jobs` and `quotes` still have **zero client write policies** —
  verified as a regression test in
  `supabase/tests/database/90_customer_job_flow.sql`. Both new Edge
  Functions depend on this remaining true; if a future task
  accidentally adds a write policy to either table, that test will
  catch the drift.
- `decide-quote-request`'s and `respond-to-design`'s authorization logic
  duplicates existing RLS policy conditions in application code
  (necessarily — Edge Functions can't invoke a table's RLS policy
  directly). If those policies ever change, these functions must be
  updated to match, or they'll silently drift apart — same caveat
  already noted for `issue-quote` in PG-007.
- Pricing configuration (`pricing_rates`/`commercial_settings`) remains
  fully inaccessible to customers — nothing in this task changed that,
  and no customer-facing code path reads either table directly (only
  the shared `calculateQuote()`, called from service-role functions).
- `respond-to-design`'s approve path checks for a released draft before
  allowing the stage transition — a genuine, if minor, additional
  safety check layered on top of PG-005's existing CAD release gate,
  not a relaxation of it.

## Known defects

None found in existing code during this task's inspection. One
pre-existing limitation surfaced again: `design_revisions.requested_by`
still can't attribute a customer-authored revision (the PG-003 gap) —
`respond-to-design` sets it to `null` for customer requests, consistent
with the existing RLS policy's own handling.

## Tests actually executed

Static structural analysis only — parenthesis/`$$`/`$q$` balance across
all 4 new TypeScript/SQL files and the pgTAP test file; every
table/column reference cross-checked against actual schema; confirmed
via `git status`/`git diff` that no existing migration or RLS policy
file was modified.

## Tests that could not be executed

Everything in `supabase/tests/database/90_customer_job_flow.sql` — no
live database in this environment, same limitation as every prior task.
The two Edge Functions' actual business logic (accept/decline state
machine, stage-transition validity) cannot be tested via pgTAP at all —
it lives in TypeScript, not SQL — and has not run anywhere.

## Verification status

**Verified locally (static analysis, not a database):** structural
balance on `decide-quote-request/index.ts`, `respond-to-design/index.ts`,
and the 4 modified/new Dart files; column names in both functions and
`JobRepository` cross-checked against `jobs`/`quotes`/`quote_requests`/
`design_revisions`/`drafts`/`job_stage_history`'s actual `CREATE TABLE`
statements; confirmed no existing migration file was touched.

**Requires live Supabase verification:**
```bash
supabase functions serve
```
Then, in order: submit a `quote_request` as a customer (via the app or
directly); call `decide-quote-request` with `decision: 'decline'` and
confirm the request is marked declined with no job created; configure
a `pricing_rates` row and `vat_percent`/`deposit_percent`, submit
another request, and call `decide-quote-request` with `decision:
'accept'` — confirm a `quotes` row and a `jobs` row are both created
correctly, and a `job_stage_history` row exists at `SUBMITTED`; as an
unrelated Centre Manager (wrong branch), confirm `decide-quote-request`
is rejected; manually advance a job to `DESIGN_SENT_FOR_APPROVAL` and
add a released `drafts` row, then call `respond-to-design` with
`action: 'approve'` as the owning customer and confirm the stage moves
to `IN_PRODUCTION`; confirm `action: 'request_change'` reverts to
`DESIGN_IN_PROGRESS` and creates a `design_revisions` row; confirm an
unrelated customer is rejected by both actions.

## Files changed

**New:** `supabase/functions/decide-quote-request/index.ts`,
`supabase/functions/respond-to-design/index.ts`,
`apps/mobile/lib/features/jobs/data/models/job_summary.dart`,
`apps/mobile/lib/features/jobs/data/job_repository.dart`,
`apps/mobile/lib/features/jobs/presentation/jobs_screen.dart`,
`apps/mobile/lib/features/jobs/presentation/job_detail_screen.dart`,
`supabase/tests/database/90_customer_job_flow.sql`,
`docs/customer-job-flow.md` (this file).

**Modified:** `apps/mobile/lib/features/catalogue/presentation/configure_screen.dart`
(Send button now functional), `apps/mobile/lib/features/auth/presentation/auth_gate.dart`
(adds a "My jobs" entry point for signed-in customers), root `README.md`.

**No database migration was added or modified in this task.**
