// mark-ready-for-dispatch
//
// PG-015, transition 1 of 3: IN_PRODUCTION -> READY_FOR_DISPATCH.
// Authorized: Production (own branch, via profiles.branch_id) or Super
// Admin — per PG-015's explicitly approved business decision. Centre
// Manager is deliberately NOT included: no existing code grants Centre
// Manager authority over production completion specifically (only over
// hold/cancel/resume/reopen, a different action set), and PG-015's own
// brief says Centre Manager may only be allowed "if the existing
// architecture already explicitly grants them this authority" — it
// doesn't, so this function doesn't either.
//
// CONCURRENCY: uses a single conditional UPDATE
// (`.eq('current_stage', 'IN_PRODUCTION')`) rather than the
// select-then-update pattern the older transition functions
// (start-design, release-draft, respond-to-design, confirm-payment)
// use — those have a real TOCTOU race under concurrent calls. This is a
// deliberate, stricter pattern for the three new PG-015 functions only,
// per this task's explicit concurrency requirement; the older functions
// are NOT retrofitted (out of scope — "do not refactor unrelated
// existing transition functions").
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { authorizeBranchScopedRole } from '../_shared/staff_auth.ts';
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
    .select('id, branch_id, status, current_stage, job_ref, customer_id')
    .eq('id', body.job_id)
    .maybeSingle();
  if (jobError || !job) {
    return jsonResponse({ error: 'Job not found' }, 404);
  }

  const auth = await authorizeBranchScopedRole(admin, userData.user.id, job.branch_id, 'production');
  if (!auth.authorized) {
    return jsonResponse({ error: auth.reason }, 403);
  }

  if (job.status !== 'active') {
    return jsonResponse({ error: `This job is ${job.status}, not active` }, 409);
  }

  // Atomic compare-and-swap: only succeeds if current_stage is still
  // exactly IN_PRODUCTION at the moment of this UPDATE. A concurrent
  // second call (or a call on an already-advanced job) matches zero
  // rows here and fails safely below — no stage can be skipped and no
  // job can be advanced twice.
  const { data: updated, error: updateError } = await admin
    .from('jobs')
    .update({ current_stage: 'READY_FOR_DISPATCH', stage_started_at: new Date().toISOString() })
    .eq('id', job.id)
    .eq('current_stage', 'IN_PRODUCTION')
    .select()
    .maybeSingle();

  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }
  if (!updated) {
    return jsonResponse(
      { error: `This job is not at IN_PRODUCTION (already advanced, or never reached it) — cannot mark ready` },
      409,
    );
  }

  await admin.from('job_stage_history').insert({
    job_id: job.id,
    stage: 'READY_FOR_DISPATCH',
    advanced_by: auth.profileId,
  });

  await admin.from('audit_events').insert({
    actor_user_id: userData.user.id,
    action: 'job.mark_ready_for_dispatch',
    entity_type: 'job',
    entity_id: job.id,
    before_state: { current_stage: 'IN_PRODUCTION' },
    after_state: { current_stage: 'READY_FOR_DISPATCH' },
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
        type: 'job.ready_for_dispatch',
        title: 'Your order is ready',
        body: `${job.job_ref} is ready to leave production.`,
        entityType: 'job',
        entityId: job.id,
      });
    }
  } catch (notifyError) {
    // Never blocks the underlying transition — see prior tasks' identical pattern.
    console.error('Notification failed:', notifyError);
  }

  return jsonResponse({ ok: true, current_stage: 'READY_FOR_DISPATCH' });
});
