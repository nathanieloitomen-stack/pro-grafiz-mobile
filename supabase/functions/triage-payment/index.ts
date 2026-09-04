// triage-payment
//
// Accountant/Super-Admin only. Sets a 'pending' payment to 'matched'
// (with the bank reference the accountant found) or 'no_match' — the
// organizational step described by the approved Payments screen's
// MATCHED/NO MATCH tags. Lower-risk than confirm-payment (no money is
// released or job stage changed here), so no fresh-challenge
// requirement — that's reserved for confirm-payment specifically, per
// CLAUDE.md: "Accountant confirmation requires a fresh challenge"
// names confirmation, not matching.
//
// No bank-statement integration exists anywhere in the docs (would
// need real banking API credentials, which this task must not create)
// — matching is a manual staff action: the accountant looks at their
// bank statement themselves and reports what they found.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'Missing Authorization header' }, 401);
  }

  const body = await req.json().catch(() => null);
  if (!body?.payment_id || !body?.result) {
    return jsonResponse({ error: 'payment_id and result are required' }, 400);
  }
  if (body.result !== 'matched' && body.result !== 'no_match') {
    return jsonResponse({ error: "result must be 'matched' or 'no_match'" }, 400);
  }
  if (body.result === 'matched' && !body.bank_reference) {
    return jsonResponse({ error: 'bank_reference is required to mark a payment matched' }, 400);
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
  if (!profile?.active || (profile.role !== 'accountant' && profile.role !== 'super_admin')) {
    return jsonResponse({ error: 'Only the Accountant or Super Admin may triage a payment' }, 403);
  }

  const { data: payment, error: paymentError } = await admin
    .from('payments')
    .select('id, status')
    .eq('id', body.payment_id)
    .maybeSingle();
  if (paymentError || !payment) {
    return jsonResponse({ error: 'Payment not found' }, 404);
  }
  if (payment.status !== 'pending') {
    return jsonResponse({ error: `This payment is already ${payment.status}, not pending` }, 409);
  }

  const { error: updateError } = await admin
    .from('payments')
    .update({
      status: body.result,
      bank_reference: body.result === 'matched' ? body.bank_reference : null,
      matched_at: body.result === 'matched' ? new Date().toISOString() : null,
    })
    .eq('id', payment.id);

  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }

  return jsonResponse({ ok: true, status: body.result });
});
