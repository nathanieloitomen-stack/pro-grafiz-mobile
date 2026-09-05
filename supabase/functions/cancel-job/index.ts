// cancel-job
//
// Centre Manager (own branch) or Super Admin only — same authority as
// hold-job. Requires cancel_reason (mandatory, matches jobs' existing
// check constraint from PG-003). Reason is free text — no enum of
// valid cancellation reasons is specified anywhere in the docs, and
// none was invented here, per this task's explicit instruction not to
// add new cancellation reasons unless required.
//
// Not allowed once current_stage = 'RELEASED' (already delivered — a
// sanity guard, not a stated rule) or if status is already 'cancelled'.
// Allowed from either 'active' or 'on_hold' — cancelling a currently
// held job is a normal operational path (no need to resume it first).
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { authorizeOperationalAction } from '../_shared/staff_auth.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'Missing Authorization header' }, 401);
  }

  const body = await req.json().catch(() => null);
  if (!body?.job_id || !body?.cancel_reason) {
    return jsonResponse({ error: 'job_id and cancel_reason are required' }, 400);
  }
  if (typeof body.cancel_reason !== 'string' || body.cancel_reason.trim().length === 0) {
    return jsonResponse({ error: 'cancel_reason cannot be empty' }, 400);
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
    .select('id, branch_id, status, current_stage')
    .eq('id', body.job_id)
    .maybeSingle();
  if (jobError || !job) {
    return jsonResponse({ error: 'Job not found' }, 404);
  }

  const auth = await authorizeOperationalAction(admin, userData.user.id, job.branch_id);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.reason }, 403);
  }

  if (job.status === 'cancelled') {
    return jsonResponse({ error: 'This job is already cancelled' }, 409);
  }
  if (job.current_stage === 'RELEASED') {
    return jsonResponse({ error: 'This job has already been released — cannot cancel' }, 409);
  }

  const { error: updateError } = await admin
    .from('jobs')
    .update({ status: 'cancelled', cancel_reason: body.cancel_reason, cancel_note: body.cancel_note ?? null })
    .eq('id', job.id);
  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }

  await admin.from('audit_events').insert({
    actor_user_id: userData.user.id,
    action: 'job.cancel',
    entity_type: 'job',
    entity_id: job.id,
    before_state: { status: job.status },
    after_state: { status: 'cancelled' },
    reason: body.cancel_reason,
  });

  return jsonResponse({ ok: true, status: 'cancelled' });
});
