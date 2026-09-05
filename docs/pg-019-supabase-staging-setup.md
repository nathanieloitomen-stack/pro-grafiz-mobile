# Supabase Staging Environment Setup (PG-019)

**Status: Environment preparation only. No live Supabase action was
performed or attempted from this environment.**

## 1. Executive Summary

PG-018 confirmed this environment has no network access, no Supabase
CLI, no Deno, no Docker, and no local Postgres — live verification is
categorically impossible here. PG-019's job is different and entirely
achievable: **prepare everything a person with internet access needs
to stand up a real Supabase staging project and get this codebase
running against it**, without performing any of those steps here.

This document is that preparation. Nothing in this task changed any
application file — confirmed at the end via `git status`/`git diff`.

**Two genuinely useful findings emerged from this inspection, worth
knowing before you start:**
1. **Every one of the 22 Edge Functions needs only the three
   environment variables Supabase auto-injects into every deployed
   function** (`SUPABASE_URL`, `SUPABASE_ANON_KEY`,
   `SUPABASE_SERVICE_ROLE_KEY`) — none requires a manually-configured
   secret to run. Payment gateway, SMS provider, and Firebase keys in
   `.env.example` are for features not yet built (no code reads them
   yet), not missing configuration for what exists today.
2. **All four Storage buckets are created by migration, not by manual
   dashboard action** — running the migrations creates them
   automatically, correctly named and with the correct public/private
   flag already set.

**Final decision: READY FOR STAGING SETUP** (Section 17 details the one
external, non-blocking dependency — an SMS provider — that affects only
one feature, not the whole setup).

## 2. Current Environment Limitation

Unchanged since PG-018: this Claude Code session has no internet
access, no Supabase CLI, no Deno runtime, no Docker, and no local
PostgreSQL. Every step in this document that involves actually running
a command against a real Supabase project must be performed by someone
with internet access, using the exact commands provided here — not
attempted, simulated, or claimed as done from this session.

## 3. Required Supabase Staging Architecture

A single Supabase project, using exactly what this codebase already
assumes and nothing more:

- **Database**: standard Supabase Postgres, with the `pgcrypto`
  extension (used for invite-token hashing, PG-004) — enabled by
  migration `20260904000001_extensions_and_functions.sql`, not a manual
  dashboard step.
- **Auth**: Supabase's built-in email/password provider (used
  unconventionally — see Section 8) plus phone/SMS OTP.
- **Storage**: four buckets, created by migration (Section 7).
- **Edge Functions**: 22 Deno functions, deployed via the Supabase CLI,
  no custom secrets required (Section 6).
- **No third-party service is required to get the core system
  running.** Payment matching is manual/bank-transfer (no gateway
  integrated yet — PG-009's own explicit finding); push notifications
  are not implemented (PG-013's own explicit finding). Only customer
  phone OTP needs an external SMS provider, and only for that one
  feature.

## 4. Required Environment Variables

Names and purposes only — **no value is given or should ever be pasted
into this chat, a commit, or this document.**

### Auto-provided by Supabase (no action needed once the project exists)

| Variable | Purpose |
|---|---|
| `SUPABASE_URL` | The project's API base URL — injected automatically into every deployed Edge Function |
| `SUPABASE_ANON_KEY` | Public/anon key — same, auto-injected |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-side bypass key — same, auto-injected. **Never** put this in a mobile/web client build |

### Needed by the mobile/web clients (not Edge Functions)

| Variable | Where used | Purpose |
|---|---|---|
| `SUPABASE_URL` | Flutter app config | Same project URL, client-side |
| `SUPABASE_ANON_KEY` | Flutter app config | Same anon key, client-side |
| `NEXT_PUBLIC_SUPABASE_URL` | Next.js admin-web | Same URL, browser-exposed (the `NEXT_PUBLIC_` prefix is required by Next.js to reach browser code, not a security relaxation — this is still the anon key, never the service-role one) |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Next.js admin-web | Same anon key, browser-exposed |

### Needed only for features not yet built (do not block setup)

| Variable | Purpose | Status |
|---|---|---|
| `SMS_PROVIDER_ACCOUNT_SID` / `SMS_PROVIDER_AUTH_TOKEN` / `SMS_PROVIDER_SENDER_ID` | Customer phone OTP delivery | **Needed for customer sign-in specifically** — no vendor has been chosen (PG-004's own open item); staff sign-in and every staff-facing feature works without this |
| `PAYSTACK_SECRET_KEY` / `FLUTTERWAVE_SECRET_KEY` | Payment gateway | **Not needed** — no code reads either variable anywhere; payments are currently manual bank-transfer matching (PG-009) |
| `FIREBASE_SERVER_KEY` | Push notifications | **Not needed** — no code reads this anywhere; notifications are in-app only (PG-013) |
| `WHATSAPP_BUSINESS_API_TOKEN` | Transactional WhatsApp | **Not needed** — the WhatsApp "handoff" (PG-013) is a manual `wa.me` link, not an API integration |
| `SENTRY_DSN` | Error monitoring | **Not needed** — no code reads this anywhere |

**No secret value is printed anywhere in this document, and none was
requested from you.**

## 5. Migration Inventory

All 33 migrations, in their required order (they are numbered
sequentially and must be applied in that exact order — this is how
`supabase db push`/`supabase migration up` will run them by default,
since they're timestamp-prefixed):

| # | Migration | Purpose | Depends on | Staging concern |
|---|---|---|---|---|
| 1 | `20260904000001_extensions_and_functions.sql` | Extensions (`pgcrypto`) + shared helper functions | none | None |
| 2 | `20260904000002_enums.sql` | All enum types | 1 | None |
| 3 | `20260904000003_lookup_tables.sql` | Branches, materials, finishes, thicknesses | 1–2 | None |
| 4 | `20260904000004_profiles_and_customers.sql` | Staff profiles, customers | 1–3 | None |
| 5 | `20260904000005_catalogue.sql` | PGLC patterns, categories, assets | 1–4 | None |
| 6 | `20260904000006_sketches_and_quoting.sql` | Sketches, quote_requests, quotes | 1–5 | None |
| 7 | `20260904000007_jobs.sql` | Jobs, job_stage_history, design_revisions | 1–6 | None |
| 8 | `20260904000008_drafts_and_cad.sql` | Drafts, draft_checks, CAD release-gate trigger | 1–7 | None |
| 9 | `20260904000009_payments.sql` | Payments, payment_events | 1–8 | None |
| 10 | `20260904000010_documents_and_dxf.sql` | Documents, DXF governance tables | 1–9 | None |
| 11 | `20260904000011_notifications_and_offline.sql` | Notifications, devices, offline_actions | 1–10 | None |
| 12 | `20260904000012_audit.sql` | audit_events | 1–11 | None |
| 13 | `20260904000013_staff_authentication.sql` | Staff auth columns, invite-token crypto helpers | 1–12 | Uses `pgcrypto`-based functions — confirm the extension from #1 actually enabled in the target project |
| 14 | `20260904000014_customer_authentication.sql` | Customer signup trigger | 1–13 | None |
| 15 | `20260904000015_authorization_helpers.sql` | RLS helper functions (`is_super_admin()`, etc.) | 1–14 | None |
| 16–24 | `rls_*.sql` (9 files) | RLS policies for every table, by area | 1–15 | **Apply in order** — some helper functions from #15 are used across all nine; none should be applied out of sequence |
| 25 | `20260904000025_pattern_favourites.sql` | pattern_favourites table + RLS | 1–24 | None |
| 26 | `20260904000026_pglc_storage_buckets.sql` | Creates `pglc-public`/`pglc-production` buckets | 1–25 | Requires the Storage extension enabled (default in every Supabase project) |
| 27 | `20260904000027_pricing_configuration.sql` | pricing_rates/commercial_settings (empty by design) | 1–26 | **Tables will be empty after this runs — this is intentional, not a bug.** See Section 10 |
| 28–30 | quantity/ref-generator fixes | Small schema additions | 1–27 | None |
| 31 | `20260904000031_job_drafts_storage_and_dxf_gate.sql` | Creates `job-drafts` bucket, tightens one function | 1–30 | None |
| 32 | `20260904000032_job_documents_storage.sql` | Creates `job-documents` bucket | 1–31 | None |
| 33 | `20260904000033_quote_request_notification_trigger.sql` | Notification trigger on quote_requests insert | 1–32 | None |

**Can this set theoretically apply cleanly to a fresh Supabase
project?** Based on static review (no live execution possible — see
Section 2), yes: every `references` clause points to a table created
in an earlier-numbered file, every function is defined before its
first use, and no migration was ever edited after being committed
(`git log --diff-filter=M -- supabase/migrations/` returns empty,
confirmed again in this task). **This is a structural, not executed,
conclusion** — the first real test of this claim is Step 4 of the
guide below.

## 6. Edge Function Inventory

All 22 functions. Every single one uses only the three auto-injected
variables from Section 4 — no function-specific secret exists to
configure.

| Function | Purpose | Auth required | DB access | Storage access |
|---|---|---|---|---|
| `staff-list-signin-identities` | Look up a staff member's sign-in email from their phone/handle | None (public) | Read `profiles` | No |
| `staff-invite` | Create a new staff account (admin) | Super Admin/Centre Manager | Read/write `profiles`, `auth.users` | No |
| `staff-reset-pin` | Reset a staff member's PIN | Super Admin/Centre Manager | Read/write `profiles` | No |
| `staff-set-initial-pin` | First-time PIN setup via invite token | Invite token, not a session | Read/write `profiles` | No |
| `estimate-quote` | Public price estimate, no persistence | None (public) | Read `pricing_rates`/`commercial_settings` | No |
| `issue-quote` | Persist a quote | Authenticated | Write `quotes` | No |
| `decide-quote-request` | Staff accept/decline a quote request | Centre Manager/central staff | Write `quote_requests`, `quotes`, `jobs`, `job_stage_history`, `audit_events` | No |
| `create-payment-request` | Customer requests deposit/balance payment | Customer (own job) | Write `payments` | No |
| `triage-payment` | Staff marks a payment matched/no_match | Accountant/Super Admin | Write `payments` | No |
| `confirm-payment` | Accountant confirms a payment (fresh PIN challenge) | Accountant, re-authenticated | Write `payments`, `jobs`, `audit_events` | No |
| `start-design` | Designer begins design work | Designer/Super Admin | Write `jobs`, `audit_events` | No |
| `request-draft-upload-url` | Signed upload URL for a draft asset | Designer/Super Admin | Read `drafts` | `job-drafts` |
| `release-draft` | Release a draft (CAD gate applies) | Designer/Super Admin | Write `drafts`, `jobs`, `audit_events` | No |
| `get-draft-file-url` | Signed download URL for a draft asset | Owning customer or staff | Read `drafts` | `job-drafts` |
| `respond-to-design` | Customer approves/requests a change | Customer (own job) | Write `jobs`, `design_revisions`, `audit_events` | No |
| `get-document-url` | Signed download URL for a PGJO/PGAO | Owning customer or staff | Read `documents` | `job-documents` |
| `hold-job` / `resume-job` / `cancel-job` / `reopen-job` | Operational job-state actions | Centre Manager (own branch)/Super Admin | Write `jobs`, `audit_events` | No |
| `mark-ready-for-dispatch` | Production confirms completion | Production (own branch)/Super Admin | Write `jobs`, `audit_events` | No |
| `dispatch-job` | Inventory confirms dispatch | Inventory (own branch)/Super Admin | Write `jobs`, `audit_events` | No |
| `release-job` | Centre Manager confirms release (balance-gated) | Centre Manager (own branch)/Super Admin | Write `jobs`, `audit_events`, read `payments`/`quotes` | No |

Every function also depends on `_shared/` modules (`cors.ts`,
`notifier.ts`, `staff_auth.ts`, `document_generator.ts`,
`quote_calculator.ts`) — these deploy automatically alongside any
function that imports them; no separate deployment step exists for
them.

**Notification dependency**: every function that calls `notify()`
writes only to the `notifications` table — no external push service is
called (Section 4 confirms `FIREBASE_SERVER_KEY` is unused). **Payment
dependency**: only `create-payment-request`, `triage-payment`, and
`confirm-payment` touch `payments` — no gateway API is called by any of
them.

## 7. Storage Configuration

| Bucket | Public? | Created by | Access model |
|---|---|---|---|
| `pglc-public` | **Yes** | Migration 26 | Anyone can read (catalogue browsing); writes restricted by `storage.objects` policy to Super Admin |
| `pglc-production` | No | Migration 26 | Staff-only, via `storage.objects` policy (production catalogue assets, e.g. DXF for patterns) |
| `job-drafts` | No | Migration 31 | **Zero** `storage.objects` policies — access exclusively through `request-draft-upload-url`/`get-draft-file-url`'s signed URLs |
| `job-documents` | No | Migration 32 | **Zero** `storage.objects` policies — access exclusively through `get-document-url`'s signed URLs |

**All four are created automatically when migrations run** — there is
no manual "create this bucket in the dashboard" step. The only
storage-related dashboard action needed is confirming Storage itself is
enabled for the project (on by default for every new Supabase project).

## 8. Authentication Configuration

### Staff (invite → PIN setup → sign-in)

Staff do **not** use real email/password sign-in in the usual sense.
Per PG-004's design: a staff member's 4-digit PIN **is** their Supabase
Auth password, under a synthetic internal email address
(`auth_login_handle`, never a real inbox). Required staging
configuration:

- `minimum_password_length = 4` in Auth settings (already declared in
  `supabase/config.toml` — if the dashboard doesn't read this file
  automatically depending on your Supabase CLI linking method, set it
  manually in **Auth → Settings → Password requirements**).
- **No SMTP/email provider needs to be configured for staff** —
  `staff-invite` creates the account with `email_confirm: true` set
  explicitly via the admin API, so no confirmation email is ever sent
  or required.

### Customers (phone → OTP → session)

- Enable **Phone** as an Auth provider.
- Requires a **real SMS provider** (Twilio, MessageBird, Termii, or
  similar) connected in **Auth → Providers → Phone** — this is a
  genuine external dependency with its own account/credentials, not
  something this codebase can substitute for. No vendor has been
  chosen (an open commercial decision since PG-004, not resolved by
  this task).
- Without this, **customer sign-in will not work** — staff sign-in and
  every staff-facing function will still work normally, since they
  don't depend on SMS at all.

### Neither flow needs

- OAuth providers (Google, Apple, etc.) — none are used anywhere in
  this codebase.
- Redirect URLs — no magic-link or OAuth callback flow exists to
  redirect from.

## 9. Test User Plan

Fictional identities only — **none of these should be created from
this session**; the setup guide (Section 11) tells you how to create
them once staging exists.

| Role | Suggested identity | Branch |
|---|---|---|
| Super Admin | `test-superadmin` | — (global) |
| Accountant | `test-accountant` | — (central) |
| Centre Manager — Branch A | `test-cm-branch-a` | Branch A |
| Centre Manager — Branch B | `test-cm-branch-b` | Branch B |
| Designer | `test-designer` | — (central) |
| Production | `test-production` | Branch A (per PG-015's branch-scoping decision — assign explicitly) |
| Inventory | `test-inventory` | Branch A (same reason) |
| Customer 1 | `+234-000-000-0001` (fictional) | — |
| Customer 2 | `+234-000-000-0002` (fictional) | — |

Use obviously fictional phone numbers and names — never a real
person's number, even for testing, since a real SMS provider
configured per Section 8 would actually attempt to send to it.

## 10. Test Data Plan

- **Branches**: at least two (matching the two Centre Managers above),
  created via `INSERT INTO branches` or the dev seed
  (`supabase/seed/0001_dev_seed.sql`, already `DEV`-prefixed and
  clearly non-production).
- **Materials/finishes/patterns**: the same dev seed file covers this —
  it can be applied via `supabase db reset` (which runs migrations +
  seed together) or run manually against staging.
- **Pricing configuration is intentionally NOT seeded anywhere in this
  codebase.** `pricing_rates`/`commercial_settings` (migration 27) are
  empty by design — no commercial rate has ever been invented at any
  point in this project (an explicit, repeated decision since PG-007).
  **Before any quote/job flow can be tested, real rows must be added to
  these two tables.** This is not a bug to fix — it's the correct,
  intentional state, and inserting rates is a business decision for
  you, not something to automate. Mark any values you insert for
  testing purposes clearly as test data (e.g., round, obviously
  placeholder numbers) so they're never mistaken for approved
  commercial pricing.
- **No real customer financial or personal data should ever be used in
  staging.**

## 11. Step-by-Step Staging Setup

**Everything below must be performed by a person with internet access,
using the Supabase CLI on their own machine (or Supabase's web
dashboard where noted) — none of it can be run from this session.**

1. **Create the Supabase staging project.** Via
   supabase.com/dashboard → New Project. Name it clearly (e.g.
   `pro-grafiz-staging`) — never reuse a production project for this.
2. **Obtain the project configuration.** In **Project Settings → API**:
   copy the Project URL and `anon`/`public` key. In **Project Settings
   → API → Project API keys**: copy the `service_role` key
   (secret — see Section 12). Store all three in a local `.env.local`
   (or your platform's secret manager) using the exact variable names
   from `.env.example` — never in a file that gets committed.
3. **Configure environment variables securely** — populate
   `.env.local` (or equivalent) locally; for deployed Edge Functions,
   `SUPABASE_URL`/`SUPABASE_ANON_KEY`/`SUPABASE_SERVICE_ROLE_KEY` are
   injected automatically by Supabase and need no manual
   `supabase secrets set` for those three specifically.
4. **Apply the migrations.** From the repository root, with the
   Supabase CLI linked to your new project
   (`supabase link --project-ref <your-project-ref>`):
   ```bash
   supabase db push
   ```
   This applies all 33 migrations in order. **If any migration fails,
   stop and record the exact error** — do not edit the migration file
   to force it through; report it as a finding instead (matching
   PG-018's own "do not silently fix" instruction, which still applies
   here).
5. **Confirm storage buckets exist.** After migrations apply, check
   **Storage** in the dashboard — `pglc-public`, `pglc-production`,
   `job-drafts`, `job-documents` should already exist (created by
   migrations 26/31/32, not this step) — this step is verification,
   not creation.
6. **Configure authentication.** In **Auth → Providers**: confirm
   Email/Password is enabled (default) and set the password minimum
   length to 4 (**Auth → Settings**) to match `supabase/config.toml`.
   For customer phone OTP, enable **Phone** and connect a real SMS
   provider (Section 8) — skip this sub-step if only staff-facing
   testing is needed initially.
7. **Configure Edge Function secrets.** None are required beyond the
   three auto-injected variables (Section 4/6) — this step is a
   no-op for the current codebase, but is listed here in case a future
   task adds a function that genuinely needs one (e.g. once a payment
   gateway or SMS provider is chosen).
8. **Deploy the Edge Functions.**
   ```bash
   supabase functions deploy
   ```
   deploys all functions in `supabase/functions/` at once (including
   the shared `_shared/` modules they import). Confirm all 22 appear in
   **Edge Functions** in the dashboard.
9. **Create fictional staging test users**, per Section 9 — staff
   accounts via the deployed `staff-invite` function (called by an
   already-existing Super Admin — the very first Super Admin must be
   created directly via the Supabase dashboard's **Auth → Users → Add
   User**, since `staff-invite` itself requires an existing
   authenticated Super Admin to call it), customers via the app's own
   phone-OTP sign-up flow once SMS is configured.
10. **Prepare for PG-018 live verification.** Once steps 1–9 are
    complete, the environment is ready for PG-018's 19 verification
    steps to actually be executed (rather than the static-only pass
    that task was forced into) — re-run that task's document
    (`docs/pg-018-staging-live-verification.md`) as a template, filling
    in real PASS/FAIL/BLOCKED results this time.

## 12. Security Requirements

- The `service_role` key is a full database bypass — treat it exactly
  like a root database password. Never commit it, never paste it into
  a chat session (including this one), never put it in a file that
  isn't explicitly gitignored.
- `.gitignore` already excludes `.env`/`.env.*` while explicitly
  allowing `.env.example` (confirmed in this task, unchanged since
  PG-001) — keep using that pattern for any new environment file.
- Never reuse a production Supabase project for staging, and never
  point a local development build at a staging project's
  `service_role` key from client code.
- If a secret is ever accidentally exposed (committed, pasted, logged),
  rotate it immediately in the Supabase dashboard — don't just delete
  the commit.

## 13. Pre-Flight Checklist

```
[ ] Supabase staging project created
[ ] Staging project URL available
[ ] Public/anon key configured securely
[ ] Service-role secret configured securely
[ ] Database accessible
[ ] Migrations applied
[ ] RLS enabled
[ ] Storage buckets configured
[ ] Auth configured
[ ] Edge Functions deployed
[ ] Function secrets configured
[ ] Test users created
[ ] Test data created
[ ] Staging connection verified
[ ] Ready for live PG-018 verification
```

## 14. What Claude Can Do

- Inspect and document the existing codebase (this document).
- Identify every required configuration item, migration, function, and
  bucket.
- Identify test-data and test-user requirements.
- Write setup and verification procedures for someone else to run.
- Once staging exists and credentials are made available through a
  connector or tool with actual network access, execute the PG-018
  verification steps for real.

## 15. What Must Be Done From an Internet-Enabled Environment

- Create the Supabase project itself.
- Obtain and store all credentials.
- Run `supabase db push` / `supabase functions deploy`.
- Configure Auth providers (including connecting a real SMS vendor).
- Create the first Super Admin user directly via the dashboard.
- Create subsequent staff/customer test accounts.
- Insert test pricing data into `pricing_rates`/`commercial_settings`.
- Perform any and all live testing (PG-018's actual execution).

## 16. Ready-for-PG-018 Criteria

Staging is ready for PG-018's live verification to actually run once:
every box in Section 13's checklist is checked, at least one
fully-configured Centre Manager/Super Admin pair exists per branch,
test pricing has been inserted, and (if customer-flow testing is in
scope) a real SMS provider is connected and verified to actually
deliver an OTP.

## 17. Known Issues / Blockers

1. **SMS provider is a genuine, unavoidable external dependency** for
   customer-facing testing specifically — not something this
   repository can work around, and not a code defect. Staff-only
   testing can proceed without it.
2. **No commercial pricing exists anywhere** — quote/job-flow testing
   cannot proceed until *someone* (the Product Owner, not this task)
   decides on and inserts real or clearly-marked test rates into
   `pricing_rates`/`commercial_settings`.
3. **The migration set has never actually been applied to a real
   database** — Section 5's "should apply cleanly" conclusion is a
   structural inference from static review, not an observation.
   Step 4 of the setup guide is the actual first test of that claim,
   and may surface an issue no static review here could catch.

---

## Final decision

### READY FOR STAGING SETUP

Nothing found in this inspection blocks starting Section 11's
procedure. The two items in Section 17 that aren't purely mechanical
(SMS vendor choice, pricing data) are genuine business decisions
outside this task's scope, not defects in the setup package itself.

---

## Git status

```
$ git status
On branch main
nothing to commit, working tree clean
```

Confirmed before and after writing this document: **zero application
files were changed.** This document is the only file this task adds.
No secret, credential, password, or token appears anywhere in it.

---

**PG-019 COMPLETE — STAGING PREPARATION ONLY**

**NO LIVE SUPABASE TESTING PERFORMED**

**PG-020 NOT STARTED**
