# Pro_Grafiz Admin Web

Next.js + TypeScript staff administration surface (branch/central admin
functions not covered by the mobile staff surface — see Master Spec
Section 6 for V1 scope split).

## Status

PG-001, PG-002, and PG-004 (Authentication) complete. `src/app/sign-in`
is a minimal staff sign-in page (no approved design exists for admin-web
specifically — see `docs/authentication.md`), reusing the same
PIN-as-password backend as mobile. `package.json` dependency versions
were declared without access to a live npm registry — run `npm install`
then check for updates before relying on exact versions.

## Environment

Needs `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` (see
root `.env.example`) — the `NEXT_PUBLIC_` prefix is required for Next.js
to expose a value to browser code; these are the same URL/anon key used
server-side, just re-exposed under the name the browser client reads.

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
│   ├── page.tsx        # placeholder route exercising the design system
│   └── sign-in/         # minimal staff sign-in (PG-004, no approved design)
├── lib/
│   └── supabase/
│       └── client.ts    # browser Supabase client
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
