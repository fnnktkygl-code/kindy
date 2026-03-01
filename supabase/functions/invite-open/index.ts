import { corsHeaders } from '../_shared/cors.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const url = new URL(req.url);
  const token =
    url.searchParams.get('token') ??
    url.searchParams.get('tokenId') ??
    url.searchParams.get('t');

  if (!token) {
    return new Response('Lien invalide.', { status: 400, headers: { 'Content-Type': 'text/plain' } });
  }

  const safeToken = encodeURIComponent(token);
  const userAgent = req.headers.get('user-agent') ?? '';
  const isAndroid = /android/i.test(userAgent);
  const appScheme = `pigio://invite?token=${safeToken}`;
  const openHref = isAndroid
    ? `intent://invite?token=${safeToken}#Intent;scheme=pigio;package=com.example.pigio.pigio_app;end`
    : appScheme;

  return new Response(null, {
    status: 302,
    headers: {
      ...corsHeaders,
      Location: openHref,
      'Cache-Control': 'no-store, no-cache, must-revalidate',
    },
  });
});
