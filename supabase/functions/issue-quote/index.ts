// issue-quote
//
// Authenticated. Given an existing `quote_request_id`, computes and
// persists an immutable, versioned `quotes` row — this is the
// service_role-backed write path that `quotes`' PG-005 RLS deliberately
// has no client INSERT policy for ("Client cannot alter authoritative
// price"). Authorization here mirrors quote_requests_select_own_or_staff
// exactly (20260904000018_rls_sketches_quoting.sql) rather than
// inventing a different rule for who may request a quote be issued.
//
// Until pricing_rates/commercial_settings are populated, this ALWAYS
// returns a 422 with a clear reason and creates NO row — never a
// fabricated price. See _shared/quote_calculator.ts.
//
// Versioning: Master Spec §10 — "Issued quotes retain immutable pricing
// snapshots" and quotes has `unique (quote_request_id, version)`. This
// function always inserts the next version for the given
// quote_request_id; it never updates an existing quotes row (matching
// "immutable").
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
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
  if (!body?.quote_request_id) {
    return jsonResponse({ error: 'quote_request_id is required' }, 400);
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

  const { data: quoteRequest, error: qrError } = await admin
    .from('quote_requests')
    .select('id, customer_id, branch_id, material_id, finish_id, thickness_mm, width_mm, height_mm, quantity')
    .eq('id', body.quote_request_id)
    .maybeSingle();

  if (qrError || !quoteRequest) {
    return jsonResponse({ error: 'Quote request not found' }, 404);
  }

  const authorized = await isAuthorized(admin, userData.user.id, quoteRequest);
  if (!authorized) {
    return jsonResponse({ error: 'Not authorized to issue a quote for this request' }, 403);
  }

  const result = await calculateQuote(admin, {
    materialId: quoteRequest.material_id,
    finishId: quoteRequest.finish_id,
    thicknessMm: quoteRequest.thickness_mm,
    widthMm: quoteRequest.width_mm,
    heightMm: quoteRequest.height_mm,
    quantity: quoteRequest.quantity,
    urgency: body.urgency ?? null,
    customerType: body.customer_type ?? null,
  });

  if (!result.available) {
    return jsonResponse({ error: result.reason }, 422);
  }

  const { data: existingVersions } = await admin
    .from('quotes')
    .select('version')
    .eq('quote_request_id', quoteRequest.id)
    .order('version', { ascending: false })
    .limit(1);
  const nextVersion = existingVersions && existingVersions.length > 0 ? existingVersions[0].version + 1 : 1;

  const { data: refData, error: refError } = await admin.rpc('generate_quote_ref_provisional');
  if (refError) {
    return jsonResponse({ error: refError.message }, 500);
  }

  const { data: inserted, error: insertError } = await admin
    .from('quotes')
    .insert({
      quote_ref: refData,
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

  if (insertError) {
    return jsonResponse({ error: insertError.message }, 500);
  }

  return jsonResponse({ quote: inserted });
});

// Mirrors quote_requests_select_own_or_staff (PG-005) exactly — the
// same people who can SEE a quote_request are the ones who may trigger
// pricing it, no broader and no narrower.
async function isAuthorized(
  // deno-lint-ignore no-explicit-any
  admin: any,
  callerId: string,
  quoteRequest: { customer_id: string; branch_id: string },
): Promise<boolean> {
  const { data: customer } = await admin
    .from('customers')
    .select('id')
    .eq('auth_user_id', callerId)
    .eq('id', quoteRequest.customer_id)
    .maybeSingle();
  if (customer) return true;

  const { data: profile } = await admin
    .from('profiles')
    .select('role, branch_id, active')
    .eq('id', callerId)
    .maybeSingle();
  if (!profile?.active) return false;

  if (profile.role === 'centre_manager') {
    return profile.branch_id === quoteRequest.branch_id;
  }
  return ['super_admin', 'accountant', 'designer', 'production', 'inventory'].includes(profile.role);
}
