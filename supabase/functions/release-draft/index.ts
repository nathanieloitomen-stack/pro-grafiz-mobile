// release-draft
//
// Designer/Super-Admin only. This function does NOT reimplement the CAD
// release gate — that already exists as enforce_draft_release_gate()
// (PG-005), a real database trigger that blocks release_status
// changing to 'released' if an unresolved draft_checks failure exists
// without override_reason. This function performs the drafts UPDATE
// (which a designer could already do directly via RLS —
// drafts_write_designer_or_super_admin) and, ONLY if that update
// actually succeeds, additionally advances the job's stage
// DESIGN_IN_PROGRESS -> DESIGN_SENT_FOR_APPROVAL — which jobs' RLS
// (zero client write policies) means no client could ever do directly.
// Bundling both in one function keeps them atomic-ish and is why this
// exists as a function at all rather than a plain client-side update.
//
// If the drafts update is rejected by the trigger (unresolved failure,
// no override), this function surfaces that exact error and does NOT
// touch the job — the gate is not bypassed or duplicated, just
// observed.
//
// "Production-ready geometry" begins existing at exactly the moment
// this function's drafts update succeeds (release_status becomes
// 'released') — no file is generated, moved, or duplicated here; only
// authorization changes, which is what staff_get_draft_dxf_path()'s
// PG-010 refinement (Production role requires released) actually gates.
//
// PG-013 update: the customer is notified once the job successfully
// advances to DESIGN_SENT_FOR_APPROVAL — matches Master Spec §16's
// "design ready"/"approval requested" events. Swallowed on failure,
// same treatment as every other post-transition side effect in this
// codebase.
//
// PG-017 update: three fixes, required by the PG-016 audit. (1) The
// drafts release update is now an atomic compare-and-swap
// (`.neq('release_status', 'released')`) — a concurrent second release
// attempt on the same draft matches zero rows and fails safely, rather
// than asking the trigger to release an already-released draft twice.
// (2) The job-advancement update is likewise atomic
// (`.eq('current_stage', 'DESIGN_IN_PROGRESS').eq('status', 'active')`).
// (3) A `draft.release` audit_events row is now written — this function
// previously wrote none, one of the four transitions PG-016 flagged.
// The CAD release gate itself (enforce_draft_release_gate) is untouched.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
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
  if (!body?.draft_id) {
    return jsonResponse({ error: 'draft_id is required' }, 400);
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
    return jsonResponse({ error: 'Only a Designer or Super Admin may release a draft' }, 403);
  }

  const { data: draft, error: draftError } = await admin
    .from('drafts')
    .select('id, job_id, release_status')
    .eq('id', body.draft_id)
    .maybeSingle();
  if (draftError || !draft) {
    return jsonResponse({ error: 'Draft not found' }, 404);
  }
  if (draft.release_status === 'released') {
    return jsonResponse({ error: 'This draft is already released' }, 409);
  }

  // The actual gate — enforce_draft_release_gate() runs as part of this
  // UPDATE and will raise if an unresolved failure exists without
  // override_reason. That exception surfaces as updateError below,
  // unmodified.
  //
  // PG-017: `.neq('release_status', 'released')` makes this an atomic
  // compare-and-swap — a concurrent second release attempt on the same
  // draft matches zero rows and fails safely below, rather than the
  // trigger being asked to release an already-released draft twice.
  const { data: releasedDraft, error: updateError } = await admin
    .from('drafts')
    .update({
      release_status: 'released',
      override_reason: body.override_reason ?? null,
    })
    .eq('id', draft.id)
    .neq('release_status', 'released')
    .select()
    .maybeSingle();

  if (updateError) {
    return jsonResponse({ error: updateError.message }, 422);
  }
  if (!releasedDraft) {
    return jsonResponse({ error: 'This draft has already been released by another request' }, 409);
  }

  await admin.from('audit_events').insert({
    actor_user_id: userData.user.id,
    action: 'draft.release',
    entity_type: 'draft',
    entity_id: draft.id,
    before_state: { release_status: draft.release_status },
    after_state: { release_status: 'released' },
    reason: body.override_reason ?? null,
  });

  const { data: job, error: jobError } = await admin
    .from('jobs')
    .select('id, current_stage, status, job_ref, customer_id')
    .eq('id', draft.job_id)
    .maybeSingle();

  let jobAdvanced = false;
  if (!jobError && job) {
    // PG-017: atomic compare-and-swap — a concurrent call (e.g. two
    // drafts for the same job somehow both being released, or a retried
    // request) that finds the job no longer at DESIGN_IN_PROGRESS
    // matches zero rows and simply doesn't re-advance or re-run the
    // notification below.
    const { data: advancedJob, error: jobUpdateError } = await admin
      .from('jobs')
      .update({ current_stage: 'DESIGN_SENT_FOR_APPROVAL', stage_started_at: new Date().toISOString() })
      .eq('id', job.id)
      .eq('current_stage', 'DESIGN_IN_PROGRESS')
      .eq('status', 'active')
      .select()
      .maybeSingle();
    if (!jobUpdateError && advancedJob) {
      await admin.from('job_stage_history').insert({
        job_id: job.id,
        stage: 'DESIGN_SENT_FOR_APPROVAL',
        advanced_by: profile.id,
        note: `Draft ${draft.id} released`,
      });
      jobAdvanced = true;

      try {
        const { data: customer } = await admin
          .from('customers')
          .select('auth_user_id')
          .eq('id', job.customer_id)
          .maybeSingle();
        if (customer?.auth_user_id) {
          await notify(admin, {
            recipientUserId: customer.auth_user_id,
            type: 'design.ready_for_approval',
            title: 'Your design is ready',
            body: `${job.job_ref} is ready for your review.`,
            entityType: 'job',
            entityId: job.id,
          });
        }
      } catch (notifyError) {
        console.error('Notification failed:', notifyError);
      }
    }
  }

  return jsonResponse({ ok: true, release_status: 'released', job_advanced: jobAdvanced });
});
