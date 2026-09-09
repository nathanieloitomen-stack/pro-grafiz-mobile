# Source Code Manifest — Pro_Grafiz (PG-001–PG-021)

Generated directly from the real repository at
`/home/claude/work/pro-grafiz`, branch `master`, 21 commits, working
tree clean. Every figure below was counted directly, not estimated.

## Major folders

| Folder | Purpose | File count |
|---|---|---|
| `apps/mobile/lib/` | Flutter customer + staff app source | 53 `.dart` files |
| `apps/admin-web/src/` | Next.js admin web source | 10 `.ts`/`.tsx` files |
| `supabase/migrations/` | Database schema, in order, schema-changes-only-via-migration | 33 `.sql` files |
| `supabase/functions/` | Edge Functions (server-side logic) | 23 functions + `_shared/` (5 modules) |
| `supabase/tests/database/` | pgTAP test suite (written, never executed live) | 17 `.sql` files |
| `docs/` | Architecture, schema, security, and per-task detail | 25 `.md`/`.html` files |
| `assets/` | Brand and catalogue assets | `brand/`, `pglc/` (catalogue assets not yet committed) |
| `backend/`, `cad-engine/` | Scaffolded, not yet integrated (V2 scope) | READMEs only |

## Applications/modules

### Flutter mobile app (`apps/mobile`)

- `lib/app/` — app shell, theming entry point
- `lib/shared/design_system/` — shared tokens, colors, typography, base widgets (PG-002)
- `lib/features/auth/` — sign-in, staff PIN flow, customer OTP (PG-004)
- `lib/features/catalogue/` — pattern browsing/detail/configure (PG-006)
- `lib/features/quoting/` — quote request submission (PG-007/008)
- `lib/features/jobs/` — job list/detail, 8-stage tracking, documents, WhatsApp handoff (PG-008/011/013)
- `lib/features/payments/` — customer deposit/balance requests, staff payment queue/PIN gate (PG-009)
- `lib/features/design_desk/` — staff draft review/release workflow (PG-010)
- `lib/features/documents/` — document repository (PG-011)
- `lib/features/operations/` — Intake, Job Queue, dashboard, dispatch/release actions (PG-012/015)
- `lib/features/notifications/` — in-app notification inbox (PG-013)
- `lib/features/home/` — customer/staff landing

### Next.js admin web (`apps/admin-web`)

- `src/app/sign-in/` — staff sign-in page (PG-004)
- `src/app/catalogue/` — Super-Admin-only pattern active/inactive toggle (PG-006)
- `src/components/ui/` — shared Button/Card/Badge/Pill components (PG-002)
- `src/lib/supabase/` — Supabase client setup

### Supabase backend (`supabase/`)

- `migrations/` — 33 files, PG-003 through PG-013 (see
  `PG-001-PG-021-CONSOLIDATED-PROJECT-REPORT.md` for the exact mapping)
- `functions/` — 23 functions: `staff-invite`, `staff-reset-pin`,
  `staff-set-initial-pin`, `staff-list-signin-identities`,
  `estimate-quote`, `issue-quote`, `decide-quote-request`,
  `create-payment-request`, `triage-payment`, `confirm-payment`,
  `start-design`, `request-draft-upload-url`, `release-draft`,
  `get-draft-file-url`, `respond-to-design`, `get-document-url`,
  `hold-job`, `resume-job`, `cancel-job`, `reopen-job`,
  `mark-ready-for-dispatch`, `dispatch-job`, `release-job`
- `functions/_shared/` — `cors.ts`, `notifier.ts`, `staff_auth.ts`,
  `document_generator.ts`, `quote_calculator.ts`
- `seed/0001_dev_seed.sql` — clearly `DEV`-prefixed sample data
  (branches, materials, patterns) — **no commercial pricing**

## Important configuration files

- `.env.example` — environment variable names/placeholders only
- `.gitignore` — excludes `.env`/`.env.*`, build artifacts
- `supabase/config.toml` — local Supabase project configuration (authored without a live `supabase init`, per its own header comment)
- `apps/mobile/analysis_options.yaml` — Dart lint configuration
- `apps/admin-web/next.config.js`, `tsconfig.json` — Next.js/TypeScript configuration
- `.github/workflows/lint.yml`, `build.yml` — CI (lint, `deno check`, build)

## Flutter package information

From `apps/mobile/pubspec.yaml` — `pro_grafiz_mobile`, version `0.1.0`,
Dart SDK `>=3.3.0 <4.0.0`:

| Package | Version | Actually used in code? |
|---|---|---|
| `supabase_flutter` | ^2.5.0 | **Yes** — the entire app's data layer |
| `flutter_riverpod` | ^2.5.0 | Declared; state management is currently mostly `StatefulWidget`-based |
| `intl`, `uuid`, `path`, `path_provider` | various | Utility packages, declared |
| `drift`, `sqlite3_flutter_libs`, `drift_dev` | ^2.16.0 / ^0.5.20 | **Declared but not yet used** — no `.dart` file imports `package:drift` anywhere. Scaffolded for future offline support (PG-003's `offline_actions`/`devices` tables exist but are similarly untouched by any code — confirmed in PG-016's audit) |
| `firebase_core`, `firebase_messaging` | ^2.27.0 / ^14.7.0 | **Declared but not yet used** — no `.dart` file imports `package:firebase_*` anywhere. Push notifications are not implemented (PG-013's explicit finding: no Firebase credentials exist, none were fabricated) |
| `flutter_lints`, `flutter_test`, `build_runner` | dev only | Standard dev tooling |

**No lockfile (`pubspec.lock`) is committed** — dependencies were
declared without live `pub get` resolution against the package
registry (no network access at any point in this project).

## Next.js package information

From `apps/admin-web/package.json` — `pro-grafiz-admin-web`, version
`0.1.0`:

| Package | Version | Purpose |
|---|---|---|
| `next` | 14.2.0 | Framework |
| `react`, `react-dom` | 18.3.0 | UI |
| `@supabase/supabase-js` | ^2.43.0 | Supabase client |
| `@supabase/ssr` | ^0.3.0 | Server-side Supabase session handling |
| `typescript` | ^5.4.0 | Dev — type checking |
| `eslint`, `eslint-config-next` | ^8.57.0 / 14.2.0 | Dev — linting |

**No lockfile (`package-lock.json`) is committed** — same reason as
the Flutter app.

## Supabase information

- **33 migrations**, strictly sequentially numbered, applied in order —
  never edited after being committed (`git log --diff-filter=M --
  supabase/migrations/` returns empty, verified repeatedly across
  PG-016/018/019/020).
- **31 tables**, **71 RLS policies**, **13 SECURITY DEFINER helper
  functions**.
- **4 Storage buckets**: `pglc-public` (public), `pglc-production`,
  `job-drafts`, `job-documents` (all private, the latter two with zero
  client-accessible policies).
- **23 Edge Functions**, all requiring only the three
  Supabase-auto-injected environment variables — no function-specific
  secret exists anywhere in this codebase.
- **`pricing_rates`/`commercial_settings` remain empty** — no
  commercial rate has ever been inserted by any migration or seed file,
  by explicit, repeated design decision since PG-007.

## Git commit summary

Real, continuous history — 21 commits, branch `master`, working tree
clean, no remote configured:

```
5bbaeb9 PG-021: local development environment readiness assessment
5ad9fb9 PG-020: staging setup blocked at Step 1 (no internet/Supabase access)
2cf8944 PG-019: Supabase staging environment preparation (no live action)
36bfb00 PG-018: staging & live verification attempt (blocked — no network access)
720646c PG-017: concurrency and audit remediation
c3c2c8d PG-016: production readiness audit (audit only, no code changes)
89cbfd1 PG-015: final job stage transitions (dispatch and release)
ad54432 PG-014: dispatch/release workflow discovery (no implementation)
b254c62 PG-013: notifications
81907a5 PG-012: operations (Intake, Job Queue, dashboard)
3033acc PG-011: documents (PGJO/PGAO)
cb410a4 PG-010: design desk / CAD QA
c103005 PG-009: payments (financial security gate)
e40dd8e PG-008: customer job flow
8f5bb5b PG-007: quote engine
85a2b46 PG-006: PGLC Catalogue
0d40a24 PG-005: authorization (Row Level Security) — security gate
4686b5d PG-004: authentication
c00dceb PG-003: database
833bc03 PG-002: design system
d71ac96 PG-001: repository foundation scaffolding
```

Each commit message (viewable in full via `git log`, not just
`--oneline`) documents that task's exact scope, files touched, and any
findings — this manifest summarizes, it does not replace, that detail.
