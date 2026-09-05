// start-design
//
// Designer/Super-Admin only. Advances a job PAYMENT_CONFIRMED ->
// DESIGN_IN_PROGRESS. Both stage names and their position in the
// sequence come directly from Master Spec §9 — what's NOT specified
// anywhere is the exact trigger for this particular transition (is it
// automatic right after payment, or a manual "I'm starting this" action
// by a designer?). Implemented here as a manual designer action, the
// natural entry point into this task's own Design Desk workflow — this
// is an interpretive decision, not a certainty, flagged in
// docs/design-desk.md.
//
// jobs has zero client write policies (PG-005, unchanged) — this
// function's use of the service-role key is the only path, consistent
// with every other job-stage transition in this codebase
// (respond-to-design, confirm-payment).
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

  const { data: profile } = await admin
    .from('profiles')
    .select('id, role, active')
    .eq('id', userData.user.id)
    .maybeSingle();
  if (!profile?.active || (profile.role !== 'designer' && profile.role !== 'super_admin')) {
    return jsonResponse({ error: 'Only a Designer or Super Admin may start design work' }, 403);
  }

  const { data: job, error: jobError } = await admin
    .from('jobs')
    .select('id, current_stage, status')
    .eq('id', body.job_id)
    .maybeSingle();
  if (jobError || !job) {
    return jsonResponse({ error: 'Job not found' }, 404);
  }
  if (job.status !== 'active') {
    return jsonResponse({ error: `This job is ${job.status}, not active` }, 409);
  }
  if (job.current_stage !== 'PAYMENT_CONFIRMED') {
    return jsonResponse(
      { error: `This job is at stage ${job.current_stage} — design can only start from PAYMENT_CONFIRMED` },
      409,
    );
  }

  const { error: updateError } = await admin
    .from('jobs')
    .update({ current_stage: 'DESIGN_IN_PROGRESS', stage_started_at: new Date().toISOString() })
    .eq('id', job.id);
  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }

  await admin.from('job_stage_history').insert({
    job_id: job.id,
    stage: 'DESIGN_IN_PROGRESS',
    advanced_by: profile.id,
  });

  return jsonResponse({ ok: true, current_stage: 'DESIGN_IN_PROGRESS' });
});
