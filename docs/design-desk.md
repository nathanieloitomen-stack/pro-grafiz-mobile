# Design Desk / CAD QA (PG-010)

**Status: PG-010 complete as scoped.** This task sits directly on a
V1/V2 boundary found during inspection — see below before anything
else.

## Critical finding: another V1/V2 conflict

Master Spec §6 lists these as **V2** ("Automation") scope: "SVG/DXF
generation," "Manufacturing checks," "Nest/sheet estimation." But §11
describes the production flow (`Pattern → SVG → Geometry Validation →
DXF → Manufacturing QA → Designer Release → Production`) and the five
mandatory checks as if they're active now, and the V1 bullet list
includes "Intake, queue, payments and **design desk**" as a staff
feature. Read together: the **workflow** (a designer reviewing a job,
recording check results, releasing or holding a design) is V1; the
**automated computation** behind SVG/DXF generation and manufacturing
checks is V2. This task builds the former only — per your explicit
instruction not to generate or release production geometry just to make
the workflow look complete, nothing here synthesizes geometry or infers
a check result. A human designer uploads a real file they created
elsewhere (in actual CAD software) and records what they found.

## The four kinds of geometry, as distinguished per your instruction

| Kind | Where it lives | Who can see it |
|---|---|---|
| Catalogue preview geometry | `pattern_assets`, `pglc-public` bucket (PG-006) | Public |
| Design-review geometry | `drafts.preview_path`, `job-drafts/preview/` (new) | The owning customer + staff (via `drafts_select_own_or_staff`, PG-005) |
| Production-ready geometry | The same `drafts.dxf_path`, once `release_status = 'released'` | No file moves or is duplicated — only authorization changes |
| Released DXF/production asset | `job-drafts/production/` (new), via `staff_get_draft_dxf_path()` | Staff only, and — new in this task — Production role specifically requires `release_status = 'released'` |

## What was built

### Database

- **`job-drafts` Storage bucket** (private, zero direct client
  policies) — `pglc-public`/`pglc-production` (PG-006) are untouched;
  this is a third, separate bucket for job-specific (not general
  catalog) files. All access goes through the two new Edge Functions
  below, never a bucket-level policy — appropriate here since these
  files are customer/job-specific, unlike the genuinely public catalog.
- **`staff_get_draft_dxf_path()` refined**, not weakened: Production
  role now additionally requires the draft to be `released` before the
  function returns a path; Designer/Super Admin access is unchanged
  (they need pre-release access to do the review itself). This is a
  *tightening*, directly implementing your instruction that "production
  DXF release must remain subject to the existing authorization,
  validation and audit requirements" — pre-release geometry was never
  meant to be treated as an authorized production asset for the
  Production role.
- **No other schema change.** `drafts`/`draft_checks` already existed,
  fully correctly shaped, from PG-003/PG-005 — including the CAD
  release-gate trigger (`enforce_draft_release_gate`), which this task
  relies on entirely rather than reimplementing.

### Server-side (Edge Functions) — only where RLS genuinely can't reach

- **`start-design`**: `PAYMENT_CONFIRMED` → `DESIGN_IN_PROGRESS`. Needed
  because `jobs` has zero client write policies. **The exact trigger for
  this transition isn't specified anywhere** — implemented as a manual
  Designer action, flagged as an interpretation, not a certainty.
- **`release-draft`**: performs the `drafts` release update (which a
  Designer could already do directly via RLS) and, only if that
  succeeds, advances the job `DESIGN_IN_PROGRESS` → `DESIGN_SENT_FOR_APPROVAL`.
  Does **not** reimplement the release gate — `enforce_draft_release_gate`
  (PG-005) still does that; this function just also touches the job,
  which RLS alone can't.
- **`request-draft-upload-url`** / **`get-draft-file-url`**: signed
  Storage URLs, since `job-drafts` has no client-accessible bucket
  policy at all.

**Draft creation and check-result recording do NOT have dedicated Edge
Functions** — `drafts_write_designer_or_super_admin` and
`draft_checks_write_designer_or_super_admin` (both PG-005) already fully
authorize a Designer to do this directly via RLS. Building functions
for these would have been redundant; the Flutter repository calls
Supabase directly for both.

### UI

- `DesignDeskScreen` — jobs needing design work.
- `DraftReviewScreen` — start design, create a draft, upload/view files
  (signed URLs shown for manual use — no in-app file picker/upload
  client was built; this app doesn't perform the actual PUT to the
  signed URL, matching "don't fake the workflow" for the one piece that
  would require picking a real file), record the five mandatory checks
  manually, release (with an override-reason prompt when a check
  failed).

## Security implications

- No client-side authorization anywhere in this task's new code —
  every function re-derives the caller's role from `profiles` via the
  service-role client, never trusts a client-asserted role.
- No direct unauthorized writes: `jobs` remains fully locked to
  service-role; `job-drafts` Storage has zero client policies.
- No production DXF exposure through public storage — `job-drafts` is
  private end-to-end; nothing in this task added a public bucket policy.
  `pglc-public`/`pglc-production` remain exactly as PG-006 left them.
- No hardcoded secrets.

## RLS implications

No existing PG-005 policy was modified — confirmed via `git status`
before committing. One SECURITY DEFINER function
(`staff_get_draft_dxf_path`) was tightened for one role (Production);
Designer/Super-Admin/customer access is byte-for-byte unchanged.

## Production-DXF implications

A draft's `dxf_path` becomes an authorized "production asset" the
instant `release_status` flips to `'released'` — no file content
changes, moves, or is regenerated at that moment. Before release, the
Production role cannot fetch it at all (new in this task); Designer/
Super Admin can, because they're the ones doing the review that leads
to release. The release gate itself (blocking release when a mandatory
check failed without an override reason) is unchanged from PG-005.

## Unspecified decisions discovered (STOPPED, not guessed)

1. **Exact trigger for `PAYMENT_CONFIRMED` → `DESIGN_IN_PROGRESS`** —
   is it automatic, or a manual "I'm starting this" action? Implemented
   as manual (a Designer explicitly starts it), flagged as an
   interpretation.
2. **Whether releasing a draft should always immediately advance the
   job to `DESIGN_SENT_FOR_APPROVAL`**, or whether there's a separate
   staff-side "send for approval" step distinct from "release." Bundled
   together here — the approved design's exact button copy for this
   specific moment isn't available with certainty.
3. **CAD tolerances, bridge widths, kerf compensation, nesting
   parameters** — none exist anywhere in the docs (confirmed by
   inspection) and none were invented. The five mandatory checks are
   recorded as a designer's plain pass/warning/fail judgment with an
   optional free-text message — no numeric thresholds are computed or
   enforced by this system.
4. **Whether Production should see jobs at all stages or only once
   released** — `DesignDeskScreen`'s job list currently shows jobs at
   `PAYMENT_CONFIRMED`/`DESIGN_IN_PROGRESS` regardless of viewer role
   (relying on `jobs_select_own_or_staff` for actual visibility, which
   already includes Production via `is_central_staff()`) — not
   specifically tailored to what Production would want to see per se,
   since that's a UI/workflow question the docs don't detail.

## Tests actually executed

Static structural analysis only — parenthesis/`$$`/`$q$` balance across
the new migration, 4 Edge Functions, and 4 Dart files; every table/
column/function reference cross-checked against the actual schema;
confirmed via `git status` that no existing migration or RLS policy
file was modified.

## Tests that could not be executed

Everything in `supabase/tests/database/110_design_desk.sql` — no live
database. `start-design`'s and `release-draft`'s actual stage-transition
logic (TypeScript, service-role) has never run anywhere, nor has the
Storage signed-URL flow in either storage function.

## Known defects

`request-draft-upload-url` sets `drafts.preview_path`/`dxf_path`
immediately upon issuing the signed URL, before the client actually
uploads the bytes — if the upload fails, the path exists in the
database pointing at nothing. A data-quality edge case, documented in
the function's own header comment, not a security issue; a two-phase
"confirm upload" step would close it but wasn't built here.

## Deferred decisions

All items under "Unspecified decisions discovered" above, plus every
open item already tracked in `docs/quote-engine.md` and
`docs/payments.md` — none of PG-010's work touched or resolved any of
those.

## Exact live-environment verification required

```bash
supabase db reset            # migration 31 applies on top of 1–30
create extension if not exists pgtap;
supabase test db              # includes 110_design_desk.sql
supabase functions serve
```

Then, in order: as Designer, call `start-design` on a job at
`PAYMENT_CONFIRMED`, confirm it advances; create a draft, request an
upload URL for `preview`, actually PUT a real file to it, then call
`get-draft-file-url` and confirm the returned signed URL actually
serves that file; record all five checks as `pass`, call `release-draft`,
confirm the job advances to `DESIGN_SENT_FOR_APPROVAL`; record one check
as `fail`, attempt release without an override — confirm it's rejected
by the existing trigger with the exact same message as before; retry
with an override reason and confirm it succeeds; as Production, attempt
`get-draft-file-url` for `production` on an unreleased draft (confirm
rejection) and again after release (confirm success); confirm a
customer session can never reach the production branch of
`get-draft-file-url` at all.
