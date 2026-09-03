# PRO_GRAFIZ MASTER SPECIFICATION

**Project:** Pro_Grafiz Mobile + Web Production Platform\
**Version:** 1.0\
**Date:** 3 September 2026\
**Status:** Production Build Baseline

## 1. Source of Truth

This document is the master engineering specification for converting the
approved Pro_Grafiz Claude Code design handoff into a secure, scalable
production application.

-   The original design handoff is the authoritative reference for
    approved UX, screens, interactions, labels and visual direction.
-   This specification is the authoritative reference for production
    architecture, data, security, scope, business rules, testing and
    deployment.
-   Do not redesign the approved product unless the product owner
    explicitly requests it.

## 2. Product Vision

Pro_Grafiz is a digital design-to-fabrication platform for metal laser
cutting and fabrication.

**Customer journey:** Browse PGLC designs → customize → request quote →
pay → approve design → track production → receive/collect job.

**Staff journey:** Intake → quote → payment verification → design desk →
customer approval → production → dispatch/release.

**Long-term platform:** PGLC catalogue + manufacturing-ready SVG/DXF +
AI-assisted design + CAD validation + nesting + multi-centre operations.

## 3. Technology Stack

-   **Mobile:** Flutter/Dart.
-   **Web administration:** Next.js + TypeScript.
-   **Backend/database:** Supabase + PostgreSQL initially.
-   **Authorization:** PostgreSQL Row Level Security plus server-side
    authorization.
-   **Server functions:** TypeScript/Deno Edge Functions; dedicated
    services when scale/complexity requires them.
-   **Offline:** SQLite/Drift or equivalent local database.
-   **Storage:** Private Supabase Storage buckets.
-   **Payments:** Provider adapter supporting Paystack or Flutterwave
    after final commercial/API due diligence.
-   **Notifications:** Firebase Cloud Messaging/APNs.
-   **Messaging:** WhatsApp Business/API with push/SMS fallback.
-   **CAD:** Isolated Python geometry/CAD worker.
-   **Source control:** GitHub.
-   **CI/CD:** GitHub Actions plus Android/iOS release pipelines.
-   **Monitoring:** Sentry + structured logs.

## 4. Target Architecture

``` text
Flutter Customer/Staff App
        |
        +-- Auth / Session
        +-- Local DB / Offline Queue
        +-- Feature Modules
        |
        v
Supabase/API Boundary
        |
        +-- PostgreSQL
        +-- RLS
        +-- Storage
        +-- Edge Functions
        +-- Realtime
        |
        +---- Payment Gateway
        +---- WhatsApp
        +---- Push Notifications
        |
        v
Design/CAD Worker
        |
        +-- SVG
        +-- DXF
        +-- Geometry Validation
        +-- Nesting
        |
        v
Production / Laser Workshop
```

## 5. Repository Target

``` text
pro-grafiz/
├── CLAUDE.md
├── PRO_GRAFIZ_MASTER_SPEC.md
├── README.md
├── docs/
│   ├── architecture.md
│   ├── database-schema.md
│   ├── api-specification.md
│   ├── security.md
│   ├── testing-strategy.md
│   └── deployment.md
├── apps/
│   ├── mobile/
│   └── admin-web/
├── backend/
├── cad-engine/
├── supabase/
│   ├── migrations/
│   └── seed/
└── assets/
    └── pglc/
```

## 6. Release Scope

### V1 --- Commercial MVP

-   Customer authentication/profile
-   Home, catalogue, categories, search and favourites
-   Pattern detail
-   Material/thickness/dimensions/finish configuration
-   Server-side quotation engine
-   Quote request/intake
-   Real payment integration
-   Eight-stage job tracking
-   Customer design approval/request-change
-   PGJO/PGAO documents
-   Staff authentication
-   Role and branch authorization
-   Intake, queue, payments and design desk
-   Catalogue administration
-   Private file storage
-   Push notifications and controlled WhatsApp handoff
-   Audit trail
-   Basic management dashboard

### V2 --- Automation

-   Camera/sketch capture
-   Sketch-to-vector assistance
-   Pattern matching
-   Blend engine
-   SVG/DXF generation
-   Manufacturing checks
-   Nest/sheet estimation
-   Offline-first staff workflow
-   DXF release grants/audit
-   Transactional WhatsApp
-   Advanced notifications
-   Operational analytics

### V3 --- Intelligent Fabrication Platform

-   AI-assisted concept-to-production
-   Parametric pattern/blend generation
-   Production CAD validation
-   Automated nesting optimization
-   Machine-time estimation
-   Inventory/procurement integration
-   Multi-centre capacity scheduling
-   Customer design studio
-   Advanced pricing optimization
-   BI/profitability analytics
-   Partner/API ecosystem

## 7. Core Database Schema

Use PostgreSQL, UUID primary keys, human-readable business references,
foreign keys, indexes and UTC timestamps.

### branches

`id uuid PK, code text UNIQUE, name text, address text, active boolean, created_at timestamptz`

### profiles

`id uuid PK/FK auth.users, full_name, initials, role enum, branch_id FK, phone, email, pin_hash nullable, active, first_login_at, created_at, updated_at`

### pattern_categories

`id uuid PK, code UNIQUE, name, description, min_thickness_mm, allowed_materials jsonb, active`

### patterns

`id uuid PK, pglc_code UNIQUE, name, category_id FK, geometry_family, density, typical_uses, engineering_note, active, version, created_at, updated_at`

### pattern_assets

`id uuid PK, pattern_id FK, asset_type (png/preview/svg/dxf/thumbnail), storage_path, checksum, file_size, production_ready, version, created_at`

### materials

`id uuid PK, code UNIQUE, name, active`

### material_thicknesses

`id uuid PK, material_id FK, thickness_mm, active`

### finishes

`id uuid PK, code UNIQUE, name, pricing_multiplier, active`

### customers

`id uuid PK, auth_user_id nullable, customer_ref UNIQUE, full_name, phone, email, default_branch_id FK, active, created_at, updated_at`

### sketches

`id uuid PK, customer_id FK nullable, capture_path, traced_outline_path nullable, description, created_by nullable, status, created_at`

### quote_requests

`id uuid PK, request_ref UNIQUE, customer_id FK, branch_id FK, source, pattern_id nullable, blend_id nullable, sketch_id nullable, material_id FK, thickness_mm, width_mm, height_mm, finish_id FK, customer_note, status, decision_reason, decided_by, decided_at, created_at, updated_at`

### quotes

`id uuid PK, quote_ref UNIQUE, quote_request_id FK, version, material_cost_kobo, cutting_cost_kobo, finishing_cost_kobo, labour_cost_kobo, wastage_cost_kobo, delivery_cost_kobo, installation_cost_kobo, discount_kobo, vat_kobo, subtotal_kobo, total_kobo, deposit_kobo, balance_kobo, sheet_count, estimated_cut_minutes, lead_time_days, pricing_snapshot jsonb, status, created_at`

### jobs

`id uuid PK, job_ref UNIQUE, customer_id FK, branch_id FK, quote_id FK, source, pattern_id nullable, blend_id nullable, material_id FK, thickness_mm, width_mm, height_mm, finish_id FK, current_stage, stage_started_at, status, hold_reason, hold_note, cancel_reason, cancel_note, created_at, updated_at`

### job_stage_history

`id uuid PK, job_id FK, stage, entered_at, exited_at, advanced_by, customer_action, note`

### design_revisions

`id uuid PK, job_id FK, revision_no, requested_by, request_note, status, created_at, closed_at`

### drafts

`id uuid PK, job_id FK, revision_id nullable, source, pattern_id nullable, material_id FK, panel_width_mm, panel_height_mm, sheet_count, waste_percent, cut_length_mm, cut_time_seconds, dxf_path, preview_path, version, release_status, override_reason, created_by, created_at`

### draft_checks

`id uuid PK, draft_id FK, check_key, result, value jsonb, message, checked_at`

### payments

`id uuid PK, job_id FK, payment_ref UNIQUE, gateway_ref, bank_reference, kind, amount_kobo, status, matched_at, confirmed_by, confirmed_at, gateway_payload jsonb, created_at`

### payment_events

`id uuid PK, payment_id FK, provider, event_type, provider_event_id UNIQUE, payload jsonb, received_at`

### documents

`id uuid PK, document_ref UNIQUE, job_id FK, type (PGJO/PGAO), event_key UNIQUE, storage_path, issue_date, authorised_by, authorisation_type, created_at`

### dxf_release_grants

`id uuid PK, customer_id FK, pattern_id FK, month_key, expires_at, issued_by, release_code_hash, used_at, revoked_at`

### dxf_download_logs

`id uuid PK, grant_id FK, customer_id FK, pattern_id FK, ip_hash, user_agent, downloaded_at`

### notifications

`id uuid PK, recipient_user_id, type, title, body, entity_type, entity_id, read_at, created_at`

### devices

`id uuid PK, user_id FK, device_name, platform, last_seen_at, sync_state, queued_action_count`

### offline_actions

`id uuid PK, device_id FK, idempotency_key UNIQUE, action_type, payload jsonb, status, created_at, synced_at`

### audit_events

`id uuid PK, actor_user_id, actor_type, action, entity_type, entity_id, before_state, after_state, reason, ip_hash, created_at`

## 8. Roles and Branch Authorization

Roles: - Super Admin - Centre Manager - Accountant - Designer -
Production - Inventory - Customer

Rules: - Centre Managers are restricted to their assigned centre. -
Customers can access only their own records. - No user can change their
own role or branch. - Central roles may see all branches according to
their permissions. - Authorization is enforced server-side, not merely
by hiding UI controls.

## 9. Job Lifecycle

``` text
SUBMITTED
→ PAYMENT_CONFIRMED
→ DESIGN_IN_PROGRESS
→ DESIGN_SENT_FOR_APPROVAL
→ IN_PRODUCTION
→ READY_FOR_DISPATCH
→ DISPATCHED
→ RELEASED
```

Every transition must record actor, timestamp, previous/new stage, note
where applicable and audit event.

Hold/cancel/resume/reopen require controlled reasons and preserve
history.

## 10. Critical Business Rules

-   Blends contain 2--3 patterns; order is significant.
-   Below-minimum thickness is an engineering warning and blocks
    production DXF release.
-   Quote calculation is authoritative on the server.
-   Issued quotes retain immutable pricing snapshots.
-   Payment screenshots never confirm payment.
-   NO MATCH payments cannot be confirmed automatically.
-   Accountant confirmation requires a fresh challenge.
-   Payment webhook events are idempotent.
-   PGJO and PGAO generation is idempotent.
-   Failed mandatory CAD checks block release.
-   Designer upload overrides require a reason.
-   Customer receives preview assets; production receives released
    production files.
-   Stage timers use server timestamps.
-   Sensitive actions create immutable audit events.

## 11. PGLC Catalogue and CAD

PGLC patterns are first-class production data, not just images.

Each pattern should carry: - PGLC code - name/category - typical uses -
manufacturing envelope - material/thickness guidance - preview/PNG -
SVG - DXF where approved - production-ready status - version/checksum

Production flow:

``` text
Pattern
→ SVG
→ Geometry Validation
→ DXF
→ Manufacturing QA
→ Designer Release
→ Production
```

Mandatory checks: 1. minimum bridge width 2. thickness floor 3. closed
cut paths 4. fixing positions 5. nesting efficiency

## 12. Quote Engine

The authoritative quote service receives pattern/blend/sketch, material,
thickness, dimensions, quantity, finish, delivery, installation, urgency
and customer type.

It returns material, cutting, finishing, labour, wastage, delivery,
installation, discount, VAT, subtotal, total, deposit, balance, sheet
count, estimated cut time and lead time.

All commercial rates must be configurable data, not source-code
constants.

## 13. Payment Architecture

Use a provider adapter. The gateway/webhook is the source of truth.

Flow:

``` text
Customer
→ Payment Request
→ Gateway
→ Verified Webhook
→ Payment Event
→ Payment Confirmation Workflow
→ PGJO
→ Job Progression
```

Provider event IDs and business operations must be idempotent.

## 14. DXF Governance

Preferred secure flow:

``` text
Authenticated Customer
→ Permission/Purchase Check
→ Backend Authorization
→ Short-lived Signed URL
→ DXF
→ Download Audit
```

Monthly DXF codes may remain as a licensing/business feature, but are
not the sole security mechanism.

## 15. Offline Architecture

Staff operational actions may be queued locally. Each mutation needs an
idempotency key. Sync must tolerate connection loss, app restart,
retries and duplicate requests.

Offline payment confirmation is disabled by default.

## 16. Notifications

Support events including quote submitted/ready, payment
requested/confirmed, design ready, approval requested, design change
requested, stage changes, hold, ready, dispatch and release.

## 17. Development Sequence

1.  PG-001 Foundation
2.  PG-002 Design System
3.  PG-003 Database
4.  PG-004 Authentication
5.  PG-005 Authorization/RLS
6.  PG-006 PGLC Catalogue
7.  PG-007 Quote Engine
8.  PG-008 Customer Job Flow
9.  PG-009 Payments
10. PG-010 Design Desk/CAD QA
11. PG-011 Documents
12. PG-012 Operations
13. PG-013 Notifications
14. PG-014 Offline
15. PG-015 CAD Pipeline
16. PG-016 Security Hardening
17. PG-017 Pilot
18. PG-018 Store Release

Do not implement the entire sequence in one pass.

## 18. Testing Gates

### Gate 0 --- UX parity

Approved V1 screens and core interactions match the handoff.

### Gate 1 --- Database/security

Migrations reproducible; backups verified; RLS and role tests pass.

### Gate 2 --- Commercial calculation

At least 100 quote cases pass expected outputs and edge cases.

### Gate 3 --- Payment integrity

Success/failure/retry/duplicate webhook tests pass; no client-only
confirmation.

### Gate 4 --- Job lifecycle

Every allowed/denied stage transition is tested.

### Gate 5 --- CAD safety

Failed mandatory checks block production release.

### Gate 6 --- Offline

Queue/replay/restart/duplicate/conflict tests pass.

### Gate 7 --- UAT

Real Pro_Grafiz staff complete scripted end-to-end scenarios.

### Gate 8 --- Production readiness

Monitoring, backups, secrets, legal/privacy, signing and rollback
complete.

### Gate 9 --- Pilot

Controlled rollout metrics meet agreed thresholds before public release.

## 19. Definition of Done --- V1

A real test customer must be able to:

``` text
Sign in
→ Browse PGLC
→ Select design
→ Configure
→ Receive authoritative quote
→ Submit
→ Pay
→ Payment verified
→ PGJO
→ Design prepared
→ Preview
→ Approve
→ PGAO
→ Production
→ Track stages
→ Release/collection
```

If this requires a hardcoded prototype value, mock payment, fake PIN,
client-only permission, mock production file or manual database edit, V1
is not production-ready.

## 20. Engineering Principle

The PGLC catalogue plus manufacturing-ready geometry and metadata is a
strategic Pro_Grafiz asset. Build it as versioned production data from
day one so the platform can evolve from catalogue → quoting → job
management → CAD → AI → automated fabrication.
