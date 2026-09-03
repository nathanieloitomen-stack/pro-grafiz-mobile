# API Specification

**Status: not started.**

This will document the Supabase/Edge Function API surface as each
feature area is built (quote engine in PG-007, job flow in PG-008,
payments in PG-009, documents in PG-011, notifications in PG-013, CAD in
PG-015). For each endpoint, record:

- Route / RPC name
- Auth requirement and role/branch scope enforced server-side
- Request/response shape
- Idempotency behaviour (required for payment webhooks, document
  generation, job creation, stage transitions, offline sync — see
  `CLAUDE.md`, "Idempotency")
- Error cases

No endpoints exist yet — there is no backend deployed at this stage.
