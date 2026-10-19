import { test, expect } from '@appetize/playwright'

/**
 * PG Appetize smoke suite — signed-out entry flows only.
 *
 * Needs NO credentials: it proves the APK installs, boots with a valid
 * staging configuration, and that both sign-in entry points (customer
 * phone-OTP and staff PIN) are reachable. Selectors use visible text from
 * features/auth/presentation/*.dart; switch to Semantics identifiers once
 * they are added (see docs/appetize-testing.md → "Stable selectors").
 */

const BOOT_TIMEOUT = 45_000

test.afterEach(async ({ session }) => {
  // Fresh install per test: no session/token bleed between tests.
  await session.reinstallApp()
})

test('build is configured for a backend (not the missing-env placeholder)', async ({ session }) => {
  // main.dart shows "MISSING CONFIGURATION" (PGLabel upper-cases) when the APK was built without
  // --dart-define SUPABASE_URL / SUPABASE_ANON_KEY. Catches a bad CI build.
  await expect(session).toHaveElement({ attributes: { text: 'Sign in' } }, { timeout: BOOT_TIMEOUT })
  await expect(session).not.toHaveElement({ attributes: { text: 'MISSING CONFIGURATION' } }, { timeout: 2_000 })
})

test('signed-out launch lands on the browsable catalogue with a Sign in action', async ({ session }) => {
  await expect(session).toHaveElement({ attributes: { text: 'Sign in' } }, { timeout: BOOT_TIMEOUT })
})

test('Sign in opens the customer / staff choice sheet', async ({ session }) => {
  await session.tap({ element: { attributes: { text: 'Sign in' } } })
  await expect(session).toHaveElement({ attributes: { text: "I'm a customer" } }, { timeout: 10_000 })
  await expect(session).toHaveElement({ attributes: { text: "I'm on staff" } })
})

test('customer path reaches phone-number entry (no OTP sent)', async ({ session }) => {
  await session.tap({ element: { attributes: { text: 'Sign in' } } })
  await session.tap({ element: { attributes: { text: "I'm a customer" } } })
  await expect(session).toHaveElement({ attributes: { text: 'Send code' } }, { timeout: 10_000 })
  // Deliberately do NOT tap "Send code": that would send a real SMS OTP.
})

test('staff path opens the staff sign-in sheet', async ({ session }) => {
  await session.tap({ element: { attributes: { text: 'Sign in' } } })
  await session.tap({ element: { attributes: { text: "I'm on staff" } } })
  await expect(session).toHaveElement({ attributes: { text: 'Staff sign-in' } }, { timeout: 15_000 })
})
