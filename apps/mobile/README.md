# Pro_Grafiz Mobile

Flutter app carrying both the customer surface and the staff surface
(role-gated), per `PRO_GRAFIZ_MASTER_SPEC.md`.

## Status

PG-001 (Foundation) and PG-002 (Design System) complete. `lib/main.dart`
wires the real theme and a temporary placeholder screen that exercises a
few base components — it is not a real screen and will be replaced when
feature work starts. No navigation, no state management wiring, no
Supabase/Drift data layer, no business logic yet.

## Setup

```bash
flutter pub get
flutter run
```

Dependency versions in `pubspec.yaml` were declared without access to a
live pub.dev registry — run `flutter pub outdated` before first install
and update as needed.

## Fonts

The approved design uses **Instrument Serif** (headings, numerals,
prices, pull quotes) and **Karla** (everything else), both from Google
Fonts. Actual font files are **not bundled** in this scaffold — PG-002
was built without network access to fetch them.

`lib/shared/design_system/tokens/typography.dart` references the family
names `InstrumentSerif` and `Karla`; until real font files are added,
Flutter falls back to the platform default font (visually wrong, not a
build break). Before shipping:

1. Download Instrument Serif (400, regular + italic) and Karla (300–800)
   from Google Fonts.
2. Add the files under `assets/fonts/`.
3. Register them in `pubspec.yaml` under `flutter: fonts:` with family
   names `InstrumentSerif` and `Karla` matching the token file.

## Structure

```
lib/
├── main.dart
├── shared/
│   └── design_system/
│       ├── design_system.dart   # single import point
│       ├── theme.dart           # ThemeData built from tokens
│       ├── tokens/              # colors, typography, spacing, radius, shadows, motion
│       └── widgets/             # generic components: buttons, pills/tags, cards, section header, toast, bottom sheet
├── app/            # app-level config, routing (later PG task)
├── features/        # one folder per feature area (catalogue, quote, jobs, staff/*) — not started
└── data/            # Supabase clients, repositories, Drift schema (PG-003+) — not started
```

`shared/design_system/` contains **no business logic and no screen
content** — it's the generic token/component layer only, matching PG-002
scope. Feature screens (Home, Patterns, Job queue, etc.) are built in
later PG tasks against these components, not inside this folder.
