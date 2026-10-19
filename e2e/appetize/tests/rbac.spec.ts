import { test, expect } from '@appetize/playwright'

/**
 * RBAC negative tests through the real mobile UI (CLAUDE.md → TESTING).
 *
 * These are scaffolds, marked test.fixme until three prerequisites exist:
 *   1. Staging seeded with one test staff account per role (seed data only).
 *   2. Their display names + PINs supplied via env / GitHub secrets
 *      (never committed): E2E_<ROLE>_NAME and E2E_<ROLE>_PIN.
 *   3. Stable Semantics identifiers on the staff home actions and PIN field.
 *
 * NOTE: UI tests are a second line of defence. The authoritative proof is
 * still the RLS/Edge Function tests in supabase/tests/database — a hidden
 * button is never a security control.
 */

type Role = 'ACCOUNTANT' | 'DESIGNER' | 'CENTRE_MANAGER' | 'PRODUCTION'

function creds(role: Role) {
  const name = process.env[`E2E_${role}_NAME`]
  const pin = process.env[`E2E_${role}_PIN`]
  return name && pin ? { name, pin } : null
}

async function staffSignIn(session: any, name: string, pin: string) {
  await session.tap({ element: { attributes: { text: 'Sign in' } } })
  await session.tap({ element: { attributes: { text: "I'm on staff" } } })
  await session.tap({ element: { attributes: { text: name } } })
  await session.type(pin)
  // The sheet has a "Sign in" button; after the sheet opens the title text
  // also differs ("Staff sign-in"), so this tap targets the button.
  await session.tap({ element: { attributes: { text: 'Sign in' } } })
  await expect(session).toHaveElement({ attributes: { text: 'Signed in — staff' } }, { timeout: 20_000 })
}

test.afterEach(async ({ session }) => {
  await session.reinstallApp()
})

test.fixme('Accountant cannot advance production', async ({ session }) => {
  const c = creds('ACCOUNTANT')
  test.skip(!c, 'E2E_ACCOUNTANT_NAME / E2E_ACCOUNTANT_PIN not set')
  await staffSignIn(session, c!.name, c!.pin)
  // TODO(PG): open Job Queue, select a seeded IN_PRODUCTION job, assert the
  // advance-stage action is absent AND that forcing it returns a server error.
})

test.fixme('Designer cannot confirm payments', async ({ session }) => {
  const c = creds('DESIGNER')
  test.skip(!c, 'E2E_DESIGNER_NAME / E2E_DESIGNER_PIN not set')
  await staffSignIn(session, c!.name, c!.pin)
  // TODO(PG): open Payments, assert no "Confirm" action on a seeded pending payment.
})

test.fixme('Centre Manager sees only own-centre jobs', async ({ session }) => {
  const c = creds('CENTRE_MANAGER')
  test.skip(!c, 'E2E_CENTRE_MANAGER_NAME / E2E_CENTRE_MANAGER_PIN not set')
  await staffSignIn(session, c!.name, c!.pin)
  // TODO(PG): open Job Queue, assert a seeded other-centre job ref is not listed.
})

test.fixme('Production cannot download private DXF without a release grant', async ({ session }) => {
  const c = creds('PRODUCTION')
  test.skip(!c, 'E2E_PRODUCTION_NAME / E2E_PRODUCTION_PIN not set')
  await staffSignIn(session, c!.name, c!.pin)
  // TODO(PG): open a seeded job without a dxf_release_grant, assert download is denied.
})
