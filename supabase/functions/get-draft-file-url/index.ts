// get-draft-file-url
//
// Preview: any caller with drafts SELECT access (customer who owns the
// job, or staff — mirrors drafts_select_own_or_staff, PG-005) may
// request a signed URL for preview_path — this is design-review
// geometry, already visible as a row to those callers.
//
// Production: staff only, and reuses staff_get_draft_dxf_path() exactly
// (PG-005, refined in PG-010's migration to additionally require
// release_status = 'released' for the Production role specifically) —
// this function does not re-implement or loosen that check, it calls
// the same RPC a raw client could also call, then turns the path into a
// short-lived signed URL. A customer can never reach this branch: the
// authorization check happens before any path is looked up.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

const BUCKET = 'job-drafts';
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
  if (!body?.draft_id || !body?.asset_type) {
    return jsonResponse({ error: 'draft_id and asset_type are required' }, 400);
  }
  if (body.asset_type !== 'preview' && body.asset_type !== 'production') {
    return jsonResponse({ error: "asset_type must be 'preview' or 'production'" }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

  // Scoped to the caller's own JWT — used for the preview path, where
  // we rely on the caller's OWN RLS-visible row, not an admin bypass.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: 'Invalid or expired session' }, 401);
  }

  let path: string | null = null;

  if (body.asset_type === 'preview') {
    // Uses the CALLER's own client, not admin — drafts_select_own_or_staff
    // decides visibility here, exactly as it would for any other query.
    const { data: draft, error: draftError } = await callerClient
      .from('drafts')
      .select('preview_path')
      .eq('id', body.draft_id)
      .maybeSingle();
    if (draftError || !draft) {
      return jsonResponse({ error: 'Draft not found or not accessible' }, 404);
    }
    path = draft.preview_path;
  } else {
    const { data: pathResult, error: rpcError } = await callerClient.rpc('staff_get_draft_dxf_path', {
      p_draft_id: body.draft_id,
    });
    if (rpcError) {
      return jsonResponse({ error: rpcError.message }, 403);
    }
    path = pathResult;
  }

  if (!path) {
    return jsonResponse({ error: 'No file has been uploaded for this draft yet' }, 404);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: signed, error: signError } = await admin.storage
    .from(BUCKET)
    .createSignedUrl(path, SIGNED_URL_TTL_SECONDS);
  if (signError) {
    return jsonResponse({ error: signError.message }, 500);
  }

  return jsonResponse({ signed_url: signed.signedUrl, expires_in: SIGNED_URL_TTL_SECONDS });
});
