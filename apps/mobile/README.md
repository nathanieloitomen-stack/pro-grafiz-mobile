# Pro_Grafiz Mobile

Flutter app carrying both the customer surface and the staff surface
(role-gated), per `PRO_GRAFIZ_MASTER_SPEC.md`.

## Status

PG-001 scaffolding only. `lib/main.dart` is a placeholder with no
screens, no design tokens, no navigation, no state management wiring.
Design system work starts at PG-002.

## Setup

```bash
flutter pub get
flutter run
```

Dependency versions in `pubspec.yaml` were declared without access to a
live pub.dev registry — run `flutter pub outdated` before first install
and update as needed.

## Structure (target, populated incrementally)

```
lib/
├── main.dart
├── app/            # app-level config, theming, routing (PG-002+)
├── features/        # one folder per feature area (catalogue, quote, jobs, staff/*)
├── data/            # Supabase clients, repositories, Drift schema (PG-003+)
└── shared/          # design-system widgets, tokens (PG-002)
```
