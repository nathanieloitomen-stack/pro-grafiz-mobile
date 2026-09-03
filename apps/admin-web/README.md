# Pro_Grafiz Admin Web

Next.js + TypeScript staff administration surface (branch/central admin
functions not covered by the mobile staff surface — see Master Spec
Section 6 for V1 scope split).

## Status

PG-001 (Foundation) and PG-002 (Design System) complete: design tokens
(`src/styles/tokens.css`), base typography (`src/styles/globals.css`),
and a small set of generic components (`src/components/ui/` — Button,
Card, Badge, Pill) matching the approved design's colour, type, spacing,
radius, shadow, and motion tokens. Still one placeholder route, no auth,
no data fetching, no real admin screens.

`package.json` dependency versions were declared without access to a
live npm registry — run `npm install` then check for updates before
relying on exact versions.

## Fonts

Wired via `next/font/google` in `src/app/layout.tsx` (Instrument Serif +
Karla), which self-hosts the font files at build time — no runtime calls
to Google Fonts once built. This requires network access at build time
to fetch the fonts once; that wasn't available while authoring this
scaffold, so it's written correctly but unverified. Run `npm run build`
to confirm.

## Setup

```bash
npm install
npm run dev
```

## Structure

```
src/
├── app/
│   ├── layout.tsx      # fonts + global styles
│   └── page.tsx        # placeholder route exercising the design system
├── styles/
│   ├── tokens.css       # design tokens as CSS custom properties
│   └── globals.css      # base typography/reset built on tokens
└── components/
    └── ui/              # generic components: Button, Card, Badge, Pill
```

`components/ui/` contains **no business logic and no screen content** —
generic token/component layer only, matching PG-002 scope. Real admin
screens (Intake, Payments, Queue, Desk, Admin) are built in later PG
tasks against these components.
