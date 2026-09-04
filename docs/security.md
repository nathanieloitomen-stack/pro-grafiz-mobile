# Security

**Status: policy defined in `CLAUDE.md`; PG-004 (Authentication)
implemented; PG-005 (Authorization/RLS) not started — see the warning
below before deploying anything.**

## Critical: no RLS yet, interim exposure

Every table exists (PG-003) with Row Level Security **disabled**. On a
real Supabase project this typically means the `anon`/`authenticated`
PostgREST roles can read/write these tables directly depending on
default grants, regardless of the authentication work done in PG-004.
**Do not point a real mobile/web build at a real deployed instance of
this schema until PG-005 lands.** Full detail in `docs/authentication.md`.

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
