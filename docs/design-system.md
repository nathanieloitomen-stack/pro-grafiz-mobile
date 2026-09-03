# Design System

**Status: PG-002 complete.** Tokens and a small library of generic,
content-free components exist in both apps. No feature screens use them
yet — that starts in later PG tasks.

## Source of truth

The approved design handoff README ("Design tokens" section) is
authoritative for every value below. If this document, the Flutter
tokens, or the CSS tokens ever disagree with each other, treat the
handoff README as correct and fix whichever file drifted — don't split
the difference or invent a new value.

## Where the tokens live

| | Flutter (mobile) | Next.js (admin-web) |
|---|---|---|
| Colour | `apps/mobile/lib/shared/design_system/tokens/colors.dart` | `apps/admin-web/src/styles/tokens.css` |
| Typography | `.../tokens/typography.dart` | `tokens.css` + fonts via `next/font/google` in `layout.tsx` |
| Spacing | `.../tokens/spacing.dart` | `tokens.css` |
| Radius | `.../tokens/radius.dart` | `tokens.css` |
| Shadows | `.../tokens/shadows.dart` | `tokens.css` |
| Motion | `.../tokens/motion.dart` | `tokens.css` |
| Theme assembly | `.../design_system/theme.dart` | `src/styles/globals.css` |
| Base components | `.../design_system/widgets/` | `src/components/ui/` |

## Colour

| Token | Hex | Use |
|---|---|---|
| Ink | `#1E1613` | Primary text, dark cards, active nav, staff headers |
| Ink deep | `#141010` | Full-bleed dark panels |
| Paper | `#FBF4EA` | App background, text on dark |
| Paper warm | `#F6EDE1` | Selected rows, inset notes, secondary cards |
| Clay | `#F2E4D2` | Accent cards, testimonial, CTA blocks |
| Clay deep | `#EDE2D4` | Pattern tile backgrounds, avatar fills, chips |
| Ember | `#C33B22` | Primary action, links, active state, counts |
| Ember bright | `#E8452B` | Live pulse dot, submit on dark |
| Ember dark | `#9E2C16` | Link hover |
| Amber | `#F0A03C` | Staff dot, camera guides, gradient end, About accent |
| Text mid / soft / faint / warm / dark | see tokens | Body / labels / timestamps / clay copy / manual copy |
| Success bg/fg | `#E4EFE7` / `#2F6B57` | Passed checks, MATCHED, CONFIRMED |
| Warning bg/fg | `#FAEFD8` / `#8A6314` | Held jobs, check warnings |
| Danger bg/fg | `#F6E3DE` / `#A33B22` | Over-SLA, NO MATCH, failed checks, cancelled |
| Auto bg/fg | `#F3EFF7` / `#5B4A7A` | Auto-draft tag and banner |
| Hairline | `rgba(30,22,19,.07–.16)` | Borders, dividers, inert fills |

Material fills: mild steel `#4A4038`, stainless `#8B8F93`, aluminium
`#A9AEB2`, corten `#8C4A2B`, black `#1E1613`. Material preview
backgrounds: steel `#EDE2D4`, stainless `#E6E7E4`, aluminium `#E9EBEC`,
corten `#F0DCCB`.

## Typography

Two families: **Instrument Serif** (headings, numerals, prices, pull
quotes) and **Karla** (everything else). Neither is bundled yet — see
"Fonts" in `apps/mobile/README.md` and `apps/admin-web/README.md` for
what's needed before shipping.

Scale: 38px hero, 30px screen title, 25–27px card title, 23px section
head, 21px quote, 19px numeric, 15px input, 14px button, 13.5px body,
12.5px meta, 11.5px caption, 11px label, 10.5px tag (spec-called-out
exception to the 11px floor, tags only).

## Spacing, radius, shadow, motion

See the token files directly — they're short, commented, and this
document would just repeat them out of date. The one constraint worth
restating here because it's a design constraint, not an implementation
detail: **exactly three shadows exist in the approved product.** Adding
a fourth anywhere is a design decision, not an engineering one — check
with the product owner first.

## What's deliberately not here

No screens, no navigation, no business logic, no data fetching. The
components in `widgets/` (Flutter) and `components/ui/` (Next.js) take
generic props (`label`, `selected`, `tone`, `children`) — they know
nothing about jobs, patterns, payments, or roles. Feature screens compose
these starting in later PG tasks.

## Visual verification

A static, dependency-free HTML preview of every token and base component
is at `docs/design-system-preview.html` — open it directly in a browser
to sanity-check fidelity against the approved design without needing
`npm install` or a Flutter SDK.
