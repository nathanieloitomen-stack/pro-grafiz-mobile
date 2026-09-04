-- PG-005: RLS — documents, dxf_release_grants, dxf_download_logs.

alter table documents enable row level security;
alter table dxf_release_grants enable row level security;
alter table dxf_download_logs enable row level security;

-- documents -------------------------------------------------------

create policy documents_select_own_or_staff on documents
  for select using (
    exists (
      select 1 from jobs j
      where j.id = documents.job_id
        and (
          j.customer_id = current_customer_id()
          or (is_centre_manager() and j.branch_id = current_staff_branch_id())
          or is_central_staff()
        )
    )
  );

-- Deliberately no write policy — Master Spec §10/§16: PGJO/PGAO
-- generation must be idempotent and tied to job-lifecycle events; that
-- generation happens server-side (service_role), not via direct client
-- insert, once the document-generation service exists (later PG task).

-- dxf_release_grants ------------------------------------------------
--
-- release_code_hash is revoked from every client role, full stop — it
-- is only ever read internally by verification logic, never by a
-- client, hashed or not.

revoke select (release_code_hash) on dxf_release_grants from authenticated, anon;

create policy dxf_release_grants_select_own_or_staff on dxf_release_grants
  for select using (
    customer_id = current_customer_id()
    or is_central_staff()
  );

-- Deliberately no write policy — grants are an admin-issued/rotated
-- mechanism (Admin screen's DXF code schedule, "Rotate early"), issued
-- server-side (service_role), not client-writable.

-- dxf_download_logs ---------------------------------------------------
--
-- No INSERT policy for authenticated/anon: per Master Spec §14's flow
-- (Authenticated Customer → Permission Check → Backend Authorization →
-- Short-lived Signed URL → DXF → Download Audit), the audit row must be
-- written by the backend at the point of issuing the signed URL, not
-- self-reported by the client after the fact — a client-written log
-- entry could be omitted or falsified. Written by service_role once the
-- signed-URL flow exists (later PG task).

create policy dxf_download_logs_select_own_or_staff on dxf_download_logs
  for select using (
    customer_id = current_customer_id()
    or is_central_staff()
  );
