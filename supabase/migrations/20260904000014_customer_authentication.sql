-- PG-004: Customer authentication — auto-provisioning on phone sign-up.
--
-- DECISION: customers authenticate via Supabase phone OTP
-- (auth.signInWithOtp / verifyOtp), not email/password and not a
-- profiles row. Reasoning:
--   - The approved design's only reference to a customer "account" is
--     phone-number-based ("Dial from the phone number on your account.
--     The payment is matched automatically." — handoff README/HTML).
--   - Nigerian context: SMS/WhatsApp are already the primary channels
--     used elsewhere in this product (Master Spec §3 notifications).
--   - No customer sign-up/sign-in screen exists in the approved 19-screen
--     design inventory at all — screen #11 "Sign-in" is explicitly staff
--     only. This is a genuine design gap, not something being overridden.
--
-- This means customers do NOT get a `profiles` row, even though
-- role_enum (20260904000002) includes 'customer' per Master Spec §8's
-- role list — see the comment added to that type below. Authorization
-- for customers (PG-005) should check "does a customers row exist with
-- customers.auth_user_id = auth.uid()", not profiles.role. Flagging this
-- interpretation for product-owner confirmation, not presenting it as
-- the only possible reading of §8.

comment on type role_enum is
  'Master Spec §8 role list, used for profiles.role (staff only). '
  'Customers do NOT get a profiles row in this implementation — see '
  '20260904000014_customer_authentication.sql. The ''customer'' value '
  'exists for documentation completeness and is not expected to appear '
  'in any actual profiles row; confirm this interpretation before '
  'building PG-005 RLS policies on top of it.';

create sequence customer_ref_provisional_seq start 1;

create or replace function generate_customer_ref_provisional()
returns text
language sql
as $$
  select 'CUST-' || lpad(nextval('customer_ref_provisional_seq')::text, 6, '0');
$$;
comment on function generate_customer_ref_provisional() is
  'PROVISIONAL prefix (CUST-) — customer_ref has no format specified '
  'anywhere in the docs provided (see docs/database-schema.md, PG-003). '
  'This unblocks the NOT NULL UNIQUE constraint so signup actually '
  'works; confirm the real format with the product owner and migrate '
  'existing rows before production launch, rather than treating this '
  'prefix as final.';

create or replace function handle_new_customer_signup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Distinguish a customer phone signup from a staff account created by
  -- staff-invite (synthetic email, no phone) without needing a separate
  -- "account type" flag on auth.users. If this assumption ever breaks
  -- (e.g. staff gain a real phone-based recovery path), revisit.
  if new.phone is not null and not exists (
    select 1 from customers where auth_user_id = new.id
  ) then
    insert into customers (auth_user_id, customer_ref, full_name, phone)
    values (
      new.id,
      generate_customer_ref_provisional(),
      coalesce(new.raw_user_meta_data ->> 'full_name', 'Customer'),
      new.phone
    );
  end if;
  return new;
end;
$$;

comment on function handle_new_customer_signup() is
  'security definer: runs as the function owner so it can insert into '
  'public.customers regardless of the privileges of whatever role '
  'Supabase Auth uses internally to insert into auth.users. Standard '
  'Supabase pattern for auto-provisioning an app-level row on signup.';

create trigger on_auth_user_created_provision_customer
  after insert on auth.users
  for each row execute function handle_new_customer_signup();
