# Backend

Most server-side logic lives as Supabase Edge Functions under
`supabase/functions/` (created when PG-007/PG-009/etc. need them). This
directory is reserved for **dedicated services** the Master Spec
anticipates only if scale or complexity requires stepping outside Edge
Functions (Section 3: "dedicated services when scale/complexity
requires them").

Nothing lives here yet. Do not add a service here speculatively — only
when a specific PG task's requirements exceed what an Edge Function can
reasonably do, and document the reason when it happens.
