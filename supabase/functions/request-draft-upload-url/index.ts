// request-draft-upload-url
//
// Designer/Super-Admin only. The `job-drafts` Storage bucket
// (PG-010 migration 20260904000031) has zero client-accessible
// policies at all — this function, using the service-role key, is the
// only way a file gets into it. Returns a short-lived signed upload URL
// (Supabase Storage's own mechanism) the client PUTs the actual file
// bytes to directly; this function never sees or handles file content
// itself, only issues permission to write to one specific,
// deterministic path.
//
// Path convention distinguishes design-review geometry from
// production-ready geometry at the STORAGE level too, not just via the
// authorization check on drafts.dxf_path:
//   preview/{job_id}/{draft_id}.{ext}     — design-review geometry
//   production/{job_id}/{draft_id}.dxf    — becomes a released
//                                            production asset once
//                                            drafts.release_status is
//                                            set via release-draft
//
// Known limitation: this sets drafts.preview_path/dxf_path immediately
// upon issuing the URL, before the client actually uploads the bytes —
// if the upload fails client-side, the path exists in the DB pointing
// at nothing. A data-quality edge case, not a security issue; a
// two-phase "confirm upload" step would close it but wasn't built here.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

const BUCKET = 'job-drafts';

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

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: 'Invalid or expired session' }, 401);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: profile } = await admin
    .from('profiles')
    .select('role, active')
    .eq('id', userData.user.id)
    .maybeSingle();
  if (!profile?.active || (profile.role !== 'designer' && profile.role !== 'super_admin')) {
    return jsonResponse({ error: 'Only a Designer or Super Admin may upload draft files' }, 403);
  }

  const { data: draft, error: draftError } = await admin
    .from('drafts')
    .select('id, job_id')
    .eq('id', body.draft_id)
    .maybeSingle();
  if (draftError || !draft) {
    return jsonResponse({ error: 'Draft not found' }, 404);
  }

  const extension = body.asset_type === 'production' ? 'dxf' : (body.extension ?? 'png');
  const path = `${body.asset_type}/${draft.job_id}/${draft.id}.${extension}`;

  const { data: signed, error: signError } = await admin.storage.from(BUCKET).createSignedUploadUrl(path);
  if (signError) {
    return jsonResponse({ error: signError.message }, 500);
  }

  const column = body.asset_type === 'production' ? 'dxf_path' : 'preview_path';
  const { error: updateError } = await admin.from('drafts').update({ [column]: path }).eq('id', draft.id);
  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }

  return jsonResponse({ signed_url: signed.signedUrl, token: signed.token, path });
});
