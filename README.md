# Pro_Grafiz Complete Project (PG-001–PG-021)

## 1. Project overview

Digital design-to-fabrication platform for Pro_Grafiz Designs Ltd (metal
laser cutting and fabrication, seven customer centres, Abuja and Lagos).
Customers browse a laser-cut pattern catalogue, request a quote, pay a
deposit, review and approve a design, track their job through an
eight-stage production lifecycle, and receive it. Staff (across seven
roles — Super Admin, Accountant, Centre Manager, Designer, Production,
Inventory) run intake, design review, payment confirmation, production,
dispatch, and release from the same app, gated by role and branch.

This repository is the **production build**, distinct from the approved
design handoff prototype (`Pro_Grafiz App.dc.html` and its README), which
remains the UX/visual reference only and is not committed here.

## 2. Technology stack

| Layer | Technology |
|---|---|
| Mobile app (customer + staff) | Flutter (Dart SDK `>=3.3.0 <4.0.0`) |
| Admin web | Next.js 14.2.0 + React 18.3.0 + TypeScript |
| Backend | Supabase (Postgres, Row Level Security, Auth, Storage, Edge Functions in Deno/TypeScript) |
| CAD/geometry worker | Isolated Python service (`cad-engine/`) — scaffolded, not yet integrated (V2 scope per Master Spec) |

## 3. System architecture

- **Database**: 31 tables across 33 migrations (`supabase/migrations/`),
  covering catalogue, quoting, jobs/lifecycle, payments, drafts/CAD,
  documents, notifications, and audit logging.
- **Authorization**: Row Level Security on every table (71 policies).
  The most sensitive tables (`jobs`, `quotes`, `payments`,
  `payment_events`, `documents`, `dxf_release_grants`,
  `dxf_download_logs`, `audit_events`) have **zero client write
  policies** — every sensitive write goes through a service-role Edge
  Function that re-derives the caller's identity and role server-side.
- **Edge Functions**: 23 functions (`supabase/functions/`) implementing
  quoting, job-lifecycle transitions, payments, design review,
  documents, and operational actions — see
  [`PG-001-PG-021-CONSOLIDATED-PROJECT-REPORT.md`](./PG-001-PG-021-CONSOLIDATED-PROJECT-REPORT.md)
  for the full list.
- **Storage**: four buckets — `pglc-public` (public catalogue previews),
  `pglc-production` (staff-only catalogue DXF), `job-drafts` and
  `job-documents` (both private, zero client policies, accessed only via
  signed URLs from Edge Functions).
- **Mobile app**: role-aware single Flutter app — one install serves
  both the customer and staff experience, gated after sign-in.
- **Admin web**: a lighter Next.js surface for a subset of staff actions
  (currently catalogue management and sign-in).

## 4. Flutter mobile app setup

```bash
cd apps/mobile
flutter pub get
```

Requires Flutter with a bundled Dart SDK satisfying `>=3.3.0 <4.0.0`
(Flutter 3.19 or later). No specific Flutter version is pinned in this
repository (no `.fvmrc`) — see
[`docs/pg-021-environment-readiness.md`](./docs/pg-021-environment-readiness.md)
for the full toolchain readiness assessment.

## 5. Next.js admin web setup

```bash
cd apps/admin-web
npm install
```

Requires Node.js 20 (matching `.github/workflows/lint.yml`/`build.yml`).

## 6. Supabase setup

This project has **never been connected to a live Supabase project**
from within this development environment (no network access has ever
been available here — see
[`docs/pg-020-staging-live-verification.md`](./docs/pg-020-staging-live-verification.md)
and
[`docs/pg-021-environment-readiness.md`](./docs/pg-021-environment-readiness.md)).
To set up a real staging project, follow
[`docs/pg-019-supabase-staging-setup.md`](./docs/pg-019-supabase-staging-setup.md)
step by step — it covers migration order, storage buckets,
authentication configuration, and Edge Function deployment in full.

Quick reference, once a project exists and the Supabase CLI is linked:

```bash
supabase db push          # applies all 33 migrations in order
supabase functions deploy # deploys all 23 Edge Functions
```

## 7. Environment variables

Names and purposes only — see `.env.example` for the placeholder file,
and
[`docs/pg-019-supabase-staging-setup.md`](./docs/pg-019-supabase-staging-setup.md#4-required-environment-variables)
for the full breakdown of which are auto-provided by Supabase, which the
clients need, and which are for features not yet built (payment gateway,
SMS, push) and therefore not required to get the current system running.

| Variable | Used by |
|---|---|
| `SUPABASE_URL` | Auto-injected into every Edge Function; also needed by both clients |
| `SUPABASE_ANON_KEY` | Same |
| `SUPABASE_SERVICE_ROLE_KEY` | Auto-injected into every Edge Function only — **never** in client code |
| `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Next.js admin-web (browser-exposed anon key, not service-role) |

Never commit real values — `.gitignore` excludes `.env`/`.env.*` while
explicitly allowing `.env.example`.

## 8. Installation instructions

```bash
git clone <this repository>
cd pro-grafiz

# Mobile
cd apps/mobile && flutter pub get && cd ../..

# Admin web
cd apps/admin-web && npm install && cd ../..
```

No lockfile is committed for either app (dependencies were declared
without network access to resolve them — see Section 6/Section 14 for
why). Run the install commands above to generate them locally.

## 9. How to run the mobile app

```bash
cd apps/mobile
flutter run
```

Requires a configured Supabase project (Section 6) and the app's
Supabase URL/anon key wired into its configuration before it can sign
in or fetch data.

## 10. How to run the admin web app

```bash
cd apps/admin-web
npm run dev
```

Serves locally at `http://localhost:3000`. Requires
`NEXT_PUBLIC_SUPABASE_URL`/`NEXT_PUBLIC_SUPABASE_ANON_KEY` set (Section 7).

## 11. Database setup instructions

See [`docs/pg-019-supabase-staging-setup.md`](./docs/pg-019-supabase-staging-setup.md)
for the complete, step-by-step procedure (creating the project,
applying migrations in order, confirming storage buckets, configuring
auth). In short, once a Supabase project exists and the CLI is linked:

```bash
supabase db push
```

applies all 33 migrations in their required order.
`supabase/seed/0001_dev_seed.sql` provides clearly `DEV`-prefixed
sample catalogue/branch data — **no commercial pricing is seeded
anywhere**; `pricing_rates`/`commercial_settings` remain intentionally
empty until the Product Owner supplies real rates.

## 12. PG-001–PG-021 feature summary

**All 21 tasks are complete** (three — PG-014, PG-016 — were
discovery/audit-only by design; two — PG-018, PG-020 — were blocked by
this development environment's lack of network access, not by any
application defect). Full detail, status, and file references for every
task are in
[`PG-001-PG-021-CONSOLIDATED-PROJECT-REPORT.md`](./PG-001-PG-021-CONSOLIDATED-PROJECT-REPORT.md).

Headline state: the full eight-stage job lifecycle
(`SUBMITTED → PAYMENT_CONFIRMED → DESIGN_IN_PROGRESS →
DESIGN_SENT_FOR_APPROVAL → IN_PRODUCTION → READY_FOR_DISPATCH →
DISPATCHED → RELEASED`) is implemented end-to-end with consistent
audit logging and atomic concurrency protection (PG-017). **No
migration, Edge Function, or RLS policy has ever been executed against
a live database** — every verification to date is static analysis; see
[`docs/pg016-production-readiness-audit.md`](./docs/pg016-production-readiness-audit.md)
and
[`docs/pg-018-staging-live-verification.md`](./docs/pg-018-staging-live-verification.md).
Several commercial/operational decisions remain open by design, not
oversight: payment gateway selection, SMS provider selection, VAT/
deposit percentages, and commercial pricing data — none has been
invented anywhere in this codebase.

## 13. Project folder structure

```
pro-grafiz/
├── CLAUDE.md                          Engineering rules and protocol
├── PRO_GRAFIZ_MASTER_SPEC.md          Production source of truth
├── PG-001-PG-021-CONSOLIDATED-PROJECT-REPORT.md   Full per-task status table
├── SOURCE-CODE-MANIFEST.md            Full file/module inventory
├── docs/                              Architecture, schema, API, security, testing, per-task detail
├── apps/
│   ├── mobile/                        Flutter customer + staff app
│   │   └── lib/
│   │       ├── app/                   App shell/theming entry
│   │       ├── features/              auth, catalogue, jobs, payments, design_desk,
│   │       │                          documents, notifications, operations, quoting, home
│   │       └── shared/design_system/  Shared tokens/widgets
│   └── admin-web/                     Next.js + TypeScript admin web
│       └── src/
│           ├── app/                   Route pages (catalogue, sign-in)
│           ├── components/ui/         Shared UI components
│           └── lib/supabase/          Supabase client setup
├── backend/                           Notes on services beyond Supabase Edge Functions
├── cad-engine/                        Isolated Python geometry/CAD worker (scaffold only)
├── supabase/
│   ├── config.toml                    Local Supabase project config
│   ├── migrations/                    33 SQL migrations, schema changes only via migration
│   ├── functions/                     23 Edge Functions + _shared/ modules
│   ├── seed/                          Development-only seed data, clearly DEV-prefixed
│   └── tests/database/                17 pgTAP test files (written, never executed live)
└── assets/
    ├── brand/                         Logo assets
    └── pglc/                          Production PGLC catalogue assets (none committed yet)
```

## 14. Git history information

This repository has a single, continuous, real git history — 21
commits on branch `master`, one per completed task (PG-001 through
PG-021), authored as this project was actually built. **Nothing about
this history is reconstructed or synthetic** — see
`git log --oneline` for the exact list. Working tree is clean; no
remote is configured (this project has been delivered via downloadable
archive at each milestone, not via `git push`).

This project was authored throughout without live network access to
any package registry or Supabase project — dependency versions in
`pubspec.yaml`/`package.json` were declared from knowledge, not
resolved against a live registry, and no migration has ever run against
a real database. Verify and update pinned versions once real tooling
access is available, and treat every piece of static verification in
`docs/` as exactly that — static, not executed — until
[`docs/pg-019-supabase-staging-setup.md`](./docs/pg-019-supabase-staging-setup.md)'s
procedure has actually been run somewhere with internet access.
