# Handoff: Pro_Grafiz Designs Ltd — Mobile App

## Overview

A mobile app for Pro_Grafiz Designs Ltd, a metal fabrication and laser-cutting company operating seven customer centres around Abuja and Lagos. One install carries two surfaces:

- **Customer surface** — browse a 1,000-design laser-cut catalogue, merge patterns into custom blends, scan a paper sketch with the camera, configure and price a panel, pay, approve the design, and track the job through eight lifecycle stages.
- **Staff surface** — behind a per-user PIN sign-in. Quote intake, job queue with departmental permissions, design desk with auto-generated DXF review, accountant payment confirmation, and admin.

The business problem it replaces: jobs currently tracked by WhatsApp message and payment confirmed by screenshot, across seven centres with no shared record.

## About the design files

**The files in this bundle are design references created in HTML.** They are prototypes showing intended look and behaviour — not production code to copy.

The task is to **recreate these designs in the target codebase's environment**, using its established patterns and libraries. If no codebase exists yet, choose the framework (React Native or Flutter are the obvious candidates for a phone app with offline handhelds) and implement there.

Specifically, do not port these implementation details:

- All state is in-memory React component state and resets on reload. Real persistence, sync and offline queueing are the build's job.
- Patterns are drawn as generated SVG masks (`plate()` / `plateMulti()` in the logic class). In production these come from the real PGLC catalogue files. The generator exists only so the prototype has a thousand distinguishable designs.
- The camera viewfinder is a mock. No `getUserMedia`, no image processing.
- PINs are plaintext constants in the source. Obviously not shippable.
- Money maths (`price` in `renderVals()`) is illustrative. Real rates come from the business.

## Fidelity

**High-fidelity.** Final colours, typography, spacing, radii, copy and interaction behaviour. Recreate pixel-accurately using the codebase's own component library where one exists.

The one exception is imagery: there are no photographs anywhere. Pattern tiles are generated geometry and stand in for real catalogue renders. The About screen has no team portraits (deliberately removed at the client's request).

## Design tokens

### Colour

| Token | Hex | Use |
|---|---|---|
| Ink | `#1E1613` | Primary text, dark cards, active nav, staff headers |
| Ink deep | `#141010` | Full-bleed dark panels (About hero, camera overlay) |
| Paper | `#FBF4EA` | App background, text on dark |
| Paper warm | `#F6EDE1` | Selected rows, inset notes, secondary cards |
| Clay | `#F2E4D2` | Accent cards, testimonial, CTA blocks |
| Clay deep | `#EDE2D4` | Pattern tile backgrounds, avatar fills, chips |
| Ember | `#C33B22` | Primary action, links, active state, counts |
| Ember bright | `#E8452B` | Live pulse dot, submit on dark |
| Ember dark | `#9E2C16` | Link hover |
| Amber | `#F0A03C` | Staff dot, camera guides, gradient end, About accent |
| Text mid | `#5C4B3F` | Body copy on paper |
| Text soft | `#8A7566` | Labels, captions, meta |
| Text faint | `#A08F80` | Timestamps, disclaimers |
| Text warm | `#6E5A4C` | Copy on clay |
| Text dark | `#3A2E27` | Body copy in the manual |
| Success bg / fg | `#E4EFE7` / `#2F6B57` | Passed checks, MATCHED, CONFIRMED |
| Warning bg / fg | `#FAEFD8` / `#8A6314` | Held jobs, check warnings |
| Warning dot | `#B07A1C` | On-hold indicator |
| Danger bg / fg | `#F6E3DE` / `#A33B22` | Over-SLA, NO MATCH, failed checks, cancelled |
| Auto bg / fg | `#F3EFF7` / `#5B4A7A` | Auto-draft tag and banner |
| Auto tag bg | `#EDE6F3` | AUTO-DRAFT pill |
| Hairline | `rgba(30,22,19,.07–.16)` | Borders, dividers, inert fills |

Material fills used inside pattern SVGs: mild steel `#4A4038`, stainless `#8B8F93`, aluminium `#A9AEB2`, corten `#8C4A2B`, black `#1E1613`.

Material preview backgrounds: steel `#EDE2D4`, stainless `#E6E7E4`, aluminium `#E9EBEC`, corten `#F0DCCB`.

### Typography

Two families, from Google Fonts:

- **Instrument Serif** (400, regular + italic) — headings, numerals, prices, pull quotes. Always `line-height` 0.9–1.3, `letter-spacing` -0.02em on the largest sizes.
- **Karla** (300–800) — everything else. Body 13.5px/1.55, labels 11px uppercase with 0.16em tracking, buttons 13–14.5px/700.

Scale in the app: 38px hero, 30px screen title, 25–27px card title, 23px section head, 21px quote, 19px numeric, 15px input, 14px button, 13.5px body, 12.5px meta, 11.5px caption, 11px label, 10.5px tag.

Never below 11px. All tap targets ≥ 44px (nav buttons 46px, primary CTAs 50–54px).

### Spacing, radius, shadow

- Screen padding: 18px horizontal, 16–18px top, 130px bottom (clears the floating nav).
- Stack gaps: 20–22px between sections, 10–14px within a group, 6–8px label-to-value.
- Radii: 999px pills and buttons; 28px hero and summary cards; 26px job cards; 24px list groups and inputs-in-cards; 22px inset notes; 20px thumbnails; 18px small notes; 16–14px icon tiles; 32px 32px 0 0 bottom sheets.
- Shadows only three: `0 14px 30px -18px rgba(30,22,19,.85)` on dark hero cards, `0 10px 22px -12px rgba(195,59,34,.9)` on primary CTAs, `0 -20px 50px -20px rgba(30,22,19,.6)` on bottom sheets.
- Press feedback: `transform: scale(.92–.98)` via `style-active`. No hover styling — it is a touch app.

### Motion

Four keyframes, nothing else:

- `pgPulse` 1.8s ease-in-out infinite — live-stage dots (1.2s in the scan step list).
- `pgRise` 0.2–0.3s ease — sheets, overlays, grid items entering.
- `pgToast` 2.6s ease forwards — the toast lifecycle.
- Progress bar width: `.6s cubic-bezier(.4,0,.2,1)`. Zoom: `.25s` same curve. Colour and background changes: `.18–.3s`.

## Data model

### Design (catalogue)

```
id        PGLC0001 … PGLC1000   // 100 per category, sequential by category
name      string                 // family name + variant number
cat        one of ten categories
kind       geometry family        // lattice hex rosette leaf waves chevron star arabesque optical dots
n          density 3–6
use        string                 // "Gates, balustrades"
```

Ten categories, each with its own manufacturing envelope (this is real engineering data, not decoration):

| Category | Materials | Thickness | Min |
|---|---|---|---|
| Geometric Lattice | Mild steel · Stainless 304 | 2–6mm | 2.0 |
| Hexagonal | Mild steel · Aluminium | 1.5–4mm | 1.5 |
| Floral Rosette | Mild steel · Stainless 304 | 2–5mm | 2.0 |
| Botanical Leaf | Mild steel · Corten | 2–5mm | 2.0 |
| Waves & Curves | All four | 1–6mm | 1.0 |
| Chevron | Mild steel · Aluminium · Corten | 1.5–5mm | 1.5 |
| Islamic Star | All four | 2–6mm | 2.0 |
| Arabesque | Mild steel · Stainless 304 | 2.5–6mm | 2.5 |
| 3D Optical | Mild steel · Aluminium | 1.5–4mm | 1.5 |
| Organic Dots | All four | 1–6mm | 1.0 |

### Blend (custom design)

```
ref        PGMX-<last4>-<last4>[-<last4>]   // from contributing PGLC ids
parts      2–3 design ids, ORDER SIGNIFICANT
style      frame | bands | blend
```

`frame`: part 1 is the border, 2 the field, 3 the centre. `bands`: equal horizontal bands separated by a solid rib. `blend`: all cut paths overlaid. Blends add one working day and need seam redrawing.

### Job

```
id           PG-nnnn
customer     string
branch       one of seven
spec         material · thickness · W×H · pattern ref
stage         0–7 (see lifecycle)
owner         inventory | production        // which department may action the current stage
mins          minutes in current stage      // > 120 = over SLA
status        null | { kind: hold|cancel, reason, note }
```

### Staff user

```
name, initials, role, title, branch?, pin
```

Thirteen accounts. Roles: `Super Admin`, `Accountant`, `Centre Manager`, `Designer`, `Production`, `Inventory`.

| Name | Title | Centre |
|---|---|---|
| Nathaniel Oitomen | Super Admin 1 | — |
| Prisca Oitomen | Super Admin 2 | — |
| Freda Ilem | Accountant | — |
| Chioma Obinwanne | Centre Manager | Idu |
| Mary Ubogu | Centre Manager | UOO |
| Ulor Priscilia | Centre Manager | Dei-Dei |
| Joy Musa | Centre Manager | Bakasi |
| Patient Dawal | Centre Manager | Maraba |
| PraiseGod Philemon | Centre Manager | Iyanakpaja |
| Kafayat Adisa | Centre Manager | Owode |
| Kurt Osadiaye | Design Team Leader | — |
| Ibrahim Musa | Production Manager | — |
| Gabriel Olobo | Inventory Manager | — |

PINs in the prototype are four-digit constants. **Replace with hashed credentials.** Real accounts set their own PIN on first sign-in via the Admin invite flow.

### Other entities

- **Quote request** — `QR-nnnn`, customer, branch, spec, source (catalogue / custom blend / sketch), age. Decision: billed or declined, recorded on the request.
- **Payment** — job id, amount, bank reference `PGD-<job4>-<n>`, `matched` boolean, kind (Deposit 60% / Balance 40%).
- **Document** — `PGJO-nnnn` (job order) or `PGAO-nnnn` (approved job order), job id, issue date, authorising party. Idempotent per event.
- **Sketch** — capture, traced outline, required description (≤240 chars), belongs to a request; several per request.
- **Draft** — generated DXF: pattern, material, panel, sheet count, waste %, cut length, cut time, and five check results.
- **Device** — name, assigned user, sync state, queued-action count when offline.

## Permissions

Two orthogonal rules. Both must be enforced server-side; the client only reflects them.

### 1. Role → visible tabs

| Role | Tabs |
|---|---|
| Super Admin | Intake, Payments, Queue, Desk, Admin |
| Centre Manager | Intake, Queue |
| Accountant | Payments |
| Designer | Desk, Queue |
| Production | Queue |
| Inventory | Queue |

A tab a role lacks is not rendered at all. Role cannot be changed from the device.

### 2. Branch scope

- **Centre managers are hard-scoped** to their own branch. Other centres' records must not reach the client — this is a data boundary, not a filter.
- **Every other role is central**, serving all seven centres: Idu, UOO, Dei-Dei, Bakasi, Maraba, Iyanakpaja, Owode. They get a branch chip row (All + seven) that narrows the *view* only, plus a branch label on every card. Selecting a branch never changes permissions.
- Per-branch sheet stock: Idu 34, UOO 19, Dei-Dei 22, Bakasi 12, Maraba 17, Iyanakpaja 9, Owode 15. Group total 128 shows only under "All centres".

### 3. Stage ownership

Within the queue, a job's current stage belongs to `production` or `inventory`. A user whose role does not match sees the card dimmed to 62% with the button reading "Waiting on inventory" / "Waiting on production" and `cursor: not-allowed`. Super Admin actions any stage. Pressing a foreign stage is refused with a message naming the owner.

## Job lifecycle

Eight stages. Customers see the friendly label; staff see the same record as a work item.

| # | Key | Customer label | Advanced by |
|---|---|---|---|
| 1 | `SUBMITTED` | Job submitted | Customer |
| 2 | `PAYMENT_CONFIRMED` | Deposit confirmed | Accountant |
| 3 | `DESIGN_IN_PROGRESS` | Design in progress | Design desk |
| 4 | `DESIGN_SENT_FOR_APPROVAL` | Waiting on your approval | Customer |
| 5 | `IN_PRODUCTION` | Cutting | Production |
| 6 | `READY_FOR_DISPATCH` | Ready for dispatch | Inventory |
| 7 | `DISPATCHED` | On the way | Inventory / driver |
| 8 | `RELEASED` | Collected | Centre manager |

Stage 4 is where jobs stall. The customer's timeline shows completed stages with timestamps, the live stage pulsing, later stages as "Pending"; the final stage shows its timestamp rather than reading as live once reached.

### Hold and cancel

Available on any queue card via `⋯`. **A reason is mandatory** — the confirm button is inert until one is picked from the fixed list.

- Hold reasons: awaiting customer response, material out of stock, machine downtime, payment dispute, specification query.
- Cancel reasons: customer withdrew, duplicate job, cannot be manufactured as specified, payment failed, replaced by a new job.

Effects: SLA clock pauses; the job leaves the queue and over-SLA counters; the card pales to 72% and its button becomes Resume / Reopen; the customer's timeline shows the reason in plain language with the optional note. Both actions log the acting account.

## Validation rules

1. **Thickness floor.** Below the pattern category's minimum the quote builder turns the value ember and shows the engineering reason. Advisory to the customer, blocking on a generated DXF.
2. **Merge cardinality.** 2 minimum, 3 maximum. A fourth selection is refused with a message. Dropping below 2 on the blend screen returns to selection mode holding the remainder.
3. **Payment reference.** Must equal the issued `PGD-…` exactly (case-insensitive, trimmed). Mismatch shows an inline error and never advances the job.
4. **Accountant PIN.** Required on every payment confirmation, not once per session.
5. **NO MATCH payments** cannot be confirmed in the app at all. The only action is escalate to accounts.
6. **Sketch descriptions** are required on every captured sketch before a request will send. Staff capture additionally requires a customer name.
7. **DXF release** requires the current month's code. `dxfDownloadEnabled` off means no download is offered anywhere.
8. **Generated DXF with a failed check cannot be released.** The primary button becomes "Redraw by hand".
9. **Documents are idempotent** — one PGJO per payment confirmation, one PGAO per design approval, never duplicated.

## Screens

Nineteen views. All are inside a 402×874 device frame in the prototype.

### Chrome (every screen)

Header, 58px top padding, 38px back button (nested screens only), logo (customer Home only) or screen title in Instrument Serif 22px, notification bell with unread badge (customer, top-level only), mode badge showing "You" or the signed-in user's initials.

Bottom nav floats over a `linear-gradient(to bottom, transparent, #FBF4EA 26%)` fade: ink pill, 5px padding, 46px items, icon + 11px label, active item filled ember.

Toast: absolutely positioned 110px from the bottom, ink card, 2.6s `pgToast`, self-clearing.

### Customer

**1. Home** — greeting by time of day; 38px serif hero; live job card (ink, masked pattern at 16% opacity, pulsing dot, stage label, gradient progress bar, tap to open); two shortcut tiles (Start a job, Browse patterns); scan-a-sketch card on clay; horizontal snap rail of five suggested designs; six service lines as a hairline-divided list; testimonial on clay; address plus WhatsApp link.

**2. Patterns** — pill search (matches id, name, category); horizontal category chips (All + ten); result count, saved count, Merge toggle; scan prompt; 2-column grid, square tiles, heart overlay top-right; Load 24 more; empty state.

**3. Design detail** — square preview on a material-tinted ground, 4-step zoom slider (tap the preview to cycle), prev/next arrows, four material pills that recolour the plate; title, PGLC id, category, favourite; three badges (SVG ready, DXF status, cut-ready geometry); material / thickness / typical-use table; category blurb; engineering note; Request a quote + gated DXF download.

**4. Camera scan** (full-bleed ink overlay) — viewfinder with amber corner guides, tilted paper mock, "Paper edges found" confirmation, 74px shutter → four-step processing timeline → result: traced outline, per-sketch cards each with a 240-char description box and remove, Add another, three closest catalogue matches with confidence %, customer name field (staff), Retake / Send to design desk.

**5. Blend** — composite preview on material ground; three style pills (Frame / Bands / Blend); generated name and PGMX ref; style explanation; contributing parts with role and remove; lead-time note; Quote this blend + save.

**6. Quote builder** — live preview taking material colour and the true W:H aspect ratio; material 2×2; thickness slider 1–6mm with floor warning; width and height sliders 600–3000mm; three finish pills; ink summary with ₦ estimate, sheet count, lead time, Send to Pro_Grafiz.

**7. Jobs** — job reference tabs; current stage card; documents list (PGJO / PGAO); hold/cancel banner when applicable; payment card (method tabs: bank transfer with reference matching, card, USSD); approval card with preview and Approve / Request a change; eight-stage timeline.

**8. Document viewer** (bottom sheet) — letterhead with logo and number, job reference, customer / centre / specification / amount / payment reference table, status line, authorising party, Send on WhatsApp + Download PDF.

**9. About** — ink hero with logo and amber-accented serif headline; story; two stat cards (36K clients, 642 projects — labels corrected from the website, which had them swapped); four-step process; mission with four ticks; ink vision card; CTA on clay. No team section.

**10. Notifications** (bottom sheet) — unread items on white with an ember dot, read items transparent; four kinds (approval, payment, stage, quote) with distinct icons; Mark all read; approval taps jump to the job.

### Staff

**11. Sign-in** (bottom sheet) — scrollable account list with initials, name, title and centre; then the PIN step with the selected identity, 4-digit masked field, inline error, Back / Sign in.

**12. Intake** — branch chips (unscoped roles); ink summary counting requests and outstanding references; quote request cards with pattern, spec, branch, source, age and Bill-and-open-job / Decline; scan-a-walk-in-sketch card.

**13. Job queue** — signed-in identity card with scope badge and permission line; branch chips; three counters (in queue, over SLA, sheets at branch); job cards with tile, reference, customer, spec, elapsed timer (ember over two hours), branch, stage tag, `⋯` and the stage action; held/cancelled banner when applicable.

**14. Hold / cancel sheet** — segmented hold vs cancel, mandatory reason list with radio marks, optional note, inert-until-valid confirm.

**15. Design desk** — branch chips; ink summary of jobs waiting and revision requests; job cards tagged AUTO-DRAFT / HAND DRAW / REVISION / SHEETS, with the auto-draft banner or the customer's revision note quoted verbatim; primary action + Sheets; DXF drop zone.

**16. Auto-draft review** (full screen) — generated drawing on clay; verdict banner coloured by worst check; five checks with ✓ / ! / ✕ marks and detail lines; horizontal nest strip, one card per sheet; material / waste / cut length / cut time table; Approve and release (or Redraw by hand when blocked), Redraw, Upload my own; signing note.

**17. Payments** — branch chips; ink count of references awaiting confirmation; payment cards with job, customer, branch, kind, amount, reference, MATCHED / NO MATCH / CONFIRMED tag and the single permitted action.

**18. Accountant PIN gate** (bottom sheet) — job reference, explanation that only the accountant may confirm, masked PIN, inline error.

**19. Admin** — WhatsApp line of record (+234 915 249 3122); active DXF code with next code and date, twelve-month schedule grid with the current month filled ember, Rotate early; device list with sync dots and queued-action counts; backup status with Run now; staff accounts with Invite.

## Interactions and behaviour

- **Navigation.** Bottom tabs for top-level; back arrow on detail, blend and quote. Blend back returns to merge selection holding the previous picks. Sign-out clears the user and returns to the customer surface.
- **Zoom.** Four discrete steps; density divisor `[1, 1.5, 2.2, 3]` so it scales monotonically. Tapping the preview cycles.
- **Merge selection.** Numbered ember rings; position matters for Frame. Floating bar counts and enables at two.
- **Live preview.** Quote builder aspect ratio and material colour update on every control change with a 0.3s transition.
- **Timers.** A 30s interval re-renders elapsed times. Over-SLA at 120 minutes flips timer and stage tag to danger colours.
- **Auto-draft.** Redraw dims the drawing to 35% for 1.4s, then re-runs checks with a confirmation toast.
- **Documents.** Generated automatically and idempotently on payment confirmation (either route) and on customer approval.
- **Offline.** Design intent: actions queue locally and replay on reconnect; the Admin device list surfaces the queued count. Not implemented in the prototype.

## Assets

- `assets/logo-on-light.png` — 600×140, transparent, dark wordmark with the ember graphic. Derived from the client's supplied JPEG (cropped to content, background removed, white recoloured to `#1E1613`).
- `assets/logo-on-dark.png` — same geometry, paper-coloured wordmark, for ink backgrounds.
- Icons are inline SVG, 1.5–1.8 stroke weight, `stroke-linecap: round`. No icon font, no icon library.
- No photographs. Pattern tiles are generated SVG. Real catalogue renders should replace them.

## Open items for the client

These are assumptions in the design, not decisions:

1. **Two-hour SLA threshold** — my figure, needs confirming per stage.
2. **"Blends add one working day"** — my estimate.
3. **Pricing** — every rate and multiplier is illustrative.
4. **PIN issuance** — deliberately not printed in the operations manual; decide the process.
5. **Whether production and inventory should stay central.** Confirmed central, but if a centre runs its own floor this needs per-branch scoping.
6. **Auto-draft coverage** — catalogue patterns are fully rule-based; blends need seam validation; sketches must stay manual.

## Build notes

- Currency is Nigerian naira, formatted `en-NG` with thousands separators.
- Dimensions are millimetres throughout. Panel range 600–3000mm, thickness 1–6mm.
- Sheet count derives from area ÷ 2.88m² (illustrative sheet size), minimum 1. Lead time in the prototype is `5 + sheets` working days.
- DXF codes `PGDL2021-01` … `-12`, rotating on the 1st. A code expires with its month.
- Payment split is Deposit 60% / Balance 40%.
- Every state-changing action must be attributed to the signed-in account in an audit log. This is the single most important non-visual requirement: it is why the sign-in exists.

## Files

| File | What it is |
|---|---|
| `Pro_Grafiz App.dc.html` | The prototype. Template + logic class in one file; the logic holds all data, permissions and validation. |
| `Pro_Grafiz App - Operations Manual.dc.html` | Sixteen-section printable manual — customer part and staff part. Written for training, but the authoritative prose description of intended behaviour. |
| `ios-frame.jsx` | Device bezel used to present the prototype. Not part of the app. |
| `doc-page.js` | Paged-document shell used by the manual. Not part of the app. |
| `assets/logo-on-light.png`, `assets/logo-on-dark.png` | Logo, both grounds. |

Read the manual alongside the prototype — it explains *why* rules exist (why a failed bridge-width check blocks release, why screenshots are no longer accepted as payment proof), which the code alone does not.
