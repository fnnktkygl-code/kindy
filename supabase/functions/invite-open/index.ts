import { corsHeaders } from '../_shared/cors.ts';
import { redirect, html } from '../_shared/response.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const url = new URL(req.url);
  const token =
    url.searchParams.get('token') ??
    url.searchParams.get('tokenId') ??
    url.searchParams.get('t');

  if (!token) {
    return html('Lien invalide.', 400);
  }

  const safeToken = encodeURIComponent(token);
  const appScheme = 'pigio://invite?token=' + safeToken;
  const intentUrl =
    'intent://invite?token=' + safeToken +
    '#Intent;scheme=pigio;package=com.example.pigio.pigio_app;end';
  const userAgent = req.headers.get('user-agent') ?? '';
  const isAndroid = /android/i.test(userAgent);
  const deepLink  = isAndroid ? intentUrl : appScheme;

  return redirect(deepLink);
});
