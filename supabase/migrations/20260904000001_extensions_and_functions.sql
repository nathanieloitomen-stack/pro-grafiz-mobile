-- PG-003: Foundation — extensions and shared helper functions.
--
-- gen_random_uuid() has been built into PostgreSQL core since v13, so no
-- extension is required for UUID generation on Supabase (Postgres 15+).
-- pgcrypto is enabled anyway as a common Supabase default and because a
-- later PG task (payment reference hashing, DXF release code hashing —
-- see dxf_release_grants.release_code_hash) will want digest()/crypt().
create extension if not exists pgcrypto;

-- Shared trigger: keeps `updated_at` current on any UPDATE. Attached
-- explicitly per table below, not globally, so it's obvious which
-- tables track an update timestamp.
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

comment on function set_updated_at() is
  'Sets updated_at = now() (UTC) on UPDATE. Attach with a BEFORE UPDATE trigger.';
