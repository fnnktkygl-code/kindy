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
  const joinUrl = `https://pigio.app/join?token=${safeToken}`;
  return Response.redirect(joinUrl, 302);
});
