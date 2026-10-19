# Appetize Mobile E2E Testing

**Status:** harness scaffolded; not yet run against a live build.
**Scope:** Android APK of `apps/mobile` on Appetize cloud devices, driven by
Playwright (`@appetize/playwright`). iOS later (needs a macOS build).

## Why Appetize, and what it is not

- It proves the real APK installs, boots and that user-facing flows work on
  real Android device images, from CI, with screenshots and traces.
- It is **not** a security control. RBAC, pricing, payment and DXF rules
  stay proven by RLS + Edge Function tests (`supabase/tests/database`). UI
  tests are a second line of defence (CLAUDE.md → "Security is server-side").

## Layout

| Path | Purpose |
|---|---|
| `e2e/appetize/playwright.config.ts` | Appetize session config. Reads `BUILD_ID` env. |
| `e2e/appetize/tests/smoke.spec.ts` | No-credential smoke: boot, env sanity, sign-in entry points |
| `e2e/appetize/tests/rbac.spec.ts` | RBAC negative-test scaffolds (`test.fixme`) |
| `.github/workflows/appetize-e2e.yml` | Build staging APK, upload to Appetize, run tests (manual trigger) |

## Phased rollout and review gates

| Phase | Deliverable | Gate to pass |
|---|---|---|
| 1 | Harness scaffold (this change) | Reviewed and approved |
| 2 | Appetize account, private app, first manual APK upload | App boots on Appetize and reaches the catalogue with "Sign in" |
| 3 | Local smoke run | `npm run test:smoke` green locally (5/5) |
| 4 | CI wiring: secrets added, workflow run manually | Workflow green and report artifact downloadable |
| 5 | Stable selectors (Semantics identifiers) + staging seed staff | Smoke suite green 3 runs in a row |
| 6 | RBAC suite un-fixme'd, role by role | Each role test green and verified against RLS tests |
| 7 | Enable push trigger on `main` | Agreed session-minute budget |

## GitHub secrets

`APPETIZE_API_TOKEN`, `APPETIZE_BUILD_ID`, `STAGING_SUPABASE_URL`,
`STAGING_SUPABASE_ANON_KEY`, plus optional `E2E_<ROLE>_NAME` / `E2E_<ROLE>_PIN`
for **seed** staff accounts. The anon key is compiled into the APK, which is
why the Appetize app must stay private and must point only at staging.

## Stable selectors

Automation ids added as Flutter `Semantics(identifier: ...)` wrappers
(non-visual; Flutter 3.19+). Design-system buttons take an optional
`testId` that does the same.

| Id | Widget |
|---|---|
| `pg_signin_button` / `pg_signout_button` | Top-right Sign in / Sign out action (`auth_gate.dart`) |
| `pg_signin_customer` | "I'm a customer" in the sign-in choice sheet |
| `pg_signin_staff` | "I'm on staff" in the sign-in choice sheet |
| `pg_phone_field` | Customer phone-number field |
| `pg_send_code_button` | "Send code" (sends a real OTP: never tap in automated tests) |
| `pg_staff_pin_field` | Staff PIN field |
| `pg_staff_pin_submit` / `pg_staff_pin_back` | Staff PIN step buttons |

The smoke tests still match visible text. **Gate before switching them to
ids:** open the build in the Appetize UI inspector and confirm these ids show
up as the element's `resource-id`. Then change selectors to
`{ attributes: { 'resource-id': 'pg_signin_button' } }`.

## Setup issues

| # | Issue | Status |
|---|---|---|
| 1 | `test/widget_test.dart` was the Flutter counter template (`MyApp`) | **Fixed.** Now a smoke test of `ProGrafizApp`'s missing-config placeholder |
| 2 | Android `applicationId` / `namespace` were `com.example.pro_grafiz_mobile` | **Fixed.** Now `com.prografizdesigns.app`; `MainActivity.kt` moved to match |
| 3 | Release builds signed with the debug key | Open. Fine for Appetize, must fix before store release |
| 4 | Project path contains spaces | Open. Can break Gradle/Flutter tooling on Windows |

## Cost control

- `workers: 1` means one concurrent Appetize session.
- The workflow is manual-only and runs the smoke suite by default.
- `reinstallApp()` after each test keeps tests isolated without new sessions.
