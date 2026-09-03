# Architecture

Source of truth: `PRO_GRAFIZ_MASTER_SPEC.md`, Sections 3–4. This file
mirrors it so architecture context lives alongside code; update both
together if they ever diverge, and treat the Master Spec as authoritative
if they conflict.

## Technology stack

- Mobile: Flutter/Dart
- Web administration: Next.js + TypeScript
- Backend/database: Supabase + PostgreSQL
- Authorization: PostgreSQL Row Level Security + server-side checks
- Server functions: TypeScript/Deno Edge Functions; dedicated services
  where scale/complexity requires them (see `backend/`)
- Offline: SQLite/Drift (mobile, staff operational actions only)
- Storage: private Supabase Storage buckets
- Payments: provider adapter over Paystack or Flutterwave
- Notifications: Firebase Cloud Messaging / APNs
- Messaging: WhatsApp Business API, push/SMS fallback
- CAD: isolated Python geometry/CAD worker (`cad-engine/`)
- Source control: GitHub
- CI/CD: GitHub Actions
- Monitoring: Sentry + structured logs

## Target architecture

```text
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

## Status

Scaffolding only (PG-001). No services are deployed. No architectural
decisions beyond what's fixed in the Master Spec have been made — do not
introduce a competing major framework without documenting the tradeoff
here first, per `CLAUDE.md`.
