// decide-quote-request
//
// Staff-only: accepts or declines a quote_request. This is the
// server-side mechanism behind the approved Intake screen's
// "Bill-and-open-job / Decline" actions — the screen itself (staff-facing
// mobile UI, approved design #12) is NOT built by this task. "Customer
// Job Flow" (PG-008) is customer-facing per its own name; Intake sits
// under the V1 bullet "Intake, queue, payments and design desk", grouped
// separately from "Quote request/intake" and "Eight-stage job tracking"
// — this function exists only because without SOME way to create a job,
// there is nothing for the customer-facing Jobs screen (this task's
// actual deliverable) to track. Flagged as a scope/task-boundary
// decision in docs/customer-job-flow.md, not a business-rule invention.
//
// Authorization mirrors quote_requests_update_staff_only (PG-005)
// exactly — Centre Manager scoped to their own branch, or any central
// staff role. Not a new or looser rule.
//
// quote_requests.status has no fixed value list anywhere in the docs
// (flagged since PG-003) — 'accepted' and 'declined' here are the same
// kind of minimal, clearly-flagged structural choice as jobs.status's
// active/on_hold/cancelled inference from PG-003, not a pricing/
// commercial invention. They only need to distinguish "decided" from
// "pending"; nothing about their exact spelling affects money.
//
// Accepting REQUIRES real pricing_rates/commercial_settings to be
// configured (same requirement issue-quote already enforces) — this
// function does not relax that in any way. If pricing isn't configured,
// accepting fails with the same honest reason, and no job is created.
//
// PG-012 update: both the accept and decline paths write an
// audit_events row — "operational actions must be audited" (PG-012's
// explicit requirement).
//
// PG-013 update: both paths also notify the customer (looked up via
// customers.auth_user_id, never a client-supplied recipient).
// Notification failures are swallowed — see _shared/notifier.ts — and
// never block the decision itself.
//
// PG-017 update: the accept path's quote_requests claim was moved to
// the START of the operation (atomic compare-and-swap on status='pending'),
// before any of the expensive downstream work (pricing, quote/job
// creation) — closing a real concurrency gap PG-016 identified, where
// the old version checked status non-atomically and only wrote the
// final quote_requests update LAST, leaving the entire creation
// sequence unprotected. If any downstream step now fails after the
// atomic claim succeeds, the claim is rolled back (status restored to
// 'pending') via a compensating update — see rollbackClaim() — rather
// than leaving the request stuck "accepted" with no job. The decline
// path got the same atomic-claim treatment for consistency, though it
// had no multi-step sequence to protect. No other logic changed; verify
// with git diff against e40dd8e.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { notify } from '../_shared/notifier.ts';
import { calculateQuote } from '../_shared/quote_calculator.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'Missing Authorization header' }, 401);
  }

  const body = await req.json().catch(() => null);
  if (!body?.quote_request_id || !body?.decision) {
    return jsonResponse({ error: 'quote_request_id and decision are required' }, 400);
  }
  if (body.decision !== 'accept' && body.decision !== 'decline') {
    return jsonResponse({ error: "decision must be 'accept' or 'decline'" }, 400);
  }
  if (body.decision === 'decline' && !body.decision_reason) {
    return jsonResponse({ error: 'decision_reason is required to decline' }, 400);
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
    .select('id, role, branch_id, active')
    .eq('id', userData.user.id)
    .maybeSingle();

  const { data: quoteRequest, error: qrError } = await admin
    .from('quote_requests')
    .select('*')
    .eq('id', body.quote_request_id)
    .maybeSingle();

  if (qrError || !quoteRequest) {
    return jsonResponse({ error: 'Quote request not found' }, 404);
  }

  const authorized =
    !!profile?.active &&
    (profile.role === 'centre_manager'
      ? profile.branch_id === quoteRequest.branch_id
      : ['super_admin', 'accountant', 'designer', 'production', 'inventory'].includes(profile.role));

  if (!authorized) {
    return jsonResponse({ error: 'Not authorized to decide this quote request' }, 403);
  }

  // PG-017: the atomic claim below (not this pre-check) is what actually
  // prevents two concurrent decisions on the same quote_request — kept
  // for a fast, friendly error in the common (non-racing) case.
  if (quoteRequest.status !== 'pending') {
    return jsonResponse({ error: `This quote request has already been decided (status: ${quoteRequest.status})` }, 409);
  }

  if (body.decision === 'decline') {
    // Atomic compare-and-swap: only succeeds if status is still exactly
    // 'pending' at the moment of this UPDATE. A concurrent second
    // request (accept or decline) matches zero rows and fails safely
    // below.
    const { data: claimed, error: updateError } = await admin
      .from('quote_requests')
      .update({
        status: 'declined',
        decision_reason: body.decision_reason,
        decided_by: userData.user.id,
        decided_at: new Date().toISOString(),
      })
      .eq('id', quoteRequest.id)
      .eq('status', 'pending')
      .select()
      .maybeSingle();
    if (updateError) return jsonResponse({ error: updateError.message }, 500);
    if (!claimed) {
      return jsonResponse({ error: 'This quote request has already been decided by another request' }, 409);
    }

    await admin.from('audit_events').insert({
      actor_user_id: userData.user.id,
      action: 'quote_request.decline',
      entity_type: 'quote_request',
      entity_id: quoteRequest.id,
      before_state: { status: 'pending' },
      after_state: { status: 'declined' },
      reason: body.decision_reason,
    });

    try {
      const { data: declinedCustomer } = await admin
        .from('customers')
        .select('auth_user_id')
        .eq('id', quoteRequest.customer_id)
        .maybeSingle();
      if (declinedCustomer?.auth_user_id) {
        await notify(admin, {
          recipientUserId: declinedCustomer.auth_user_id,
          type: 'quote_request.declined',
          title: 'Your request was declined',
          body: body.decision_reason,
          entityType: 'quote_request',
          entityId: quoteRequest.id,
        });
      }
    } catch (notifyError) {
      console.error('Notification failed:', notifyError);
    }

    return jsonResponse({ ok: true, status: 'declined' });
  }

  // Accept: claim the quote_request FIRST, atomically, before doing any
  // of the more expensive downstream work (pricing, quote/job
  // creation). This is what actually closes the concurrency gap PG-016
  // identified — the older version of this function checked status
  // non-atomically and only updated quote_requests LAST, which left the
  // entire quote/job creation sequence unprotected against a race.
  //
  // If any downstream step fails after this claim succeeds, the claim
  // is rolled back (status restored to 'pending') so the request isn't
  // left stuck "accepted" with no job — see rollbackClaim() below. This
  // is a compensating action, not a real multi-statement transaction
  // (PostgREST doesn't expose one to this function) — the best available
  // correctness guarantee given that constraint.
  const { data: claimed, error: claimError } = await admin
    .from('quote_requests')
    .update({
      status: 'accepted',
      decided_by: userData.user.id,
      decided_at: new Date().toISOString(),
    })
    .eq('id', quoteRequest.id)
    .eq('status', 'pending')
    .select()
    .maybeSingle();
  if (claimError) return jsonResponse({ error: claimError.message }, 500);
  if (!claimed) {
    return jsonResponse({ error: 'This quote request has already been decided by another request' }, 409);
  }

  const rollbackClaim = async () => {
    await admin
      .from('quote_requests')
      .update({ status: 'pending', decided_by: null, decided_at: null })
      .eq('id', quoteRequest.id);
  };

  // Issue the quote (same logic as issue-quote — inlined rather than an
  // HTTP call between functions) then create the job.
  const result = await calculateQuote(admin, {
    materialId: quoteRequest.material_id,
    finishId: quoteRequest.finish_id,
    thicknessMm: quoteRequest.thickness_mm,
    widthMm: quoteRequest.width_mm,
    heightMm: quoteRequest.height_mm,
    quantity: quoteRequest.quantity,
  });

  if (!result.available) {
    await rollbackClaim();
    return jsonResponse({ error: result.reason }, 422);
  }

  const { data: existingVersions } = await admin
    .from('quotes')
    .select('version')
    .eq('quote_request_id', quoteRequest.id)
    .order('version', { ascending: false })
    .limit(1);
  const nextVersion = existingVersions && existingVersions.length > 0 ? existingVersions[0].version + 1 : 1;

  const { data: quoteRef, error: refError } = await admin.rpc('generate_quote_ref_provisional');
  if (refError) {
    await rollbackClaim();
    return jsonResponse({ error: refError.message }, 500);
  }

  const { data: quote, error: quoteInsertError } = await admin
    .from('quotes')
    .insert({
      quote_ref: quoteRef,
      quote_request_id: quoteRequest.id,
      version: nextVersion,
      material_cost_kobo: result.materialCostKobo,
      cutting_cost_kobo: result.cuttingCostKobo,
      finishing_cost_kobo: result.finishingCostKobo,
      labour_cost_kobo: result.labourCostKobo,
      wastage_cost_kobo: result.wastageCostKobo,
      delivery_cost_kobo: result.deliveryCostKobo,
      installation_cost_kobo: result.installationCostKobo,
      discount_kobo: result.discountKobo,
      vat_kobo: result.vatKobo,
      subtotal_kobo: result.subtotalKobo,
      total_kobo: result.totalKobo,
      deposit_kobo: result.depositKobo,
      balance_kobo: result.balanceKobo,
      sheet_count: result.sheetCount,
      estimated_cut_minutes: result.estimatedCutMinutes,
      pricing_snapshot: result.pricingSnapshot,
    })
    .select()
    .single();

  if (quoteInsertError) {
    await rollbackClaim();
    return jsonResponse({ error: quoteInsertError.message }, 500);
  }

  const { data: job, error: jobInsertError } = await admin
    .from('jobs')
    .insert({
      customer_id: quoteRequest.customer_id,
      branch_id: quoteRequest.branch_id,
      quote_id: quote.id,
      pattern_id: quoteRequest.pattern_id,
      blend_id: quoteRequest.blend_id,
      material_id: quoteRequest.material_id,
      thickness_mm: quoteRequest.thickness_mm,
      width_mm: quoteRequest.width_mm,
      height_mm: quoteRequest.height_mm,
      finish_id: quoteRequest.finish_id,
    })
    .select()
    .single();

  if (jobInsertError) {
    await rollbackClaim();
    return jsonResponse({ error: jobInsertError.message }, 500);
  }

  await admin.from('job_stage_history').insert({
    job_id: job.id,
    stage: 'SUBMITTED',
    advanced_by: userData.user.id,
    note: 'Job opened from accepted quote request',
  });

  await admin.from('audit_events').insert({
    actor_user_id: userData.user.id,
    action: 'quote_request.accept',
    entity_type: 'quote_request',
    entity_id: quoteRequest.id,
    before_state: { status: 'pending' },
    after_state: { status: 'accepted', job_id: job.id },
  });

  try {
    const { data: acceptedCustomer } = await admin
      .from('customers')
      .select('auth_user_id')
      .eq('id', quoteRequest.customer_id)
      .maybeSingle();
    if (acceptedCustomer?.auth_user_id) {
      await notify(admin, {
        recipientUserId: acceptedCustomer.auth_user_id,
        type: 'quote_request.accepted',
        title: 'Your request was accepted',
        body: `Job ${job.job_ref} has been opened.`,
        entityType: 'job',
        entityId: job.id,
      });
    }
  } catch (notifyError) {
    console.error('Notification failed:', notifyError);
  }

  return jsonResponse({ ok: true, status: 'accepted', quote, job });
});
