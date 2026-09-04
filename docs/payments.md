# Payments (PG-009)

**Status: PG-009 complete as scoped, with a payment provider decision
and several business rules explicitly reported rather than resolved.**
This is a financial security gate — every claim below is deliberately
conservative.

## What Master Spec §13 actually specifies

> Use a provider adapter. The gateway/webhook is the source of truth.
>
> Flow: Customer → Payment Request → Gateway → Verified Webhook →
> Payment Event → Payment Confirmation Workflow → PGJO → Job
> Progression.
>
> Provider event IDs and business operations must be idempotent.

Master Spec §3 (Technology Stack): "Provider adapter supporting
Paystack **or** Flutterwave after final commercial/API due diligence."

CLAUDE.md's Payment Rules add: the seven-state list (already
implemented as `payment_status_enum` since PG-003), "NO MATCH cannot be
confirmed automatically," "Accountant confirmation requires a fresh
challenge," and idempotent duplicate-event handling.

## STOP: payment provider is not specified

"Paystack or Flutterwave, after final commercial/API due diligence" is
explicitly unresolved business due diligence (contract terms, settlement
fees, API access), not a technical decision available to make here.
**No provider was chosen. No gateway integration, no webhook handler,
no card/USSD payment method exists in this codebase.** Per your
instruction, this is reported, not silently resolved.

## STOP: business rules confirmed absent from both documents

Verified by direct search (not memory) before writing any code — zero
matches for each of these in `PRO_GRAFIZ_MASTER_SPEC.md` or `CLAUDE.md`:

- Deposit percentage (still open from PG-007 — unchanged here)
- Payment plans / payment milestones
- Late-payment penalties
- Refund rules (when, how much, under what conditions — `'refunded'`
  exists only as a status *value*, with no trigger or workflow defined)
- Cancellation charges
- Gateway fees / transaction fees
- Accounting treatments

None of these were invented, assumed, or implemented. A generic
"escalate" or "refund" action was deliberately **not** built — with no
defined trigger criteria or amount rules, any such function would be
guessing at business logic, exactly what this task prohibits.

## What was built instead: the gateway-independent parts

Two things in the approved design don't depend on which gateway is
eventually chosen, and both have enough specified detail to build
correctly:

1. **Manual bank-transfer matching** — the schema already has
   `payments.bank_reference`, and the approved Payments screen (#17)
   shows exactly this: MATCHED / NO MATCH / CONFIRMED tags for
   reference-based reconciliation. No bank-statement API integration
   exists anywhere in the docs (would need real banking credentials,
   explicitly prohibited) — matching is a manual staff action: the
   Accountant looks at their own bank statement and reports what they
   found.
2. **Accountant fresh-challenge confirmation** — the approved
   "Accountant PIN gate" screen (#18) is described in enough detail
   ("only the accountant may confirm, masked PIN, inline error") to
   implement exactly, independent of any gateway.

## Server-side (Edge Functions)

- **`create-payment-request`** (customer-only): creates a `pending`
  payment for a job's already-quoted `deposit_kobo` or `balance_kobo` —
  the amount is read from the job's own issued quote, **never supplied
  by the client**. Enforces deposit-before-balance sequencing (an
  inference from the schema's split, not stated verbatim — flagged).
- **`triage-payment`** (Accountant/Super Admin): sets a `pending`
  payment to `matched` (with a bank reference) or `no_match`. Lower risk
  than confirmation — no fresh challenge required, since no money is
  released here.
- **`confirm-payment`** (Accountant **only** — not Super Admin, matching
  the approved screen's exact copy "only the accountant may confirm"):
  the fresh challenge is a genuine re-authentication — a brand-new
  `signInWithPassword` attempt using the PIN supplied in *this* request,
  not a check against the caller's existing session token. Allowed from
  `matched` **or** `no_match` (CLAUDE.md's wording is "cannot be
  confirmed *automatically*," implying deliberate manual confirmation of
  a no-match case is allowed). On confirming a `deposit` payment for a
  job at `SUBMITTED`, advances it to `PAYMENT_CONFIRMED` — implementing
  Master Spec §13's own stated flow ("Payment Confirmation Workflow →
  PGJO → Job Progression"), not inventing a new sequence. No PGJO
  document is created — that's PG-011, not built.

## Database changes

One migration: `generate_payment_ref_provisional()` — `payment_ref` had
no format specified anywhere (flagged since PG-003), same provisional
treatment as `customer_ref` and `quote_ref`. **No other schema change.**
`payments`/`payment_events` already existed, fully correctly shaped,
from PG-003/PG-005.

## UI changes

- `JobDetailScreen` (customer): a deposit-payment section at the
  `SUBMITTED` stage — request the deposit, see its status
  (pending/matched/no_match/confirmed) and bank reference once matched.
- `StaffPaymentsScreen` (new): payment list with the MATCHED/NO
  MATCH/CONFIRMED action, per approved screen #17.
- `AccountantPinGate` (new): the PIN-entry bottom sheet, per approved
  screen #18.

## Security implications

- **No client-side payment trust**: `create-payment-request` reads the
  amount from the job's own quote — never accepts a client-supplied
  figure.
- **No client-side payment confirmation**: `payments` still has zero
  client write policies (unchanged from PG-005); all three functions
  write via the service-role key, the only path.
- **Customers can never mark anything paid**: `confirm-payment` is
  restricted to the `accountant` role in application code, and even an
  accountant must pass the fresh-challenge check in the same request.
- **Fresh challenge is real, not simulated**: implemented as an actual
  Supabase Auth re-authentication attempt, not a client-side flag or a
  reused session check.
- **Staff role permissions follow PG-005 exactly**: `triage-payment`
  checks `role = 'accountant' or role = 'super_admin'` directly against
  `profiles`, matching the existing authorization model rather than
  inventing a new one.

## RLS implications

**No existing PG-005 policy was modified.** Confirmed via `git status`
before committing — the only new migration adds a function, not a
policy. `payments`/`payment_events` visibility (Accountant + Super Admin
+ branch-scoped Centre Manager + the owning customer) is exactly as
PG-005 left it; nothing in this task widened or narrowed it. A
regression test (`100_payments.sql`) confirms `payments` still has zero
write policies for any role, since all three new functions depend on
that remaining true.

## Tests actually executed

Static structural analysis only — parenthesis/`$$` balance across the
new migration and all 5 new/modified TypeScript/Dart files; every
table/column reference cross-checked against the actual schema;
confirmed via `git status` that no existing migration or RLS policy
file was modified.

## Tests not executed

Everything in `supabase/tests/database/100_payments.sql` — no live
database in this environment. The three Edge Functions' actual logic
(fresh-challenge verification, the matched/no_match/confirmed state
machine, deposit-before-balance sequencing) cannot be tested via pgTAP
at all — it's TypeScript, not SQL — and has not run anywhere. This is
the task where that gap matters most: **the fresh-challenge mechanism
in `confirm-payment` has never actually been exercised against a live
Supabase Auth instance.**

## Open business decisions (unchanged from PG-007, plus new ones)

All seven items from `docs/quote-engine.md` remain open. New to this
task:

1. **Payment provider** — Paystack vs. Flutterwave, pending commercial
   due diligence not performable here.
2. **Refund rules** — trigger conditions, amounts, and workflow are
   entirely unspecified; `'refunded'` exists only as an unused status
   value.
3. **Escalation criteria** — same situation for `'escalated'`.
4. **Deposit-before-balance sequencing** — a reasonable inference from
   the schema, not a stated rule; confirm before relying on it.
5. **Failed-payment handling** — no automated path exists to reach
   `'failed'` without a gateway; not addressed.

## Required live verification

```bash
supabase db reset          # migration 30 applies on top of 1–29
create extension if not exists pgtap;
supabase test db            # includes 100_payments.sql
supabase functions serve
```

Then, in order: as a customer, call `create-payment-request` for a
job's deposit and confirm the amount matches the job's quote exactly;
attempt `balance` before any deposit is confirmed and confirm it's
rejected; as the Accountant, call `triage-payment` to mark it matched;
call `confirm-payment` with the **correct** PIN and confirm the payment
becomes `confirmed` and the job advances to `PAYMENT_CONFIRMED`; call
`confirm-payment` again with an **incorrect** PIN on a different
payment and confirm it's rejected with no state change; confirm a
Designer session gets zero rows from `payments` entirely; confirm Super
Admin cannot call `confirm-payment` (accountant-only, by design).
