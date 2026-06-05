import { getCorsHeaders } from './cors.ts';

/**
 * Returns a JSON response with origin-restricted CORS headers.
 */
export function json(body: unknown, status = 200, req?: Request) {
  const cors = req ? getCorsHeaders(req) : {};
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

export function html(body: string, status = 200, req?: Request) {
  const cors = req ? getCorsHeaders(req) : {};
  return new Response(body, {
    status,
    headers: {
      ...cors,
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

export function redirect(to: string, status = 302, req?: Request) {
  const cors = req ? getCorsHeaders(req) : {};
  return new Response(null, {
    status,
    headers: {
      ...cors,
      'Location': to,
      'Cache-Control': 'no-store',
    },
  });
}
