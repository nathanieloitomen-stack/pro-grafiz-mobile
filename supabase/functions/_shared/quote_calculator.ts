// Shared quote-calculation core for the PG-007 quote engine.
//
// Every actual RATE VALUE this reads comes from `pricing_rates` /
// `commercial_settings` (PG-007 migration 20260904000027) — both
// created empty, on purpose. This file contains the ARITHMETIC that
// combines those rates (sum of cost components, VAT = base × rate,
// deposit = total × rate) — standard, uncontroversial financial
// mechanics, not a business-specific invention. What IS a judgment
// call, made here and flagged for confirmation rather than presented
// as settled (see docs/quote-engine.md):
//
//   - Cutting and finishing are billed by AREA, not true cut length —
//     real nesting/geometry is V2 scope (Master Spec §6), yet §12 lists
//     sheet count/cut time as V1 outputs. This is a genuine spec
//     conflict, not resolved unilaterally here.
//   - Labour is a flat per-job rate, not area-scaled.
//   - Discount is always 0 — no promo/discount-code or customer-tier
//     mechanism exists anywhere in the schema or docs.
//   - "urgency" and "customer_type" inputs are accepted and recorded in
//     the pricing snapshot for future reference, but never affect price
//     — no rate impact for either is specified anywhere.
//   - Sheet count / estimated cut minutes are computed ONLY if
//     standard_sheet_width_mm, standard_sheet_height_mm, and
//     cutting_speed_sqm_per_minute are ALL configured; otherwise left
//     null, which is an honest "not computable yet", not a guess.
//
// UNTESTED: written without a live Supabase project, network, or Deno
// runtime available. Review before deploying.

export interface QuoteSpec {
  materialId: string;
  finishId: string;
  thicknessMm: number;
  widthMm: number;
  heightMm: number;
  quantity: number;
  urgency?: string | null;
  customerType?: string | null;
}

export interface QuoteCalculationResult {
  available: boolean;
  reason?: string;
  areaSqm?: number;
  materialCostKobo?: number;
  cuttingCostKobo?: number;
  finishingCostKobo?: number;
  labourCostKobo?: number;
  wastageCostKobo?: number;
  deliveryCostKobo?: number;
  installationCostKobo?: number;
  discountKobo?: number;
  vatKobo?: number;
  subtotalKobo?: number;
  totalKobo?: number;
  depositKobo?: number;
  balanceKobo?: number;
  sheetCount?: number | null;
  estimatedCutMinutes?: number | null;
  pricingSnapshot?: Record<string, unknown>;
}

interface PricingRateRow {
  material_rate_per_sqm_kobo: number | null;
  cutting_rate_per_sqm_kobo: number | null;
  finishing_rate_per_sqm_kobo: number | null;
  labour_rate_kobo: number | null;
  wastage_percent: number | null;
}

// deno-lint-ignore no-explicit-any
type SupabaseClientLike = any;

export async function calculateQuote(
  supabase: SupabaseClientLike,
  spec: QuoteSpec,
): Promise<QuoteCalculationResult> {
  const { data: rateRow, error: rateError } = await supabase
    .from('pricing_rates')
    .select('material_rate_per_sqm_kobo, cutting_rate_per_sqm_kobo, finishing_rate_per_sqm_kobo, labour_rate_kobo, wastage_percent')
    .eq('material_id', spec.materialId)
    .eq('finish_id', spec.finishId)
    .eq('active', true)
    .maybeSingle();

  if (rateError) {
    return { available: false, reason: `Could not look up pricing: ${rateError.message}` };
  }

  const rates = rateRow as PricingRateRow | null;
  if (!rates || rates.material_rate_per_sqm_kobo == null) {
    return {
      available: false,
      reason:
        'No pricing configured for this material/finish combination yet. ' +
        'A Super Admin must add a row to pricing_rates before this can be priced.',
    };
  }

  const settings = await fetchSettings(supabase, ['vat_percent', 'deposit_percent', 'delivery_flat_kobo', 'installation_flat_kobo', 'standard_sheet_width_mm', 'standard_sheet_height_mm', 'cutting_speed_sqm_per_minute']);

  if (settings.vat_percent == null || settings.deposit_percent == null) {
    return {
      available: false,
      reason:
        'Material/finish pricing exists, but commercial_settings is missing ' +
        'vat_percent and/or deposit_percent — both are required before any ' +
        'quote can be issued. A Super Admin must configure these first.',
    };
  }

  const areaSqm = (spec.widthMm / 1000) * (spec.heightMm / 1000) * spec.quantity;

  const materialCostKobo = round(areaSqm * rates.material_rate_per_sqm_kobo);
  const cuttingCostKobo = round(areaSqm * (rates.cutting_rate_per_sqm_kobo ?? 0));
  const finishingCostKobo = round(areaSqm * (rates.finishing_rate_per_sqm_kobo ?? 0));
  const labourCostKobo = round(rates.labour_rate_kobo ?? 0);
  const wastageCostKobo = round(materialCostKobo * ((rates.wastage_percent ?? 0) / 100));
  const deliveryCostKobo = round(settings.delivery_flat_kobo ?? 0);
  const installationCostKobo = round(settings.installation_flat_kobo ?? 0);
  // No discount mechanism exists anywhere in the schema or docs
  // (no promo codes, no customer-tier rule) — always 0, an honest
  // absence rather than an invented one.
  const discountKobo = 0;

  const subtotalKobo =
    materialCostKobo +
    cuttingCostKobo +
    finishingCostKobo +
    labourCostKobo +
    wastageCostKobo +
    deliveryCostKobo +
    installationCostKobo -
    discountKobo;

  const vatKobo = round(subtotalKobo * (settings.vat_percent / 100));
  const totalKobo = subtotalKobo + vatKobo;
  const depositKobo = round(totalKobo * (settings.deposit_percent / 100));
  const balanceKobo = totalKobo - depositKobo;

  let sheetCount: number | null = null;
  let estimatedCutMinutes: number | null = null;
  if (settings.standard_sheet_width_mm && settings.standard_sheet_height_mm) {
    const sheetAreaSqm = (settings.standard_sheet_width_mm / 1000) * (settings.standard_sheet_height_mm / 1000);
    if (sheetAreaSqm > 0) {
      sheetCount = Math.ceil(areaSqm / sheetAreaSqm);
    }
  }
  if (settings.cutting_speed_sqm_per_minute && settings.cutting_speed_sqm_per_minute > 0) {
    estimatedCutMinutes = round2(areaSqm / settings.cutting_speed_sqm_per_minute);
  }

  return {
    available: true,
    areaSqm: round2(areaSqm),
    materialCostKobo,
    cuttingCostKobo,
    finishingCostKobo,
    labourCostKobo,
    wastageCostKobo,
    deliveryCostKobo,
    installationCostKobo,
    discountKobo,
    vatKobo,
    subtotalKobo,
    totalKobo,
    depositKobo,
    balanceKobo,
    sheetCount,
    estimatedCutMinutes,
    pricingSnapshot: {
      spec,
      rates,
      settings,
      computed_at: new Date().toISOString(),
      formula_version: 1,
    },
  };
}

async function fetchSettings(supabase: SupabaseClientLike, keys: string[]): Promise<Record<string, number | null>> {
  const { data, error } = await supabase.from('commercial_settings').select('key, value').in('key', keys);
  const result: Record<string, number | null> = {};
  for (const key of keys) result[key] = null;
  if (error || !data) return result;
  for (const row of data as { key: string; value: number }[]) {
    result[row.key] = row.value;
  }
  return result;
}

function round(n: number): number {
  return Math.round(n);
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}
