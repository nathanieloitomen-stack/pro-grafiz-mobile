# Operations (PG-012)

**Status: PG-012 complete as scoped.** Zero schema changes — everything
needed already existed from PG-003/005.

## Critical findings confirmed by direct search

- **"SLA" and "pause" appear nowhere in either governing document.**
  The only place "SLA" appears anywhere in this whole codebase is a
  design-token color label I wrote in `docs/design-system.md` (PG-002),
  describing what a "danger" tone might be used for (an "Over-SLA" tag
  the original prototype's copy referenced) — not an actual numeric
  threshold or timer. **No SLA threshold was invented in this task.**
  "Hold pauses SLA" cannot be concretely implemented, because there is
  no SLA timer to pause in the first place. What's preserved instead:
  the exact moment a hold begins is recorded (in the `audit_events` row
  `hold-job` writes), so a future SLA feature — once a threshold is
  ever specified — could exclude held periods from an elapsed-time
  calculation. No such calculation exists in this codebase.
- **`jobs.status`'s check constraints already require a reason**
  (`chk_jobs_hold_reason_requires_hold`,
  `chk_jobs_cancel_reason_requires_cancel`, both PG-003) — this task's
  functions satisfy those by construction, they don't add or duplicate
  the requirement.
- **`audit_events` has never been written to by any function until this
  task.** `hold-job`, `resume-job`, `cancel-job`, `reopen-job`, and
  (retrofitted) `decide-quote-request` are the first writers.

## Exact scope, per the task list

CLAUDE.md/Master Spec name PG-012 only as "Operations," mapped from the
V1 bullet "Intake, queue, payments and design desk" (Payments = PG-009,
Design Desk = PG-010, both already separate tasks) plus "Basic
management dashboard." This task builds: the Intake decision UI
(server logic already existed from PG-008), a Job Queue with hold/
resume/cancel/reopen, and a minimal dashboard.

## What was built

### Server-side (Edge Functions)

- **`hold-job`, `resume-job`, `cancel-job`, `reopen-job`** (all new):
  Centre Manager (own branch) or Super Admin only — see "Authority
  decision" below. All four write an `audit_events` row.
- **`decide-quote-request` (PG-008) modified**: added audit logging to
  both the accept and decline paths. This is the only existing file
  touched in this task, and the diff is exactly two small,
  clearly-scoped `audit_events` inserts — nothing else in that
  function's logic changed. Verify with `git diff` against `e40dd8e`.
- **`_shared/staff_auth.ts`** (new): the shared branch-scoped
  authorization check, reused by all four job-lifecycle functions
  rather than duplicated four times.

### UI

- `IntakeScreen` — accept/decline pending quote requests.
- `JobQueueScreen` — hold/resume/cancel/reopen, with elapsed
  time-in-stage shown as a plain fact, never colored or compared
  against a threshold.
- `OperationsDashboardScreen` — basic counts (pending requests, jobs
  per stage, held/cancelled totals). No approved pixel design exists
  for this screen (Master Spec gives no detail beyond the bullet's
  name) — kept minimal and functional.

## Authority decision (flagged, not specified anywhere)

Master Spec never states who may hold/cancel/resume/reopen a job. This
task restricts all four actions to **Centre Manager (own branch only)
and Super Admin** — explicitly **not** Designer, Production,
Accountant, or Inventory, even though those roles do have broader read
access to jobs elsewhere in this codebase (via `is_central_staff()`).
Reasoning: each of those roles has its own specific domain (design,
production, payments, inventory), and nothing in the docs gives them
general job-management authority. This is narrower than the "any
central staff" pattern used for read access and for quote-request
decisions — a deliberate, conservative choice for actions that can
disrupt or end a job, not a default carried over from elsewhere without
thought. **Confirm this is the intended authority model** — it's this
task's own interpretation.

## Role/branch authorization behavior

- Every new function re-derives the caller's role/branch from
  `profiles` via the service-role client — never trusts a client-
  supplied role or branch, and cannot be bypassed via request
  parameters (the branch used for the authority check is the *job's own*
  `branch_id`, looked up server-side, never accepted from the client).
- `IntakeScreen`/`JobQueueScreen` add no client-side filtering — the
  underlying `quote_requests_select_own_or_staff`/
  `jobs_select_own_or_staff` RLS policies (PG-005, unmodified)
  determine what a Centre Manager's session receives from the query
  itself. A Centre Manager literally cannot construct a request that
  returns another branch's data through these screens, because the
  data never leaves the database in the first place.

## Job lifecycle transitions implemented

None of the eight approved stages were touched, added, or removed.
This task's new functions only move `jobs.status` between
`active`/`on_hold`/`cancelled` — `current_stage` is untouched by
hold/resume/cancel/reopen (a held or cancelled job stays at whatever
stage it was in; only whether it's actively progressing changes).

## Hold/cancel behavior

- **Hold**: `active` → `on_hold`, mandatory `hold_reason`, blocked once
  `current_stage = 'RELEASED'` (a sanity guard, not a stated rule — you
  can't hold a job that's already delivered).
- **Resume**: `on_hold` → `active`, no reason required (no schema
  column to store one; an optional note goes to `audit_events` only —
  see the function's own comment for why this doesn't contradict "hold/
  cancel/resume/reopen require controlled reasons").
- **Cancel**: `active` or `on_hold` → `cancelled`, mandatory
  `cancel_reason`. No new cancellation reason categories were invented
  — the reason is free text, matching the existing schema exactly.
- **Reopen**: `cancelled` → `active`, read as "undo the cancellation" —
  this specific interpretation isn't stated verbatim anywhere, flagged
  as this task's own reading of the only reversible terminal state
  `jobs.status` has.

## SLA behavior

**None implemented.** No threshold exists anywhere in the docs (see
"Critical findings" above). The Job Queue shows elapsed time in the
current stage as a neutral, uncoded fact. If an SLA feature is wanted,
the threshold value itself is an open business decision — report it
rather than picking a number (this task did not).

## Database/schema changes

**None.** `jobs`, `audit_events`, and `quote_requests` already existed,
fully correctly shaped, from PG-003/PG-005.

## Security/RLS implications

- **No existing RLS policy was modified.** Confirmed via `git status`
  — zero migration files added or touched.
- `jobs` and `audit_events` both retain zero client write policies —
  this task's four new functions and the retrofit to
  `decide-quote-request` are the only ways either table is written to,
  matching every prior task's pattern.
- No client-side authorization anywhere — every authority check happens
  server-side against `profiles`, re-fetched fresh on every call.

## Production/DXF implications

None — this task doesn't touch drafts, DXF, or Storage at all. The
PG-010 Production-role restriction (unreleased DXF inaccessible) is
untouched.

## Documents implications

None — no new document type was created, and PG-011's idempotency
mechanism (`event_key` uniqueness) was not touched by this task.

## Unspecified decisions discovered (STOPPED, not guessed)

1. **Who may hold/cancel/resume/reopen a job** — resolved narrowly
   (Centre Manager own-branch + Super Admin), flagged above as this
   task's own interpretation.
2. **SLA threshold** — confirmed absent from both documents; not
   invented; reported as an open business decision.
3. **Exact meaning of "reopen"** — read as undoing a cancellation;
   flagged as an interpretation.
4. **Dashboard content/design** — no approved detail beyond the bullet
   name; built as basic counts.

## Deferred decisions

All of the above, plus every item already open from PG-007/009/010/011
(pricing, VAT, deposit, refunds, payment provider, CAD tolerances,
document format, signatures) — untouched by this task.

## Tests actually executed

Static structural analysis only — parenthesis/`$$` balance across the
new shared module, 4 new Edge Functions, the modified section of
`decide-quote-request`, and the 5 new Dart files; every table/column
reference cross-checked against the actual schema; confirmed via `git
diff` that `decide-quote-request`'s only change is the two audit-log
insertions.

## Tests that could not be executed

Everything in `supabase/tests/database/130_operations.sql` — no live
database. The actual branch-authority logic in `_shared/staff_auth.ts`
(TypeScript) has never run anywhere.

## Known defects

None newly introduced. PG-010's upload-path data-quality issue remains
untouched technical debt, as instructed — this task did not depend on
it.

## Exact live-environment verification required

```bash
create extension if not exists pgtap;
supabase test db               # includes 130_operations.sql
supabase functions serve
```

Then, in order: as Centre Manager A, hold a job at branch A (confirm
success, `audit_events` row written); attempt to hold a job at branch B
(confirm rejection); as Super Admin, hold/resume/cancel/reopen jobs at
any branch (confirm all succeed); as Designer/Production/Accountant/
Inventory, attempt any of the four actions (confirm all rejected —
this is the authority-narrowing decision, worth explicit verification);
accept and decline quote requests via Intake and confirm exactly one
`audit_events` row is written per decision with the correct
before/after state.
