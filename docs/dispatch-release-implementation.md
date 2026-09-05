# Dispatch & Release Implementation (PG-015)

**Status: PG-015 complete.** Implements exactly the three transitions
approved after PG-014's discovery — no new stage, no new table, no new
document type, no new payment percentage.

## The three transitions

| Function | Transition | Authorized | Branch scope |
|---|---|---|---|
| `mark-ready-for-dispatch` | `IN_PRODUCTION` → `READY_FOR_DISPATCH` | Production, or Super Admin | Production's own `profiles.branch_id` must match the job's branch |
| `dispatch-job` | `READY_FOR_DISPATCH` → `DISPATCHED` | Inventory, or Super Admin | Same pattern, for Inventory |
| `release-job` | `DISPATCHED` → `RELEASED` | Centre Manager (own branch), or Super Admin | Reuses the exact existing `authorizeOperationalAction()` from PG-012 — the same actor set already used for hold/cancel/resume/reopen |

Centre Manager is deliberately **excluded** from the first two
transitions — no existing code granted Centre Manager authority over
production or dispatch confirmation specifically, and PG-015's brief
was explicit that this authority must not be invented. `release-job`
reuses the shared Centre-Manager helper directly because it's a genuine
match to an already-approved actor set, not a new grant.

## Branch scope for Production/Inventory — how it was resolved

Production and Inventory are treated as central (non-branch-scoped)
roles everywhere else in this codebase. PG-015 explicitly required
branch scope for these two roles for these two specific actions. This
was resolved using **existing schema only**: `profiles.branch_id`
already exists for every role, not just Centre Manager. A new shared
helper, `authorizeBranchScopedRole()`, checks that the acting
Production/Inventory profile's own `branch_id` matches the job's
`branch_id` — no new column, no new table. Added additively to
`_shared/staff_auth.ts`; the existing `authorizeOperationalAction()`
export is completely unchanged.

## Concurrency / idempotency

All three functions use a single atomic conditional UPDATE —
`.eq('current_stage', 'EXPECTED_STAGE')` in the same statement as the
`.update(...)` call — rather than the older select-then-update pattern
`start-design`/`release-draft`/`respond-to-design`/`confirm-payment`
use. This is a **deliberate, stricter divergence** for these three new
functions only, made because this task explicitly emphasizes
concurrency safety; the four older functions have a real (if
lower-stakes) TOCTOU race and were **not** retrofitted, per "do not
refactor unrelated existing transition functions."

Practically: if two staff members call the same transition on the same
job at the same moment, exactly one UPDATE matches a row (Postgres
evaluates the `WHERE` clause including `current_stage` at commit time
under row-level locking); the second call's `.maybeSingle()` result is
`null`, and the function returns a clean 409 rather than a duplicated
or corrupted state. The same mechanism is what makes stage-skipping
impossible: `dispatch-job` can only ever match a row still at
`READY_FOR_DISPATCH`, so a job that's already `DISPATCHED` (or was
never `READY_FOR_DISPATCH`) simply doesn't match, regardless of who
calls it or when.

## Balance enforcement

`release-job` checks `quotes.balance_kobo` (the quote engine's own
already-authoritative figure, PG-007) and, if positive, requires a
`payments` row for the job with `kind = 'balance'` and
`status = 'confirmed'` to exist — the exact same existence-check
pattern `create-payment-request` (PG-009) already uses for its own
deposit-before-balance precondition. No client-supplied amount is
read anywhere in this check. If `balance_kobo <= 0` (a valid
configuration — e.g. a 100% deposit), release proceeds without
requiring a balance payment record, since none could ever be created
for a zero amount. This did not require stopping and reporting a gap —
the existing schema was sufficient.

## Audit consistency

All three new functions write an `audit_events` row —
`job.mark_ready_for_dispatch`, `job.dispatch`, `job.release`
respectively, each with `before_state`/`after_state`. PG-014 found that
the five older transition functions don't all do this consistently;
per this task's explicit instruction, that inconsistency was **not**
fixed retroactively — only the three new functions were made
consistent with each other.

## Notifications

All three call PG-013's existing `notify()` — no second notification
mechanism, no push infrastructure, no Firebase credentials. Recipients
are the job's own customer, resolved server-side via
`customers.auth_user_id`, matching every other notification call site
in this codebase.

## Database changes

**None.** Confirmed via `git status` — no migration file was added.
Everything needed (`jobs`, `job_stage_history`, `audit_events`,
`quotes.balance_kobo`, `payments.kind`/`status`, `notifications`, and
`profiles.branch_id`) already existed.

## UI

Extended the **existing** `JobQueueScreen`/`OperationsRepository`
(PG-012) — no new dispatch dashboard, no driver management, no
delivery tracking. Three new conditional buttons ("Mark Ready for
Dispatch," "Mark Dispatched," "Release Job") appear only when the
job's `current_stage` matches AND the caller's own role plausibly
matches. **This role check is UI convenience only** — a new
`fetchOwnRole()` repository method exists purely to decide what to
render; it has no bearing on what the server actually allows, which is
re-checked from scratch, server-side, on every call regardless of what
the client believes about itself.

## Security/RLS implications

- **No RLS policy was created, modified, or weakened.** `jobs`,
  `audit_events`, and `payments` all retain the exact zero-client-write
  posture established in PG-005 — confirmed via `git diff` showing no
  migration file touched.
- No client-side authorization anywhere: every function re-derives
  role and branch from `profiles`, fresh, on every call.
- Branch authority for all three transitions is read from the job's own
  persisted `branch_id`, never from a client-supplied value.
- The atomic compare-and-swap pattern is itself a security property, not
  just a correctness one: it's what makes "two staff members
  double-advancing a job" and "skipping a stage via a race" structurally
  impossible, not just unlikely.

## Tests actually executed

Static structural analysis only — parenthesis/`$$` balance across the
modified shared module, 3 new Edge Functions, and 2 modified Dart
files; every table/column reference cross-checked against the actual
schema; confirmed via `git status`/`git diff` that no migration file
was added and no existing RLS policy or unrelated function logic was
touched.

## Tests not executed

All 14 positive/negative cases named in the task brief require a live
Supabase project and Deno function execution — none were run. The
pgTAP file added (`150_dispatch_release.sql`) covers only what's
testable without that: the RLS regression guarantees (`jobs`/
`audit_events` still fully locked, stage-skipping impossible via raw
SQL) and schema sanity checks for the columns `release-job`'s balance
logic depends on. **Live verification is required before trusting any
of this in production** — see the checklist below.

## Known issues

None newly introduced. Every open item from PG-007/009/010/011/012/013
(pricing, VAT, deposit percentage, refunds, payment provider, CAD
tolerances, document format, signatures, SLA threshold, hold/cancel
authority, the dispatch-vs-collection business-model question raised in
PG-014) remains exactly as open as before — none were touched,
resolved, or re-interpreted by this task.

## Live verification required

```bash
create extension if not exists pgtap;
supabase test db               # includes 150_dispatch_release.sql
supabase functions serve
```

Then, walking the task brief's own 14 cases in order: Production
advances a job at their own branch (succeeds); at another branch
(rejected); Inventory advances a `READY_FOR_DISPATCH` job (succeeds);
Centre Manager releases a `DISPATCHED` job with balance confirmed
(succeeds); Super Admin performs all three anywhere; a Designer
attempts any of the three (rejected); a Centre Manager attempts
`release-job` on another branch's job (rejected); `mark-ready-for-dispatch`
attempted on a job at `DESIGN_IN_PROGRESS` (rejected — cannot skip to
`READY_FOR_DISPATCH`); `dispatch-job` attempted on a job still at
`IN_PRODUCTION` (rejected); `release-job` attempted twice in quick
succession on the same job, or from two sessions simultaneously
(exactly one succeeds, the other gets a clean 409); a raw client
attempts `UPDATE jobs SET current_stage = ...` directly (rejected by
RLS, unchanged); a nonexistent `job_id` is passed to any of the three
(404); confirm a deliberately-broken `notify()` call (e.g. temporarily
point at a bad table name) still lets the underlying transition
succeed; confirm `job_stage_history` and `audit_events` rows exist with
correct `before_state`/`after_state` after each transition.
