import { getCorsHeaders } from '../_shared/cors.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: getCorsHeaders(req) });

  const url = new URL(req.url);
  const token =
    url.searchParams.get('token') ??
    url.searchParams.get('tokenId') ??
    url.searchParams.get('t');

  if (!token) {
    return new Response('Lien invalide.', { status: 400, headers: { 'content-type': 'text/plain; charset=utf-8' } });
  }

  const safeToken = encodeURIComponent(token);
  const userAgent = req.headers.get('user-agent') ?? '';
  const isAndroid = /android/i.test(userAgent);
  const appScheme = `pigio://invite?token=${safeToken}`;
  const openHref = isAndroid
    ? `intent://invite?token=${safeToken}#Intent;scheme=pigio;package=app.pigio.android;end`
    : appScheme;

  if (isAndroid) {
    const headers = new Headers(getCorsHeaders(req));
    headers.set('location', openHref);
    headers.set('cache-control', 'no-store, no-cache, must-revalidate');
    return new Response(null, {
      status: 302,
      headers,
    });
  }
  const headers = new Headers(getCorsHeaders(req));
  headers.set('location', appScheme);
  headers.set('cache-control', 'no-store, no-cache, must-revalidate');

  return new Response(null, {
    status: 302,
    headers,
  });
});
