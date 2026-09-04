# Security

**Status: PG-004 (Authentication) and PG-005 (Authorization/RLS)
complete.** See [`docs/authorization.md`](./docs/authorization.md) for
the full RLS design, authorization matrix, and — critically — which
claims are verified locally vs. require a live Supabase project.
**PG-005 has not been executed against a live database** — every policy
was written and statically checked, but none of it has run. Do not
treat this as production-verified; follow the "REQUIRES LIVE SUPABASE
VERIFICATION" checklist in that document before any real deployment.

This document will become the working detail (threat model, RLS policy
matrix, secrets inventory, signed-URL flow for DXF, audit event catalog)
behind the non-negotiable rules already fixed in `CLAUDE.md`:

- Security is enforced server-side (PostgreSQL RLS + backend
  authorization), never by hiding UI or trusting client-supplied
  role/branch/price/payment-status values.
- No hardcoded secrets, PINs, API keys, or tokens — environment secrets
  only.
- The backend quote engine is the sole authority on price.
- Payment confirmation only via verified gateway/webhook or approved
  bank-reference workflow; never from a screenshot or client action.
- Idempotent payment webhooks, document generation, job creation, stage
  transitions, and offline sync.
- Private production DXF files require backend authorization; customer
  previews and production CAD assets are separate.
- Every sensitive action produces an immutable audit event.

### Known anti-patterns from the design prototype (do not carry forward)

The approved UX prototype (not part of this repository) demonstrates
several patterns that must not appear in production, called out here so
they aren't accidentally reintroduced during later PG tasks:

- Client-side-only PIN/role checks with no server enforcement
- Client-computed authoritative pricing
- Client-side payment "matched" status with no reconciliation source of
  truth
- No audit attribution on state changes

### Minimum negative-test coverage (per `CLAUDE.md`)

To be implemented alongside the relevant PG task, not before the
underlying feature exists:

- Centre Manager cannot access another centre
- Accountant cannot advance production
- Designer cannot confirm payments
- Customer cannot access another customer's records
- Customer cannot access private DXF without authorization
- Client cannot alter authoritative price
- Duplicate webhook cannot duplicate records
- Failed CAD check blocks release
