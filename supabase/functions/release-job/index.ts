// release-job
//
// PG-015, transition 3 of 3: DISPATCHED -> RELEASED. Authorized: Centre
// Manager (own branch) or Super Admin — the SAME actor set as
// hold/resume/cancel/reopen (PG-012), so this reuses
// authorizeOperationalAction() directly rather than duplicating it —
// unlike mark-ready-for-dispatch/dispatch-job, this is a genuine match,
// not a reuse-for-convenience.
//
// BALANCE ENFORCEMENT (PG-015's explicit business decision — the
// outstanding balance must be fully paid before release): determined
// entirely from existing, already-authoritative schema — quotes' own
// balance_kobo (the quote engine's own computed figure, PG-007) and
// payments.status = 'confirmed' with kind = 'balance' (the exact same
// existence-check pattern create-payment-request already uses for its
// own deposit-before-balance precondition, PG-009). No client-supplied
// amount is trusted anywhere in this check. If balance_kobo <= 0 (a
// valid, if unusual, configuration — e.g. a 100% deposit was
// configured), nothing is owed and release proceeds without requiring
// a balance payment record to exist, since none could ever be created
// for a zero or negative amount.
//
// Customer confirmation is explicitly NOT required for V1, per PG-015's
// approved decision — an authorized staff member's action alone closes
// the job.
//
// Same atomic compare-and-swap concurrency pattern as the other two new
// functions in this task.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { authorizeOperationalAction } from '../_shared/staff_auth.ts';
import { notify } from '../_shared/notifier.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'Missing Authorization header' }, 401);
  }

  const body = await req.json().catch(() => null);
  if (!body?.job_id) {
    return jsonResponse({ error: 'job_id is required' }, 400);
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

  const { data: job, error: jobError } = await admin
    .from('jobs')
    .select('id, branch_id, status, current_stage, job_ref, customer_id, quote_id')
    .eq('id', body.job_id)
    .maybeSingle();
  if (jobError || !job) {
    return jsonResponse({ error: 'Job not found' }, 404);
  }

  const auth = await authorizeOperationalAction(admin, userData.user.id, job.branch_id);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.reason }, 403);
  }

  if (job.status !== 'active') {
    return jsonResponse({ error: `This job is ${job.status}, not active` }, 409);
  }

  // Balance enforcement — checked BEFORE attempting the stage
  // transition, using only server-derived, already-authoritative data.
  const { data: quote, error: quoteError } = await admin
    .from('quotes')
    .select('balance_kobo')
    .eq('id', job.quote_id)
    .maybeSingle();
  if (quoteError || !quote) {
    return jsonResponse({ error: "Could not load this job's quote to verify the balance" }, 500);
  }

  if (quote.balance_kobo > 0) {
    const { data: confirmedBalance } = await admin
      .from('payments')
      .select('id')
      .eq('job_id', job.id)
      .eq('kind', 'balance')
      .eq('status', 'confirmed')
      .limit(1)
      .maybeSingle();
    if (!confirmedBalance) {
      return jsonResponse(
        { error: 'The outstanding balance has not been confirmed as paid — cannot release this job' },
        409,
      );
    }
  }

  const { data: updated, error: updateError } = await admin
    .from('jobs')
    .update({ current_stage: 'RELEASED', stage_started_at: new Date().toISOString() })
    .eq('id', job.id)
    .eq('current_stage', 'DISPATCHED')
    .select()
    .maybeSingle();

  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }
  if (!updated) {
    return jsonResponse(
      { error: 'This job is not at DISPATCHED (already advanced, or never reached it) — cannot release' },
      409,
    );
  }

  await admin.from('job_stage_history').insert({
    job_id: job.id,
    stage: 'RELEASED',
    advanced_by: auth.profileId,
  });

  await admin.from('audit_events').insert({
    actor_user_id: userData.user.id,
    action: 'job.release',
    entity_type: 'job',
    entity_id: job.id,
    before_state: { current_stage: 'DISPATCHED' },
    after_state: { current_stage: 'RELEASED' },
  });

  try {
    const { data: customer } = await admin
      .from('customers')
      .select('auth_user_id')
      .eq('id', job.customer_id)
      .maybeSingle();
    if (customer?.auth_user_id) {
      await notify(admin, {
        recipientUserId: customer.auth_user_id,
        type: 'job.released',
        title: 'Job complete',
        body: `${job.job_ref} has been released.`,
        entityType: 'job',
        entityId: job.id,
      });
    }
  } catch (notifyError) {
    console.error('Notification failed:', notifyError);
  }

  return jsonResponse({ ok: true, current_stage: 'RELEASED' });
});
