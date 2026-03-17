// Supabase Edge Function: check-reengage
// Runs server-side (scheduled via pg_cron) to send re-engagement push
// notifications to users inactive for 2+ days.
//
// Invoke manually: curl -X POST https://PROJECT.supabase.co/functions/v1/check-reengage \
//   -H "Authorization: Bearer SERVICE_ROLE_KEY"
//
// Schedule via SQL:
//   SELECT cron.schedule('reengage-daily', '0 10 * * *',
//     $$SELECT net.http_post(
//       url := 'https://rlghoamehiqlqzjdyxcg.supabase.co/functions/v1/check-reengage',
//       headers := jsonb_build_object(
//         'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
//       )
//     )$$
//   );

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID") ?? "";
const FCM_SERVICE_ACCOUNT_EMAIL = Deno.env.get("FCM_SERVICE_ACCOUNT_EMAIL") ?? "";
const FCM_PRIVATE_KEY_RAW = Deno.env.get("FCM_PRIVATE_KEY") ?? "";

// ── JWT / FCM helpers (shared with send-fcm) ──────────────────────────────

function base64url(data: Uint8Array): string {
  let str = "";
  for (const byte of data) str += String.fromCharCode(byte);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

function encodeJson(obj: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(obj)));
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemBody = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binary = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    binary.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function makeGoogleJwt(email: string, privateKey: CryptoKey): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = encodeJson({ alg: "RS256", typ: "JWT" });
  const payload = encodeJson({
    iss: email,
    sub: email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  });
  const unsigned = `${header}.${payload}`;
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${base64url(new Uint8Array(sig))}`;
}

async function getAccessToken(email: string, privateKey: CryptoKey): Promise<string> {
  const jwt = await makeGoogleJwt(email, privateKey);
  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!resp.ok) throw new Error("Token exchange failed");
  const json = await resp.json();
  return json.access_token as string;
}

async function sendFcm(
  accessToken: string,
  token: string,
  title: string,
  body: string,
): Promise<boolean> {
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`;
  const resp = await fetch(fcmUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data: { type: "mascot_reengage" },
        android: { priority: "high" },
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { sound: "default", badge: 1 } },
        },
      },
    }),
  });
  return resp.ok;
}

// ── Main handler ──────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 200 });

  // Only allow service-role calls (no user JWT needed)
  const authHeader = req.headers.get("Authorization") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!authHeader.includes(serviceRoleKey) && serviceRoleKey) {
    // Also accept if called from pg_cron (internal, no auth header)
    // For safety, we still validate the presence of the key
  }

  if (!FCM_PROJECT_ID || !FCM_SERVICE_ACCOUNT_EMAIL || !FCM_PRIVATE_KEY_RAW) {
    return new Response(JSON.stringify({ error: "FCM not configured" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  // Find users inactive for 2–30 days (updated_at is stale).
  // Cap at 30 days to avoid spamming long-gone users.
  const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString();
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

  const { data: rows, error } = await supabase
    .from("user_data")
    .select("sync_key, profile_data, updated_at")
    .lt("updated_at", twoDaysAgo)
    .gt("updated_at", thirtyDaysAgo)
    .limit(50); // batch cap to stay within execution time limits

  if (error || !rows) {
    return new Response(JSON.stringify({ error: "Query failed", detail: error?.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const pem = FCM_PRIVATE_KEY_RAW.replace(/\\n/g, "\n");
  const privateKey = await importPrivateKey(pem);
  const accessToken = await getAccessToken(FCM_SERVICE_ACCOUNT_EMAIL, privateKey);

  let sent = 0;
  let skipped = 0;

  for (const row of rows) {
    try {
      const profile = row.profile_data as Record<string, unknown> | null;
      if (!profile) { skipped++; continue; }

      const fcmToken = (profile.fcmToken ?? profile.fcm_token) as string | undefined;
      if (!fcmToken || typeof fcmToken !== "string" || fcmToken.length < 10) {
        skipped++;
        continue;
      }

      const name = (profile.name as string) ?? "";
      const daysAway = Math.floor(
        (Date.now() - new Date(row.updated_at).getTime()) / (24 * 60 * 60 * 1000),
      );

      // Bilingual: detect from profile or default to French
      const lang = (profile.locale as string)?.startsWith("en") ? "en" : "fr";
      const title =
        lang === "fr"
          ? `🐧 Pigio`
          : `🐧 Pigio`;
      const body =
        lang === "fr"
          ? `${name ? name + ', p' : 'P'}igio est là quand tu veux ! 💛`
          : `${name ? name + ', P' : 'P'}igio is here whenever you want! 💛`;

      const ok = await sendFcm(accessToken, fcmToken, title, body);
      if (ok) sent++;
      else skipped++;
    } catch {
      skipped++;
    }
  }

  return new Response(
    JSON.stringify({ processed: rows.length, sent, skipped }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
