// Supabase Edge Function: churn-reengage
// Enhanced re-engagement with churn scoring and contextual push messages.
//
// Replaces the generic check-reengage with smart, high-value pushes:
//   - Priority 1: Upcoming birthday for a contact (highest value)
//   - Priority 2: Unreserved wishes available (gift ideas)
//   - Priority 3: Warm generic (only for high-risk users)
//
// Schedule via pg_cron:
//   SELECT cron.schedule('churn-reengage-daily', '0 10 * * *',
//     $$ SELECT net.http_post(
//       url := '<SUPABASE_URL>/functions/v1/churn-reengage',
//       headers := jsonb_build_object('Authorization', 'Bearer <CRON_SECRET>')
//     ) $$);

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { json } from '../_shared/response.ts';

const FCM_PROJECT_ID = Deno.env.get('FCM_PROJECT_ID') ?? '';
const FCM_SERVICE_ACCOUNT_EMAIL = Deno.env.get('FCM_SERVICE_ACCOUNT_EMAIL') ?? '';
const FCM_PRIVATE_KEY_RAW = Deno.env.get('FCM_PRIVATE_KEY') ?? '';
const CRON_SECRET = Deno.env.get('CRON_SECRET') ?? '';

// --- FCM auth helpers ---

function base64url(data: Uint8Array): string {
  let str = '';
  for (const byte of data) str += String.fromCharCode(byte);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

function encodeJson(obj: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(obj)));
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemBody = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const binary = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    binary.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

async function getAccessToken(email: string, privateKey: CryptoKey): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = encodeJson({ alg: 'RS256', typ: 'JWT' });
  const payload = encodeJson({
    iss: email, sub: email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now, exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  });
  const unsigned = `${header}.${payload}`;
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', privateKey,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64url(new Uint8Array(sig))}`;
  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!resp.ok) throw new Error('Token exchange failed');
  const body = await resp.json();
  return body.access_token as string;
}

async function sendFcmPush(
  accessToken: string, token: string, title: string, body: string, type: string,
): Promise<boolean> {
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`;
  const resp = await fetch(fcmUrl, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data: { type },
        android: { priority: 'high' },
        apns: { headers: { 'apns-priority': '10' }, payload: { aps: { sound: 'default', badge: 1 } } },
      },
    }),
  });
  return resp.ok;
}

// --- Churn scoring ---

interface UserRow {
  sync_key: string;
  user_id: string | null;
  profile_data: Record<string, unknown> | null;
  contacts_data: unknown[] | null;
  wishes_data: unknown[] | null;
  updated_at: string;
}

function computeChurnScore(row: UserRow, daysAway: number): number {
  let score = 0;

  // Days away (strongest signal)
  if (daysAway >= 14) score += 40;
  else if (daysAway >= 7) score += 25;
  else if (daysAway >= 3) score += 10;

  // No contacts
  const contacts = Array.isArray(row.contacts_data) ? row.contacts_data : [];
  if (contacts.length === 0) score += 20;
  else if (contacts.length < 3) score += 10;

  // No wishes
  const wishes = Array.isArray(row.wishes_data) ? row.wishes_data : [];
  if (wishes.length === 0) score += 15;

  return Math.min(score, 100);
}

function daysUntilBirthday(day: number, month: number): number {
  const now = new Date();
  const thisYear = now.getFullYear();
  let bd = new Date(thisYear, month - 1, day);
  const today = new Date(thisYear, now.getMonth(), now.getDate());
  if (bd < today) bd = new Date(thisYear + 1, month - 1, day);
  return Math.round((bd.getTime() - today.getTime()) / 86_400_000);
}

interface PushContent {
  title: string;
  body: string;
  type: string;
}

function getBestPush(row: UserRow, daysAway: number): PushContent | null {
  const score = computeChurnScore(row, daysAway);
  if (score < 20) return null; // Low risk, skip

  const contacts = Array.isArray(row.contacts_data) ? row.contacts_data : [];

  // Priority 1: Upcoming birthday
  for (const c of contacts) {
    if (typeof c !== 'object' || !c) continue;
    const contact = c as Record<string, unknown>;
    const name = contact.name as string | undefined;
    const birthdate = contact.birthdate as string | undefined;
    if (!name || !birthdate) continue;
    const parts = birthdate.split('/');
    if (parts.length < 2) continue;
    const day = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10);
    if (isNaN(day) || isNaN(month)) continue;
    const daysLeft = daysUntilBirthday(day, month);
    if (daysLeft >= 0 && daysLeft <= 7) {
      return {
        title: '🎂 Anniversaire à venir',
        body: daysLeft === 0
          ? `C'est l'anniversaire de ${name} aujourd'hui !`
          : `L'anniversaire de ${name} est dans ${daysLeft} jour${daysLeft > 1 ? 's' : ''}`,
        type: 'churn_birthday',
      };
    }
  }

  // Priority 2: Warm generic (only for medium+ risk)
  if (score >= 30) {
    const profile = row.profile_data;
    const name = (profile?.name as string) ?? '';
    return {
      title: '🐧 Pigio',
      body: name
        ? `${name}, tes proches ont peut-être mis à jour leurs envies`
        : `Tes proches ont peut-être mis à jour leurs envies`,
      type: 'churn_generic',
    };
  }

  return null;
}

// --- Main ---

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { status: 200 });

  const authHeader = req.headers.get('Authorization') ?? '';
  const bearer = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
  if (!CRON_SECRET || bearer !== CRON_SECRET) {
    return json({ error: 'Unauthorized' }, 401);
  }

  if (!FCM_PROJECT_ID || !FCM_SERVICE_ACCOUNT_EMAIL || !FCM_PRIVATE_KEY_RAW) {
    return json({ error: 'FCM not configured' }, 500);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: 'Supabase env missing' }, 500);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Find users inactive 2-30 days
  const twoDaysAgo = new Date(Date.now() - 2 * 86_400_000).toISOString();
  const thirtyDaysAgo = new Date(Date.now() - 30 * 86_400_000).toISOString();

  const { data: rows, error } = await admin
    .from('user_data')
    .select('sync_key, user_id, profile_data, contacts_data, wishes_data, updated_at')
    .lt('updated_at', twoDaysAgo)
    .gt('updated_at', thirtyDaysAgo)
    .not('user_id', 'is', null)
    .not('profile_data', 'is', null)
    .limit(100);

  if (error) return json({ error: 'DB query failed', detail: error.message }, 500);

  const pem = FCM_PRIVATE_KEY_RAW.replace(/\\n/g, '\n');
  const privateKey = await importPrivateKey(pem);
  const accessToken = await getAccessToken(FCM_SERVICE_ACCOUNT_EMAIL, privateKey);

  let sent = 0;
  let skipped = 0;

  for (const row of (rows ?? []) as UserRow[]) {
    if (row.sync_key?.startsWith('cprof_') || row.sync_key?.startsWith('notif_')) {
      skipped++;
      continue;
    }

    const profile = row.profile_data;
    if (!profile) { skipped++; continue; }
    const fcmToken = (profile.fcmToken ?? profile.fcm_token) as string | undefined;
    if (!fcmToken || fcmToken.length < 10) { skipped++; continue; }

    const daysAway = Math.floor(
      (Date.now() - new Date(row.updated_at).getTime()) / 86_400_000,
    );

    const push = getBestPush(row, daysAway);
    if (!push) { skipped++; continue; }

    const ok = await sendFcmPush(accessToken, fcmToken, push.title, push.body, push.type);
    if (ok) sent++;
    else skipped++;
  }

  return json({ ok: true, processed: (rows ?? []).length, sent, skipped });
});
