// staff-list-signin-identities
//
// Public / anon-callable. Backs the approved staff sign-in screen
// (design handoff screen #11): a scrollable account list shown BEFORE
// the device has any session, so this can't require authentication.
//
// Returns auth_login_handle alongside the display fields — it's the
// identifier the client needs to actually sign in next
// (signInWithPassword(email: auth_login_handle, password: pin)), and
// unlike a real email it's not sensitive: it's an internal, meaningless
// synthetic address that grants no access without the matching PIN.
// What's deliberately withheld is anything that IS sensitive or
// target-selecting: real email, phone, and invite/PIN state — exposing
// which accounts are mid-invite would let an attacker pick the accounts
// most vulnerable to a take-over attempt.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data, error } = await supabase
    .from('profiles')
    .select('id, full_name, initials, role, branch_id, auth_login_handle, branches(name)')
    .eq('active', true)
    .order('full_name');

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  return jsonResponse({ identities: data });
});
