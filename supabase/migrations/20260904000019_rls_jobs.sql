-- PG-005: RLS — jobs, job_stage_history, design_revisions.
--
-- jobs and job_stage_history have NO write policy for authenticated/anon
-- at all — not even a narrow staff one. Master Spec §9 is explicit:
-- "Use a server-side transition service. Do not allow arbitrary
-- current-stage updates." Every job created, and every stage
-- transition, must happen through a future service_role-backed Edge
-- Function (PG-008/PG-009), not direct table access. This is the
-- concrete DB-level enforcement behind two of the named negative tests:
-- "Accountant cannot advance production" and "Designer cannot confirm
-- payments" both hold trivially, because NO staff role — nor even Super
-- Admin — can write to jobs directly through the API at all yet. That
-- transition service does not exist as of PG-005; until it's built,
-- jobs can only be created/advanced via the service_role key directly
-- (e.g. from a trusted script), which is the correct interim state, not
-- a gap.

alter table jobs enable row level security;
alter table job_stage_history enable row level security;
alter table design_revisions enable row level security;

create policy jobs_select_own_or_staff on jobs
  for select using (
    customer_id = current_customer_id()
    or (is_centre_manager() and branch_id = current_staff_branch_id())
    or is_central_staff()
  );

-- Deliberately no INSERT/UPDATE/DELETE policy on jobs for
-- authenticated/anon — see header comment.

create policy job_stage_history_select_own_or_staff on job_stage_history
  for select using (
    exists (
      select 1 from jobs j
      where j.id = job_stage_history.job_id
        and (
          j.customer_id = current_customer_id()
          or (is_centre_manager() and j.branch_id = current_staff_branch_id())
          or is_central_staff()
        )
    )
  );

-- Deliberately no write policy on job_stage_history — append-only,
-- written by the same future transition service as jobs itself.

-- design_revisions ------------------------------------------------------
--
-- Unlike jobs/job_stage_history, this table DOES get a direct client
-- write path: a customer requesting a design change, or a designer
-- logging one, is a simple record-creation action, not a lifecycle
-- transition — it doesn't need a dedicated service the way stage
-- advancement or payment confirmation do.
--
-- KNOWN GAP (flagged in PG-003's docs/database-schema.md too):
-- requested_by references profiles(id), so a customer-authored revision
-- request has no profiles row to attach — the WITH CHECK below requires
-- requested_by to be null in that case, meaning customer-authored
-- revisions currently can't be attributed to the specific customer
-- beyond the job's own customer_id. Revisit once this table gets a
-- proper dual-attribution column.

create policy design_revisions_select_own_or_staff on design_revisions
  for select using (
    exists (
      select 1 from jobs j
      where j.id = design_revisions.job_id
        and (
          j.customer_id = current_customer_id()
          or (is_centre_manager() and j.branch_id = current_staff_branch_id())
          or is_central_staff()
        )
    )
  );

create policy design_revisions_insert_own_or_staff on design_revisions
  for insert with check (
    (
      exists (select 1 from jobs j where j.id = job_id and j.customer_id = current_customer_id())
      and requested_by is null
    )
    or (is_active_staff() and (requested_by is null or requested_by = auth.uid()))
  );

create policy design_revisions_update_staff_only on design_revisions
  for update using (
    exists (
      select 1 from jobs j
      where j.id = design_revisions.job_id
        and ((is_centre_manager() and j.branch_id = current_staff_branch_id()) or is_central_staff())
    )
  )
  with check (
    exists (
      select 1 from jobs j
      where j.id = design_revisions.job_id
        and ((is_centre_manager() and j.branch_id = current_staff_branch_id()) or is_central_staff())
    )
  );
