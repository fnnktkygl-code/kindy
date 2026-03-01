// Allowed browser origins. Native mobile apps send no Origin header,
// which is handled separately in getCorsHeaders() below.
const ALLOWED_ORIGINS = [
  'https://pigio.app',
  'https://www.pigio.app',
];

/**
 * Returns CORS headers appropriate for the incoming request origin.
 * - Mobile apps (no Origin header) → no Allow-Origin needed; not subject to CORS.
 * - pigio.app browser → reflects origin back with Vary.
 * - Any other origin → no Allow-Origin; browser CORS check blocks the request.
 */
export function getCorsHeaders(req: Request): HeadersInit {
  const origin = req.headers.get('origin');
  const baseHeaders = {
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    return {
      ...baseHeaders,
      'Access-Control-Allow-Origin': origin,
      'Vary': 'Origin',
    };
  }
  return baseHeaders;
}

// Kept for backward-compat with existing function imports.
// Functions that call public endpoints (invite-open, invite-status) may keep
// using this; functions that mutate data should switch to getCorsHeaders(req).
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
