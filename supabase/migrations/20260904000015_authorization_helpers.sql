-- PG-005: Authorization helper functions.
--
-- Staff and customers both connect as the same Postgres role
-- (`authenticated`) under Supabase's model — there is no native
-- "staff" vs "customer" role distinction at the connection level. Every
-- distinction in this file and in the policies that follow is made by
-- looking up auth.uid() against `profiles` (staff) or `customers`
-- (customers), not by which Postgres role is connected.
--
-- All functions are SECURITY DEFINER, STABLE, and owned by the
-- migration-running role (which owns profiles/customers and therefore
-- bypasses their RLS). This is the standard, Supabase-recommended
-- pattern for reading auth context from within policies without
-- triggering recursive RLS evaluation (a policy on `profiles` that
-- itself queried `profiles` through a non-definer function would be
-- evaluated under the caller's own RLS, which is unnecessary complexity
-- and a common source of subtle bugs). `set search_path = public` on
-- each pins name resolution and is a standard defense against
-- search-path hijacking in SECURITY DEFINER functions.
--
-- EXECUTE is granted to `authenticated` only (not `anon`, not `public`)
-- — anonymous/unauthenticated callers have no legitimate reason to call
-- these, and auth.uid() would just be null for them anyway.

create or replace function current_staff_role()
returns role_enum
language sql stable security definer set search_path = public
as $$
  select role from profiles where id = auth.uid() and active;
$$;

create or replace function current_staff_branch_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select branch_id from profiles where id = auth.uid() and active;
$$;

create or replace function is_active_staff()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from profiles where id = auth.uid() and active);
$$;

create or replace function is_super_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from profiles where id = auth.uid() and active and role = 'super_admin');
$$;

create or replace function is_centre_manager()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from profiles where id = auth.uid() and active and role = 'centre_manager');
$$;

create or replace function is_accountant()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from profiles where id = auth.uid() and active and role = 'accountant');
$$;

create or replace function is_designer()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from profiles where id = auth.uid() and active and role = 'designer');
$$;

create or replace function is_production()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from profiles where id = auth.uid() and active and role = 'production');
$$;

create or replace function is_inventory()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from profiles where id = auth.uid() and active and role = 'inventory');
$$;

-- "Central" roles operate across all branches per Master Spec §8
-- ("Central roles may see all branches according to their
-- permissions") — everything except centre_manager, which is the one
-- explicitly branch-scoped role.
create or replace function is_central_staff()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and active
      and role in ('super_admin', 'accountant', 'designer', 'production', 'inventory')
  );
$$;

create or replace function current_customer_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select id from customers where auth_user_id = auth.uid() and active;
$$;

create or replace function is_active_customer()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from customers where auth_user_id = auth.uid() and active);
$$;

-- Centre Manager branch isolation, expressed once and reused everywhere
-- a table has a branch_id column: true for every other staff role
-- (they see all branches, subject to their own function-level
-- restrictions elsewhere), true for a Centre Manager only when the
-- row's branch matches their own, false for anyone else.
create or replace function staff_can_see_branch(p_branch_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select case
    when not is_active_staff() then false
    when is_centre_manager() then current_staff_branch_id() = p_branch_id
    else true
  end;
$$;

revoke execute on function current_staff_role() from public;
revoke execute on function current_staff_branch_id() from public;
revoke execute on function is_active_staff() from public;
revoke execute on function is_super_admin() from public;
revoke execute on function is_centre_manager() from public;
revoke execute on function is_accountant() from public;
revoke execute on function is_designer() from public;
revoke execute on function is_production() from public;
revoke execute on function is_inventory() from public;
revoke execute on function is_central_staff() from public;
revoke execute on function current_customer_id() from public;
revoke execute on function is_active_customer() from public;
revoke execute on function staff_can_see_branch(uuid) from public;

grant execute on function current_staff_role() to authenticated;
grant execute on function current_staff_branch_id() to authenticated;
grant execute on function is_active_staff() to authenticated;
grant execute on function is_super_admin() to authenticated;
grant execute on function is_centre_manager() to authenticated;
grant execute on function is_accountant() to authenticated;
grant execute on function is_designer() to authenticated;
grant execute on function is_production() to authenticated;
grant execute on function is_inventory() to authenticated;
grant execute on function is_central_staff() to authenticated;
grant execute on function current_customer_id() to authenticated;
grant execute on function is_active_customer() to authenticated;
grant execute on function staff_can_see_branch(uuid) to authenticated;
