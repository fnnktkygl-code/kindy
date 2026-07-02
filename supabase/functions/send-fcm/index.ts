// Supabase Edge Function: send-fcm
// Deploy with: supabase functions deploy send-fcm
//
// Required secrets (set via Supabase dashboard or CLI):
//   supabase secrets set FCM_PROJECT_ID=your-firebase-project-id
//   supabase secrets set FCM_SERVICE_ACCOUNT_EMAIL=firebase-adminsdk-xxx@your-project.iam.gserviceaccount.com
//   supabase secrets set FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
//
// How to get these values:
//   1. Firebase Console → Project Settings → Service Accounts
//   2. Click "Generate new private key" → downloads a JSON file
//   3. FCM_PROJECT_ID    = "project_id" field in the JSON
//   4. FCM_SERVICE_ACCOUNT_EMAIL = "client_email" field
//   5. FCM_PRIVATE_KEY   = "private_key" field (include the full PEM string)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getCorsHeaders } from '../_shared/cors.ts';
import { importPrivateKey, getAccessToken, base64url, encodeJson } from '../_shared/fcm.ts';

const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID") ?? "";
const FCM_SERVICE_ACCOUNT_EMAIL = Deno.env.get("FCM_SERVICE_ACCOUNT_EMAIL") ?? "";
const FCM_PRIVATE_KEY_RAW = Deno.env.get("FCM_PRIVATE_KEY") ?? "";

// ---- Per-user rate limiter: max 50 pushes per hour ----------------------

const userRateMap = new Map<string, { count: number; resetAt: number }>();
const USER_RATE_LIMIT = 50;
const USER_RATE_WINDOW_MS = 3_600_000;

function isUserRateLimited(userId: string): boolean {
  const now = Date.now();
  const entry = userRateMap.get(userId);
  if (!entry || now >= entry.resetAt) {
    userRateMap.set(userId, { count: 1, resetAt: now + USER_RATE_WINDOW_MS });
    return false;
  }
  entry.count++;
  return entry.count > USER_RATE_LIMIT;
}

// -------------------------------------------------------------------------

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: getCorsHeaders(req) });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    // ── Authentication: require a valid Supabase JWT ──────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const userToken = authHeader.slice(7); // strip "Bearer "
    const { data: { user }, error: authError } = await supabase.auth.getUser(userToken);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Rate limit per authenticated user
    if (isUserRateLimited(user.id)) {
      return new Response(JSON.stringify({ error: "Rate limit exceeded" }), {
        status: 429,
        headers: { "Content-Type": "application/json" },
      });
    }
    // ─────────────────────────────────────────────────────────────────────

    if (!FCM_PROJECT_ID || !FCM_SERVICE_ACCOUNT_EMAIL || !FCM_PRIVATE_KEY_RAW) {
      return new Response(
        JSON.stringify({ error: "FCM not configured" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    const body = await req.json() as { token?: string; title?: string; body?: string; type?: string };
    const { type } = body;

    // Validate and cap all string inputs
    const token = typeof body.token === "string" ? body.token.trim().substring(0, 512) : "";
    const title = typeof body.title === "string" ? body.title.trim().substring(0, 200) : "";
    const msgBody = typeof body.body === "string" ? body.body.trim().substring(0, 500) : "";

    if (!token || !title || !msgBody) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: token, title, body" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const pem = FCM_PRIVATE_KEY_RAW.replace(/\\n/g, "\n");
    const privateKey = await importPrivateKey(pem);
    const accessToken = await getAccessToken(FCM_SERVICE_ACCOUNT_EMAIL, privateKey);

    const fcmUrl =
      `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`;

    const fcmPayload = {
      message: {
        token,
        notification: { title, body: msgBody },
        data: { type: type ?? "notification" },
        android: { priority: "high" },
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { sound: "default", badge: 1 } },
        },
      },
    };

    const fcmResp = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(fcmPayload),
    });

    if (!fcmResp.ok) {
      return new Response(
        JSON.stringify({ error: "FCM delivery failed" }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch {
    return new Response(
      JSON.stringify({ error: "Unexpected error" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
