-- PG-003: Enum types.
--
-- Only created where the source docs give an explicit, closed value
-- list (Master Spec / CLAUDE.md). Everywhere else a status-like column
-- is plain `text` for now, with a comment pointing at the open decision
-- — the exact state lists for quote_requests.status, quotes.status,
-- design_revisions.status, drafts.release_status, offline_actions.status
-- and devices.sync_state are not specified anywhere in the docs
-- provided, and CLAUDE.md is explicit: "Never invent business rules
-- just to keep coding." Confirm these with the product owner before a
-- later PG task locks them into enums.

-- Master Spec §8 "Roles and Branch Authorization".
create type role_enum as enum (
  'super_admin',
  'centre_manager',
  'accountant',
  'designer',
  'production',
  'inventory',
  'customer'
);

-- Master Spec §9 "Job Lifecycle" — the eight stages, in order.
create type job_stage_enum as enum (
  'SUBMITTED',
  'PAYMENT_CONFIRMED',
  'DESIGN_IN_PROGRESS',
  'DESIGN_SENT_FOR_APPROVAL',
  'IN_PRODUCTION',
  'READY_FOR_DISPATCH',
  'DISPATCHED',
  'RELEASED'
);

-- jobs.status is distinct from jobs.current_stage: the stage enum above
-- tracks lifecycle progress, this tracks whether that progress is
-- currently active, paused, or abandoned. Inferred directly from the
-- jobs table's own hold_reason/hold_note/cancel_reason/cancel_note
-- columns (Master Spec §7) rather than invented independently — but
-- flagging it as an inference, not a value list given verbatim anywhere.
create type job_status_enum as enum (
  'active',
  'on_hold',
  'cancelled'
);

-- CLAUDE.md "PAYMENT RULES": "States include pending, matched, no_match,
-- confirmed, failed, refunded and escalated."
create type payment_status_enum as enum (
  'pending',
  'matched',
  'no_match',
  'confirmed',
  'failed',
  'refunded',
  'escalated'
);

-- Master Spec §16 "PGJO = payment/order document. PGAO = customer
-- approval/order document."
create type document_type_enum as enum (
  'PGJO',
  'PGAO'
);

-- Master Spec §7 pattern_assets.asset_type.
create type asset_type_enum as enum (
  'png',
  'preview',
  'svg',
  'dxf',
  'thumbnail'
);

-- Master Spec §10: "Below-minimum thickness is an engineering warning
-- and blocks production DXF release" implies a three-state check
-- result (not just pass/fail) — pass / warning / fail.
create type check_result_enum as enum (
  'pass',
  'warning',
  'fail'
);
