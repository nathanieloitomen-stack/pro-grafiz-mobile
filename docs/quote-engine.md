# Quote Engine (PG-007)

**Status: PG-007 complete as scoped, with explicit open decisions
reported below rather than silently resolved.** This document exists
specifically to satisfy the instruction: "If PG-007 requires a decision
that is not specified in the Master Spec, STOP and report the decision
rather than silently inventing a business rule." Several such decisions
came up. Each is listed under "Decisions requiring your approval," with
exactly what was built in the meantime so the system is honest, not
broken, while they're open.

## What Master Spec §12 actually specifies

> The authoritative quote service receives pattern/blend/sketch,
> material, thickness, dimensions, quantity, finish, delivery,
> installation, urgency and customer type.
>
> It returns material, cutting, finishing, labour, wastage, delivery,
> installation, discount, VAT, subtotal, total, deposit, balance, sheet
> count, estimated cut time and lead time.
>
> All commercial rates must be configurable data, not source-code
> constants.

That's the entire specification. It names the input/output fields and
one hard constraint (configurable data, not constants). It does not
specify: the pricing formula, any rate value, VAT/deposit percentages,
what "urgency" or "customer type" mean or how they affect price, or how
sheet count/cut time are computed.

## A real spec conflict found during inspection

Master Spec §6 lists "Nest/sheet estimation" under **V2** scope
("Automation"), but §12 (V1's Quote Engine) requires **sheet count**
and **estimated cut time** as outputs. Real nesting needs actual
geometry data that doesn't exist until the CAD pipeline (PG-015, V2).
This wasn't resolved by picking a side — see the sheet-count/cut-time
handling below, which makes both fields optional and null unless a
specific set of settings a product owner would need to explicitly
provide are configured.

## What was built

### Schema (all additive — no PG-005 policy touched)

1. **`pricing_rates`** (`20260904000027_pricing_configuration.sql`) —
   per material+finish: `material_rate_per_sqm_kobo`,
   `cutting_rate_per_sqm_kobo`, `finishing_rate_per_sqm_kobo`,
   `labour_rate_kobo`, `wastage_percent`. **Created empty. No seed
   data.** RLS: Super Admin + Accountant read, Super Admin write only,
   zero customer/other-staff access (unlike public catalogue reference
   tables, rate cards are competitively sensitive).
2. **`commercial_settings`** (same migration) — key/value global terms:
   `vat_percent`, `deposit_percent`, `delivery_flat_kobo`,
   `installation_flat_kobo`, `standard_sheet_width_mm`,
   `standard_sheet_height_mm`, `cutting_speed_sqm_per_minute`. **Created
   empty.** Same RLS shape as `pricing_rates`.
3. **`quote_requests.quantity`** (`20260904000028`) — Master Spec §12
   names quantity as an input; no column existed anywhere. Added
   `not null default 1`, `check (quantity >= 1)`. This is *not* a
   business decision — "how many of this item" is unambiguous
   regardless of pricing formula — so it was added without stopping.
4. **`generate_quote_ref_provisional()`** (`20260904000029`) — same
   treatment as `customers.customer_ref` from PG-004: `quotes.quote_ref`
   has no format specified anywhere, so a `QT-xxxxxx` placeholder
   unblocks the NOT NULL UNIQUE constraint. Confirm the real format
   before production.

### Server-side logic

- **`_shared/quote_calculator.ts`** — the arithmetic that combines
  configured rates into the fields `quotes` needs: sums of cost
  components, `VAT = subtotal × vat_percent`, `deposit = total ×
  deposit_percent`. This is standard financial arithmetic, not a
  business-specific invention — but *how* each cost component is
  computed (area-based vs. length-based, flat vs. scaled) involved real
  judgment calls, listed below. **If any required rate is missing, the
  function returns `{ available: false, reason: "..." }` and computes
  nothing — it never fabricates a number.**
- **`estimate-quote`** — public/anon-callable. Pure calculation, no
  database writes. Powers a live estimate while configuring (see UI
  changes below). Strips the raw `pricing_rates` values from its
  response before returning — those must never reach an anonymous
  caller (see "A leak I found and fixed" below).
- **`issue-quote`** — authenticated. Given an existing
  `quote_request_id`, authorizes the caller with the *exact same logic*
  as `quote_requests_select_own_or_staff` (PG-005) — not a new or
  looser rule — then computes and inserts an immutable, versioned
  `quotes` row via the service-role client, which is the only way a
  `quotes` row can be created at all (PG-005 gave that table zero
  client INSERT policies, on purpose). Returns 422 with a clear reason
  and creates no row if pricing isn't configured.

### UI changes

- `ConfigureScreen`'s summary card now calls `estimate-quote` live as
  material/thickness/width/height/finish change, and shows either a
  real ₦ total or an honest "pricing not available yet" message —
  never a placeholder number. This is the part of approved screen #6
  this task's own V1 bullet ("Server-side quotation engine") covers.
- The **"Send to Pro_Grafiz" button remains exactly as inert as PG-006
  left it**, per your explicit decision #3/#4. Nothing about quote
  *submission* changed.

## A leak I found and fixed during this task

`estimate-quote` is deliberately public (a live estimate shouldn't
require signing in). The shared calculator's result embeds the raw
`pricing_rates` row (for audit purposes, needed when `issue-quote`
persists it). Left as-is, that would have meant **any anonymous caller
could read Pro_Grafiz's actual per-square-metre rates** through the
public estimate endpoint — a real information leak, caught before
shipping, not after. Fixed by stripping the snapshot from
`estimate-quote`'s response; `issue-quote`'s persisted record (visible
only to the owning customer or authorized staff, per existing `quotes`
RLS) keeps the full detail.

## Decisions requiring your approval

None of these block the infrastructure above from working correctly
once resolved — each is isolated to `_shared/quote_calculator.ts` or a
`commercial_settings` row.

1. **Material/cutting/finishing cost model.** Implemented as
   area-based (₦/m²) for all three, including cutting — which normally
   should be priced by cut *length*, not area, but real cut-length data
   needs nesting/geometry (V2, per the conflict above). Confirm whether
   area-based cutting is an acceptable V1 approximation, or whether
   quotes should wait for real nesting before shipping cutting cost at
   all.
2. **Labour cost model.** Implemented as a flat per-job rate
   (`labour_rate_kobo`), not scaled by area or time. Confirm.
3. **Discount mechanism.** No promo-code or customer-tier discount
   system exists anywhere in the schema or docs. `discount_kobo` is
   always `0`. If discounts are needed, the mechanism (codes? tiers?
   manual staff override?) needs to be specified.
4. **"Urgency" and "customer type."** Accepted as optional inputs,
   recorded in the persisted `pricing_snapshot` for future reference,
   but **have zero effect on price** — no rate impact for either is
   specified anywhere. If they should affect price, the valid values
   and the rate impact both need to be specified.
5. **Sheet count / estimated cut time.** Computed only if
   `standard_sheet_width_mm`, `standard_sheet_height_mm`, and
   `cutting_speed_sqm_per_minute` are all configured in
   `commercial_settings`; otherwise `null`. This sidesteps the V1/V2
   conflict above rather than resolving it — confirm whether an
   area-based sheet estimate is acceptable for V1 or whether these
   fields should simply stay null until real nesting exists.
6. **VAT and deposit percentages.** No values exist anywhere in the
   provided docs (an earlier assessment of mine, from before PG-003,
   mentioned a "60%/40% deposit split" — on re-inspection during this
   task, that number does **not** appear anywhere in
   `PRO_GRAFIZ_MASTER_SPEC.md` or `CLAUDE.md`; it was not sourced from
   the documents and should not be relied on to have been. This is
   flagged explicitly rather than quietly carried forward.) `quotes`
   cannot be issued at all until `vat_percent` and `deposit_percent`
   are set in `commercial_settings` — that's enforced by
   `calculateQuote()`, not just documentation.
7. **Delivery and installation costs.** Modeled as flat fees
   (`delivery_flat_kobo`, `installation_flat_kobo`), not
   distance/area-scaled — there's no address or location data in the
   schema to scale by. Confirm this is acceptable for V1.

## RLS/security implications

- No existing PG-005 policy was modified. `pricing_rates` and
  `commercial_settings` are new tables with their own fresh, narrower
  policies (finance-staff read, Super-Admin write, zero customer
  access).
- `issue-quote`'s authorization logic duplicates
  `quote_requests_select_own_or_staff`'s rule in application code
  (necessarily — Edge Functions can't "call into" a table's RLS policy
  directly) rather than inventing a different one. If that RLS policy
  is ever changed, `issue-quote`'s `isAuthorized()` function must be
  updated to match, or the two will drift apart silently. Worth a
  regression test once a live project exists.
- `quotes` still has zero client INSERT/UPDATE policies (unchanged from
  PG-005) — `issue-quote` is the only way a row is created, via the
  service-role key, never exposed to any client.
- No production secrets, credentials, or real rate values were
  introduced anywhere in this task.

## Files changed

**New:** `20260904000027_pricing_configuration.sql`,
`20260904000028_quote_request_quantity.sql`,
`20260904000029_quote_ref_provisional.sql`,
`supabase/functions/_shared/quote_calculator.ts`,
`supabase/functions/estimate-quote/index.ts`,
`supabase/functions/issue-quote/index.ts`,
`apps/mobile/lib/features/quoting/data/quote_repository.dart`,
`supabase/tests/database/80_pricing_configuration.sql`,
`docs/quote-engine.md` (this file).

**Modified:** `apps/mobile/lib/features/catalogue/presentation/configure_screen.dart`
(live estimate wiring only — the Send button's `onPressed: null` is
untouched), `docs/database-schema.md`, `docs/authorization.md`,
root `README.md` (status lines).

## Verification status

Same standard as every prior task — nothing here has executed against
a live database or Deno runtime.

**Verified locally (static analysis actually run, not a database):**
parenthesis/`$$`/`$q$` balance across all 3 new migrations, 3 new
TypeScript files, and the pgTAP test file; every column name referenced
in the calculator and both Edge Functions cross-checked against the
actual `CREATE TABLE` statements; confirmed via `git status` that no
existing migration file (PG-001–006) was modified; confirmed
`estimate-quote`'s response no longer includes the `rates` object after
the leak fix.

**Requires live Supabase verification:**
```bash
supabase db reset                      # migrations 27–29 apply on top of 1–26
create extension if not exists pgtap;
supabase test db                       # includes 80_pricing_configuration.sql
supabase functions serve
```
Then: call `estimate-quote` with no rates configured and confirm
`available: false` with no numbers; add a `pricing_rates` row and
`vat_percent`/`deposit_percent` settings, call it again, and manually
verify the arithmetic; call `issue-quote` as the owning customer and as
an unrelated customer (should be rejected) and as a Centre Manager from
a different branch (should be rejected); confirm the inserted `quotes`
row's `pricing_snapshot` is NOT reachable via the public
`estimate-quote` path under any input.
