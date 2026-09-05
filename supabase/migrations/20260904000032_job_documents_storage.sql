-- PG-011: job-documents Storage bucket.
--
-- Same pattern as job-drafts (PG-010): private, ZERO client-accessible
-- storage.objects policies. Generated documents (PGJO/PGAO) are
-- job-specific and contain customer/financial data — not public catalog
-- content — so access goes exclusively through a service-role Edge
-- Function (get-document-url) issuing short-lived signed URLs, exactly
-- like job-drafts' preview/production split. This is a THIRD, distinct
-- bucket from job-drafts and pglc-public/pglc-production — a generated
-- PGJO/PGAO document is a different kind of artifact from a design
-- draft or a catalogue image, and keeping them in separate buckets
-- preserves that distinction at the infrastructure level, not just in
-- documentation.

insert into storage.buckets (id, name, public)
values ('job-documents', 'job-documents', false)
on conflict (id) do nothing;

-- No storage.objects policies added — intentional, matching job-drafts.
