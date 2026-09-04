// staff-set-initial-pin
//
// Public / unauthenticated (the caller has no session yet by
// definition). Completes either first-time setup (after staff-invite)
// or a reset (after staff-reset-pin) — both flows converge here.
// Requires the one-time invite token, never just profile_id, so the
// public staff-list-signin-identities endpoint can't be combined with
// this one to take over someone else's account.
//
// Error messages are deliberately vague on the failure path ("Invalid
// request") rather than distinguishing "wrong token" from "no such
// profile" from "already set up" — that distinction would help an
// attacker enumerate valid profile_ids or guess whether a token is
// close to correct.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying, especially the
// auth.admin.updateUserById call.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const body = await req.json().catch(() => null);
  if (!body?.profile_id || !body?.invite_token || !body?.new_pin) {
    return jsonResponse({ error: 'profile_id, invite_token and new_pin are required' }, 400);
  }
  if (!/^\d{4}$/.test(body.new_pin)) {
    return jsonResponse({ error: 'new_pin must be exactly 4 digits' }, 400);
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: profile, error: profileError } = await admin
    .from('profiles')
    .select('id, invite_token_hash, invite_token_expires_at, first_login_at, active')
    .eq('id', body.profile_id)
    .maybeSingle();

  if (profileError || !profile || !profile.active || !profile.invite_token_hash) {
    return jsonResponse({ error: 'Invalid request' }, 400);
  }
  if (new Date(profile.invite_token_expires_at) < new Date()) {
    return jsonResponse({ error: 'Invite token has expired — ask an admin to resend it' }, 400);
  }

  const { data: valid, error: verifyError } = await admin.rpc('verify_invite_token', {
    p_hash: profile.invite_token_hash,
    p_token: body.invite_token,
  });
  if (verifyError || !valid) {
    return jsonResponse({ error: 'Invalid request' }, 400);
  }

  const { error: pwError } = await admin.auth.admin.updateUserById(profile.id, {
    password: body.new_pin,
  });
  if (pwError) {
    return jsonResponse({ error: pwError.message }, 500);
  }

  const { error: updateError } = await admin
    .from('profiles')
    .update({
      invite_token_hash: null,
      invite_token_expires_at: null,
      // Preserve the original first_login_at across a later reset —
      // only set it the first time.
      first_login_at: profile.first_login_at ?? new Date().toISOString(),
    })
    .eq('id', profile.id);
  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }

  return jsonResponse({ ok: true });
});
