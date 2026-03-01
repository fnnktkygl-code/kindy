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

  const page = `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Invitation Pigio</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
           background: #f8f5f0; display: flex; align-items: center; justify-content: center;
           min-height: 100vh; margin: 0; }
    .card { background: #fff; border-radius: 24px; padding: 48px 32px; max-width: 380px;
            width: 90%; text-align: center; box-shadow: 0 4px 24px rgba(0,0,0,.08); }
    .mascot { font-size: 72px; margin-bottom: 16px; }
    h1 { font-size: 20px; margin: 0 0 8px; color: #2d2a26; }
    p  { color: #8a857e; font-size: 14px; margin: 0 0 28px; }
    a  { display: block; width: 100%; padding: 14px; border-radius: 12px; font-size: 15px;
         font-weight: 700; text-decoration: none; margin-bottom: 10px; box-sizing: border-box; }
    .primary { background: #e8a063; color: #fff; }
    .secondary { background: #f0ece6; color: #2d2a26; }
  </style>
</head>
<body>
  <div class="card">
    <div class="mascot">&#x1F426;</div>
    <h1>Vous avez une invitation Pigio&nbsp;!</h1>
    <p>Ouverture de l&rsquo;app en cours&hellip;</p>
    <a class="primary" id="open" href="${openHref}">Ouvrir Pigio</a>
    ${isAndroid
      ? `<a class="secondary" href="https://play.google.com/store/apps/details?id=com.example.pigio.pigio_app">&#x1F4F1; T&eacute;l&eacute;charger sur le Play Store</a>`
      : `<a class="secondary" href="https://apps.apple.com/app/pigio/id0000000000">&#x1F4F1; T&eacute;l&eacute;charger sur l&rsquo;App Store</a>`}
  </div>
  <script>
    setTimeout(function() {
      window.location.href = '${openHref}';
    }, 120);
  </script>
</body>
</html>`;

  return new Response(page, {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store, no-cache, must-revalidate',
    },
  });
});
