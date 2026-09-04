// estimate-quote
//
// Public / anon-callable. Powers a live ₦ estimate while a customer is
// configuring a design (the part of approved screen #6, "Quote
// builder", that PG-006 deliberately left out — see docs/catalogue.md).
// Pure calculation, no database writes at all — nothing here creates a
// quote_request or a quote. Deliberately public: browsing a live
// estimate while configuring shouldn't require signing in, matching the
// same "browse before commit" philosophy PG-006 already applied to
// catalogue browsing.
//
// Until pricing_rates/commercial_settings are populated by a Super
// Admin, this ALWAYS returns { available: false, reason: "..." } —
// never a fabricated number. See _shared/quote_calculator.ts for the
// full reasoning.
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

  const body = await req.json().catch(() => null);
  if (!body?.material_id || !body?.finish_id || !body?.width_mm || !body?.height_mm) {
    return jsonResponse({ error: 'material_id, finish_id, width_mm and height_mm are required' }, 400);
  }

  const quantity = Number(body.quantity ?? 1);
  if (!Number.isInteger(quantity) || quantity < 1) {
    return jsonResponse({ error: 'quantity must be a positive integer' }, 400);
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const result = await calculateQuote(supabase, {
    materialId: body.material_id,
    finishId: body.finish_id,
    thicknessMm: Number(body.thickness_mm ?? 0),
    widthMm: Number(body.width_mm),
    heightMm: Number(body.height_mm),
    quantity,
    urgency: body.urgency ?? null,
    customerType: body.customer_type ?? null,
  });

  // This endpoint is anon-callable by design (see header comment) — the
  // pricing_snapshot's `rates` field carries raw pricing_rates values
  // (competitively sensitive; that table has no customer/anon SELECT
  // policy at all), so it must never appear in a public response even
  // though it's fine to persist as part of an actual issued quote via
  // issue-quote. Strip it here rather than changing what
  // calculateQuote() returns, since issue-quote's persisted snapshot
  // legitimately needs the full detail for audit purposes.
  const { pricingSnapshot: _omit, ...publicResult } = result;

  return jsonResponse(publicResult);
});
