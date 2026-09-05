# Staging & Live Verification (PG-018)

## 1. Executive Summary

**Live Supabase staging could not be established in this environment.**
This is stated immediately and plainly, per this task's own core
instruction ("PROVE WHAT ACTUALLY WORKS — DO NOT HIDE FAILURES") and
its explicit prohibition on claiming untested work.

Before writing anything else, three separate access paths were tested
directly, not assumed:

```
curl https://api.supabase.com   → HTTP 403
curl https://supabase.com       → HTTP 403
which psql / postgres / pg_ctl  → not found
which supabase (CLI)            → not found
which deno                      → not found
which docker                    → not found
```

This sandbox has **zero network egress** (confirmed by direct HTTP
request, not inferred from a settings flag) and **no local database,
Supabase CLI, Deno runtime, or container engine** of any kind. Every
one of PG-018's 19 execution steps (Steps 2–20) requires at least one
of these, and none is available. This is not a new discovery — every
prior task since PG-001 stated the same limitation — but PG-018 is the
first task whose entire purpose depends on that limitation not being
true, so it is reported first, in full, before anything else.

**What was actually done**: a fresh, independent static/structural
verification pass — re-reading every migration, function, RLS policy,
environment template, and CI configuration file directly, rather than
citing PG-016's audit as a substitute. Where this pass agrees with
PG-016, that's noted as independent confirmation, not assumed
consistency. No application code was changed. No test data was
created (none could be, without a database). No staging project
exists.

**Final assessment: CONDITIONAL GO** — see Section 24. Development may
continue; genuine Supabase staging access is a hard precondition
before this application can be considered production-ready, and
remains completely unaddressed by this task, through no lack of
effort within it.

## 2. Staging Environment

**Not established.** No Supabase project — staging or otherwise — was
created, connected to, or configured. `supabase/config.toml` was
authored in PG-001 with its own honest disclaimer ("authored without
running `supabase init` — no network/CLI access in the authoring
environment... regenerate or reconcile... once the Supabase CLI is
available") — that disclaimer remains accurate today, unchanged.
`.env.example` was re-verified to contain placeholder values only
(confirmed by direct inspection, not sampling) — no real credential of
any kind exists anywhere in this repository, staging or production.

## 3. Migration Verification

**BLOCKED — no database available to apply migrations to.**

What was possible instead: a fresh static pass over all 33 migration
files, independent of PG-016's own count —
- Every file's parentheses and `$$`/`$q$` delimiters balance (verified
  via script, not visual inspection).
- Every `references` clause was checked against a table defined in an
  earlier-numbered migration file (migrations are strictly
  sequentially numbered and never reordered — confirmed via `git log
  --diff-filter=M -- supabase/migrations/`, which returns empty,
  meaning no migration was ever edited after being committed).
- No duplicate table, policy, or index name exists across all 33 files
  (re-confirmed by grep, independent of the PG-016 count).

**This proves the SQL is internally self-consistent. It does not and
cannot prove the migrations actually execute against a real Postgres
instance without error** — no tool in this environment can execute
SQL against anything. A subtle runtime-only issue (e.g. an extension
not enabled, a function volatility mismatch, a trigger firing order
dependency) would not be caught by any check performed here.

## 4. Authentication Verification

**BLOCKED — no Supabase Auth service reachable.** Customer phone→OTP
and staff invite→PIN-setup→sign-in flows were re-read in full
(`supabase/functions/staff-invite`, `staff-set-initial-pin`,
`staff-list-signin-identities`, `staff-reset-pin`, and the
`handle_new_customer_signup` trigger) — the code is structurally
consistent with itself (a staff PIN really is used as a Supabase Auth
password via a synthetic `auth_login_handle`; invite tokens really are
hashed before storage; `confirm-payment`'s fresh challenge really does
call `signInWithPassword` against a separate client). **None of this
was exercised against Supabase's actual Auth implementation.** Whether
Supabase's real password-length enforcement, rate limiting, or session
behavior interacts correctly with this design is unverified.

## 5. RLS/Security Verification

**BLOCKED for live execution.** The 17 pgTAP test files
(`00_helpers.sql` through `160_concurrency_audit_remediation.sql`,
covering PG-005 through PG-017) have never run — `pgTAP` requires a
live Postgres instance with the extension installed, unavailable here.

Static re-verification performed independently in this task (not
copied from PG-016's numbers, re-derived from scratch):

| Table | Write policy exists? |
|---|---|
| `jobs` | No |
| `quotes` | No |
| `payments` | No |
| `payment_events` | No |
| `documents` | No |
| `dxf_release_grants` | No |
| `dxf_download_logs` | No |
| `audit_events` | No |

Matches PG-016's own finding exactly — independent confirmation, not a
copy.

## 6. Role/Branch Verification

**BLOCKED for live execution** — see Section 11 of PG-016's audit for
the full static role matrix, unchanged since (this task made no code
changes). No new information to add beyond what was already
established: every branch check in every operational function reads
the job's own `branch_id` server-side, and `authorizeOperationalAction`/
`authorizeBranchScopedRole` remain the only two authority helpers in
use.

## 7. Eight-Stage Lifecycle Verification

**BLOCKED — cannot run a single transition without a database.** The
full transition matrix (function, actor, precondition, audit,
notification, concurrency-safety) is unchanged from PG-016's Section 4
and PG-017's remediation — every one of the 9 previously non-atomic
functions now uses PG-015's atomic pattern (verified again by direct
re-reading of all 9 files' current `UPDATE` statements in this task,
not assumed from the PG-017 commit message).

## 8. Invalid Transition Tests

**BLOCKED.** No live system exists to attempt a wrong-role, cross-branch,
stage-skip, repeated-transition, or unauthorized-client-write attempt
against. Static reasoning about *why* each should fail is unchanged
from PG-016/017 and was not re-litigated here without new evidence to
add.

## 9. Payment Verification

**BLOCKED.** The `pending → matched → Accountant confirmation →
PAYMENT_CONFIRMED` flow, the fresh PIN challenge, and the
`DISPATCHED + unpaid balance → RELEASED must fail` / `DISPATCHED +
paid balance → RELEASED succeeds` rules were all re-read directly in
this task (`confirm-payment`, `release-job`) and are internally
consistent with their own stated logic — but none was executed. No
test payment, test PIN, or test job was created, because none could
be, without a database to hold them.

## 10. Quote Verification

**BLOCKED.** The `submit → accept/decline → quote issued → job
created` sequence in `decide-quote-request` was re-read directly,
including PG-017's new atomic-claim-first restructuring — logically
sound on paper, unexecuted in practice. **No test pricing was added**
— `pricing_rates`/`commercial_settings` remain empty (re-confirmed:
zero `INSERT` into either table in any migration or seed file), so
even if a database existed, quote issuance would currently fail
honestly with "pricing not configured" rather than fabricate a number,
exactly as designed.

## 11. Design/DXF Verification

**BLOCKED.** `job-drafts`' zero-client-policy posture,
`staff_get_draft_dxf_path()`'s Production-role release gate, and the
CAD release trigger were re-read directly and are unchanged since
PG-010/016. No signed URL was ever requested, because no Storage
bucket exists anywhere to request one from.

## 12. Document Verification

**BLOCKED.** `generateDocument()`'s `event_key`-based idempotency and
its explicit `23505` race handling were re-read directly in this task,
independent of PG-016's prior confirmation, and remain internally
sound. **No document was ever generated** — no job, no payment, no
approval event exists anywhere for it to trigger on.

## 13. Notification Verification

**BLOCKED.** All 9 `notify()` call sites (5 from PG-013, 3 from
PG-015, plus `payment.confirm`'s sibling notification unaffected by
PG-017) were re-confirmed individually wrapped in `try/catch` that
sits after the real operation commits. No notification was ever sent —
there is no recipient, no device, and no Supabase project to send one
through.

## 14. Concurrency Verification

**BLOCKED — and this is the single most significant gap**, since this
task's own brief calls it "a critical PG-017 verification." **Nothing
about PG-017's atomic compare-and-swap fix has been proven under an
actual simultaneous request.** Every claim about it (in PG-017's own
report and in this document) is a claim about what the code *should*
do given how Postgres `UPDATE ... WHERE` row-locking works — a
well-founded claim, but not an observation. Firing two genuinely
concurrent HTTP requests requires a running Deno function behind a
real HTTP endpoint, which requires Supabase (or at minimum a local
Deno + Postgres setup), neither of which exists here.

## 15. Audit Trail Verification

**BLOCKED.** The five audit action strings added by PG-017
(`payment.confirm`, `job.start_design`, `draft.release`,
`job.approve_design`, `job.request_design_change`) were re-confirmed
present in their respective functions' code by direct inspection. No
row was ever inserted — there is no table to insert into.

## 16. Storage Security Verification

**BLOCKED.** The four-bucket separation (`pglc-public`,
`pglc-production`, `job-drafts`, `job-documents`) and the zero-policy
posture of the two job-scoped buckets were re-confirmed by reading the
migration files directly. No bucket exists in any real Storage
service to test against.

## 17. Edge Function Verification

**BLOCKED.** All 22 Edge Functions were re-confirmed to structurally
balance (braces/parens) and to use the service-role pattern
consistently. **None has ever executed** — `deno check` (CI's own
static type-check, per `.github/workflows/lint.yml`) is the closest
thing to a runtime check any of this code has received, and even that
requires the Deno toolchain, unavailable in this sandbox to run
manually and not something this task can confirm actually passed in
CI (no CI run access from here either).

## 18. Mobile/Web Verification

**BLOCKED, explicitly, per this task's own instruction not to claim
this was performed.** No Flutter SDK, no Android/iOS toolchain, no
Node.js/Next.js dev server, and no network were available to even
attempt connecting either client to anything. The Flutter and
Next.js source trees were not re-read for new issues in this task
(no code change occurred here that would affect them) beyond
confirming, by directory listing, that they still exist in the state
PG-001–015 left them.

## 19. Failed Tests

**No test in the traditional pass/fail sense was executed at all** —
every test in Steps 4–17 is **BLOCKED**, not failed. A BLOCKED result
means the environment prevented execution, not that the code was run
and found wanting. This distinction matters and is kept precise
throughout this document, per the task's own formatting requirement.

| Test area | Result |
|---|---|
| Migration application | BLOCKED |
| Authentication (customer OTP) | BLOCKED |
| Authentication (staff invite/PIN) | BLOCKED |
| RLS (pgTAP suite, 17 files) | BLOCKED |
| Role/branch live checks | BLOCKED |
| Eight-stage lifecycle (all 8 transitions) | BLOCKED |
| Invalid transition attempts | BLOCKED |
| Payment flow + balance gate | BLOCKED |
| Quote issuance | BLOCKED |
| Design/DXF access control | BLOCKED |
| Document generation + idempotency | BLOCKED |
| Notifications (9 call sites) | BLOCKED |
| Concurrency (PG-017's core claim) | BLOCKED |
| Audit trail (5 new + 5 existing actions) | BLOCKED |
| Storage security | BLOCKED |
| Edge Function execution | BLOCKED |
| Mobile connection | BLOCKED |
| Web connection | BLOCKED |

## 20. Critical Findings

1. **No live verification of this application has ever occurred, at
   any point across 18 tasks.** This is not new to PG-018, but PG-018
   was specifically tasked with closing this gap and could not, for
   reasons entirely outside the application's own code quality (a
   sandboxed environment with no network egress). This remains the
   single largest risk to production readiness, larger than any
   individual code finding from PG-016.
2. **PG-017's concurrency fix — the most safety-critical change in the
   project — remains completely unproven under real concurrent load.**
   The reasoning is sound; the observation does not exist.

## 21. High-Priority Findings

1. Payment confirmation's audit trail (PG-017) has never been observed
   to actually produce a row with correct `actor_user_id`/`entity_id`
   values under real Supabase Auth-issued JWTs — only under the
   assumption that `auth.uid()`/`userData.user.id` behave as documented.
2. The fresh-PIN-challenge mechanism (`confirm-payment`) has never been
   exercised against Supabase's real `signInWithPassword` behavior —
   whether it behaves exactly as this code assumes (fails cleanly on a
   wrong PIN, doesn't leak timing information, doesn't get rate-limited
   in a way that blocks legitimate rapid confirmations) is unknown.

## 22. Medium/Low Findings

1. `supabase/config.toml` was authored without ever running `supabase
   init` — it may not exactly match what a real `supabase init` would
   generate for this Supabase CLI version, since no CLI has ever been
   available to compare against.
2. CI (`lint.yml`/`build.yml`) has never actually run in this
   environment either — their correctness is inferred from reading
   YAML, not from a green checkmark.

## 23. Recommended Remediation Tasks

1. **A future task, run from an environment with genuine network
   access**, should perform literally everything in Steps 2–18 of this
   task's brief — this document's structure is ready to be filled in
   with real PASS/FAIL results the moment such an environment exists.
   This is not a new task to design; it's this exact task, re-run
   somewhere capable of executing it.
2. Once live, prioritize Step 13 (concurrency) and Step 8 (payment/
   balance gate) first, given Section 20's two critical findings.

## 24. Production Readiness Assessment

### CONDITIONAL GO

Development may continue. Nothing discovered in this task contradicts
PG-016's static assessment that the codebase is internally consistent
and free of the security-boundary weaknesses that audit specifically
checked for. **The condition, unresolved by this task through no fault
within it**: genuine Supabase staging access must be obtained and
Steps 2–18 actually executed — not re-attempted statically again —
before this system is taken anywhere near production, and ideally
before much further feature work compounds on top of entirely
unexecuted code.

---

## Git status

```
$ git status
On branch main
nothing to commit, working tree clean
```

Confirmed before writing this report and re-confirmed after: **zero
application files were changed.** This document is the only file this
task adds.

## Security of the (non-existent) staging environment

No staging environment was created, so none of Step 20's checks apply
in the affirmative — there are no secrets to secure, no service-role
key to accidentally commit, no staging/production confusion possible,
because nothing was stood up. The existing `.env.example` (placeholders
only, verified again in this task) and `.gitignore` (`.env`/`.env.*`
excluded, `.env.example` explicitly allowed) remain the correct
pattern for whenever staging *is* established.

**No secret, credential, password, or private token appears anywhere
in this report, this repository, or was generated during this task.**

---

**PG-018 COMPLETE — LIVE VERIFICATION BLOCKED**

**NO UNAUTHORIZED APPLICATION CHANGES MADE**

**PG-019 NOT STARTED**
