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

**PG-001 through PG-017 complete.** PG-016's audit found two issues;
both are now fixed. Nine lifecycle-adjacent functions now use an atomic
compare-and-swap (matching PG-015's pattern) instead of a non-atomic
check-then-act sequence, and the four transitions that wrote no audit
trail — including payment confirmation — now do. See
[`docs/pg017-concurrency-audit-remediation.md`](./docs/pg017-concurrency-audit-remediation.md).
**The actual concurrency property has not been verified live** — no
Supabase project or Deno runtime has been available at any point in
this project; only static structural checks were possible. **All
pricing/payment/format/authority decisions from PG-007/009/011/012
remain open.** **PG-005 has still not been executed against a live
database.** No offline sync, no automated CAD pipeline exist yet. See
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
