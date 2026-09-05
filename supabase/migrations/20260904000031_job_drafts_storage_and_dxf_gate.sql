-- PG-010: job-drafts Storage bucket, and a refinement to
-- staff_get_draft_dxf_path().
--
-- Distinguishing four kinds of geometry per this task's explicit
-- instruction (none of these are new business rules — this is naming
-- what already exists across PG-003/PG-005/PG-006, plus what's added
-- here):
--   - Catalogue preview geometry: pattern_assets, pglc-public bucket
--     (PG-006) — public, general-purpose pattern images.
--   - Design-review geometry: drafts.preview_path, THIS bucket's
--     preview/ prefix (new) — job-specific, customer + staff visible,
--     not yet authorized for production.
--   - Production-ready geometry: the same drafts.dxf_path, once
--     drafts.release_status = 'released' (PG-005's
--     enforce_draft_release_gate trigger, unchanged) — the file
--     content doesn't move or duplicate; what changes is authorization.
--   - Released DXF/production asset: THIS bucket's production/ prefix
--     (new), reachable only via staff_get_draft_dxf_path() (tightened
--     below) — never a public bucket policy, unlike pglc-public.
--
-- This bucket is PRIVATE with NO direct storage.objects policies at
-- all — unlike pglc-public/pglc-production (PG-006), which are
-- catalog-wide and appropriately bucket-policy-gated. Job drafts are
-- customer- and job-specific, not general catalog content, so access
-- goes exclusively through Edge Functions issuing short-lived signed
-- URLs (Master Spec §14's own pattern: "Backend Authorization →
-- Short-lived Signed URL"), never a broad bucket-level SELECT/INSERT
-- policy. This preserves the pglc-public/pglc-production separation
-- untouched — nothing in this migration modifies either bucket or their
-- existing policies.

insert into storage.buckets (id, name, public)
values ('job-drafts', 'job-drafts', false)
on conflict (id) do nothing;

-- No storage.objects policies are added for this bucket — intentional.
-- All access is via service-role Edge Functions
-- (request-draft-upload-url, get-draft-file-url), which perform their
-- own authorization checks matching drafts'/jobs' existing RLS
-- conditions before issuing a signed URL. A bucket with zero policies
-- and RLS enabled (Supabase's default on storage.objects) means direct
-- client access is impossible regardless of bucket_id — the only path
-- is through those functions.

-- Refinement, not a weakening: staff_get_draft_dxf_path() previously
-- allowed any of super_admin/designer/production to fetch a draft's DXF
-- path regardless of release_status. Per this task's explicit
-- instruction ("Production DXF release must remain subject to the
-- existing authorization, validation and audit requirements"),
-- Production role staff should only ever see RELEASED geometry —
-- pre-release drafts are a Designer/Super-Admin review concern, not yet
-- an authorized production asset. Designer/Super Admin access is
-- unchanged (they legitimately need pre-release access to do the
-- review/release work itself).
create or replace function staff_get_draft_dxf_path(p_draft_id uuid)
returns text
language plpgsql stable security definer set search_path = public
as $$
declare
  v_path text;
  v_release_status text;
begin
  if not (is_super_admin() or is_designer() or is_production()) then
    raise exception 'Not authorized to access production DXF files';
  end if;

  select dxf_path, release_status into v_path, v_release_status
  from drafts where id = p_draft_id;

  if is_production() and not is_super_admin() and not is_designer() and v_release_status <> 'released' then
    raise exception 'This draft has not been released — Production may only access released geometry';
  end if;

  return v_path;
end;
$$;
