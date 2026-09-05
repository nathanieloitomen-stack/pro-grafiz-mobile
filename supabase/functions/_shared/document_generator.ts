// Shared PGJO/PGAO document generation core for PG-011.
//
// Every field in the generated document is read directly from the
// database in this file — nothing is passed in from a caller as
// free-form content, and nothing is invented. This is the concrete
// mechanism behind "documents must reflect the actual underlying
// record."
//
// FORMAT DECISION (flagged, not specified anywhere in the docs): these
// are generated as HTML, not PDF. Master Spec gives the data fields on
// `documents` and requires idempotent generation, but never specifies a
// file format. A real PDF-generation library was not used because none
// is verified to work correctly in the Supabase Edge Function (Deno)
// runtime in this environment — HTML is a genuine, valid, printable
// file format servable directly from Storage, and the query logic below
// (which is the actual authoritative-data-sourcing work) is unaffected
// by whatever rendering layer eventually replaces this. See
// docs/documents.md for the full reasoning.
//
// IDEMPOTENCY: `documents.event_key` (PG-003) is UNIQUE. This function
// checks for an existing document by event_key FIRST, before doing any
// query, rendering, or Storage upload — a retried call is a true no-op,
// not just a caught duplicate-key error. Callers pass a deterministic
// event_key derived from the job and document type (one PGJO and one
// PGAO per job, matching the single occurrence of each in Master Spec's
// customer journey diagram).
//
// UNTESTED: written without a live Supabase project or network access
// to verify against. Review before deploying.

const BUCKET = 'job-documents';

// deno-lint-ignore no-explicit-any
type SupabaseClientLike = any;

export interface GenerateDocumentParams {
  jobId: string;
  type: 'PGJO' | 'PGAO';
  eventKey: string;
  authorisedBy: string | null;
  authorisationType: string;
}

export async function generateDocument(admin: SupabaseClientLike, params: GenerateDocumentParams) {
  const { data: existing } = await admin
    .from('documents')
    .select('*')
    .eq('event_key', params.eventKey)
    .maybeSingle();
  if (existing) {
    return { document: existing, created: false };
  }

  const context = await loadJobContext(admin, params.jobId);
  if (!context) {
    throw new Error(`Cannot generate ${params.type}: job ${params.jobId} or its related records were not found`);
  }

  const html =
    params.type === 'PGJO' ? await renderPgjo(admin, context) : await renderPgao(admin, context);

  const path = `${params.type.toLowerCase()}/${params.jobId}.html`;
  const { error: uploadError } = await admin.storage
    .from(BUCKET)
    .upload(path, new Blob([html], { type: 'text/html' }), { upsert: true, contentType: 'text/html' });
  if (uploadError) {
    throw new Error(`Failed to store ${params.type} document: ${uploadError.message}`);
  }

  const { data: inserted, error: insertError } = await admin
    .from('documents')
    .insert({
      job_id: params.jobId,
      type: params.type,
      event_key: params.eventKey,
      storage_path: path,
      authorised_by: params.authorisedBy,
      authorisation_type: params.authorisationType,
    })
    .select()
    .single();

  if (insertError) {
    // Unique violation on event_key means a concurrent call already
    // created it — genuinely idempotent, not an error from the caller's
    // point of view.
    if (insertError.code === '23505') {
      const { data: raceWinner } = await admin.from('documents').select('*').eq('event_key', params.eventKey).maybeSingle();
      if (raceWinner) return { document: raceWinner, created: false };
    }
    throw new Error(`Failed to record ${params.type} document: ${insertError.message}`);
  }

  return { document: inserted, created: true };
}

interface JobContext {
  job: Record<string, unknown>;
  customer: Record<string, unknown>;
  branch: Record<string, unknown>;
  material: Record<string, unknown>;
  finish: Record<string, unknown>;
  quote: Record<string, unknown> | null;
}

async function loadJobContext(admin: SupabaseClientLike, jobId: string): Promise<JobContext | null> {
  const { data: job } = await admin
    .from('jobs')
    .select('id, job_ref, customer_id, branch_id, material_id, finish_id, thickness_mm, width_mm, height_mm, quote_id, current_stage')
    .eq('id', jobId)
    .maybeSingle();
  if (!job) return null;

  const [{ data: customer }, { data: branch }, { data: material }, { data: finish }] = await Promise.all([
    admin.from('customers').select('customer_ref, full_name, phone, email').eq('id', job.customer_id).maybeSingle(),
    admin.from('branches').select('name, address').eq('id', job.branch_id).maybeSingle(),
    admin.from('materials').select('name').eq('id', job.material_id).maybeSingle(),
    admin.from('finishes').select('name').eq('id', job.finish_id).maybeSingle(),
  ]);

  let quote = null;
  if (job.quote_id) {
    const { data } = await admin.from('quotes').select('*').eq('id', job.quote_id).maybeSingle();
    quote = data;
  }

  if (!customer || !branch || !material || !finish) return null;

  return { job, customer, branch, material, finish, quote };
}

async function renderPgjo(admin: SupabaseClientLike, ctx: JobContext): Promise<string> {
  const { data: payment } = await admin
    .from('payments')
    .select('payment_ref, kind, amount_kobo, bank_reference, confirmed_at, confirmed_by')
    .eq('job_id', ctx.job.id)
    .eq('kind', 'deposit')
    .eq('status', 'confirmed')
    .order('confirmed_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  let confirmedByName = 'Unknown';
  if (payment?.confirmed_by) {
    const { data: accountant } = await admin.from('profiles').select('full_name').eq('id', payment.confirmed_by).maybeSingle();
    confirmedByName = accountant?.full_name ?? 'Unknown';
  }

  return renderHtml('Pro_Grafiz Job Order (PGJO)', ctx, [
    ['Job reference', ctx.job.job_ref as string],
    ['Centre', `${ctx.branch.name} — ${ctx.branch.address ?? ''}`],
    ['Customer', `${ctx.customer.full_name} (${ctx.customer.customer_ref})`],
    ['Specification', `${ctx.material.name}, ${ctx.job.thickness_mm}mm, ${ctx.job.width_mm}×${ctx.job.height_mm}mm, ${ctx.finish.name}`],
    ['Payment reference', payment?.payment_ref ?? 'N/A'],
    ['Bank reference', payment?.bank_reference ?? 'N/A'],
    ['Amount confirmed', payment ? formatKobo(payment.amount_kobo as number) : 'N/A'],
    ['Confirmed by', confirmedByName],
    ['Confirmed at', payment?.confirmed_at ? new Date(payment.confirmed_at as string).toISOString() : 'N/A'],
    ['Quote total', ctx.quote ? formatKobo(ctx.quote.total_kobo as number) : 'N/A'],
    ['Deposit', ctx.quote ? formatKobo(ctx.quote.deposit_kobo as number) : 'N/A'],
    ['Balance remaining', ctx.quote ? formatKobo(ctx.quote.balance_kobo as number) : 'N/A'],
  ]);
}

async function renderPgao(admin: SupabaseClientLike, ctx: JobContext): Promise<string> {
  const { data: draft } = await admin
    .from('drafts')
    .select('version, release_status')
    .eq('job_id', ctx.job.id)
    .eq('release_status', 'released')
    .order('version', { ascending: false })
    .limit(1)
    .maybeSingle();

  const { data: approvalEvent } = await admin
    .from('job_stage_history')
    .select('entered_at')
    .eq('job_id', ctx.job.id)
    .eq('customer_action', 'approved')
    .order('entered_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  return renderHtml('Pro_Grafiz Approval Order (PGAO)', ctx, [
    ['Job reference', ctx.job.job_ref as string],
    ['Centre', `${ctx.branch.name} — ${ctx.branch.address ?? ''}`],
    ['Customer', `${ctx.customer.full_name} (${ctx.customer.customer_ref})`],
    ['Specification', `${ctx.material.name}, ${ctx.job.thickness_mm}mm, ${ctx.job.width_mm}×${ctx.job.height_mm}mm, ${ctx.finish.name}`],
    ['Approved design version', draft ? `v${draft.version}` : 'N/A'],
    ['Approved by', 'Customer (self-service approval — see PG-003/008 for why this cannot reference a staff profile row)'],
    ['Approved at', approvalEvent?.entered_at ? new Date(approvalEvent.entered_at as string).toISOString() : 'N/A'],
    ['Quote total', ctx.quote ? formatKobo(ctx.quote.total_kobo as number) : 'N/A'],
  ]);
}

function renderHtml(title: string, ctx: JobContext, rows: [string, string][]): string {
  const escapedRows = rows
    .map(([label, value]) => `<tr><th>${escapeHtml(label)}</th><td>${escapeHtml(value)}</td></tr>`)
    .join('\n');
  return `<!doctype html>
<html><head><meta charset="utf-8"><title>${escapeHtml(title)}</title>
<style>
body { font-family: sans-serif; padding: 32px; color: #1e1613; }
h1 { font-size: 20px; }
table { border-collapse: collapse; width: 100%; margin-top: 16px; }
th, td { text-align: left; padding: 8px; border-bottom: 1px solid #ddd; }
th { width: 220px; color: #5c4b3f; }
.footer { margin-top: 24px; font-size: 12px; color: #8a7566; }
</style></head>
<body>
<h1>Pro_Grafiz Designs Ltd — ${escapeHtml(title)}</h1>
<table>${escapedRows}</table>
<p class="footer">Generated automatically from job ${escapeHtml(ctx.job.job_ref as string)}'s server-side records. No field on this document was manually entered at generation time.</p>
</body></html>`;
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));
}

function formatKobo(kobo: number): string {
  return `₦${(kobo / 100).toLocaleString('en-NG', { minimumFractionDigits: 0 })}`;
}
