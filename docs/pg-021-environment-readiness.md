# Environment Readiness (PG-021)

**Status: Environment assessment only. Nothing installed, nothing
modified.**

## 1. Execution environment

| Item | Result |
|---|---|
| OS | Ubuntu 24.04.4 LTS (Noble Numbat), kernel `6.18.44-fc-v24` |
| Environment type | **RESTRICTED** — the kernel build string (`fc-v24`, built by `builder@sandboxing`) indicates a Firecracker microVM sandbox, not Nathaniel's local machine. Confirmed independently by the network result below, not by the kernel string alone. |
| Working directory | `/` (session root); the project repository lives at `/home/claude/work/pro-grafiz` |
| Hostname / user | `vm` / `root` |
| Git version | 2.43.0 |
| Git remote | **Not configured** — `git remote -v` returns empty |
| Current branch | `master` |
| Working tree | Clean (`git status --short` returns empty) |

**This is a Claude Code sandboxed execution session, not Nathaniel's
own computer.** Any tool installed here would need to be reinstalled
in whatever environment actually runs the eventual staging setup
(PG-020's task) — installing things here would not carry forward to a
real development machine.

## 2. Required tools — installed?

| Tool | Status | Version |
|---|---|---|
| Supabase CLI | NOT INSTALLED | — |
| Docker | NOT INSTALLED | — |
| PostgreSQL client (`psql`) | NOT INSTALLED | — |
| Git | INSTALLED | 2.43.0 |
| Node.js | INSTALLED | v22.22.2 |
| npm | INSTALLED | 10.9.7 |
| Flutter SDK | NOT INSTALLED | — |
| Dart SDK | NOT INSTALLED | — |

## 3. Network test

```
$ curl -D - -o /dev/null https://www.google.com
HTTP/2 403
x-deny-reason: host_not_allowed

$ curl -D - -o /dev/null https://supabase.com
HTTP/2 403
x-deny-reason: host_not_allowed
```

**Blocked**, identically for a general HTTPS endpoint and Supabase's
own — this confirms (again, independently of PG-020's finding) that
the block is a total sandbox-level egress restriction, not anything
specific to Supabase. No credentials were used or needed to observe
this; both requests were anonymous.

## 4. Supabase CLI capability

**Not installed — no diagnostic possible.** No version check, no
reachability check, and no login/link attempt was made (none would
have been attempted even if installed, per this task's explicit
restriction).

## 5. Docker capability

**Not installed — no diagnostic possible.**

## 6. PostgreSQL client capability

**Not installed — no diagnostic possible.**

## 7. Repository check

```
$ git status
On branch master
nothing to commit, working tree clean

$ git remote -v
(no output — no remote configured)
```

Confirmed: clean tree, `master` branch, no remote. This repository has
never been pushed anywhere from any session in this project — every
delivery so far has been via downloadable zip archives, not `git
push`, consistent with there being no remote to push to.

## 8. Project tooling requirements (as declared by the project itself)

| Component | Declared requirement | Source |
|---|---|---|
| Next.js (admin-web) | `next@14.2.0`, `react@18.3.0`, no explicit `engines` field | `apps/admin-web/package.json` |
| CI Node.js | `'20'` | `.github/workflows/{lint,build}.yml` |
| Flutter/Dart (mobile) | Dart SDK `>=3.3.0 <4.0.0`; **no specific Flutter version is pinned anywhere** (no `.fvmrc` or equivalent exists) | `apps/mobile/pubspec.yaml` |
| Supabase CLI | No version pinned anywhere in the project | — |

**One discrepancy worth flagging, not a blocker**: this sandbox's
installed Node.js is v22.22.2, but CI specifies Node 20. Not a problem
for this task (nothing here runs the app), but worth matching Node 20
on whatever machine actually does staging setup, for consistency with
CI.

## 9. Readiness matrix

| Requirement | Required? | Installed? | Version | Status | Action |
|---|---|---|---|---|---|
| Internet access | A | No | — | BLOCKED (this sandbox only) | Use a different machine/environment for staging setup |
| Supabase CLI | A | No | — | Missing | Install on the machine that will run staging setup |
| Docker | B | No | — | Missing | Install only if you choose local Supabase dev (`supabase start`) over a hosted staging project; not required for a hosted project |
| PostgreSQL client (`psql`) | B | No | — | Missing | Useful for manual inspection/debugging; not strictly required — the Supabase CLI and dashboard cover migration application and table browsing |
| Git | A | Yes | 2.43.0 | Ready | None |
| Node.js | A (for admin-web) | Yes | v22.22.2 | Ready, version differs from CI's `20` | Match Node 20 on the real dev machine for CI consistency |
| npm | A (for admin-web) | Yes | 10.9.7 | Ready | None |
| Flutter SDK | A (for mobile) | No | — | Missing | Install before any mobile build/run work |
| Dart SDK | A (for mobile) | No | — | Missing | Bundled with Flutter — installs automatically alongside it |

**A** = Required for Supabase staging setup (PG-020's task) or for
running the existing app. **B** = Recommended but not strictly
required. **C** = Not required yet — nothing in this project currently
needs anything beyond the above (no additional tooling was identified
as "not required yet" — everything checked here is either needed now
or genuinely optional).

## 10. Recommended installation order

This assumes staging setup will happen on a real machine with actual
internet access — not this sandbox, which cannot run any of this
regardless of what's installed here.

1. **Supabase CLI** — yes, install this first. It's the one tool with
   no substitute for applying migrations and deploying Edge Functions
   (PG-019's setup guide, Steps 4/8, depends on it directly). Use the
   current stable release from Supabase's own install instructions
   (`npm install -g supabase` or the platform-specific package) —
   this project doesn't pin a specific CLI version anywhere, so
   "current stable" is the right default rather than guessing an exact
   number.
2. **Docker Desktop — only if you want local Supabase development**
   (`supabase start`, which runs Postgres/Auth/Storage in containers on
   your machine) **as well as** a hosted staging project. If you're
   going straight to a hosted Supabase staging project (as PG-019's
   guide assumes — `supabase link` + `supabase db push` against a
   real hosted project), Docker is **not required** at all. Recommend
   holding off on Docker until you know whether local-first development
   is actually wanted, rather than installing it by default.
3. **PostgreSQL client tools (`psql`)** — recommended, not required.
   Handy for ad-hoc inspection of the staging database beyond what the
   Supabase dashboard's table editor offers, but everything PG-019's
   setup guide describes can be done through the CLI and dashboard
   alone.
4. **Versions**: Supabase CLI — current stable (unpinned by this
   project). Docker — current stable, if installed at all. `psql` —
   match whatever Postgres major version the Supabase CLI/dashboard
   reports for a newly created project (currently Postgres 15 for new
   Supabase projects, but confirm against the actual project once
   created rather than assuming). Node.js — 20, to match CI exactly.
   Flutter — any version bundling Dart `>=3.3.0` (Flutter 3.19 or
   later) — no more specific constraint exists anywhere in this
   project to narrow this further.
5. **Genuinely required before PG-022** (assuming PG-022 continues the
   staging-setup effort): Supabase CLI, and a machine with real
   internet access. That's it — Docker, `psql`, and Flutter/Dart are
   not blockers for getting migrations applied and Edge Functions
   deployed, only for local-container development and mobile app
   testing respectively.
6. **Can wait**: Docker (until local-dev-vs-hosted is decided),
   `psql` (nice-to-have), Flutter/Dart (only needed once mobile-app
   testing against staging specifically is in scope, not for
   migration/Edge-Function setup itself).

## 11. Security

No credential of any kind was requested, entered, displayed, or stored
during this task. No Supabase project, database, or service was
reached (the network test in Section 3 was two anonymous, credential-free
HTTPS requests to public pages). Nothing in this document requires or
references a secret value.

## 12. Stop condition

This task stops here, as instructed. No Supabase staging setup was
attempted. PG-022 was not started.

---

## Git status

```
$ git status
On branch master
nothing to commit, working tree clean
```

Confirmed before and after writing this document: **zero application
files, migrations, RLS policies, or Edge Functions were changed.** This
document is the only file this task adds. Nothing was installed in
this session, and nothing installed here would matter even if it had
been — this sandbox cannot run the staging setup regardless of its
tooling, per Section 3.

---

PG-021 STATUS: PARTIALLY READY

CLAUDE EXECUTION ENVIRONMENT: RESTRICTED

INTERNET ACCESS: BLOCKED

SUPABASE CLI: NOT INSTALLED

DOCKER: NOT INSTALLED

POSTGRESQL CLIENT: NOT INSTALLED

REPOSITORY STATUS: CLEAN

GIT REMOTE: NOT CONFIGURED

TOOLS REQUIRING INSTALLATION: Supabase CLI (required); Flutter SDK + bundled Dart (required for mobile work); Docker (only if local Supabase dev is wanted); PostgreSQL client (recommended, optional)

TOOLS RECOMMENDED BUT NOT YET REQUIRED: Docker Desktop (pending local-vs-hosted decision); `psql` (convenience only)

USER ACTION REQUIRED: Perform PG-020's staging setup from a machine or environment with genuine, unrestricted internet access (not this Claude Code sandbox); on that machine, install the Supabase CLI (current stable) and, if mobile testing is in scope, Flutter (3.19+); decide whether local Supabase development (Docker) is wanted before installing Docker; align that machine's Node.js to v20 to match CI

APPLICATION CODE CHANGED: NO

DATABASE MIGRATIONS CHANGED: NO

PG-022 STATUS: NOT STARTED
