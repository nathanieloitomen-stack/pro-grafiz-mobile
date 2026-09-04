// create-payment-request
//
// Customer-only. Creates a `payments` row (status: 'pending') for one
// of the two amounts already computed on the job's issued quote —
// `deposit_kobo` or `balance_kobo`. This is the "Customer → Payment
// Request" step in Master Spec §13's flow diagram; everything after it
// (Gateway → Verified Webhook) is explicitly NOT built in this task —
// no payment provider is specified (see docs/payments.md). This
// function only records that the customer intends to pay a specific,
// already-quoted amount; it records no gateway reference, confirms
// nothing, and moves no job stage.
//
// Deposit-before-balance sequencing (balance can't be requested until a
// deposit for the same job is confirmed) is this function's own
// inference from the schema's deposit_kobo/balance_kobo split — not
// stated verbatim anywhere. Flagged in docs/payments.md, not presented
// as certain.
//
// amount_kobo is read directly from the job's own issued quote, never
// supplied by the client — this is the concrete enforcement behind "no
// client-side payment trust": a customer cannot request to pay an
// arbitrary amount.
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
  if (!body?.job_id || !body?.kind) {
    return jsonResponse({ error: 'job_id and kind are required' }, 400);
  }
  if (body.kind !== 'deposit' && body.kind !== 'balance') {
    return jsonResponse({ error: "kind must be 'deposit' or 'balance'" }, 400);
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

  const { data: customer } = await admin
    .from('customers')
    .select('id')
    .eq('auth_user_id', userData.user.id)
    .maybeSingle();
  if (!customer) {
    return jsonResponse({ error: 'Only the owning customer may request payment' }, 403);
  }

  const { data: job, error: jobError } = await admin
    .from('jobs')
    .select('id, customer_id, quote_id')
    .eq('id', body.job_id)
    .maybeSingle();
  if (jobError || !job) {
    return jsonResponse({ error: 'Job not found' }, 404);
  }
  if (job.customer_id !== customer.id) {
    return jsonResponse({ error: 'This job does not belong to you' }, 403);
  }

  const { data: quote, error: quoteError } = await admin
    .from('quotes')
    .select('deposit_kobo, balance_kobo')
    .eq('id', job.quote_id)
    .maybeSingle();
  if (quoteError || !quote) {
    return jsonResponse({ error: 'No issued quote found for this job' }, 404);
  }

  if (body.kind === 'balance') {
    const { data: confirmedDeposit } = await admin
      .from('payments')
      .select('id')
      .eq('job_id', job.id)
      .eq('kind', 'deposit')
      .eq('status', 'confirmed')
      .limit(1)
      .maybeSingle();
    if (!confirmedDeposit) {
      return jsonResponse({ error: 'The deposit must be confirmed before requesting the balance payment' }, 409);
    }
  }

  const { data: existingPending } = await admin
    .from('payments')
    .select('id')
    .eq('job_id', job.id)
    .eq('kind', body.kind)
    .in('status', ['pending', 'matched'])
    .limit(1)
    .maybeSingle();
  if (existingPending) {
    return jsonResponse({ error: `A ${body.kind} payment request already exists for this job` }, 409);
  }

  const amountKobo = body.kind === 'deposit' ? quote.deposit_kobo : quote.balance_kobo;

  const { data: paymentRef, error: refError } = await admin.rpc('generate_payment_ref_provisional');
  if (refError) return jsonResponse({ error: refError.message }, 500);

  const { data: payment, error: insertError } = await admin
    .from('payments')
    .insert({
      job_id: job.id,
      payment_ref: paymentRef,
      kind: body.kind,
      amount_kobo: amountKobo,
    })
    .select()
    .single();

  if (insertError) {
    return jsonResponse({ error: insertError.message }, 500);
  }

  return jsonResponse({ payment });
});
