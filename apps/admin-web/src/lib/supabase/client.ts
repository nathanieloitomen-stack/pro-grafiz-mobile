'use client';

import { createBrowserClient } from '@supabase/ssr';

/**
 * Browser-side Supabase client. Values come from NEXT_PUBLIC_* env vars
 * (see .env.example) — never the service role key, which must only
 * ever be used server-side (Edge Functions, not this app).
 *
 * UNTESTED: written without a live Supabase project or `npm install`
 * having been run in this environment (no network) — the shape matches
 * @supabase/ssr's documented API but hasn't executed. Verify before
 * relying on it.
 */
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
