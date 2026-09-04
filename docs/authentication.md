# Authentication

**Status: PG-004 complete.** No Row Level Security yet (PG-005) — see
the warning at the bottom of this document before deploying any of this
to a real Supabase project.

## Staff: PIN is the Supabase Auth password

The approved design (handoff screen #11, "Sign-in") specifies: pick an
account from a list, then enter a 4-digit PIN. The handoff README adds:
"Real accounts set their own PIN on first sign-in via the Admin invite
flow" and "PINs in the prototype are four-digit constants. Replace with
hashed credentials."

Rather than hand-rolling PIN hashing, session issuance, and JWT minting
— none of which could be tested end-to-end in the environment this was
built in — the decision made here is: **the 4-digit PIN a staff member
types IS their real Supabase Auth password.** Each staff member gets a
genuine `auth.users` row under a synthetic internal email
(`profiles.auth_login_handle`, e.g. `a1b2c3d4e5f6@staff.pro-grafiz.internal`
— meaningless, no real inbox, not a secret). Supabase's own audited
password hashing and session issuance (GoTrue) secures sign-in.
`supabase/config.toml` lowers `minimum_password_length` to `4` to make
this possible.

This is a real design decision, not something dictated by the docs —
flagged plainly rather than presented as the only possible reading.
Reconsider it once PG-005 and real usage exist; a 4-digit space is small
(10,000 combinations), so Supabase Auth's own rate-limiting/lockout
behaviour matters more here than usual.

### Invite / first-time setup / reset

No screen design exists for any of these — the prototype only shows an
admin-side toast ("Invite sent. The new user sets their own PIN on
first sign-in.") with no corresponding screen, and the Admin screen's
per-staff-row description ("Reset PIN, change role or revoke access
from here") likewise has no detailed design. The flow implemented here:

1. **Invite** (`staff-invite` Edge Function, admin-only): creates the
   `auth.users` + `profiles` rows and a one-time invite token, returned
   once in the response. The calling admin delivers it out-of-band
   (WhatsApp/SMS — the product's own existing messaging stack), never by
   email (there's no real inbox to receive it).
2. **Set PIN** (`staff-set-initial-pin`, public/unauthenticated): the
   invitee submits `profile_id` + the invite token + their chosen PIN.
   Requiring the token (not just the profile ID) matters: the public
   `staff-list-signin-identities` endpoint lists every active account,
   so without a token, anyone could "claim" an uninitialized account by
   guessing which ones are pending setup.
3. **Reset** (`staff-reset-pin`, admin-only): issues a fresh invite
   token for an existing profile, without touching role/branch/history.
   Completed via the same `staff-set-initial-pin` endpoint.

`apps/mobile/lib/features/auth/presentation/staff_set_pin_screen.dart`
is a minimal, functional stand-in for step 2 — not a pixel-approved
screen. How the invite token actually reaches a staff member's device
(deep link vs. reading it off a WhatsApp message) is an open UX question
for a later task.

### Interim authorization in the Edge Functions

`staff-invite` and `staff-reset-pin` check the caller's own role
(`super_admin` or `centre_manager`, branch-scoped for the latter)
directly in the function, because PG-005 (RLS) hasn't landed yet — this
is the one privileged mutation PG-004 introduces, so it couldn't be left
open in the interim. This is **not** a substitute for PG-005;
comprehensive table-level RLS across all 28 tables is still a separate,
later task.

## Customers: phone OTP

No approved screen design exists for customer sign-in at all — the
19-screen inventory's only "Sign-in" screen is explicitly staff-only.
Phone OTP (`auth.signInWithOtp` / `verifyOTP`) was chosen based on the
product's own copy elsewhere referencing "the phone number on your
account" for payment matching, and the product's existing reliance on
SMS/WhatsApp. `supabase/migrations/20260904000014_customer_authentication.sql`
auto-provisions a `customers` row on first phone signup via a trigger on
`auth.users`, with a **provisional** `customer_ref` format (`CUST-xxxxxx`)
— no format was given anywhere in the docs, so this is a placeholder to
confirm, not a final answer.

`apps/mobile/lib/features/auth/presentation/customer_phone_sign_in_screen.dart`
and `customer_otp_verify_screen.dart` are minimal, functional, unapproved
UI for this — flagged the same way in their own file comments.

Customers deliberately do **not** get a `profiles` row, even though
`role_enum` (defined in PG-003) includes `'customer'` per Master Spec
§8's role list. See the comment on that type in
`20260904000014_customer_authentication.sql` for the reasoning and the
explicit flag that this interpretation needs product-owner confirmation
before PG-005 builds RLS policies on top of it.

## What was decided vs. what's still open

| Decided here | Still open |
|---|---|
| Staff PIN = Supabase Auth password | Invite-token delivery mechanism (deep link vs. manual entry) |
| Synthetic `auth_login_handle` per staff, safe to expose publicly | Whether customers should also get a `profiles` row for a unified RLS model |
| Customer auth = phone OTP | `customer_ref` real format (currently a flagged placeholder) |
| Invite token required (not just profile ID) to prevent account takeover | SMS provider vendor (config.toml has a placeholder value, not a real choice) |

## Critical: no RLS yet

Every table created in PG-003 has Row Level Security **disabled** —
that's explicitly PG-005's job, not this one. On a real Supabase
project, RLS-disabled tables in the `public` schema are typically
reachable by the `anon`/`authenticated` PostgREST roles depending on the
project's default grants. **Do not point a real mobile/web build at a
real deployed instance of this schema until PG-005 lands** — until then,
treat any live deployment as fully open, regardless of the auth work
done here. Authentication (who you are) and authorization (what you can
touch) are different problems; PG-004 only solved the first one.

## Verification

None of this has run against a live Supabase project — no network
access or Supabase CLI was available while building it. Every SQL
migration and Edge Function was checked by hand for syntax balance;
none of the Edge Functions, the Flutter auth screens, or the admin-web
sign-in page have executed. Before trusting any of it:

```bash
supabase start
supabase db reset
supabase functions serve
```

Then exercise the full staff invite → set-PIN → sign-in loop and the
customer phone → OTP loop against a real (or local) project before
building anything on top of it.
