import { getCorsHeaders, corsHeaders } from './cors.ts';

/**
 * Returns a JSON response.
 * Pass `req` to restrict CORS to known origins (pigio.app).
 * Omit `req` for responses that are intentionally public (e.g. read-only public endpoints).
 */
export function json(body: unknown, status = 200, req?: Request) {
  const cors = req ? getCorsHeaders(req) : corsHeaders;
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

export function html(body: string, status = 200) {
  return new Response(body, {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

export function redirect(to: string, status = 302) {
  return new Response(null, {
    status,
    headers: {
      ...corsHeaders,
      'Location': to,
      'Cache-Control': 'no-store',
    },
  });
}
