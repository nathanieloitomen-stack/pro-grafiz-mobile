-- PG-004: Staff authentication — schema changes and crypto helpers.
--
-- DECISION (documented here because it reverses a PG-003 placeholder):
-- profiles.pin_hash was added in PG-003 with a comment deferring the
-- hashing approach to PG-004. The decision made now is to NOT hand-roll
-- PIN hashing/verification/session-issuance at all — instead, the
-- approved design's 4-digit PIN *is* the staff member's Supabase Auth
-- password. Each staff member gets a real auth.users row under a
-- synthetic internal email (auth_login_handle, meaningless, never a
-- real inbox); Supabase's own audited password hashing and session
-- issuance (GoTrue) secures sign-in, rather than custom code written in
-- this sandbox with no way to test it end-to-end. This requires
-- supabase/config.toml's `[auth] minimum_password_length` to allow a
-- 4-digit password — see that file.
--
-- This is a real design decision, not something the source docs
-- dictated — flagging it plainly rather than presenting it as obviously
-- correct. Confirm it holds up once PG-005 (RLS) and real usage exist.

alter table profiles drop column pin_hash;

alter table profiles add column auth_login_handle text not null unique
  default (encode(gen_random_bytes(6), 'hex') || '@staff.pro-grafiz.internal');
comment on column profiles.auth_login_handle is
  'Synthetic auth.users email — an internal identifier, not a real '
  'mailbox. Not a secret by itself (reveals nothing without the '
  'matching PIN/password), but still only exposed to the client via '
  'the staff-list-signin-identities Edge Function response, not queried '
  'directly from the table.';

alter table profiles add column invite_token_hash text;
alter table profiles add column invite_token_expires_at timestamptz;
comment on column profiles.invite_token_hash is
  'One-time token (hashed) proving the holder is the actual invitee, '
  'not just anyone who saw an uninitialized account in the public '
  'identity list. Delivered out-of-band by the inviting admin (e.g. '
  'WhatsApp/SMS — CLAUDE.md messaging stack), never emailed to '
  'auth_login_handle, which has no real inbox. Set by staff-invite / '
  'staff-reset-pin Edge Functions, consumed and cleared by '
  'staff-set-initial-pin.';

-- Crypto helpers, thin wrappers over pgcrypto (already enabled in
-- 20260904000001). Deliberately restricted to service_role only —
-- these back an authentication mechanism and must never be callable
-- directly by anon/authenticated clients via PostgREST RPC.

create or replace function hash_invite_token(p_token text)
returns text
language sql
as $$
  select crypt(p_token, gen_salt('bf'));
$$;

create or replace function verify_invite_token(p_hash text, p_token text)
returns boolean
language sql
as $$
  select p_hash is not null and p_hash = crypt(p_token, p_hash);
$$;

revoke execute on function hash_invite_token(text) from public;
revoke execute on function verify_invite_token(text, text) from public;
grant execute on function hash_invite_token(text) to service_role;
grant execute on function verify_invite_token(text, text) to service_role;

comment on function hash_invite_token(text) is
  'service_role only. Called from the staff-invite / staff-reset-pin '
  'Edge Functions.';
comment on function verify_invite_token(text, text) is
  'service_role only. Called from the staff-set-initial-pin Edge '
  'Function.';
