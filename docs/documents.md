# Documents — PGJO/PGAO (PG-011)

**Status: PG-011 complete as scoped.** Every field in a generated
document traces to a real query — see "Document data sources" below for
the exact mapping.

## Exact scope, per the docs

CLAUDE.md: "PGJO = payment/order document. PGAO = customer
approval/order document. Document creation is idempotent and
auditable." Master Spec's two flow diagrams place generation precisely:

- `Payment Confirmation Workflow → PGJO → Job Progression` (§13)
- `Approve → PGAO → Production` (customer journey, §19)

Both moments already exist in this codebase (PG-008's `respond-to-design`,
PG-009's `confirm-payment`) — PG-011's job was to generate the right
document at each, using only real data, idempotently.

## What was built

### Database

One migration: a new, private `job-documents` Storage bucket (zero
client policies, matching `job-drafts`' PG-010 pattern) — a **third**,
distinct bucket from `job-drafts` and `pglc-public`/`pglc-production`,
preserving the geometry-vs-document distinction at the infrastructure
level. **No other schema change** — `documents`' table, RLS,
`document_type_enum`, and the `PGJO-xxxxxx`/`PGAO-xxxxxx` reference
generator all already existed, fully correct, from PG-003/PG-005.

### Server-side

- **`_shared/document_generator.ts`**: the core. Checks for an existing
  document by `event_key` first (true idempotency — a retry doesn't even
  re-render or re-upload); if absent, queries jobs/customers/branches/
  materials/finishes/quotes/payments/drafts/job_stage_history directly,
  renders an HTML document from *only* that queried data, uploads it,
  and inserts the `documents` row (relying on the existing trigger for
  `document_ref`).
- **`confirm-payment` (PG-009) and `respond-to-design` (PG-008) were
  modified** — the only existing files touched in this task, both
  already-reviewed financial/approval security gates. The change in
  each is a single, clearly-scoped addition: after the existing
  stage-transition logic succeeds (unchanged), call `generateDocument()`
  for the matching document type, wrapped in try/catch so a
  document-generation failure can **never** roll back or block the
  underlying payment confirmation or design approval, which have
  already fully succeeded by that point. Nothing else in either
  function was changed — verify with `git diff` against `c103005`
  (PG-009) and `e40dd8e` (PG-008).
- **`get-document-url`**: signed download URL, using the *caller's own*
  client (not admin) to look up the document row — visibility comes
  entirely from `documents_select_own_or_staff` (PG-005, unmodified),
  not a new rule.

### UI

`JobDetailScreen` gets a "Documents" section — a "View" button per
available type, opening a signed URL. No in-app document viewer/PDF
renderer was built; the URL is shown for the person to open.

## Documents generated

- **PGJO**: once, when a job's deposit payment is confirmed (the exact
  moment already existed in `confirm-payment`).
- **PGAO**: once, when a customer approves their design (the exact
  moment already existed in `respond-to-design`).

Exactly one of each per job — enforced by the deterministic
`event_key` (`PGJO-{job_id}` / `PGAO-{job_id}`) against the existing
UNIQUE constraint, not by application-level "check first" logic alone
(a race is still caught: see "Idempotency implementation" below).

## Document data sources

Every field, and where it comes from — nothing on this list is
free-form or passed through from the calling function's own state:

| PGJO field | Source |
|---|---|
| Job reference, specification | `jobs` (joined to `materials`, `finishes`) |
| Centre | `branches` |
| Customer | `customers` |
| Payment reference, bank reference, amount, confirmed at | `payments` (the specific confirmed deposit row) |
| Confirmed by | `profiles.full_name`, via `payments.confirmed_by` |
| Quote total/deposit/balance | `quotes`, via `jobs.quote_id` |

| PGAO field | Source |
|---|---|
| Job reference, specification, centre, customer | Same as PGJO |
| Approved design version | `drafts` (the released version for this job) |
| Approved at | `job_stage_history` (the row where `customer_action = 'approved'`) |
| Quote total | `quotes` |

`authorised_by` for PGJO is the confirming Accountant's `profiles.id`
(a real staff row). For PGAO it's `null` with
`authorisation_type = 'customer_approval'` — a customer isn't a
`profiles` row (the same gap flagged since PG-003 for
`design_revisions.requested_by`), so this document says so explicitly
in its own "Approved by" field rather than fabricating a staff
attribution.

## Idempotency implementation

1. Look up by `event_key` before doing anything else — a true retry
   never re-queries the job, re-renders, or re-uploads.
2. If the INSERT still races (two concurrent calls both pass the
   lookup), the `event_key` UNIQUE constraint rejects the second
   INSERT (`23505`); the function catches that specific error and
   returns the winning row instead of surfacing an error — a caller can
   never observe a failure caused by the document already existing.
3. Storage upload uses `upsert: true` at a deterministic path
   (`{type}/{job_id}.html`) — a retried upload overwrites with
   byte-identical content rather than erroring or creating a duplicate
   file.

## Security/RLS implications

- **No existing RLS policy was modified.** `documents` still has zero
  client write policies — confirmed via `git status`/`git diff` before
  committing; `generateDocument()`'s use of the service-role key is the
  only path, unchanged in principle from every other write path in this
  codebase.
- **No production DXF/CAD exposure through documents**: the generated
  HTML deliberately does **not** embed any drafts.preview_path or
  dxf_path link, signed or otherwise — a stored document with an
  embedded 5-minute signed URL would be broken the moment someone
  reopened it later, and more importantly this avoids ever putting
  production geometry access inside a long-lived stored artifact. The
  PGAO document references the approved draft only by version number.
- `job-documents` has zero client-accessible bucket policies, matching
  `job-drafts`' PG-010 pattern — no public exposure path exists.
- No hardcoded secrets.

## Unspecified decisions discovered (STOPPED, not guessed)

1. **Document file format.** Neither document specifies PDF, HTML, or
   any other format — only the data fields and the idempotency
   requirement. Generated as HTML (real, valid, printable, servable
   directly from Storage) because no PDF-generation library is verified
   to work in the Supabase Edge Function (Deno) runtime in this
   environment. The authoritative-data-sourcing logic — the actual
   substance of this task — is unaffected by whatever rendering layer
   might replace this later.
2. **Signature requirement.** Nothing in either document mentions a
   signature, digital or physical. None was implemented.
3. **Numbering convention** was NOT an open decision — `PGJO-xxxxxx`/
   `PGAO-xxxxxx` is fixed by CLAUDE.md and was already built in PG-003.
4. **Approval rule for PGAO's "authorised_by"** — a customer has no
   `profiles` row to reference (flagged above); resolved by leaving the
   column `null` with an explicit `authorisation_type`, not by
   inventing a workaround identity.
5. **Company information on the document** — only "Pro_Grafiz Designs
   Ltd" (the company's actual, already-known name) and the specific
   branch's real address (from `branches.address`) appear. No fabricated
   head-office address, phone number, RC number, or other company detail
   was added — anything not queryable from the database was simply
   omitted rather than invented.

## Tests actually executed

Static structural analysis only — parenthesis/`$$` balance across the
new migration, 2 new Edge Functions, the modified sections of
`confirm-payment`/`respond-to-design`, and the new Dart files; every
table/column reference cross-checked against the actual schema;
confirmed via `git diff` that neither modified function's existing
logic changed beyond the flagged addition.

## Tests that could not be executed

Everything in `supabase/tests/database/120_documents.sql` — no live
database. `generateDocument()`'s actual rendering and idempotency
behavior, and the two integration points in `confirm-payment`/
`respond-to-design`, have never run anywhere.

## Known defects

None newly introduced. The PG-010 upload-path data-quality issue
(recorded as technical debt in that task) is unrelated to and not
touched by this task's work.

## Deferred decisions

Document format (HTML vs. PDF) and signature requirements, both above.
Everything already open from PG-007/009/010 (pricing, VAT, deposit,
refunds, payment provider, CAD tolerances) remains untouched.

## Exact live-environment verification required

```bash
supabase db reset             # migration 32 applies on top of 1–31
create extension if not exists pgtap;
supabase test db               # includes 120_documents.sql
supabase functions serve
```

Then, in order: confirm a deposit payment via `confirm-payment` and
verify exactly one `documents` row (`type = 'PGJO'`) is created, with
every field matching the real payment/job/quote records; call
`confirm-payment`'s underlying flow again in a way that would re-trigger
generation (e.g. by re-running the job-advancement branch) and confirm
no second PGJO is created; approve a design via `respond-to-design` and
verify exactly one PGAO document is created; call `get-document-url` as
the owning customer and as an unrelated customer (confirm rejection);
open the returned signed URL and confirm the HTML renders correctly and
contains no embedded DXF/preview link.
