# Pro_Grafiz

Digital design-to-fabrication platform for Pro_Grafiz Designs Ltd (metal
laser cutting and fabrication, seven customer centres, Abuja and Lagos).

This repository is the **production build**, distinct from the approved
design handoff prototype (`Pro_Grafiz App.dc.html` and its README), which
remains the UX/visual reference only and is not committed here.

## Start here

1. Read [`CLAUDE.md`](./CLAUDE.md) — non-negotiable engineering rules and
   working protocol for anyone (human or AI agent) working in this repo.
2. Read [`PRO_GRAFIZ_MASTER_SPEC.md`](./PRO_GRAFIZ_MASTER_SPEC.md) — the
   authoritative production architecture, schema, business rules, and
   task sequence (PG-001 … PG-018).
3. Read [`docs/`](./docs) for the working detail behind each area
   (architecture, schema, API, security, testing, deployment).

## Repository layout

```
pro-grafiz/
├── CLAUDE.md                   Engineering rules and protocol
├── PRO_GRAFIZ_MASTER_SPEC.md   Production source of truth
├── docs/                       Architecture, schema, API, security, testing, deployment
├── apps/
│   ├── mobile/                 Flutter customer + staff app
│   └── admin-web/              Next.js + TypeScript admin web
├── backend/                    Server-side services beyond Supabase Edge Functions
├── cad-engine/                 Isolated Python geometry/CAD worker
├── supabase/
│   ├── migrations/             SQL migrations (schema changes only via migration)
│   └── seed/                   Development-only seed data, clearly marked
└── assets/
    └── pglc/                   Production PGLC catalogue assets (none committed yet)
```

## Status

**PG-001 (Foundation), PG-002 (Design System), PG-003 (Database),
PG-004 (Authentication), and PG-005 (Authorization/RLS) complete.**
Every table has Row Level Security enabled with an explicit policy —
see [`docs/authorization.md`](./docs/authorization.md) for the full
authorization matrix, design decisions, and — critically — exactly
which claims are verified locally vs. still require a live Supabase
project to confirm. **PG-005 has not been executed against a live
database** — treat it as a thorough, reviewable draft, not proof.
No payment gateway integration, no feature screens exist yet. See
[`PRO_GRAFIZ_MASTER_SPEC.md`](./PRO_GRAFIZ_MASTER_SPEC.md#17-development-sequence)
for the full task sequence. Do not implement tasks beyond the currently
authorized one in a single pass.

## Local setup (once tooling is available)

This scaffold was authored without network access, so dependency
manifests are declared but not installed and no lockfiles are committed.
Before development:

```bash
# Mobile
cd apps/mobile && flutter pub get

# Admin web
cd apps/admin-web && npm install

# Supabase (local)
supabase start
```

Verify tool versions against `apps/mobile/pubspec.yaml` and
`apps/admin-web/package.json` and update pinned versions if newer stable
releases exist — they were not checked against a live registry when this
scaffold was created.
