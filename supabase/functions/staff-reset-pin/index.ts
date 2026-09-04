// staff-reset-pin
//
// Admin-only: issues a new one-time invite token for an existing staff
// member who forgot their PIN, without touching role, branch, or
// history. Completed via staff-set-initial-pin, same as first-time
// setup. Same interim authorization caveat as staff-invite — see that
// file's header comment.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

const INVITE_TOKEN_TTL_HOURS = 48;

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'Missing Authorization header' }, 401);
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

  const { data: callerProfile } = await admin
    .from('profiles')
    .select('id, role, branch_id, active')
    .eq('id', userData.user.id)
    .maybeSingle();

  if (!callerProfile?.active || (callerProfile.role !== 'super_admin' && callerProfile.role !== 'centre_manager')) {
    return jsonResponse({ error: 'Only Super Admin or Centre Manager may reset a staff PIN' }, 403);
  }

  const body = await req.json().catch(() => null);
  if (!body?.profile_id) {
    return jsonResponse({ error: 'profile_id is required' }, 400);
  }

  const { data: targetProfile } = await admin
    .from('profiles')
    .select('id, branch_id')
    .eq('id', body.profile_id)
    .maybeSingle();
  if (!targetProfile) {
    return jsonResponse({ error: 'Profile not found' }, 404);
  }
  if (callerProfile.role === 'centre_manager' && targetProfile.branch_id !== callerProfile.branch_id) {
    return jsonResponse({ error: 'Centre Manager cannot reset a PIN outside their own branch' }, 403);
  }

  const inviteToken = crypto.randomUUID().replace(/-/g, '').slice(0, 12);
  const { data: tokenHash, error: hashError } = await admin.rpc('hash_invite_token', {
    p_token: inviteToken,
  });
  if (hashError) {
    return jsonResponse({ error: hashError.message }, 500);
  }

  const { error: updateError } = await admin
    .from('profiles')
    .update({
      invite_token_hash: tokenHash,
      invite_token_expires_at: new Date(Date.now() + INVITE_TOKEN_TTL_HOURS * 3600 * 1000).toISOString(),
    })
    .eq('id', body.profile_id);
  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }

  return jsonResponse({
    profile_id: body.profile_id,
    invite_token: inviteToken,
    expires_in_hours: INVITE_TOKEN_TTL_HOURS,
  });
});
