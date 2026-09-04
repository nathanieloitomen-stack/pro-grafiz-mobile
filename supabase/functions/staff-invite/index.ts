// staff-invite
//
// Admin-only: creates a new staff auth.users row (synthetic email,
// unusable random temporary password) plus its profiles row, and
// issues a one-time invite token. The token is returned exactly once in
// this response — it is never stored in plaintext and never emailed
// (auth_login_handle has no real inbox). Deliver it to the invitee
// out-of-band (WhatsApp/SMS per the product's existing messaging stack).
// The invitee completes setup via staff-set-initial-pin.
//
// This function performs its own authorization check (caller must be
// an active super_admin or centre_manager) because PG-005 (Row Level
// Security) hasn't landed yet — this is the one privileged mutation
// PG-004 introduces, so it can't be left open in the interim. This is
// NOT a substitute for PG-005; comprehensive table-level RLS across all
// 28 tables is still a separate, later task.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying, especially the
// auth.admin.createUser / deleteUser calls.
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

  // Scoped to the caller's own JWT — used only to identify who is
  // calling, never to perform the privileged mutation itself.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: 'Invalid or expired session' }, 401);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: callerProfile, error: callerProfileError } = await admin
    .from('profiles')
    .select('id, role, branch_id, active')
    .eq('id', userData.user.id)
    .maybeSingle();

  if (callerProfileError || !callerProfile || !callerProfile.active) {
    return jsonResponse({ error: 'Caller has no active staff profile' }, 403);
  }
  if (callerProfile.role !== 'super_admin' && callerProfile.role !== 'centre_manager') {
    return jsonResponse({ error: 'Only Super Admin or Centre Manager may invite staff' }, 403);
  }

  const body = await req.json().catch(() => null);
  if (!body?.full_name || !body?.role) {
    return jsonResponse({ error: 'full_name and role are required' }, 400);
  }

  let branchId: string | null = body.branch_id ?? null;
  if (callerProfile.role === 'centre_manager') {
    // Centre Managers are branch-scoped (Master Spec §8): cannot invite
    // into a different branch, and cannot create a Super Admin.
    branchId = callerProfile.branch_id;
    if (body.role === 'super_admin') {
      return jsonResponse({ error: 'Centre Manager cannot create a Super Admin account' }, 403);
    }
  }

  const inviteToken = crypto.randomUUID().replace(/-/g, '').slice(0, 12);
  const { data: tokenHash, error: hashError } = await admin.rpc('hash_invite_token', {
    p_token: inviteToken,
  });
  if (hashError) {
    return jsonResponse({ error: hashError.message }, 500);
  }

  const syntheticEmail = `${crypto.randomUUID().replace(/-/g, '').slice(0, 12)}@staff.pro-grafiz.internal`;
  const temporaryPassword = crypto.randomUUID(); // random, never revealed, never used to sign in

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email: syntheticEmail,
    password: temporaryPassword,
    email_confirm: true,
  });
  if (createError || !created.user) {
    return jsonResponse({ error: createError?.message ?? 'Failed to create auth user' }, 500);
  }

  const { error: profileError } = await admin.from('profiles').insert({
    id: created.user.id,
    full_name: body.full_name,
    initials: body.initials ?? null,
    role: body.role,
    branch_id: branchId,
    phone: body.phone ?? null,
    email: body.email ?? null,
    auth_login_handle: syntheticEmail,
    invite_token_hash: tokenHash,
    invite_token_expires_at: new Date(Date.now() + INVITE_TOKEN_TTL_HOURS * 3600 * 1000).toISOString(),
  });

  if (profileError) {
    // Roll back the orphaned auth user rather than leaving a
    // profile-less account behind.
    await admin.auth.admin.deleteUser(created.user.id);
    return jsonResponse({ error: profileError.message }, 500);
  }

  return jsonResponse({
    profile_id: created.user.id,
    invite_token: inviteToken,
    expires_in_hours: INVITE_TOKEN_TTL_HOURS,
  });
});
