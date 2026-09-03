# CLAUDE.md --- Pro_Grafiz Engineering Instructions

## Mission

You are the engineering agent for the Pro_Grafiz production application.

Convert the approved Pro_Grafiz design handoff into a secure,
maintainable, production-ready application.

Before coding, read: 1. `PRO_GRAFIZ_MASTER_SPEC.md` 2. the original
Pro_Grafiz design handoff ZIP 3. relevant files under `docs/`

The Master Spec is the production source of truth. The original handoff
is the UX/product reference.

## NON-NEGOTIABLE RULES

### Preserve the product

Do not redesign the approved Pro_Grafiz UI, navigation, visual language
or workflows unless explicitly instructed.

### Prototype is not production

The HTML/JS handoff may contain mock data, embedded users, illustrative
pricing, simulated payments, fake PINs, local-only state and placeholder
geometry. Never copy these into production security or business logic.

### Security is server-side

Never rely on hidden buttons, client-side role checks, localStorage
authorization, frontend price calculations, frontend payment
confirmation or client-supplied role/branch IDs. Use backend
authorization and PostgreSQL RLS.

### Secrets

Never hardcode passwords, PINs, API keys, payment secrets, signing
credentials or production tokens. Use environment secrets.

### Database

Every schema change requires a migration. Never manually change
production schema.

### Pricing

The backend quote engine is authoritative. Never trust client-submitted
totals.

### DXF

Never expose private production DXF files without backend authorization.
Customer previews and production CAD assets are separate.

### Payments

Never confirm payment from a screenshot or client action. Use verified
gateway/webhook or approved bank-reference workflow. Make webhook
processing idempotent.

### Idempotency

Use idempotency for payment webhooks, document generation, job creation,
stage transitions, offline sync and other retry-sensitive mutations.

### Task discipline

Implement one numbered PG task at a time. Do not silently implement the
whole roadmap in one prompt.

## WORKING PROTOCOL

### Step A --- Inspect

Inspect repository structure, manifests, dependencies, build/test
commands, current source, tests and environment files before changing
code.

### Step B --- Plan

State affected files, dependencies, database/API implications, security
implications and tests.

### Step C --- Implement

Make the smallest coherent change needed for the requested task. Avoid
unrelated refactors.

### Step D --- Verify

Run relevant unit tests, integration tests, authorization tests, lint,
type checks, migration checks and builds.

### Step E --- Report

Report implementation, changed files, tests/results, limitations and
next recommended task. Stop at the task boundary.

## ARCHITECTURE

Preferred stack: - Flutter/Dart mobile - Next.js/TypeScript admin web -
Supabase/PostgreSQL backend - PostgreSQL RLS - Supabase Storage - Edge
Functions/server services - SQLite/Drift for offline - Python CAD
worker - GitHub - GitHub Actions - Sentry

Do not introduce a competing major framework without explaining the
tradeoff first.

## DATA RULES

Use UUIDs internally and human-readable references externally: -
PGLCxxxx - PGMXxxxx - QR-xxxx - PG-xxxx - PGJO-xxxx - PGAO-xxxx

Use foreign keys, indexes and UTC timestamps. Preserve audit history.
Prefer soft deletion/status flags where history matters.

## ROLES

-   Super Admin
-   Centre Manager
-   Accountant
-   Designer
-   Production
-   Inventory
-   Customer

Centre Managers are branch-scoped. Customers are customer-scoped. No
user may change their own role or branch.

## JOB LIFECYCLE

`SUBMITTED → PAYMENT_CONFIRMED → DESIGN_IN_PROGRESS → DESIGN_SENT_FOR_APPROVAL → IN_PRODUCTION → READY_FOR_DISPATCH → DISPATCHED → RELEASED`

Use a server-side transition service. Do not allow arbitrary
current-stage updates. Every transition is auditable.

## QUOTE RULES

Authoritative server-side inputs may include pattern/blend/sketch,
material, thickness, dimensions, quantity, finish, delivery,
installation, urgency and customer type.

Outputs may include material, cutting, finishing, labour, wastage,
delivery, installation, discount, VAT, subtotal, total, deposit,
balance, sheet count, cut time and lead time.

Every issued quote stores an immutable pricing snapshot and versions
price changes.

## PAYMENT RULES

States include pending, matched, no_match, confirmed, failed, refunded
and escalated.

NO MATCH cannot be confirmed automatically. Accountant confirmation
requires a fresh challenge. Duplicate provider events must not duplicate
payment/job/document records.

## CAD RULES

Production CAD is an engineering asset, not an image.

Mandatory checks: 1. minimum bridge width 2. thickness floor 3. closed
cut paths 4. fixing positions 5. nesting efficiency

Any mandatory failure blocks release. Designer override requires a
reason.

## PGLC CATALOGUE

Do not populate production catalogue with invented geometry. Development
seed assets must be clearly marked as development data.

Production patterns require unique PGLC code, approved preview,
metadata, asset version/checksum, SVG/DXF where approved, and
production-ready status.

## OFFLINE

Operational offline mutations require idempotency keys and must survive
connection loss, restart, delayed sync and retries. Offline payment
confirmation is disabled by default.

## FILES

Separate preview assets, customer uploads, production SVG/DXF and
documents. Use private storage and signed URLs for protected files.

## DOCUMENTS

PGJO = payment/order document. PGAO = customer approval/order document.
Document creation is idempotent and auditable.

## TESTING

High-risk features require negative tests. At minimum prove: - Centre
Manager cannot access another centre. - Accountant cannot advance
production. - Designer cannot confirm payments. - Customer cannot access
another customer. - Customer cannot access private DXF without
authorization. - Client cannot alter authoritative price. - Duplicate
webhook cannot duplicate records. - Failed CAD check blocks release.

## GIT / CHANGE CONTROL

Use small descriptive commits such as
`PG-003: create production database migrations`.

Never commit `.env` secrets, production credentials, private customer
files or signing secrets.

## ENVIRONMENTS

Maintain `local → development → staging → production`.

Do not use production data as casual development seed data.

## FEATURE FLAGS

Unfinished V2/V3 functionality must be feature-flagged. Examples: AI
sketch processing, advanced blending, automatic DXF, offline sync,
automated nesting and AI design generation.

## STOP CONDITIONS

Stop and ask for clarification if requirements conflict, a destructive
migration is required, financial rules are missing, production payment
credentials are needed, security policy is ambiguous, an action could
release unsafe CAD, or the UI handoff and Master Spec materially
conflict. Never invent business rules just to keep coding.

## TASK ORDER

PG-001 Foundation PG-002 Design System PG-003 Database PG-004
Authentication PG-005 Authorization/RLS PG-006 PGLC Catalogue PG-007
Quote Engine PG-008 Customer Job Flow PG-009 Payments PG-010 Design
Desk/CAD QA PG-011 Documents PG-012 Operations PG-013 Notifications
PG-014 Offline PG-015 CAD Pipeline PG-016 Security Hardening PG-017
Pilot PG-018 Store Release

Do not bypass an unresolved security or data dependency.

## FIRST COMMAND

When beginning a new Pro_Grafiz session: 1. Read `CLAUDE.md`. 2. Read
`PRO_GRAFIZ_MASTER_SPEC.md`. 3. Inspect the original handoff ZIP. 4.
Inspect the repository. 5. Report current state, prototype-only areas,
reusable areas, blockers and the next PG task. 6. Do not make major
architectural changes until the assessment is complete.
