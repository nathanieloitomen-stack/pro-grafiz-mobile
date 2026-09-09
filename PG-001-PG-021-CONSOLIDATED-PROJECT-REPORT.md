# PG-001–PG-021 Consolidated Project Report

**Project**: Pro_Grafiz (metal laser cutting business app suite)
**Stack**: Flutter (mobile) + Next.js (admin-web) + Supabase (Postgres/Auth/Storage/Edge Functions)
**Source of truth for this report**: `/home/claude/work/pro-grafiz`, git branch `master`, 21 commits, working tree clean at time of writing.

This report is drawn directly from the repository's own commit
history and the `docs/*.md` file each task produced — nothing below is
inferred or reconstructed from outside the actual project.

| PG | Feature/Module | Status | Main Files | Description |
|---|---|---|---|---|
| PG-001 | Repository foundation scaffolding | **Completed** | `apps/`, `supabase/`, `backend/`, `cad-engine/`, `.github/workflows/` | Monorepo skeleton for the Flutter app, Next.js admin-web, Supabase backend, and CI lint/build workflows. No screens or schema yet. |
| PG-002 | Design system | **Completed** | `apps/mobile/lib/shared/design_system/`, `apps/admin-web/src/styles/`, `docs/design-system.md` | Shared color/typography/spacing tokens and base widgets/components for both the Flutter app and the admin-web, sourced from the original handoff design tokens. |
| PG-003 | Database schema | **Completed** | `supabase/migrations/20260904000001`–`000012` (12 files, 28 tables) | Full core schema: branches, profiles, customers, catalogue (patterns/materials/finishes), quote_requests/quotes, jobs/job_stage_history, drafts/draft_checks, payments, documents, notifications, audit_events. |
| PG-004 | Authentication | **Completed** | `20260904000013`–`000014`, `supabase/functions/staff-*`, `apps/mobile/lib/features/auth/` | Staff PIN-as-password sign-in (via a synthetic `auth_login_handle`), invite/set-PIN flow with hashed tokens; customer phone-OTP signup trigger. |
| PG-005 | Authorization (RLS) — security gate | **Completed** | `20260904000015`–`000024` (10 files, 59 policies) | RLS enabled and policies written for all 28 tables; 13 SECURITY DEFINER helper functions; `jobs`/`quotes`/`payments`/`documents`/`audit_events` given zero client write policies (service-role only). |
| PG-006 | PGLC Catalogue | **Completed** | `20260904000025`–`000026`, `apps/mobile/lib/features/catalogue/`, `apps/admin-web/src/app/catalogue/` | Pattern browsing, detail, and configure screens; `pglc-public`/`pglc-production` storage buckets; pattern favourites. |
| PG-007 | Quote engine | **Completed** | `20260904000027`–`000029`, `supabase/functions/estimate-quote`, `issue-quote`, `_shared/quote_calculator.ts` | Server-side quote arithmetic over configured rates; `pricing_rates`/`commercial_settings` created **empty by design** — no commercial value has ever been invented. |
| PG-008 | Customer job flow | **Completed** | `supabase/functions/decide-quote-request`, `respond-to-design`, `apps/mobile/lib/features/jobs/` | Staff accept/decline of quote requests (opens a job); customer approve/request-change on a released design; 8-stage job tracking UI. |
| PG-009 | Payments (financial security gate) | **Completed** | `20260904000030`, `supabase/functions/create-payment-request`, `triage-payment`, `confirm-payment` | Manual bank-transfer payment matching; Accountant-only confirmation with a genuine fresh PIN re-challenge. No payment gateway is integrated — an explicit, unresolved commercial decision, not an oversight. |
| PG-010 | Design Desk / CAD QA | **Completed** | `20260904000031`, `supabase/functions/start-design`, `release-draft`, `request-draft-upload-url`, `get-draft-file-url` | Staff design review/release workflow; `job-drafts` private storage bucket; CAD release-gate trigger; Production role restricted from unreleased DXF. No automated SVG/DXF generation (explicitly V2 scope per Master Spec, not built). |
| PG-011 | Documents (PGJO/PGAO) | **Completed** | `20260904000032`, `supabase/functions/_shared/document_generator.ts`, `get-document-url` | Idempotent, event-key-guarded generation of PGJO (on deposit confirmation) and PGAO (on customer approval) documents as HTML, stored privately, with signed-URL access. |
| PG-012 | Operations (Intake, Job Queue, dashboard) | **Completed** | `supabase/functions/hold-job`, `resume-job`, `cancel-job`, `reopen-job`, `apps/mobile/lib/features/operations/` | Staff Intake decision UI, Job Queue with hold/resume/cancel/reopen (Centre Manager own-branch/Super Admin only), basic dashboard counts. No SLA threshold invented (confirmed absent from all specs). |
| PG-013 | Notifications | **Completed** | `20260904000033`, `supabase/functions/_shared/notifier.ts`, `apps/mobile/lib/features/notifications/` | In-app notification inbox; notification hooks on every implemented lifecycle event; controlled WhatsApp handoff link. No push/FCM infrastructure (no credentials available, explicitly not fabricated). |
| PG-014 | Dispatch/release workflow discovery | **Completed (discovery only, no implementation)** | `docs/dispatch-release-workflow-discovery.md` | Identified that 3 of 8 job stages had no transition mechanism; proposed (not implemented) a transition matrix for Product Owner review. |
| PG-015 | Final job stage transitions | **Completed** | `supabase/functions/mark-ready-for-dispatch`, `dispatch-job`, `release-job` | Implements `IN_PRODUCTION → READY_FOR_DISPATCH → DISPATCHED → RELEASED`, per PG-014's approved decisions; release gated on the balance being fully paid; atomic compare-and-swap concurrency pattern. |
| PG-016 | Production readiness audit | **Completed (audit only, no code changes)** | `docs/pg016-production-readiness-audit.md` | Verified RLS/schema integrity across all 33 migrations; found a concurrency gap in 9 older lifecycle functions and a missing audit trail on 4 transitions. |
| PG-017 | Concurrency & audit remediation | **Completed** | 9 modified Edge Functions (see `docs/pg017-concurrency-audit-remediation.md`) | Fixed the exact 9 functions PG-016 flagged with an atomic compare-and-swap pattern; added the 4 missing `audit_events` writes, including payment confirmation. |
| PG-018 | Staging & live verification | **Blocked — environment limitation, not a code issue** | `docs/pg-018-staging-live-verification.md` | Attempted live verification; this sandboxed environment has zero network egress, so every live-execution step is marked BLOCKED, not passed. |
| PG-019 | Supabase staging setup preparation | **Completed (documentation only)** | `docs/pg-019-supabase-staging-setup.md` | Full migration/Edge-Function/storage/auth inventory and a step-by-step guide for a person with internet access to actually stand up staging. |
| PG-020 | Staging setup & live verification attempt | **Blocked — environment limitation, not a code issue** | `docs/pg-020-staging-live-verification.md` | Re-confirmed zero network egress (`x-deny-reason: host_not_allowed`) from a fresh check; stopped at Step 1 per explicit instruction, no staging action taken. |
| PG-021 | Local development environment readiness | **Completed (assessment only)** | `docs/pg-021-environment-readiness.md` | Full tool/readiness matrix for this sandbox; confirmed Git/Node.js present, Supabase CLI/Docker/psql/Flutter/Dart absent; installation-order recommendation for a real development machine. |

## Status legend

- **Completed** — implemented, committed, and (where applicable) documented with its own `docs/*.md` file covering scope, security implications, and known limitations.
- **Blocked** — the task's own objective could not be executed due to this sandboxed environment's lack of network access, not due to any defect in the application. No application code was affected.
- **Discovery/audit only** — by explicit design, these tasks produced findings and recommendations, not code.

## What has never been executed against a live system

Stated plainly, carried through every relevant task's own documentation
and restated here for a single point of reference: **no migration has
ever been applied to a real Postgres/Supabase instance, no Edge
Function has ever run, and no pgTAP test (17 files) has ever executed.**
Everything from PG-003 onward has been verified by static analysis
only — parenthesis/schema-reference checking, RLS policy re-reading,
and cross-file consistency checks — because this execution environment
has never had internet access (confirmed directly and repeatedly,
most recently in PG-020/021). This is the single largest gap between
"this code is internally consistent" and "this system is
production-verified," and it remains open.
