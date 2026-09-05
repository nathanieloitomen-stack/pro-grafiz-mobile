# Notifications (PG-013)

**Status: PG-013 complete as scoped, with one significant gap reported
rather than silently filled.**

## Exact scope, per Master Spec §16

> Support events including quote submitted/ready, payment
> requested/confirmed, design ready, approval requested, design change
> requested, stage changes, hold, ready, dispatch and release.

Plus the V1 bullet "Push notifications and controlled WhatsApp
handoff" (§6) — distinct from V2's "Transactional WhatsApp."

## CRITICAL GAP FOUND: three stages have no transition mechanism at all

Before writing any notification code, I inspected every existing
function for `current_stage` writes. Only five of the eight approved
stages have one:

| Stage | Function |
|---|---|
| `SUBMITTED` | `decide-quote-request` (PG-008) |
| `PAYMENT_CONFIRMED` | `confirm-payment` (PG-009) |
| `DESIGN_IN_PROGRESS` | `start-design` (PG-010) |
| `DESIGN_SENT_FOR_APPROVAL` | `release-draft` (PG-010) |
| `IN_PRODUCTION` | `respond-to-design` (PG-008) |
| `READY_FOR_DISPATCH` | **none** |
| `DISPATCHED` | **none** |
| `RELEASED` | **none** |

Master Spec §16 explicitly names "ready, dispatch and release" as
notifiable events — but nothing anywhere in this codebase can ever
cause a job to reach those three stages. I also checked the full
18-task development sequence (§17): no task name — not PG-012
Operations, not PG-013 Notifications, not anything later — obviously
and explicitly owns building the production/dispatch workflow that
would create these transitions.

**I did not build them.** Doing so under "Notifications" would mean
inventing a production/dispatch workflow (who triggers it, what
preconditions apply, what data it records) with zero specification —
exactly the kind of unspecified-rule invention this task instructs me
to stop and report instead of guessing. It would also mean "silently
fixing" a gap that spans PG-010/PG-012's territory, which I was
separately instructed not to do.

**Practical consequence**: notification hooks exist for every event in
Master Spec's list *except* "ready," "dispatch," and "release" — those
three are structurally impossible until a future task builds the
missing transition service. This should be resolved explicitly — either
by assigning it to an existing later task (PG-014 Offline and PG-015
CAD Pipeline don't obviously include it either, from their names) or by
inserting a new task for it.

## What was built

### Database

One migration: a trigger on `quote_requests` INSERT
(`notify_branch_manager_of_new_quote_request`) — the "quote submitted"
event. This is the *only* event in the list without a corresponding
Edge Function (customers insert `quote_requests` directly via existing
RLS, PG-005), so a trigger is the sole available mechanism, matching
the precedent already set by `handle_new_customer_signup` (PG-004).
**Recipient decision, flagged**: notifies only that branch's Centre
Manager, if one is currently assigned and active — not central staff
broadly. Nothing in the docs says who staffs Intake; a single, obvious
recipient is more conservative than guessing at several roles. No
notification is sent if no Centre Manager is assigned (a valid state,
not an error).

### Server-side

**`_shared/notifier.ts`** (new): a plain insert helper —
`notifications` has zero client INSERT policy (PG-005, unchanged), so
this is the only way a row is created, called from service-role
functions at existing trigger points. `findBranchCentreManager()` is
the same recipient-lookup logic the new DB trigger also uses,
factored out for reuse.

**Six existing files modified** — each gets exactly one small,
clearly-scoped notification call added after its existing (unchanged)
logic succeeds, wrapped so a notification failure never undoes the
real operation:

| File | Event | Recipient |
|---|---|---|
| `decide-quote-request` (PG-008) | quote accepted/declined | Customer |
| `confirm-payment` (PG-009) | payment confirmed | Customer |
| `release-draft` (PG-010) | design ready / approval requested | Customer |
| `respond-to-design` (PG-008) | design change requested | The designer who created the latest draft (`drafts.created_by`) |
| `hold-job`, `cancel-job` (PG-012) | hold / cancellation | Customer |

Every diff follows the exact minimal-change discipline used in
PG-011/012 — verify with `git diff` against the commits named in each
file's own updated header comment.

**"Stage changes" as a generic event** was not separately implemented
— each specific transition above already gets its own, more useful,
specifically-worded notification (e.g. "payment confirmed" is more
informative than a generic "stage changed to PAYMENT_CONFIRMED"). A
generic stage-change notification firing *in addition to* these would
be redundant noise for the same event.

### UI

- `NotificationsScreen` — in-app inbox (list + mark-as-read), available
  to both customer and staff sessions.
- **Controlled WhatsApp handoff**: a button on the Job detail screen
  builds a `wa.me` deep link pre-filled with the job reference, using
  the company's already-known WhatsApp number (visible on `HomeScreen`
  since PG-006 — not a new company detail invented here). Shown in a
  dialog for the person to open manually, rather than launched directly
  — no URL-launching package is declared in this project, and adding an
  unverified new dependency felt riskier than the same "show the link"
  pattern already used for signed URLs throughout PG-010/011.

## STOP: push notifications (FCM) were not wired up

Master Spec §3 names Firebase Cloud Messaging/APNs for delivery. Doing
so requires a real Firebase project and service-account credentials —
this environment has none, and creating or fabricating them is
explicitly prohibited ("no hardcoded secrets," "no production
credentials"). This is the same situation as PG-009's payment gateway:
the `devices` table (PG-003) already exists and is already
self-service-writable by its owner (`devices_all_own`, PG-005) for
future token registration, but no actual push-send call exists
anywhere in this codebase. The in-app `NotificationsScreen` is
currently the *only* way anyone sees a notification — there is no
external ping.

## Role/branch authorization

No new authorization surface was introduced. Every notification
recipient is resolved server-side from existing, already-scoped data
(the job's own `customer_id`, the draft's own `created_by`, the
quote_request's own `branch_id` via the Centre Manager lookup) — never
a client-supplied recipient. `NotificationsScreen` shows only what
`notifications_select_own` (PG-005, unmodified) returns for the current
`auth.uid()`.

## Security/RLS implications

- **No existing RLS policy was modified.** Confirmed via `git status`/
  `git diff` — one new migration (a trigger, not a policy change), zero
  touched policy files.
- `notifications` retains zero client INSERT policy; only `read_at` is
  client-writable (unchanged column grant from PG-005).
- No service-role credentials are exposed to any client — every
  notification-creating code path runs server-side.

## Tests actually executed

Static structural analysis only — parenthesis/`$$`/`$q$` balance across
the new migration, the new shared module, and every modified/new
TypeScript and Dart file; every table/column reference cross-checked
against the actual schema; confirmed via `git diff` that each of the
six modified functions' changes are exactly the flagged notification
addition and nothing else.

## Tests not executed

Everything in `supabase/tests/database/140_notifications.sql` — no
live database. The actual notification-sending logic in all six
modified functions has never run anywhere.

## Known defects

None newly introduced. PG-010's upload-path data-quality issue and
every other prior task's open item are untouched, as instructed.

## Unspecified decisions discovered

1. **The missing READY_FOR_DISPATCH/DISPATCHED/RELEASED transition
   service** — the major finding above. Needs an explicit owner.
2. **Recipient for "quote submitted"** — resolved as the branch's
   Centre Manager only; flagged as a judgment call, not a certainty.
3. **Push notification delivery (FCM)** — requires real credentials not
   available here; infrastructure (device registration) exists, actual
   sending does not.
4. **WhatsApp number** used for the handoff is the one already surfaced
   in the app since PG-006 — not verified against any authoritative
   source beyond that.

## Deferred decisions

The gap above, plus every item already open from PG-007/009/010/011/012
(pricing, VAT, deposit, refunds, payment provider, CAD tolerances,
document format, signatures, SLA threshold, hold/cancel/resume/reopen
authority) — none touched by this task.

## Files changed

**New:** `20260904000033_quote_request_notification_trigger.sql`,
`supabase/functions/_shared/notifier.ts`,
`apps/mobile/lib/features/notifications/data/notification_repository.dart`,
`apps/mobile/lib/features/notifications/presentation/notifications_screen.dart`,
`supabase/tests/database/140_notifications.sql`,
`docs/notifications.md` (this file).

**Modified:** `supabase/functions/decide-quote-request/index.ts`,
`supabase/functions/confirm-payment/index.ts`,
`supabase/functions/release-draft/index.ts`,
`supabase/functions/respond-to-design/index.ts`,
`supabase/functions/hold-job/index.ts`,
`supabase/functions/cancel-job/index.ts`,
`apps/mobile/lib/features/jobs/presentation/job_detail_screen.dart`
(WhatsApp handoff button), `apps/mobile/lib/features/auth/presentation/auth_gate.dart`
(Notifications entry points), root `README.md`, `docs/authorization.md`,
`docs/database-schema.md`.

## Exact live-environment verification required

```bash
supabase db reset             # migration 33 applies on top of 1–32
create extension if not exists pgtap;
supabase test db               # includes 140_notifications.sql
supabase functions serve
```

Then, in order: submit a `quote_request` and confirm the branch's
Centre Manager receives a `quote_request.submitted` notification;
accept/decline it and confirm the customer receives the matching
notification; confirm a deposit payment and confirm the customer is
notified and the notification appears alongside the PGJO generation
without one blocking the other; release a draft and confirm the
customer is notified; request a design change and confirm the
drafting designer is notified; hold and cancel a job and confirm the
customer receives both; open the WhatsApp handoff link on a real device
and confirm it opens a chat with the pre-filled job reference.
