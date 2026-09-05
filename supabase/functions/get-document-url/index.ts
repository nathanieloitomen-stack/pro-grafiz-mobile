// get-document-url
//
// Returns a short-lived signed URL for a generated PGJO/PGAO document.
// Uses the CALLER's own client (not admin) to look up the document row
// — documents_select_own_or_staff (PG-005, unmodified) decides
// visibility exactly as it would for any other query: the owning
// customer, branch-scoped Centre Manager, or central staff. No new
// authorization rule is introduced here.
//
// job-documents (PG-011) has zero client-accessible bucket policies, so
// admin is used only for the signed-URL step itself, after visibility
// has already been established via the caller's own RLS-scoped query.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

const BUCKET = 'job-documents';
const SIGNED_URL_TTL_SECONDS = 300;

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'Missing Authorization header' }, 401);
  }

  const body = await req.json().catch(() => null);
  if (!body?.job_id || !body?.type) {
    return jsonResponse({ error: 'job_id and type are required' }, 400);
  }
  if (body.type !== 'PGJO' && body.type !== 'PGAO') {
    return jsonResponse({ error: "type must be 'PGJO' or 'PGAO'" }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: 'Invalid or expired session' }, 401);
  }

  const { data: document, error: documentError } = await callerClient
    .from('documents')
    .select('id, document_ref, storage_path, issue_date')
    .eq('job_id', body.job_id)
    .eq('type', body.type)
    .maybeSingle();

  if (documentError || !document) {
    return jsonResponse({ error: `No ${body.type} document exists for this job yet, or it is not accessible to you` }, 404);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: signed, error: signError } = await admin.storage
    .from(BUCKET)
    .createSignedUrl(document.storage_path, SIGNED_URL_TTL_SECONDS);
  if (signError) {
    return jsonResponse({ error: signError.message }, 500);
  }

  return jsonResponse({
    document_ref: document.document_ref,
    issue_date: document.issue_date,
    signed_url: signed.signedUrl,
    expires_in: SIGNED_URL_TTL_SECONDS,
  });
});
