// hold-job
//
// Centre Manager (own branch) or Super Admin only — see
// _shared/staff_auth.ts for why this is narrower than most other
// staff-facing functions in this codebase.
//
// Master Spec §9: "Hold/cancel/resume/reopen require controlled
// reasons and preserve history." "Controlled" here means mandatory,
// non-empty — no enum of valid reasons is specified anywhere (a
// free-text reason is what the schema already provides:
// jobs.hold_reason is `text`, not an enum), so none was invented.
//
// Does NOT change current_stage — a held job stays at whatever stage
// it was in; only jobs.status moves active -> on_hold. jobs.status
// already has a check constraint (PG-003) requiring hold_reason to be
// set whenever status = 'on_hold' — this function satisfies that by
// construction, it doesn't relax or duplicate it.
//
// "Hold pauses SLA" — CANNOT be implemented as an actual timer pause,
// because no SLA threshold exists anywhere in the docs (confirmed by
// direct search — see docs/operations.md). What IS preserved: the
// timestamp this hold began (via the audit_events row's created_at and
// jobs.updated_at) is available for a future SLA feature to exclude
// held periods from an elapsed-time calculation, once a threshold is
// ever specified. No such calculation exists in this codebase.
//
// Writes an audit_events row — "operational actions must be audited"
// (this task's explicit requirement) — the first place in this codebase
// that table is actually written to.
//
// PG-013 update: the customer is notified of the hold, including the
// reason — matches Master Spec §16's "hold" event.
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
  if (!body?.job_id || !body?.hold_reason) {
    return jsonResponse({ error: 'job_id and hold_reason are required' }, 400);
  }
  if (typeof body.hold_reason !== 'string' || body.hold_reason.trim().length === 0) {
    return jsonResponse({ error: 'hold_reason cannot be empty' }, 400);
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

  const auth = await authorizeOperationalAction(admin, userData.user.id, job.branch_id);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.reason }, 403);
  }

  if (job.status !== 'active') {
    return jsonResponse({ error: `This job is ${job.status}, not active — cannot hold` }, 409);
  }
  if (job.current_stage === 'RELEASED') {
    return jsonResponse({ error: 'This job has already been released — cannot hold' }, 409);
  }

  const { error: updateError } = await admin
    .from('jobs')
    .update({ status: 'on_hold', hold_reason: body.hold_reason, hold_note: body.hold_note ?? null })
    .eq('id', job.id);
  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }

  await admin.from('audit_events').insert({
    actor_user_id: userData.user.id,
    action: 'job.hold',
    entity_type: 'job',
    entity_id: job.id,
    before_state: { status: job.status },
    after_state: { status: 'on_hold' },
    reason: body.hold_reason,
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
        type: 'job.on_hold',
        title: 'Your job is on hold',
        body: `${job.job_ref}: ${body.hold_reason}`,
        entityType: 'job',
        entityId: job.id,
      });
    }
  } catch (notifyError) {
    console.error('Notification failed:', notifyError);
  }

  return jsonResponse({ ok: true, status: 'on_hold' });
});
