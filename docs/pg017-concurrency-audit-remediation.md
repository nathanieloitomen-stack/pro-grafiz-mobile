# Concurrency & Audit Remediation (PG-017)

**Status: PG-017 complete.** Addresses exactly the two findings PG-016
identified — nothing else was touched.

## PG-016 findings addressed

1. **Concurrency**: 9 of 12 lifecycle-adjacent functions used a
   non-atomic check-then-act pattern. All 9 are fixed.
2. **Missing audit events**: 4 of 8 lifecycle transitions wrote zero
   `audit_events` rows. All 4 now do.

## The exact 9 functions fixed for concurrency

`decide-quote-request`, `confirm-payment`, `start-design`,
`release-draft`, `respond-to-design` (both branches), `hold-job`,
`resume-job`, `cancel-job`, `reopen-job`.

Each now uses the same pattern PG-015 established: the precondition
(`current_stage`/`status` equality or inequality) is checked **inside
the same `UPDATE` statement** as the write, via `.eq()`/`.neq()`, and
the function checks whether a row was actually returned
(`.select().maybeSingle()`) before proceeding. A concurrent second
request against the same row matches zero rows once the first has
committed, and gets a clean 409 rather than racing to also succeed.
The earlier read-then-check (kept in most functions) is now purely a
fast, friendly early exit for the common non-racing case — it is not
what provides correctness.

## The exact 4 functions that gained audit events

| Function | New audit action | Entity |
|---|---|---|
| `confirm-payment` | `payment.confirm` | `payment` |
| `start-design` | `job.start_design` | `job` |
| `release-draft` | `draft.release` | `draft` |
| `respond-to-design` (approve) | `job.approve_design` | `job` |
| `respond-to-design` (request_change) | `job.request_design_change` | `job` |

`respond-to-design` handles two distinct customer-triggered
transitions in one function; both branches previously wrote nothing,
so both now get their own action, rather than one being fixed and the
other left as a residual gap.

`audit_events.action` is free text (PG-003, no enum) — none of these
five new values required a schema change.

## Payment confirmation, specifically

Per this task's explicit emphasis, `confirm-payment`'s remediation was
done first and reviewed most carefully. The `payment.confirm` audit
row is written **immediately after** the atomic confirmation succeeds
(before the job-advancement/document/notification steps, which are
independent of it), and records:

- **What happened**: `before_state: {status: <previous>}`,
  `after_state: {status: 'confirmed', job_id: <job>}`.
- **Which payment/job**: `entity_type: 'payment'`, `entity_id`, plus the
  job id in `after_state`.
- **Who**: `actor_user_id` — the caller's own verified `auth.uid()`,
  the same identity the fresh-PIN-challenge already authenticated.
  Never a client-supplied value.
- **When**: `created_at` (the table's own default).

**Nothing about payment behavior, amounts, or the Accountant PIN
process was touched.** The fresh-challenge block
(`signInWithPassword` against a brand-new client) is byte-for-byte
unchanged — verify with `git diff`.

## Idempotency / duplicate side effects

The atomic pattern directly prevents the duplicate-side-effect risk
PG-016 described: since only one of two racing requests can ever
successfully claim the row (the `UPDATE...WHERE` match), only that one
request proceeds to write `job_stage_history`, `audit_events`, or call
`notify()` — the losing request returns a 409 before reaching any of
those. This is a structural guarantee (the same row can't match twice
after the first commit), not a best-effort reduction in probability.

`decide-quote-request`'s accept path is the one genuinely multi-step
transition among the nine (calculate quote → insert quote → insert job
→ history/audit/notify) — its atomic claim was moved to the **start**
of the function, before any of that work, rather than left at the end
where the original code had it. If any downstream step fails after the
claim succeeds (pricing unavailable, a quote/job insert error), the
claim is **rolled back** — `quote_requests.status` restored to
`pending` — via a compensating `UPDATE`, so a failed accept doesn't
leave the request permanently stuck "accepted" with no job. This isn't
a real multi-statement transaction (PostgREST doesn't expose one to an
Edge Function) — it's the best available correctness guarantee given
that constraint, and is a new but narrowly-scoped addition, not a
change to what "accept" means.

## `generateDocument()` — untouched, and still correctly independent

Per this task's explicit instruction, `generateDocument()` was not
modified in any way. It didn't need to be: its own idempotency
(`event_key` lookup before any work, plus an explicit `23505`
unique-violation catch) was already independently race-safe, as
PG-016 confirmed by direct code inspection. The concurrency fixes in
this task protect the *stage transition* that triggers document
generation; the document generation itself was never the problem.

## Functions modified

`decide-quote-request`, `confirm-payment`, `start-design`,
`release-draft`, `respond-to-design`, `hold-job`, `resume-job`,
`cancel-job`, `reopen-job` — exactly the 9 named above, and no others.
**The three PG-015 functions (`mark-ready-for-dispatch`,
`dispatch-job`, `release-job`) were not touched** — they already used
the correct pattern; there was no genuine defect requiring a change.

## Security/RLS

- **Zero RLS policies were created, modified, or weakened.** Confirmed
  via `git status`/`git diff` — no migration file exists in this
  commit.
- **No new business rule, role, branch rule, or payment rule was
  introduced.** Every precondition added to an atomic `UPDATE`'s
  `WHERE` clause is the exact same precondition the function already
  checked in its earlier read-then-check version — moved into the
  `UPDATE` itself, not changed in meaning.
- **No client-side lifecycle write was introduced.** Every fix
  operates entirely within functions that already used the
  service-role key; `jobs`/`payments`/`quote_requests`/`drafts`/
  `audit_events` retain exactly the write-policy posture (none) they
  had before this task.
- The atomic pattern is itself a security-relevant property, not just
  a correctness one — it's what makes "two staff members racing to
  double-process the same transition" structurally impossible, the
  same property PG-015 established for the three newer functions.

## Database changes

**None.** No migration was created. Everything needed
(`current_stage`/`status` columns, `audit_events.action` as free text)
already existed.

## Tests actually executed

Static structural analysis — parenthesis/`$$`/`$q$` balance across all
9 modified functions and the new test file; every table/column
reference cross-checked against the actual schema; confirmed via
`git status` that no migration file was added and no RLS policy file
was touched; confirmed via `git diff` that each function's
authorization logic, branch-scoping, business preconditions, payment
amounts, and PIN process are otherwise byte-for-byte unchanged aside
from the flagged atomic-update and audit-insert additions.

## Tests not executed — and why, explicitly

**The actual concurrency property (two simultaneous requests, one
wins, one fails safely) cannot be verified without a live Supabase
project and two genuinely concurrent HTTP calls against a running Deno
function.** No live database or network has been available at any
point in this project. `supabase/tests/database/160_concurrency_audit_remediation.sql`
covers only what's testable without that: RLS regression guarantees
(the five tables these functions depend on still have zero write
policies) and a schema sanity check confirming the new audit action
strings need no migration. **It does not and cannot prove the race
itself is fixed** — that requires the live procedure below.

None of the 14 test cases enumerated in the task brief were executed
against a live system. They are listed, mapped to how each would be
exercised, in the live verification section below.

## Regression check

Verified via `git diff` on each of the 9 files: every existing
authorization check (`profiles.role`, branch-scoping via
`authorizeOperationalAction`), every existing business precondition
(deposit/balance sequencing, released-draft-before-approval, mandatory
hold/cancel reasons), every existing notification call, and every
existing document-generation call are present, unchanged, in the exact
same relative position, in every modified file. PG-015's three
functions are confirmed untouched (`git status` shows no changes to
their files).

## Known issues

None newly introduced. `decide-quote-request`'s rollback-on-failure
path is new code with its own (currently untested, per the limitation
above) failure mode: if the compensating rollback `UPDATE` itself
fails (e.g. a transient network error between the failed insert and
the rollback attempt), the request could be left claimed with no job —
an edge case of an edge case, not exercised by any test here, worth
covering in live testing specifically.

## Live verification required

```bash
create extension if not exists pgtap;
supabase test db               # includes 160_concurrency_audit_remediation.sql
supabase functions serve
```

Then, mapped to the task brief's 14 cases:

**Concurrency (1–5)**: for each of the 9 functions, fire two requests
at the same job/payment/quote_request/draft simultaneously (e.g. two
parallel `curl` processes, or a small script using `Promise.all`
against two separate fetches) — confirm exactly one returns success,
the other returns a 409 with the "already changed by another request"
message, no stage/status ends up skipped or invalid, and exactly one
set of `job_stage_history`/`audit_events`/notification rows exists
afterward (not two). Repeat specifically for `decide-quote-request`'s
accept path with a deliberately-failing pricing configuration to
confirm the rollback restores `status='pending'` correctly.

**Audit (6–9)**: confirm `payment.confirm`, `job.start_design`,
`draft.release`, `job.approve_design`, and `job.request_design_change`
each produce exactly one `audit_events` row with the correct
`actor_user_id` (matching the authenticated caller), `entity_id`
(matching the affected payment/job/draft), and accurate
`before_state`/`after_state`.

**Regression (10–14)**: re-run every existing PG-008/009/010/012 manual
verification checklist unchanged — accept/decline, payment
confirmation via fresh PIN challenge, design start/release/approve/
request-change, hold/resume/cancel/reopen — confirming each still
succeeds under normal (non-racing) use, still respects every
authorization and branch rule, still fires its existing notification,
and that PGJO/PGAO generation remains idempotent under a retried
`confirm-payment`/`respond-to-design` call.
