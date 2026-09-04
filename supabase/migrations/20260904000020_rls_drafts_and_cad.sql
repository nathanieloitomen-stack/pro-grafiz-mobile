-- PG-005: RLS — drafts, draft_checks, and the CAD release-block guarantee.

alter table drafts enable row level security;
alter table draft_checks enable row level security;

-- drafts.dxf_path is production CAD geometry — CLAUDE.md: "Never expose
-- private production DXF files without backend authorization." Column
-- access is revoked from EVERYONE (staff included) at the table level;
-- staff fetch it only through staff_get_draft_dxf_path() below, which
-- performs its own role check. This is stricter than strictly necessary
-- for staff, but keeps a single, auditable seam for adding real
-- signed-URL/download-logging behaviour later (PG-011/PG-015) without
-- having to retrofit access control onto a previously-open column.
revoke select (dxf_path) on drafts from authenticated, anon;

create or replace function staff_get_draft_dxf_path(p_draft_id uuid)
returns text
language plpgsql stable security definer set search_path = public
as $$
declare
  v_path text;
begin
  if not (is_super_admin() or is_designer() or is_production()) then
    raise exception 'Not authorized to access production DXF files';
  end if;
  select dxf_path into v_path from drafts where id = p_draft_id;
  return v_path;
end;
$$;
revoke execute on function staff_get_draft_dxf_path(uuid) from public;
grant execute on function staff_get_draft_dxf_path(uuid) to authenticated;

-- Row visibility: customers see their own job's drafts (for the
-- approval-card preview — preview_path remains a normal, selectable
-- column); staff visibility follows the same central-vs-branch-scoped
-- split used throughout.
create policy drafts_select_own_or_staff on drafts
  for select using (
    exists (
      select 1 from jobs j
      where j.id = drafts.job_id
        and (
          j.customer_id = current_customer_id()
          or (is_centre_manager() and j.branch_id = current_staff_branch_id())
          or is_central_staff()
        )
    )
  );

-- Writes: Designer + Super Admin only. Production and Centre Manager do
-- not create or modify drafts in the approved design (Design Desk /
-- Auto-draft review, screens #15–16, are Designer-facing).
create policy drafts_write_designer_or_super_admin on drafts
  for all using (is_designer() or is_super_admin())
  with check (is_designer() or is_super_admin());

-- Guarantees "any mandatory failure blocks release" (CLAUDE.md CAD
-- RULES) as an actual enforced constraint, not just a UI convention —
-- this directly backs the "Failed CAD check blocks release" negative
-- test named in CLAUDE.md's TESTING section. release_status has no
-- fixed enum (see docs/database-schema.md), so this checks the literal
-- string 'released' as the one terminal value the business rule cares
-- about; if the real value list turns out different, update the string
-- here, not the enforcement logic.
create or replace function enforce_draft_release_gate()
returns trigger
language plpgsql
as $$
declare
  has_unresolved_failure boolean;
begin
  if new.release_status = 'released' and (old.release_status is distinct from 'released') then
    select exists (
      select 1 from draft_checks
      where draft_id = new.id and result = 'fail'
    ) into has_unresolved_failure;

    if has_unresolved_failure and (new.override_reason is null or length(trim(new.override_reason)) = 0) then
      raise exception
        'Draft % has a failed mandatory check and no override_reason — release is blocked (CLAUDE.md CAD RULES).',
        new.id;
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_enforce_draft_release_gate
  before update on drafts
  for each row execute function enforce_draft_release_gate();

-- draft_checks: staff-only visibility (the five mandatory checks and
-- their detail are a Design Desk concern, not shown on the customer's
-- approval card per the approved screens) and staff-only writes.
create policy draft_checks_select_staff on draft_checks
  for select using (
    exists (
      select 1 from drafts d
      join jobs j on j.id = d.job_id
      where d.id = draft_checks.draft_id
        and ((is_centre_manager() and j.branch_id = current_staff_branch_id()) or is_central_staff())
    )
  );
create policy draft_checks_write_designer_or_super_admin on draft_checks
  for all using (is_designer() or is_super_admin())
  with check (is_designer() or is_super_admin());
