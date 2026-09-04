# PGLC Catalogue (PG-006)

**Status: PG-006 complete.** Home, Patterns (browse/search/categories/
favourites), Design detail, and the material/thickness/dimensions/
finish Configure step are built, backed entirely by PG-003's schema and
PG-005's RLS. No RLS policy from PG-005 was modified — this task only
added two new tables/objects with their own fresh policies.

## Scope, per Master Spec §6's V1 bullet list

> Home, catalogue, categories, search and favourites
> Pattern detail
> Material/thickness/dimensions/finish configuration
> Catalogue administration

Built. **Deliberately not built** (belongs to a different, separate V1
bullet or a later PG task):

| Item | Why deferred |
|---|---|
| Server-side ₦ estimate, sheet count, lead time on Configure | "Server-side quotation engine" is its own V1 bullet — PG-007 |
| "Send to Pro_Grafiz" quote submission | "Quote request/intake" is its own V1 bullet — PG-008 (even though `quote_requests` already has a working customer INSERT policy from PG-005) |
| Camera scan (screen #4) | Not named in the V1 bullet list for this task; a substantial flow of its own |
| Blend (screen #5) | Same reason, plus it touches the already-flagged `blends` ownership gap — better addressed deliberately, not as a side effect of building catalogue browsing |
| Live job card / "Start a job" leading anywhere distinct from Browse | Needs real job data — PG-008 |
| Gated DXF download on Design detail | Master Spec §14's signed-URL flow — a later PG task; the badge on Design detail only reflects existence/status, never a path |

## Schema additions

Two additive changes, neither touching any existing PG-005 policy:

1. **`pattern_favourites`** (`20260904000025_pattern_favourites.sql`) —
   gap-fill, same situation as `blends` from PG-003: Master Spec names
   "favourites" as a V1 feature but never defines a table for it. Fresh
   RLS: a customer manages only their own rows; no staff access at all
   (no legitimate reason for it). A `pattern_favourite_counts` view
   exposes only the aggregate count per pattern, publicly, without
   revealing who favourited what — views default to the owner's
   privileges in Postgres, which is what makes this safe.
2. **Storage buckets** (`20260904000026_pglc_storage_buckets.sql`) — no
   bucket existed for `pattern_assets` to point at. Split into
   `pglc-public` (previews/thumbnails/SVG, public read) and
   `pglc-production` (DXF, staff-only), mirroring the row-level split
   already established in `pattern_assets`' PG-005 policies. This is an
   infrastructure decision made to unblock the feature, not something
   the docs specify verbatim — flagged in the migration itself.

## Where things live

```
apps/mobile/lib/features/
├── catalogue/
│   ├── data/
│   │   ├── catalogue_repository.dart   # all Supabase queries; no auth logic of its own
│   │   └── models/                      # PatternCategory, PatternSummary, PatternDetail, MaterialOption, FinishOption
│   └── presentation/
│       ├── patterns_screen.dart         # approved screen #2
│       ├── pattern_detail_screen.dart   # approved screen #3
│       └── configure_screen.dart        # subset of approved screen #6 — no pricing, no submission
└── home/
    └── presentation/
        └── home_screen.dart              # catalogue-relevant portions of approved screen #1

apps/admin-web/src/app/catalogue/page.tsx  # minimal catalogue administration — no approved design exists for this
```

`AuthGate` (PG-004) now routes to the catalogue `HomeScreen` both
signed-in and signed-out — browsing was already public per PG-005's
RLS (`active or is_active_staff()` on `patterns`, etc.), so gating the
UI behind a sign-in wall would have contradicted a decision already
made, not reflected one. Favouriting still requires a session; it just
fails gracefully (no-ops) rather than blocking the browse experience
when signed out.

## Security notes

- `CatalogueRepository` adds no authorization logic of its own — every
  method's actual result set is whatever the caller's RLS allows. This
  is intentional (CLAUDE.md: "Security is server-side") and means the
  repository code itself needed no security review beyond "does it
  query the right tables/columns", not "does it correctly restrict
  access."
- The Configure screen's "Send to Pro_Grafiz" button is `onPressed:
  null` (a real, inert Flutter button state) rather than a disguised
  fake success message or a silent no-op — the person using it sees
  exactly why nothing happens.
- The admin-web catalogue page performs no client-side role check
  before rendering the edit table; a non-Super-Admin session simply
  gets a rejected write from Postgres (`patterns_write_super_admin`).
  This is deliberate, per this task's explicit instruction not to
  introduce client-side authorization as a substitute for database
  authorization — the page fetches optimistically and lets the RLS
  policy be the actual gate.

## PG-005 follow-ups tracked, not addressed here

Per this task's explicit instructions, these are noted but were not
touched because PG-006 didn't require it:

- `blends`/`blend_patterns` ownership gap
- Customer quote-request withdrawal
- Centre Manager audit-event visibility
- Staff access to `drafts.dxf_path` (still function-gated via
  `staff_get_draft_dxf_path()`, unchanged)

## Verification status

Same honesty standard as every prior task: **nothing in this feature
has run against a live Supabase project.** Structural checks actually
performed in this sandbox (Python parsing, not a database):

- Both new migrations balance-checked (parens, `$$` pairs). ✅
- Every Dart file in `features/catalogue/`, `features/home/`, and the
  modified `features/auth/presentation/auth_gate.dart` balance-checked
  for braces/parens. ✅
- Column/table names referenced in `CatalogueRepository` and the new
  migrations cross-checked against the actual PG-003 `CREATE TABLE`
  statements. ✅
- Confirmed via `git status`/`git diff` that no existing migration file
  (PG-001–005) was modified — only new files added. ✅

**Requires live Supabase verification before trusting this feature
works:**
1. `supabase db reset` — confirm migrations 25–26 apply cleanly on top
   of 1–24.
2. Exercise `CatalogueRepository` against a real project with seeded
   patterns/categories/materials/finishes (PG-003's `supabase/seed/`
   dev data, or a richer set) — the PostgREST embedded-resource filter
   syntax used for search (`pattern_categories.code` dot-path filtering)
   and `.inFilter()` for batched favourite/count lookups have not been
   exercised against a real PostgREST instance.
3. Confirm `pattern_favourite_counts` actually resolves correctly for
   an anonymous caller (the security-relevant claim about Postgres view
   ownership privileges, stated in this doc and the migration comment,
   is standard documented Postgres behavior but hasn't been observed
   running here).
4. Upload at least one real preview image to the `pglc-public` bucket
   and confirm it's fetchable by an anonymous client; confirm a
   `pglc-production` upload is rejected for a non-staff session.
5. Confirm the admin-web catalogue page's writes are actually rejected
   for a non-Super-Admin session, and succeed for one.
