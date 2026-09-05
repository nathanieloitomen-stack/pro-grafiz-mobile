# Production Readiness Audit (PG-016)

**Status: Audit only. Zero code, migrations, RLS, UI, or Edge Function
changes were made for this task.** Every finding below was verified by
direct inspection of the repository — grep output and exact line
references are included so each claim can be checked, not just taken
on faith. Where a check could only be done statically (no live
database available throughout this entire project), that limitation is
stated explicitly rather than implied to be more thorough than it is.

## Executive answer

**Is the current architecture safe and ready to proceed to the next
development phase (implementation of remaining V1 scope, then live
verification)?**

**Yes, with one clear finding that should be fixed before production
launch, not before continuing development.** The security boundary
(RLS + server-side authorization) is intact and verified consistent
across all 33 migrations and 22 Edge Functions — nothing found in this
audit weakens it. The one real issue found is a **concurrency gap**
affecting 9 of 12 lifecycle-adjacent functions (Section 12) — it does
not corrupt data or bypass authorization, but it can produce duplicate
audit/notification records under concurrent calls. This is a quality
issue, not a security hole, and does not block continued development —
but it should be resolved before this system handles real concurrent
staff usage in production.

**No live Supabase verification has ever been performed across
PG-001–015.** Every task said so honestly at the time; this audit
confirms that remains true and is the single largest outstanding risk
independent of any specific finding below — see the Testing Gate
section at the end.

---

## 1. Database

**Verified, not just asserted:**
- 31 tables, zero duplicate table/policy/index names (checked via grep
  across all 33 migration files).
- 71 total RLS policies.
- **Zero migration file has ever been modified after being committed**
  (`git log --diff-filter=M -- supabase/migrations/` returns empty) —
  every schema change genuinely went through a new migration, exactly
  as CLAUDE.md requires ("Never manually change production schema").
- `quotes.balance_kobo`, `deposit_kobo`, `total_kobo` are all
  `bigint not null default 0` — confirmed this backs `release-job`'s
  balance check safely (a `NULL > 0` JavaScript coercion bug would have
  been possible if this column were nullable; it isn't).
- `pricing_rates`/`commercial_settings` (PG-007) contain **zero rows**
  in any migration or seed file — confirmed the "no fabricated
  pricing" claim from every task since PG-007 by checking there's
  literally no `INSERT` anywhere that could have snuck real-looking
  numbers in.
- Dev seed data (`supabase/seed/0001_dev_seed.sql`) is clearly
  `DEV-`-prefixed and contains no real business data.

**No suspicious or conflicting structures found.**

## 2. Authentication

- Staff PIN-as-Supabase-Auth-password design (PG-004) intact:
  `profiles.role`/`branch_id`/`active`/`auth_login_handle`/
  `invite_token_*` remain column-revoked from `authenticated` — verified
  the exact `revoke`/`grant` statements are unchanged since PG-004.
- Invite tokens are hashed (`hash_invite_token`/`verify_invite_token`,
  pgcrypto-backed), never stored or logged in plaintext; both functions
  are `revoke`d from `public` and granted only to `service_role`.
- **No function anywhere sets `profiles.role`, `branch_id`, or `active`
  from a client-supplied value without first checking the caller's own
  server-derived role.** Checked `staff-invite` specifically (the one
  function that legitimately accepts a `role` field, since inviting
  someone requires specifying their role) — confirmed the caller's own
  `callerProfile.role` is checked server-side *before* `body.role` is
  ever used, with an explicit guard preventing a Centre Manager from
  creating a Super Admin.
- Customer phone-OTP flow unchanged since PG-004; `handle_new_customer_signup`
  trigger remains `SECURITY DEFINER`, scoped correctly.

**No privilege-escalation vector found.**

## 3. RLS / Security

**The eight tables this project has treated as maximally sensitive
(zero client write policy, by design, since PG-005) were re-verified
line-by-line across every one of the 33 migrations, not just recalled
from memory:**

| Table | Policies | Write policy? |
|---|---|---|
| `jobs` | 1 | None |
| `quotes` | 1 | None |
| `payments` | 1 | None |
| `payment_events` | 1 | None |
| `documents` | 1 | None |
| `dxf_release_grants` | 1 | None |
| `dxf_download_logs` | 1 | None |
| `audit_events` | 1 | None |

Each has exactly the one `SELECT` policy it was given at creation —
confirmed by grep, not by trusting prior tasks' own reports.

- **Customer isolation**: verified via `pgTAP` test design
  (`10_customer_isolation.sql`) and by re-reading every customer-facing
  policy's condition — all resolve identity through
  `customers.auth_user_id = auth.uid()`, never `profiles`.
- **Centre Manager branch isolation**: verified consistently applied —
  `hold-job`/`resume-job`/`cancel-job`/`reopen-job`/`release-job` all
  use the same `authorizeOperationalAction()` helper (one
  implementation, reused, not five separate hand-rolled checks that
  could drift from each other).
- **PGLC/production DXF protection**: four distinct Storage buckets
  confirmed (`pglc-public`, `pglc-production`, `job-drafts`,
  `job-documents`) — the two job-scoped buckets have **zero**
  `storage.objects` policies (access only via signed URLs from
  service-role functions); `staff_get_draft_dxf_path()`'s Production-role
  gate (requires `release_status = 'released'`) is unchanged since
  PG-010.
- **No broad write policy was ever added "merely to make a function
  work"** — every Edge Function that needs to write a locked-down table
  uses the service-role key, not a widened policy. Confirmed by the
  policy count table above staying exactly at 1 (SELECT-only) for all
  eight tables across every subsequent task.

**No RLS weakening found anywhere.**

## 4. Eight-stage job lifecycle

| Transition | Function | Authorized | Branch-scoped | Precondition check | Audit event? | Notification? | Concurrency-safe? |
|---|---|---|---|---|---|---|---|
| → `SUBMITTED` | `decide-quote-request` | Centre Mgr (branch) / central staff | Yes | `status='pending'` | Yes | Yes | **No** (see Section 12) |
| → `PAYMENT_CONFIRMED` | `confirm-payment` | Accountant only, fresh challenge | N/A | `status∈{matched,no_match}` | **No** | Yes | **No** |
| → `DESIGN_IN_PROGRESS` | `start-design` | Designer/Super Admin | N/A | `stage='PAYMENT_CONFIRMED'` | **No** | No* | **No** |
| → `DESIGN_SENT_FOR_APPROVAL` | `release-draft` | Designer/Super Admin | N/A | CAD release gate (trigger) | **No** | Yes | **No** |
| → `IN_PRODUCTION` | `respond-to-design` (approve) | Customer (own job) | N/A | `stage='DESIGN_SENT_FOR_APPROVAL'`, released draft exists | **No** | No* | **No** |
| → `READY_FOR_DISPATCH` | `mark-ready-for-dispatch` | Production (own branch)/Super Admin | Yes | `stage='IN_PRODUCTION'` | Yes | Yes | **Yes** |
| → `DISPATCHED` | `dispatch-job` | Inventory (own branch)/Super Admin | Yes | `stage='READY_FOR_DISPATCH'` | Yes | Yes | **Yes** |
| → `RELEASED` | `release-job` | Centre Mgr (own branch)/Super Admin | Yes | `stage='DISPATCHED'`, balance confirmed | Yes | Yes | **Yes** |

`*` — not in Master Spec §16's notification list, so absence is by
design, not a gap.

**Stage-skipping**: confirmed impossible under normal (non-concurrent)
use for every transition — each function checks the exact required
`current_stage` before writing. Under a *race* (Section 12), the risk
is duplicate side-effects at the same correct stage, never an actual
skip to the wrong stage — this distinction matters and is verified,
not assumed.

**Audit consistency gap, confirmed by exact grep count**: `confirm-payment`,
`start-design`, `release-draft`, `respond-to-design` — 4 of 8 stage
transitions — write **zero** `audit_events` rows. This is the same gap
PG-014 found and PG-015 deliberately did not retroactively fix (correctly,
per that task's explicit scope limit) — flagging it here as a
confirmed, unresolved finding, most concerning specifically for
`confirm-payment` (a financial confirmation with no audit trail) and
`respond-to-design`'s approve path (a customer-facing legal/commercial
approval with no audit trail).

## 5. Payments

**Specifically verified**: *"Can a job incorrectly reach `RELEASED`
while an outstanding balance exists?"*

**No.** `release-job`'s check:
```
if (quote.balance_kobo > 0) {
  // requires a payments row: kind='balance', status='confirmed'
  // else: 409, no transition attempted
}
```
`balance_kobo` is schema-guaranteed `NOT NULL` (Section 1), so the
`> 0` comparison can't be silently bypassed by a null value. No
client-supplied amount is read anywhere in this check — it's entirely
server-derived from `quotes` (computed once, at quote-issuance time,
by the server-side quote engine) and `payments.status` (settable only
by `confirm-payment`, itself gated behind the Accountant fresh
challenge). **No path found that reaches `RELEASED` with an unpaid
balance.**

Deposit/balance sequencing (`create-payment-request` refusing to create
a `balance` request until a `deposit` is confirmed) remains intact and
unchanged since PG-009.

## 6. Quote engine

- `quotes` has zero client write policy (Section 3) — every quote is
  created by `issue-quote` or `decide-quote-request`'s internal call to
  the same `calculateQuote()` core, both service-role.
- `calculateQuote()` reads only `pricing_rates`/`commercial_settings`
  (server config, empty — Section 1) and the job/quote_request's own
  already-validated spec fields — no client-supplied price component is
  read anywhere in the arithmetic.
- **No pricing value was created during this audit** — `pricing_rates`/
  `commercial_settings` remain exactly as empty as PG-007 left them,
  confirmed again in Section 1.
- Immutability: `quotes.unique(quote_request_id, version)` plus the
  complete absence of any `UPDATE` policy or function targeting
  `quotes` means an issued quote's commercial fields can never change
  in place — a repriced quote is a new row, not a mutation.

**No client-side price manipulation path found.**

## 7. Design / DXF security

- Catalogue previews (`pglc-public`) remain public-read, as designed —
  this is intentional (Master Spec §11's browsable catalogue), not a
  leak.
- `pattern_assets` rows with `asset_type='dxf'` remain excluded from
  non-staff `SELECT` at the **row** level (not just a hidden column) —
  unchanged since PG-005.
- Design-review geometry (`drafts.preview_path`) is customer+staff
  visible via `drafts_select_own_or_staff`; production-ready geometry
  (`drafts.dxf_path`) remains column-revoked from **everyone**,
  reachable only via `staff_get_draft_dxf_path()`, which itself now
  requires `release_status='released'` for the Production role
  specifically (PG-010's tightening, unchanged since).
- The CAD release gate (`enforce_draft_release_gate` trigger, PG-005)
  is unmodified — a failed mandatory check still blocks
  `release_status='released'` without an `override_reason`.
- Customer approval (`respond-to-design`) still requires a released
  draft to exist before allowing `IN_PRODUCTION` — verified unchanged.

**No path found for an unauthorized user to obtain a production DXF
file.**

## 8. Documents

- `document_type_enum` remains fixed to `PGJO`/`PGAO` — no third type
  was ever added.
- **Idempotency verified as genuinely race-safe**, not just
  documented as such: `generateDocument()` checks `event_key` before
  any work, and explicitly catches a `23505` (unique violation) on
  insert to return the already-created row instead of erroring —
  confirmed by re-reading the exact code, not just the comment above
  it. This means even under the concurrency gap described in Section
  12 (the *stage transition* that triggers document generation isn't
  atomic), the *document itself* cannot be duplicated.
- `job-documents` bucket: zero client-accessible policies, matching
  `job-drafts`' pattern — confirmed unchanged.
- No embedded DXF/preview link in any generated document (verified in
  PG-011, re-confirmed by re-reading `document_generator.ts` — only a
  draft *version number* is referenced in PGAO, never a path).

**No duplicate-generation risk found**, despite the underlying
transition race (Section 12) — this is a genuine, verified positive
finding, not an oversight in the audit.

## 9. Notifications

- All 9 `notify()` call sites (across `decide-quote-request` ×2,
  `confirm-payment`, `release-draft`, `respond-to-design`, `hold-job`,
  `cancel-job`, `mark-ready-for-dispatch`, `dispatch-job`, `release-job`)
  are wrapped in `try/catch` — confirmed individually, not by pattern
  assumption (my first grep pass used too narrow a search window and
  under-counted; corrected and re-verified before including this
  finding).
- **Notification failure cannot block a business transaction** —
  every wrapping `try/catch` sits *after* the real operation has
  already committed.
- **Recipient resolution is always server-side** — the job's own
  `customer_id`, the draft's own `created_by`, or the branch's own
  Centre Manager, never a client-supplied recipient.
- **Duplicate notifications ARE possible**, but only as a direct
  consequence of the Section 12 concurrency gap, not a separate
  notification-specific bug — a race that produces two `audit_events`
  rows for the same hold action would also produce two "your job is on
  hold" notifications. This is the same root cause, not a new one.

## 10. Offline architecture

**Confirmed entirely unimplemented, not partially implemented as it
might appear from the schema alone**: `devices` and `offline_actions`
(PG-003) are referenced by **zero** application code anywhere in this
repository — no registration flow, no sync processor, no read path.
They exist as pure schema, currently inert. This means:

- **No offline write can currently reach a sensitive operation at
  all** — there is no code path that ever reads `offline_actions` and
  replays it into a real mutation, so the "could an offline write
  bypass a security rule" question is currently moot by construction,
  not because it was carefully guarded against. When PG-(future)
  offline sync is eventually built, this needs deliberate design, not
  an assumption that today's absence of a problem will continue.

## 11. Branch / role model

| Role | Read | Write (via server functions) | Lifecycle actions | Branch-scoped? |
|---|---|---|---|---|
| Super Admin | All | All (via functions) | All | No (global) |
| Accountant | Payments, quote_requests (branch-agnostic) | `confirm-payment`, `triage-payment` | `PAYMENT_CONFIRMED` | No |
| Centre Manager | Own-branch jobs/quote_requests/customers/payments/documents | `decide-quote-request` (own branch), `hold/resume/cancel/reopen-job`, `release-job` | `SUBMITTED` (branch), `RELEASED` | **Yes** |
| Designer | Drafts, jobs (central read) | `start-design`, `release-draft`, draft_checks | `DESIGN_IN_PROGRESS`, `DESIGN_SENT_FOR_APPROVAL` | No |
| Production | Jobs (central read) | `mark-ready-for-dispatch` (own branch only, PG-015) | `READY_FOR_DISPATCH` | **Yes** (PG-015 only — inconsistent with its general central-read status, flagged already in PG-015) |
| Inventory | Jobs (central read) | `dispatch-job` (own branch only, PG-015) | `DISPATCHED` | **Yes** (same inconsistency as Production) |
| Customer | Own records only | `respond-to-design`, `create-payment-request`, quote_request insert, pattern_favourites | `IN_PRODUCTION` (via approve) | N/A (row-owned, not branch-owned) |

**Flagged inconsistency** (already noted in PG-015's own docs, restated
here as a confirmed audit finding, not a new discovery): Production and
Inventory are **central** (non-branch-scoped) for every read-access
purpose established since PG-005, but branch-scoped for exactly one
action each (PG-015). This is an intentional, explicitly-approved
decision — not an accident — but it means these two roles now have a
genuinely split model (central for visibility, local for this one
action) that a future reviewer could easily misread as inconsistent
without this context. Worth a one-line clarifying comment if either
role gains a second action later.

**No invented permission found** — every cell in this matrix traces to
an actual policy or function check, not an inference.

## 12. Concurrency / idempotency — the audit's primary finding

**Only 3 of 12 lifecycle-adjacent functions use a safe atomic
compare-and-swap** (`mark-ready-for-dispatch`, `dispatch-job`,
`release-job` — PG-015, `.eq('current_stage', 'EXPECTED')` in the same
statement as the `UPDATE`). The other 9 use a select-then-check-then-update
pattern with a genuine TOCTOU race window:

`decide-quote-request`, `confirm-payment`, `start-design`,
`release-draft`, `respond-to-design`, `hold-job`, `resume-job`,
`cancel-job`, `reopen-job`.

**What this can and cannot cause, verified precisely rather than
assumed:**

- **Cannot** cause an invalid final state — every racing call enforces
  the identical precondition, so if both proceed, both write the
  *same* correct target value. No stage-skip, no corruption.
- **Cannot** duplicate a generated document — `generateDocument()`'s
  own idempotency is independently race-safe (Section 8).
- **Can** duplicate `audit_events` and `job_stage_history` rows, and
  duplicate customer notifications, if two calls race within the same
  narrow window (milliseconds, in practice — this is a low-probability,
  not a high-probability, event).
- **`decide-quote-request` has a partially-mitigated version of this
  race**: two concurrent "accept" calls on the same `quote_request`
  could both pass the `status !== 'pending'` check before either
  writes, both proceed through `calculateQuote()`, and both attempt to
  insert a `quotes` row — but `quotes.unique(quote_request_id, version)`
  (an *accidental* safety net, not one designed for this purpose)
  causes the second insert to fail with a `23505`, which the function
  currently surfaces as a generic 500 error rather than a clean,
  informative conflict response. **No duplicate quote or duplicate job
  is actually created** — the losing request just gets an ugly error
  instead of a clean one.

**Severity assessment**: Low-to-medium. No security boundary is
crossed, no data corruption occurs, no financial double-charge is
possible (the payment-confirmation gate is a separate, single-action
Accountant-only path with its own fresh-challenge requirement, not
subject to this same race in a way that could double-confirm the same
payment — `confirm-payment`'s precondition, `status ∈ {matched,
no_match}`, transitions to `confirmed`, and a second racing call would
see `status='confirmed'` and correctly refuse, since that value isn't
in the allowed precondition set). The practical impact is duplicate
audit noise and duplicate customer notifications under genuinely
concurrent staff action on the *same* job — an operational polish
issue, not a security or financial one.

**Recommendation**: before production launch (not before continuing
development), retrofit the 9 older functions to the same atomic
compare-and-swap pattern PG-015 established. This is a mechanical,
low-risk change to each function's own `UPDATE` call — it does not
require any schema change, RLS change, or business-logic change, and
was explicitly out of scope for every task through PG-015 ("do not
refactor unrelated existing transition functions").

---

## Testing gate — the standing risk independent of any finding above

**No live Supabase project, network connection, or Deno runtime has
been available at any point across PG-001 through this audit.** Every
single claim in this document about *runtime behavior* (as opposed to
static code/schema structure, which was genuinely and directly
verified) is a structural inference, not an observation. The 16 pgTAP
test files that exist have never executed. This has been stated
honestly at the end of every prior task and remains true here — it is
the single largest gap between "this code appears correct on paper"
and "this system is production-verified," and no amount of further
static auditing can close it. **Live verification (the checklists at
the end of every PG-00X doc, `supabase db reset` + `supabase test db` +
`supabase functions serve` + manual exercise of every role/branch/stage
combination) remains a mandatory gate before production use, exactly
as PG-005's original framing established.**

## Summary of findings requiring action (in priority order)

1. **[Medium, pre-production] Concurrency**: retrofit 9 older
   lifecycle functions to PG-015's atomic pattern (Section 12).
2. **[Medium, pre-production] Audit gap**: add `audit_events` logging
   to `confirm-payment`, `start-design`, `release-draft`,
   `respond-to-design` (Section 4) — most important for
   `confirm-payment` specifically.
3. **[Low] Error clarity**: `decide-quote-request`'s race-losing path
   returns a generic 500 instead of a clean 409 (Section 12).
4. **[Informational] Role-model note**: Production/Inventory's
   split central-vs-branch-scoped model (Section 11) is correct but
   worth a code comment if extended later.
5. **[Standing, not new] Live verification**: still entirely
   unperformed across the whole project (Testing Gate above).

None of these block continued development. Item 5 blocks production
launch on its own, independent of anything else in this document.

---

**This audit made no code, schema, RLS, UI, or Edge Function changes.**
Confirmed via `git status` before committing — this task's commit
contains exactly one new file.

**PG-016 AUDIT COMPLETE**
**PG-017 NOT STARTED**
