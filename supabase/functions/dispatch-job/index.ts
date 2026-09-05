// dispatch-job
//
// PG-015, transition 2 of 3: READY_FOR_DISPATCH -> DISPATCHED.
// Authorized: Inventory (own branch, via profiles.branch_id) or Super
// Admin — per PG-015's explicitly approved business decision. No driver
// workflow, delivery management, or dispatch table is introduced here —
// explicitly out of scope per this task's brief; this function only
// flips current_stage and records the event through the existing
// job_stage_history/audit_events tables.
//
// Same atomic compare-and-swap concurrency pattern as
// mark-ready-for-dispatch — see that file's header comment for why this
// diverges from the older transition functions' pattern.
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

  const auth = await authorizeBranchScopedRole(admin, userData.user.id, job.branch_id, 'inventory');
  if (!auth.authorized) {
    return jsonResponse({ error: auth.reason }, 403);
  }

  if (job.status !== 'active') {
    return jsonResponse({ error: `This job is ${job.status}, not active` }, 409);
  }

  const { data: updated, error: updateError } = await admin
    .from('jobs')
    .update({ current_stage: 'DISPATCHED', stage_started_at: new Date().toISOString() })
    .eq('id', job.id)
    .eq('current_stage', 'READY_FOR_DISPATCH')
    .select()
    .maybeSingle();

  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }
  if (!updated) {
    return jsonResponse(
      { error: 'This job is not at READY_FOR_DISPATCH (already advanced, or never reached it) — cannot dispatch' },
      409,
    );
  }

  await admin.from('job_stage_history').insert({
    job_id: job.id,
    stage: 'DISPATCHED',
    advanced_by: auth.profileId,
  });

  await admin.from('audit_events').insert({
    actor_user_id: userData.user.id,
    action: 'job.dispatch',
    entity_type: 'job',
    entity_id: job.id,
    before_state: { current_stage: 'READY_FOR_DISPATCH' },
    after_state: { current_stage: 'DISPATCHED' },
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
        type: 'job.dispatched',
        title: 'Your order has left Pro_Grafiz',
        body: `${job.job_ref} has been dispatched.`,
        entityType: 'job',
        entityId: job.id,
      });
    }
  } catch (notifyError) {
    console.error('Notification failed:', notifyError);
  }

  return jsonResponse({ ok: true, current_stage: 'DISPATCHED' });
});
