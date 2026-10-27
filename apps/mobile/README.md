# Pro_Grafiz Mobile

Flutter app carrying both the customer surface and the staff surface
(role-gated), per `PRO_GRAFIZ_MASTER_SPEC.md`.

## Status

PG-001 (Foundation), PG-002 (Design System), and PG-004 (Authentication)
complete. Staff PIN sign-in (`features/auth/presentation/staff_sign_in_sheet.dart`,
the approved design's screen #11) and customer phone-OTP sign-in are
wired to Supabase Auth and the PG-004 Edge Functions — see
`docs/authentication.md` for the design decisions behind both. Still no
navigation framework, no catalogue/job/payment screens, no offline sync.

## Environment

The app needs `SUPABASE_URL` and `SUPABASE_ANON_KEY` at build/run time,
via `--dart-define` (see `lib/app/env.dart`):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xyz.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

Without these, the app still runs but shows a placeholder screen instead
of the sign-in flow — it won't crash on a bare `flutter run`.

## Setup

```bash
flutter pub get
flutter run
```

Dependency versions in `pubspec.yaml` were declared without access to a
live pub.dev registry — run `flutter pub outdated` before first install
and update as needed.

## Fonts and brand assets

As of PG-024 the approved fonts are bundled under `assets/fonts/` and
registered in `pubspec.yaml`: **Instrument Serif** (regular + italic) and
**Karla** (300-800, static instances cut from the Google Fonts variable
font). Both are SIL Open Font License; the licence texts sit next to the
font files.

The logo (`assets/brand/logo-on-light.png`, `logo-on-dark.png`, 600x140,
from the design handoff) appears in the customer Home header and on the
customer sign-in screen. The Android launcher icon is a temporary crop of
the logo mark; replace it with an export from the original vector logo
before store release.

## Structure

```
lib/
├── main.dart
├── app/
│   └── env.dart          # --dart-define environment config
├── features/
│   └── auth/
│       ├── data/          # AuthRepository, StaffIdentity — wraps Supabase Auth + PG-004 Edge Functions
│       └── presentation/  # staff sign-in sheet (approved #11), set-PIN screen, customer phone/OTP screens, AuthGate
├── shared/
│   └── design_system/
│       ├── design_system.dart   # single import point
│       ├── theme.dart           # ThemeData built from tokens
│       ├── tokens/              # colors, typography, spacing, radius, shadows, motion
│       └── widgets/             # generic components: buttons, pills/tags, cards, section header, toast, bottom sheet
└── data/            # Drift schema (later PG task) — not started
```

`shared/design_system/` still contains no business logic. `features/auth/`
is the first feature folder — catalogue, jobs, queue, etc. follow the
same `data/` + `presentation/` split in later PG tasks.
