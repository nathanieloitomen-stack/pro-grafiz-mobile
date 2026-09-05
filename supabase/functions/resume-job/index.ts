// resume-job
//
// Centre Manager (own branch) or Super Admin only — same authority as
// hold-job (_shared/staff_auth.ts).
//
// No reason is required to resume — Master Spec §9 says hold/cancel/
// resume/reopen all "require controlled reasons," but jobs.status has
// no resume-specific reason column (only hold_reason/hold_note and
// cancel_reason/cancel_note), and requiring a reason with nowhere to
// store it would mean silently discarding it. An optional `note` is
// accepted and recorded only in the audit_events row, satisfying
// "preserve history" without inventing a schema-unbacked requirement.
//
// Clears hold_reason/hold_note on the jobs row itself (they describe
// the CURRENT hold, which is ending) — the permanent record of why this
// job was held lives in the audit_events row this function also writes
// (and in the one hold-job wrote originally), not in the mutable jobs
// row. current_stage is untouched — resuming does not advance the job,
// it only un-pauses it.
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
    .select('id, branch_id, status, hold_reason')
    .eq('id', body.job_id)
    .maybeSingle();
  if (jobError || !job) {
    return jsonResponse({ error: 'Job not found' }, 404);
  }

  const auth = await authorizeOperationalAction(admin, userData.user.id, job.branch_id);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.reason }, 403);
  }

  if (job.status !== 'on_hold') {
    return jsonResponse({ error: `This job is ${job.status}, not on_hold — cannot resume` }, 409);
  }

  const { error: updateError } = await admin
    .from('jobs')
    .update({ status: 'active', hold_reason: null, hold_note: null })
    .eq('id', job.id);
  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }

  await admin.from('audit_events').insert({
    actor_user_id: userData.user.id,
    action: 'job.resume',
    entity_type: 'job',
    entity_id: job.id,
    before_state: { status: 'on_hold', hold_reason: job.hold_reason },
    after_state: { status: 'active' },
    reason: body.note ?? null,
  });

  return jsonResponse({ ok: true, status: 'active' });
});
