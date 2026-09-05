// confirm-payment
//
// The highest-security function in this task. CLAUDE.md: "NO MATCH
// cannot be confirmed automatically. Accountant confirmation requires a
// fresh challenge." The approved design's "Accountant PIN gate" screen
// (#18) is literally this: "job reference, explanation that only the
// accountant may confirm, masked PIN, inline error." Restricted to role
// = 'accountant' ONLY — not Super Admin — matching that screen's own
// copy ("only the accountant may confirm") literally, not the broader
// "accountant or super_admin" pattern used elsewhere in this codebase.
//
// "Fresh challenge" is implemented as a genuine re-authentication, not
// just checking the caller still has a valid session token: this
// function attempts a brand-new signInWithPassword using the caller's
// own auth_login_handle and the PIN supplied in THIS request. If that
// fails, the PIN is wrong right now, regardless of whether their
// existing session is still valid — this is what makes it a "fresh"
// challenge rather than a reused one.
//
// Allowed from 'matched' OR 'no_match' — CLAUDE.md's exact wording is
// "cannot be confirmed automatically," which implies manual, deliberate
// confirmation of a no_match case IS allowed (e.g. the accountant
// verified out-of-band that a payment which didn't auto-match is
// actually valid). This is not a relaxation of "no client-side payment
// confirmation" — the client still can't set status directly; this
// function's own authorization + fresh-challenge gate is the only path,
// exactly as for 'matched'.
//
// On confirming a 'deposit' payment for a job still at SUBMITTED, this
// advances the job to PAYMENT_CONFIRMED — Master Spec §13's own flow
// diagram: "Payment Confirmation Workflow → PGJO → Job Progression."
// Implementing that explicitly-given sequence, not inventing a new one.
// PG-011 update: a PGJO document is now generated here, once, when the
// deposit is confirmed and the job actually advances — see
// generateDocument() in _shared/document_generator.ts for what data it
// contains (all queried fresh, nothing passed through from this
// function's own state) and how it stays idempotent under a retried
// call. Document generation is wrapped so a failure there never rolls
// back or blocks the payment confirmation itself, which has already
// fully succeeded by that point — a secondary audit artifact failing to
// generate must not undo a real, confirmed financial transaction.
//
// PG-013 update: the customer is also notified once confirmation and
// document generation both attempt to complete — same swallowed-failure
// treatment, a notification failure never undoes the payment.
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying — this is the one
// function in this task where a subtle bug has direct financial
// consequences.
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
  if (!body?.payment_id || !body?.pin) {
    return jsonResponse({ error: 'payment_id and pin are required' }, 400);
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
    .select('id, role, active, auth_login_handle')
    .eq('id', userData.user.id)
    .maybeSingle();

  if (!profile?.active || profile.role !== 'accountant') {
    return jsonResponse({ error: 'Only the Accountant may confirm a payment' }, 403);
  }

  // Fresh challenge: a brand-new sign-in attempt with the PIN supplied
  // in THIS request, using a client that shares no state with the
  // caller's existing session.
  const challengeClient = createClient(supabaseUrl, anonKey);
  const { error: challengeError } = await challengeClient.auth.signInWithPassword({
    email: profile.auth_login_handle,
    password: body.pin,
  });
  if (challengeError) {
    return jsonResponse({ error: 'Incorrect PIN' }, 401);
  }

  const { data: payment, error: paymentError } = await admin
    .from('payments')
    .select('id, job_id, kind, status')
    .eq('id', body.payment_id)
    .maybeSingle();
  if (paymentError || !payment) {
    return jsonResponse({ error: 'Payment not found' }, 404);
  }
  if (payment.status !== 'matched' && payment.status !== 'no_match') {
    return jsonResponse(
      { error: `This payment is ${payment.status} — only 'matched' or 'no_match' payments can be confirmed` },
      409,
    );
  }

  const { error: updateError } = await admin
    .from('payments')
    .update({
      status: 'confirmed',
      confirmed_by: profile.id,
      confirmed_at: new Date().toISOString(),
    })
    .eq('id', payment.id);
  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }

  let jobAdvanced = false;
  if (payment.kind === 'deposit') {
    const { data: job } = await admin
      .from('jobs')
      .select('id, current_stage, job_ref, customer_id')
      .eq('id', payment.job_id)
      .maybeSingle();
    if (job?.current_stage === 'SUBMITTED') {
      const { error: jobUpdateError } = await admin
        .from('jobs')
        .update({ current_stage: 'PAYMENT_CONFIRMED', stage_started_at: new Date().toISOString() })
        .eq('id', job.id);
      if (!jobUpdateError) {
        await admin.from('job_stage_history').insert({
          job_id: job.id,
          stage: 'PAYMENT_CONFIRMED',
          advanced_by: profile.id,
          note: `Deposit payment ${payment.id} confirmed`,
        });
        jobAdvanced = true;

        try {
          await generateDocument(admin, {
            jobId: job.id,
            type: 'PGJO',
            eventKey: `PGJO-${job.id}`,
            authorisedBy: profile.id,
            authorisationType: 'accountant_confirmation',
          });
        } catch (docError) {
          // Deliberately swallowed — see the header comment. The
          // payment is already confirmed; a document-generation failure
          // is logged, not propagated as an error on this response.
          console.error('PGJO generation failed:', docError);
        }

        try {
          const { data: customer } = await admin
            .from('customers')
            .select('auth_user_id')
            .eq('id', job.customer_id)
            .maybeSingle();
          if (customer?.auth_user_id) {
            await notify(admin, {
              recipientUserId: customer.auth_user_id,
              type: 'payment.confirmed',
              title: 'Payment confirmed',
              body: `Your deposit for ${job.job_ref} has been confirmed.`,
              entityType: 'job',
              entityId: job.id,
            });
          }
        } catch (notifyError) {
          console.error('Notification failed:', notifyError);
        }
      }
    }
  }

  return jsonResponse({ ok: true, status: 'confirmed', job_advanced: jobAdvanced });
});
