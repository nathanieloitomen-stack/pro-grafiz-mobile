// respond-to-design
//
// Customer-only: "Approve" or "Request a change" on their own job's
// design, per approved screen #7's approval card. This is the specific
// server-side transition service Master Spec §9 requires ("Use a
// server-side transition service. Do not allow arbitrary current-stage
// updates.") — jobs has zero client write policies (PG-005), so this
// function, using the service-role key, is the only way these two
// customer-triggered transitions can happen.
//
// Transition mapping used here: DESIGN_SENT_FOR_APPROVAL -> IN_PRODUCTION
// (approve) or DESIGN_SENT_FOR_APPROVAL -> DESIGN_IN_PROGRESS
// (request a change, alongside creating a design_revisions row). Both
// stage names and their order are given explicitly in Master Spec §9 —
// this is implementing the specified state machine, not inventing a new
// one. What direction "request a change" reverts to is this function's
// own reasonable reading (the design has to go back to being worked on),
// not stated verbatim anywhere — flagged in docs/customer-job-flow.md.
//
// Approve additionally requires the job to have a released draft
// (drafts.release_status = 'released') — approving a design that was
// never actually released would be inconsistent with the CAD release
// gate PG-005 already enforces (enforce_draft_release_gate trigger).
//
// PG-011 update: approving now also generates a PGAO document (once,
// idempotently) — see _shared/document_generator.ts. Generation is
// wrapped so a failure there never undoes the approval itself, which
// has already fully succeeded by that point.
//
// PG-013 update: requesting a change notifies whoever created the
// job's most recent draft (drafts.created_by, a profiles.id — usable
// directly as a recipient since profiles.id = auth.users.id). Matches
// Master Spec §16's "design change requested" event. No approve-side
// notification was added here — that event ("design ready"/"approval
// requested") is already covered at its actual source, release-draft.
//
// PG-017 update: three fixes, required by the PG-016 audit, applied to
// BOTH branches (approve and request_change). (1) Each branch's job
// stage update is now an atomic compare-and-swap
// (`.eq('current_stage', 'DESIGN_SENT_FOR_APPROVAL').eq('status', 'active')`
// in the same statement as `.update()`) — a concurrent second response
// to the same job (e.g. approve and request_change racing, or the same
// action retried) matches zero rows and fails safely rather than both
// proceeding. (2) `job.approve_design` / `job.request_design_change`
// audit_events rows are now written for each branch — this function
// previously wrote none, one of the four transitions PG-016 flagged.
// (3) No change to the approve path's released-draft precondition, the
// request_change path's design_revisions insert, or any notification/
// document logic — verify with git diff.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { generateDocument } from '../_shared/document_generator.ts';
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
  if (!body?.job_id || !body?.action) {
    return jsonResponse({ error: 'job_id and action are required' }, 400);
  }
  if (body.action !== 'approve' && body.action !== 'request_change') {
    return jsonResponse({ error: "action must be 'approve' or 'request_change'" }, 400);
  }
  if (body.action === 'request_change' && !body.request_note) {
    return jsonResponse({ error: 'request_note is required for request_change' }, 400);
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
    return jsonResponse({ error: 'Only the owning customer may respond to a design' }, 403);
  }

  const { data: job, error: jobError } = await admin
    .from('jobs')
    .select('id, customer_id, current_stage, status')
    .eq('id', body.job_id)
    .maybeSingle();

  if (jobError || !job) {
    return jsonResponse({ error: 'Job not found' }, 404);
  }
  if (job.customer_id !== customer.id) {
    return jsonResponse({ error: 'This job does not belong to you' }, 403);
  }
  if (job.status !== 'active') {
    return jsonResponse({ error: `This job is currently ${job.status}, not active` }, 409);
  }
  if (job.current_stage !== 'DESIGN_SENT_FOR_APPROVAL') {
    return jsonResponse(
      { error: `This job is at stage ${job.current_stage} — a design response is only valid at DESIGN_SENT_FOR_APPROVAL` },
      409,
    );
  }

  if (body.action === 'approve') {
    const { data: releasedDraft } = await admin
      .from('drafts')
      .select('id')
      .eq('job_id', job.id)
      .eq('release_status', 'released')
      .limit(1)
      .maybeSingle();
    if (!releasedDraft) {
      return jsonResponse({ error: 'No released design found for this job yet — cannot approve.' }, 422);
    }

    const nextStage = 'IN_PRODUCTION';
    // PG-017: atomic compare-and-swap — a concurrent second
    // approve/request_change call on the same job matches zero rows and
    // fails safely below, rather than both racing to transition it.
    const { data: updatedJob, error: updateError } = await admin
      .from('jobs')
      .update({ current_stage: nextStage, stage_started_at: new Date().toISOString() })
      .eq('id', job.id)
      .eq('current_stage', 'DESIGN_SENT_FOR_APPROVAL')
      .eq('status', 'active')
      .select()
      .maybeSingle();
    if (updateError) return jsonResponse({ error: updateError.message }, 500);
    if (!updatedJob) {
      return jsonResponse(
        { error: 'This job is no longer at DESIGN_SENT_FOR_APPROVAL (already responded to by another request)' },
        409,
      );
    }

    await admin.from('job_stage_history').insert({
      job_id: job.id,
      stage: nextStage,
      customer_action: 'approved',
    });

    await admin.from('audit_events').insert({
      actor_user_id: userData.user.id,
      action: 'job.approve_design',
      entity_type: 'job',
      entity_id: job.id,
      before_state: { current_stage: 'DESIGN_SENT_FOR_APPROVAL' },
      after_state: { current_stage: nextStage },
    });

    try {
      await generateDocument(admin, {
        jobId: job.id,
        type: 'PGAO',
        eventKey: `PGAO-${job.id}`,
        authorisedBy: null, // customer, not a profiles row — see PG-003's flagged gap
        authorisationType: 'customer_approval',
      });
    } catch (docError) {
      // Deliberately swallowed — see header comment. The approval is
      // already recorded; a document-generation failure is logged, not
      // propagated as an error on this response.
      console.error('PGAO generation failed:', docError);
    }

    return jsonResponse({ ok: true, current_stage: nextStage });
  }

  // request_change
  const { error: revisionError } = await admin.from('design_revisions').insert({
    job_id: job.id,
    revision_no: await nextRevisionNumber(admin, job.id),
    request_note: body.request_note,
    requested_by: null, // customer, not a profiles row — see PG-003's flagged gap
  });
  if (revisionError) return jsonResponse({ error: revisionError.message }, 500);

  const nextStage = 'DESIGN_IN_PROGRESS';
  // PG-017: same atomic compare-and-swap as the approve branch above.
  const { data: revertedJob, error: updateError } = await admin
    .from('jobs')
    .update({ current_stage: nextStage, stage_started_at: new Date().toISOString() })
    .eq('id', job.id)
    .eq('current_stage', 'DESIGN_SENT_FOR_APPROVAL')
    .eq('status', 'active')
    .select()
    .maybeSingle();
  if (updateError) return jsonResponse({ error: updateError.message }, 500);
  if (!revertedJob) {
    return jsonResponse(
      { error: 'This job is no longer at DESIGN_SENT_FOR_APPROVAL (already responded to by another request)' },
      409,
    );
  }

  await admin.from('job_stage_history').insert({
    job_id: job.id,
    stage: nextStage,
    customer_action: 'requested_change',
    note: body.request_note,
  });

  await admin.from('audit_events').insert({
    actor_user_id: userData.user.id,
    action: 'job.request_design_change',
    entity_type: 'job',
    entity_id: job.id,
    before_state: { current_stage: 'DESIGN_SENT_FOR_APPROVAL' },
    after_state: { current_stage: nextStage },
    reason: body.request_note,
  });

  try {
    const { data: latestDraft } = await admin
      .from('drafts')
      .select('created_by')
      .eq('job_id', job.id)
      .order('version', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (latestDraft?.created_by) {
      await notify(admin, {
        recipientUserId: latestDraft.created_by,
        type: 'design.change_requested',
        title: 'Change requested',
        body: body.request_note,
        entityType: 'job',
        entityId: job.id,
      });
    }
  } catch (notifyError) {
    console.error('Notification failed:', notifyError);
  }

  return jsonResponse({ ok: true, current_stage: nextStage });
});

// deno-lint-ignore no-explicit-any
async function nextRevisionNumber(admin: any, jobId: string): Promise<number> {
  const { data } = await admin
    .from('design_revisions')
    .select('revision_no')
    .eq('job_id', jobId)
    .order('revision_no', { ascending: false })
    .limit(1);
  return data && data.length > 0 ? data[0].revision_no + 1 : 1;
}
