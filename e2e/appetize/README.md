# Pro_Grafiz — Appetize E2E tests (Android)

Playwright tests that drive the real Pro_Grafiz Flutter APK on Appetize
cloud devices. Full rationale, gates and open items: `docs/appetize-testing.md`.

## First-time setup (Windows, PowerShell)

```powershell
cd "$env:USERPROFILE\ProGrafiz Designs mobile-app_\pro-grafiz\e2e\appetize"
npm install -D @appetize/playwright @playwright/test   # pins versions + creates package-lock.json
npx playwright install chromium
```

Commit the generated `package.json` changes and `package-lock.json`
(CI uses `npm ci`, which needs the lock file).

## Build and upload the APK (manual, first time)

```powershell
cd "$env:USERPROFILE\ProGrafiz Designs mobile-app_\pro-grafiz\apps\mobile"
flutter build apk --release `
  --dart-define=SUPABASE_URL=<STAGING_URL> `
  --dart-define=SUPABASE_ANON_KEY=<STAGING_ANON_KEY>
```

Upload `build\app\outputs\flutter-apk\app-release.apk` at
https://appetize.io/upload, and keep the app **private**. Copy its **buildId**.

## Run

```powershell
cd ..\..\e2e\appetize
$env:BUILD_ID = "<your buildId>"
npm run test:headed   # watch the device
npm run test:smoke    # headless, smoke only
npm test              # everything (RBAC tests are fixme until seeded)
```

Never run against production. Staging + seed data only.
