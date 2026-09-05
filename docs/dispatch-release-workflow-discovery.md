# Dispatch & Release Workflow — Discovery / Decision Gate (PG-014)

**Status: Discovery only. No production code, migration, UI, or Edge
Function was written for this task.** This document exists to resolve
the gap PG-013 correctly identified and did not fill in.

## 1. Executive finding

Three of the eight approved job stages — `READY_FOR_DISPATCH`,
`DISPATCHED`, `RELEASED` — have **no transition mechanism, no owning
role assignment, and no supporting data model anywhere in this
codebase.** Master Spec names the stages and, separately, names a role
list (§8) and a one-line staff journey ("...production →
dispatch/release"), but **nowhere does it map a specific role to a
specific one of these three transitions.** The mapping this task's own
brief suggests (Production → ready, Inventory → dispatched, Centre
Manager → released) is a plausible reading of role *names* against
stage *names*, not a stated rule — Section 5 below evaluates it rather
than assuming it.

Beyond role assignment, two substantive precondition questions are
genuinely open and financially/operationally significant: **whether the
balance payment must be confirmed before physical release**, and
**whether customer confirmation of receipt is required to close the
job.** Neither is specified anywhere. Both are flagged for the Product
Owner rather than assumed.

**Recommendation in brief** (full reasoning in Section 10): implement
the smallest possible version — three new Edge Functions mirroring the
existing `start-design`/`release-draft` pattern exactly, no new tables,
explicit reasons and audit events on every transition, and the two
open precondition questions answered by the Product Owner *before*
writing any of it — not deferred to "confirm later."

## 2. Existing lifecycle implementation

Every stage transition currently in the codebase, confirmed by direct
inspection of every `current_stage:` write:

| Stage reached | Function | Actor (as implemented) | Branch-scoped? | Audited? | Notified? |
|---|---|---|---|---|---|
| `SUBMITTED` | `decide-quote-request` (PG-008) | Centre Manager (own branch) or central staff | Yes | Yes (PG-012) | Yes — customer (PG-013) |
| `PAYMENT_CONFIRMED` | `confirm-payment` (PG-009) | Accountant only | N/A (accountant is central) | **No** | Yes — customer |
| `DESIGN_IN_PROGRESS` | `start-design` (PG-010) | Designer or Super Admin | N/A | **No** | No (deliberately — not in Master Spec §16's list) |
| `DESIGN_SENT_FOR_APPROVAL` | `release-draft` (PG-010) | Designer or Super Admin | N/A | **No** | Yes — customer |
| `IN_PRODUCTION` | `respond-to-design` (PG-008), "approve" branch | **Customer** (not staff — this transition is customer-triggered) | N/A | **No** | No (the customer already knows — they just triggered it) |

Every one of these five uses the identical, established pattern this
discovery treats as the baseline to extend: caller identity resolved
server-side from their JWT → `profiles`/`customers` row looked up fresh
→ authorization checked in application code (`jobs` has zero client
write policies, so this is the *only* enforcement layer for who may
write `current_stage`) → precondition checked (current stage/status) →
`jobs` UPDATE via service-role → `job_stage_history` row inserted →
(inconsistently) `audit_events` row inserted → (where applicable)
`notify()` called.

**Existing audit inconsistency, noted but not fixed here** (this
discovery must not modify PG-008/009/010/013): `decide-quote-request`,
`hold-job`, `cancel-job`, `resume-job`, `reopen-job` write
`audit_events`; `confirm-payment`, `start-design`, `release-draft`,
`respond-to-design` do not, despite all being sensitive stage-changing
actions. Whatever is built for the three missing transitions should
audit consistently — that's a reason to *not* copy every existing
function verbatim, addressed in Section 10.

`jobs.status` (`active`/`on_hold`/`cancelled` — a PG-003 inference, not
a Master Spec enum) is orthogonal to `current_stage` and already fully
implemented (`hold-job`/`resume-job`/`cancel-job`/`reopen-job`, PG-012)
— nothing about the three missing transitions requires touching
`status` at all, only `current_stage`.

## 3. Missing transition analysis

Confirmed by grep across every migration and function — zero matches
for any of the following:

- Any write of `current_stage` to `READY_FOR_DISPATCH`, `DISPATCHED`,
  or `RELEASED`.
- Any table, column, or enum value containing "dispatch," "delivery,"
  "collection," "driver," "courier," "handover," or "logistics" —
  except: `quotes.delivery_cost_kobo` / `quotes.installation_cost_kobo`
  (pricing line items only, no workflow behind them), and the stage
  names themselves.
- Any role-to-these-three-stages mapping in Master Spec or CLAUDE.md.

Master Spec's only relevant text is narrative, not a specification:

> "**Staff journey:** Intake → quote → payment verification → design
> desk → customer approval → production → dispatch/release."

> "Sign in → Browse PGLC → ... → Track stages → **Release/collection**."

Neither names an actor, a precondition, or any data to record.

## 4. Proposed transition matrix

**Proposed for evaluation — not implemented, not confirmed.** Column
values marked "OPEN" are the Section 11 decisions.

| From | To | Proposed actor | Preconditions (proposed) | Audit event | Notification |
|---|---|---|---|---|---|
| `IN_PRODUCTION` | `READY_FOR_DISPATCH` | Production, or Super Admin | job.status = 'active'; current_stage = 'IN_PRODUCTION' | `job.mark_ready` | Customer: "your order is ready" |
| `READY_FOR_DISPATCH` | `DISPATCHED` | Inventory, or Super Admin | job.status = 'active'; current_stage = 'READY_FOR_DISPATCH'; OPEN: dispatch method/reference required? | `job.dispatch` | Customer: "on the way" / "ready for collection" |
| `DISPATCHED` | `RELEASED` | Centre Manager (own branch), or Super Admin | job.status = 'active'; current_stage = 'DISPATCHED'; **OPEN: balance payment confirmed?**; **OPEN: customer confirmation required?** | `job.release` | Customer: "collected/delivered" |

This mirrors the branch-scoped-Centre-Manager-or-Super-Admin authority
pattern already established for hold/cancel (PG-012) for the one
transition (`RELEASED`) that is genuinely a physical, branch-located
event — a customer collects *at a specific centre*. The other two
proposed actors (Production, Inventory) are **not** branch-scoped in
this proposal, matching how `is_production()`/`is_inventory()` are
already treated as central (non-branch) roles everywhere else in this
codebase (`is_central_staff()` includes both, PG-005) — see Section 5
for why this still needs confirmation rather than being treated as
settled.

## 5. Role/branch authorization analysis

**The suggested Production→ready / Inventory→dispatched /
CentreManager→released mapping was evaluated, not assumed.** Reasoning
for and against:

**For:** Role *names* thematically match. "Inventory" managing physical
stock/dispatch and "Production" completing the cut both read naturally.
Every other role in this schema (`Accountant`↔payments,
`Designer`↔drafts) already owns exactly the stage transition its name
suggests, established in PG-009/PG-010 without needing this exact
mapping to be spelled out — that precedent is real and worth weighing.

**Against:** Master Spec §8 explicitly lists what's stated about roles
(branch restriction for Centre Manager, general "central roles see all
branches") and **stops there** — it does not extend the pattern to
these three stages the way it extends naturally for Accountant/Designer
(whose domain-matching was validated by this codebase's own existing,
already-accepted functions, not just name-matching). Two roles
(`Production`, `Inventory`) have had **zero functions written against
them anywhere in this codebase until now** — every existing use of
`is_production()`/`is_inventory()` is either the CAD-file-access
refinement (PG-010, a read/authorization-tightening context, not an
action-taking one) or membership in the generic `is_central_staff()`
read-access list. There is no precedent of either role *performing* a
state-changing action anywhere in this codebase to validate the
inference against, unlike Accountant/Designer.

**Also unconfirmed**: whether Centre Manager is the right actor for
`RELEASED`, or whether Inventory (already handling `READY_FOR_DISPATCH`
→`DISPATCHED` in this proposal) should also close it out. "Centre
manager" appears in the task brief's own suggested table but not in
Master Spec's text about this specific moment — the actual physical
handover at a centre plausibly involves whichever front-of-house staff
member is present, which could be Centre Manager, Inventory, or even
Accountant (verifying final payment) depending on how Pro_Grafiz
actually staffs collection.

**Conclusion: present the matrix in Section 4 as the most defensible
starting proposal, given naming precedent and this codebase's existing
central-vs-branch-scoped conventions — but treat role assignment for
all three transitions as an explicit Product Owner decision, not a
default to implement unreviewed.**

## 6. Preconditions

For each proposed transition, the specific dimensions this task's brief
asked to be evaluated:

| Dimension | `→READY_FOR_DISPATCH` | `→DISPATCHED` | `→RELEASED` |
|---|---|---|---|
| Branch-scope requirement | Proposed: no (central role) | Proposed: no (central role) | Proposed: yes (own branch) |
| Required DB state | `current_stage='IN_PRODUCTION'`, `status='active'` | `current_stage='READY_FOR_DISPATCH'`, `status='active'` | `current_stage='DISPATCHED'`, `status='active'` |
| Required evidence/data | None identified as necessary; OPEN whether a completion note should be optional/mandatory | **OPEN**: dispatch method (customer collects vs. delivered)? A reference/tracking value? No schema exists for either | **OPEN**: any handover evidence (signature, photo)? No schema exists |
| Customer approval required? | No — this is a staff-only operational step, unlike `IN_PRODUCTION` which is customer-triggered | No | **OPEN**: does the customer need to actively confirm receipt, or is staff's action alone sufficient to close the job? |
| Payment status relevant? | Deposit already guaranteed confirmed by this point (structural: `IN_PRODUCTION` is unreachable without it) | Same as above — no new payment consideration | **OPEN, significant**: `quotes.balance_kobo` may still be entirely unpaid at this point — nothing in the existing chain forces balance payment before `IN_PRODUCTION`. Whether physical release should be blocked on balance confirmation is a real business/financial decision, not assumed here either way |
| Inventory confirmation required? | N/A (this transition creates the "ready" state Inventory would confirm) | **OPEN**: does moving to `DISPATCHED` implicitly mean Inventory already confirmed something happened, or is a separate confirmation step needed? | No |
| Dispatch information required? | No | **OPEN**: see "required evidence" above | No |
| Customer confirmation required? | No | No | **OPEN**: see "customer approval required" above |

## 7. Security/RLS implications

- **`jobs` must remain fully locked to service-role for writes** — no
  new client write policy should be added for any of these three
  transitions, exactly matching the existing five. This preserves
  "no direct client-side job-stage manipulation" without exception.
- **Branch, where used, must be read from the job's own persisted
  `branch_id`, server-side** — never accepted from the client request
  body, exactly matching `hold-job`/`cancel-job`/`resume-job`/
  `reopen-job`'s existing pattern (`_shared/staff_auth.ts`). If
  `RELEASED` is confirmed as Centre-Manager-scoped, that same shared
  helper should be reused, not reimplemented.
- **If a new evidence/reference field is ever added** (e.g. a dispatch
  reference or collection note), it must not become a vector for
  privilege escalation or data leakage — e.g. a free-text field
  shouldn't silently become a place client input reaches an audit trail
  unsanitized. Not a concern yet, since no such field is confirmed.
- **No change to any existing RLS policy is implied by anything in this
  document.** All three proposed transitions, like all five existing
  ones, operate entirely through the service-role bypass already
  established — RLS's role is exactly what it already is: preventing
  any direct client path to `jobs`, full stop.
- **Audit consistency**: whatever is eventually built should write
  `audit_events` for all three transitions (unlike the inconsistent
  existing five, per Section 2) — this is a recommendation for the
  implementation task, not a change made here.

## 8. Notification implications

Mapped to PG-013's existing `_shared/notifier.ts` infrastructure — no
new notification mechanism is needed, only new call sites, once the
transitions themselves exist:

- **`READY_FOR_DISPATCH`**: matches Master Spec §16's "ready" event.
  Notify the customer.
- **`DISPATCHED`**: matches "dispatch." Notify the customer — exact
  wording depends on the OPEN dispatch-method question (Section 6):
  "on the way" reads wrong if the actual model is "ready for you to
  collect," which is arguably the *same* event as `READY_FOR_DISPATCH`
  rather than a distinct one if Pro_Grafiz's real model is
  collection-only, not delivery. **This is itself a business-model
  question**, not just a copywriting one — flagged in Section 11.
- **`RELEASED`**: matches "release." Notify the customer, and this is
  also the point Master Spec §16's generic "quote ready"/journey-closing
  language implies a final, job-closing notice makes sense.

No push delivery exists for any of this (PG-013 already reported FCM
requires real credentials not available here) — these would be
in-app-inbox-only notifications, same limitation as everything already
built.

## 9. Required schema considerations

**No new table is recommended for V1.** Evaluated against the existing
architecture:

- **Dispatch/delivery/collection/handover entity**: `job_stage_history`
  already exists and already captures exactly the shape a "dispatch
  event log" would need (`job_id`, `stage`, `entered_at`, `advanced_by`,
  `note`) — a free-text `note` on the existing `DISPATCHED`/`RELEASED`
  rows is sufficient to record e.g. "collected by customer in person"
  or "delivered via [method]" without a new table, *unless* the Product
  Owner confirms structured fields (a tracking number, a signature
  image, a specific delivery-method enum) are actually required — in
  which case a dedicated table becomes justified, but not before that
  requirement exists.
- **Driver assignment**: no evidence anywhere that Pro_Grafiz uses
  third-party couriers or assigns drivers as a first-class concept —
  the customer journey narrative says "collect," not "delivered by
  driver X." Building a driver-assignment model now would be inventing
  a delivery workflow that isn't described anywhere, which this task
  explicitly prohibits.
- **A new `document_type_enum` value** (e.g. a waybill/collection
  receipt) is NOT recommended for V1 either — `document_type_enum` is
  fixed to `PGJO`/`PGAO` by CLAUDE.md explicitly; a third type is a
  real product decision (format, numbering convention, legal
  requirement) equivalent in weight to the PGJO/PGAO decision itself,
  not something to add as a side effect of this task.
- **If balance-payment enforcement is confirmed as a precondition**
  (Section 6), no new schema is needed for that either —
  `payments`/`quotes.balance_kobo` already fully support checking "is
  there a confirmed balance payment for this job," the same way
  `create-payment-request` already checks for a confirmed deposit
  before allowing a balance request.

## 10. V1 implementation recommendation

**Smallest production-safe scope**, once Section 11's decisions are
answered:

1. Three Edge Functions (`mark-ready-for-dispatch`, `dispatch-job`,
   `release-job`), each mirroring `start-design`'s exact shape:
   resolve caller → check role (and branch, if `release-job` is
   confirmed Centre-Manager-scoped) → check current
   `current_stage`/`status` → UPDATE `jobs` → insert
   `job_stage_history` → insert `audit_events` (closing the existing
   inconsistency, not replicating it) → call `notify()`.
2. **No new table.** A `note`/`reference` field can be accepted as
   free text into `job_stage_history.note` if the Product Owner wants
   any dispatch detail recorded, without a schema change.
3. **No new document type.**
4. If balance-payment enforcement is confirmed: `release-job` gains one
   additional precondition check against `payments`, mirroring
   `create-payment-request`'s existing deposit-check pattern exactly.
5. If customer confirmation is confirmed as required before `RELEASED`:
   this becomes a fourth, customer-triggered function
   (`confirm-receipt`, mirroring `respond-to-design`'s customer-auth
   pattern) rather than a precondition on staff's `release-job` — a
   meaningfully different shape, which is exactly why this needs
   answering before implementation starts, not during it.
6. Fix the audit-logging inconsistency **only within these three new
   functions** — do not retroactively touch `confirm-payment`/
   `start-design`/`release-draft`/`respond-to-design` under this task,
   per "do not silently fix unrelated issues."

## 11. Explicit unresolved Product Owner decisions

1. **Who owns each of the three transitions?** Production/Inventory/
   Centre Manager is a plausible proposal (Section 5), not a confirmed
   rule — needs explicit sign-off, especially since two of those three
   roles have never performed a state-changing action in this codebase
   before.
2. **Is `DISPATCHED` a real, distinct event from `READY_FOR_DISPATCH`,
   or is Pro_Grafiz's actual model collection-only** (in which case the
   two stages may need identical staff-facing treatment, differing only
   in whether the customer picked it up yet)? This affects both the
   transition logic and the notification wording (Section 8).
3. **Must the balance payment be confirmed before `RELEASED`?** Not
   specified anywhere; a real business/financial decision with direct
   revenue-collection consequences if answered incorrectly.
4. **Is customer confirmation required to close the job at `RELEASED`,
   or is a staff action alone sufficient?** Changes the shape of the
   implementation (Section 10, item 5).
5. **Is any structured dispatch/collection evidence required** (a
   reference number, a signature, a photo), or is a free-text note in
   `job_stage_history` sufficient for V1?
6. **Delivery vs. collection-only**: does Pro_Grafiz ever deliver, or is
   every job collected in person at the centre? `quotes.delivery_cost_kobo`
   existing as a priced line item suggests delivery is at least a
   priced option, which would materially affect whether `DISPATCHED`
   needs delivery-specific handling distinct from `RELEASED`.

None of these were guessed at or defaulted in this document.

## 12. Recommended implementation task breakdown

Given the number of open decisions, a single follow-on implementation
task is recommended, gated on Section 11's answers, rather than
splitting further:

- **PG-014 (implementation, once re-authorized with decisions
  answered)**: the three Edge Functions per Section 10, using whichever
  role/precondition answers the Product Owner provides. If customer
  confirmation is required (decision 4), that's a fourth function in
  the same task, not a separate one — it's the same feature.
- **Not recommended as separate tasks**: a dedicated dispatch/delivery
  entity, a driver-assignment system, or a new document type — none are
  justified by anything found during this discovery, and building any
  of them without an explicit requirement would be inventing scope.

---

## Testing

This was a discovery task: repository and static analysis only (grep
across every migration and function, direct reading of Master Spec/
CLAUDE.md sections 3, 5–9, 11, 13, 16, 19). **No live database
verification was performed or claimed.** No production behavior was
modified — confirmed via `git status`, which shows only this new
document.

---

**PG-014 DISCOVERY COMPLETE — IMPLEMENTATION NOT STARTED**

**PG-015 NOT STARTED**
