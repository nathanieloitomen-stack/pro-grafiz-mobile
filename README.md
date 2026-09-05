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

**PG-001 through PG-011 complete.** PGJO and PGAO documents now
generate automatically — once, idempotently — at the exact moments
already built in PG-008/PG-009 (design approval, deposit confirmation).
Every field in a generated document traces to a real database query;
none is invented — see [`docs/documents.md`](./docs/documents.md), which
also flags the one unspecified decision found (document file format —
built as HTML, since no format was ever specified and no PDF library is
verified to work in this environment). **All pricing/payment decisions
from PG-007/009 remain open** — see
[`docs/quote-engine.md`](./docs/quote-engine.md) and
[`docs/payments.md`](./docs/payments.md). **PG-005 has still not been
executed against a live database** — see
[`docs/authorization.md`](./docs/authorization.md). No staff Intake/
Operations screens, no notifications exist yet. See
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
