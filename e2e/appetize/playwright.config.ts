import { defineConfig } from '@playwright/test'
import type { AppetizeTestOptions } from '@appetize/playwright'

/**
 * Appetize session configuration for the Pro_Grafiz Android build.
 *
 * BUILD_ID is the Appetize buildId (formerly "publicKey") of the uploaded
 * Pro_Grafiz APK. It is NOT a secret in the cryptographic sense, but it is
 * kept out of git (env var / GitHub secret) so the app link is not public.
 *
 * Never point this suite at production. Staging + seed data only
 * (CLAUDE.md → ENVIRONMENTS).
 */
const buildId = process.env.BUILD_ID

if (!buildId) {
  throw new Error(
    'BUILD_ID is not set. Export the Appetize buildId of the Pro_Grafiz APK ' +
      '(see e2e/appetize/README.md) before running the suite.',
  )
}

export default defineConfig<AppetizeTestOptions>({
  testDir: './tests',
  outputDir: 'test-results/',
  timeout: 120 * 1000,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? [['line'], ['html', { open: 'never' }]] : 'line',

  // workers == concurrent Appetize device sessions. Keep at 1 until the
  // Appetize plan's concurrency limit is confirmed.
  workers: 1,
  fullyParallel: false,

  use: {
    trace: 'retain-on-failure',
    baseURL: 'https://appetize.io',
    config: {
      buildId,
      device: process.env.APPETIZE_DEVICE ?? 'pixel7',
      osVersion: process.env.APPETIZE_OS_VERSION ?? '13',
    },
  },

  projects: [
    // Mid-range reference device (default).
    { name: 'android-pixel7' },
    // Add a lower-end / older Android profile once the smoke suite is green,
    // to reflect typical shop-floor and customer phones in Nigeria, e.g.:
    // { name: 'android-low-end', use: { config: { buildId, device: 'pixel4', osVersion: '11' } } },
  ],
})
