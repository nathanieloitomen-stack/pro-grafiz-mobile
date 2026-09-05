// reopen-job
//
// Centre Manager (own branch) or Super Admin only — same authority as
// hold-job. "Reopen" is read here as: undo a cancellation, returning
// job.status to 'active' at whatever current_stage it was already at —
// the only terminal, reversible state jobs.status has (active/on_hold/
// cancelled, per PG-003's inference from the schema). This
// interpretation is not stated verbatim anywhere; flagged in
// docs/operations.md.
//
// No reason is required — same reasoning as resume-job: Master Spec
// groups "hold/cancel/resume/reopen" together as requiring "controlled
// reasons," but only hold_reason/cancel_reason columns actually exist
// on jobs; an optional note is recorded in the audit_events row.
//
// PG-017 update: the status update below is now an atomic compare-and-swap
// (`.eq('status', 'cancelled')` in the same statement as `.update()`,
// checking a row was actually returned) — closing the concurrency gap
// PG-016 identified.
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
    .select('id, branch_id, status, cancel_reason')
    .eq('id', body.job_id)
    .maybeSingle();
  if (jobError || !job) {
    return jsonResponse({ error: 'Job not found' }, 404);
  }

  const auth = await authorizeOperationalAction(admin, userData.user.id, job.branch_id);
  if (!auth.authorized) {
    return jsonResponse({ error: auth.reason }, 403);
  }

  if (job.status !== 'cancelled') {
    return jsonResponse({ error: `This job is ${job.status}, not cancelled — cannot reopen` }, 409);
  }

  const { data: updated, error: updateError } = await admin
    .from('jobs')
    .update({ status: 'active', cancel_reason: null, cancel_note: null })
    .eq('id', job.id)
    .eq('status', 'cancelled')
    .select()
    .maybeSingle();
  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }
  if (!updated) {
    return jsonResponse({ error: 'This job is no longer cancelled (already changed by another request) — cannot reopen' }, 409);
  }

  await admin.from('audit_events').insert({
    actor_user_id: userData.user.id,
    action: 'job.reopen',
    entity_type: 'job',
    entity_id: job.id,
    before_state: { status: 'cancelled', cancel_reason: job.cancel_reason },
    after_state: { status: 'active' },
    reason: body.note ?? null,
  });

  return jsonResponse({ ok: true, status: 'active' });
});
