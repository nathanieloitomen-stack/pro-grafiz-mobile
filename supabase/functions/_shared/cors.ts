// Shared CORS headers for Pro_Grafiz Edge Functions.
//
// Access-Control-Allow-Origin is wide open ('*') for now because the
// mobile app and admin-web's real deployed origins aren't known yet at
// this stage of the build. Tighten this to the actual app/web origins
// before production launch — see docs/security.md.
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
