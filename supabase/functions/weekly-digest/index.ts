// Supabase Edge Function: weekly-digest
// Deploy with: supabase functions deploy weekly-digest
//
// Invoked once per week (Monday 10am) by pg_cron:
//   SELECT cron.schedule('weekly-digest', '0 10 * * 1',
//     $$ SELECT net.http_post(
//       url := '<SUPABASE_URL>/functions/v1/weekly-digest',
//       headers := jsonb_build_object('Authorization', 'Bearer <CRON_SECRET>')
//     ) $$);
//
// Sends each user a single push summarising:
//   - Upcoming birthdays this week
//   - Number of unreserved wishes across all contacts

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
    iss: email,
    sub: email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  });
  const unsigned = `${header}.${payload}`;
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
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
  accessToken: string,
  token: string,
  title: string,
  body: string,
): Promise<boolean> {
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`;
  const resp = await fetch(fcmUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data: { type: 'weekly_digest' },
        android: { priority: 'high' },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: { aps: { sound: 'default', badge: 1 } },
        },
      },
    }),
  });
  return resp.ok;
}

// --- Helpers ---

function daysUntilBirthday(day: number, month: number): number {
  const now = new Date();
  const thisYear = now.getFullYear();
  let bd = new Date(thisYear, month - 1, day);
  const today = new Date(thisYear, now.getMonth(), now.getDate());
  if (bd < today) bd = new Date(thisYear + 1, month - 1, day);
  return Math.round((bd.getTime() - today.getTime()) / 86_400_000);
}

interface UpcomingBirthday {
  name: string;
  daysLeft: number;
}

function getUpcomingBirthdays(contactsData: unknown): UpcomingBirthday[] {
  if (!Array.isArray(contactsData)) return [];
  const result: UpcomingBirthday[] = [];
  for (const c of contactsData) {
    if (typeof c !== 'object' || !c) continue;
    const rec = c as Record<string, unknown>;
    const name = rec.name;
    const birthdate = rec.birthdate;
    if (typeof name !== 'string' || typeof birthdate !== 'string') continue;
    const parts = birthdate.split('/');
    if (parts.length < 2) continue;
    const day = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10);
    if (isNaN(day) || isNaN(month)) continue;
    const daysLeft = daysUntilBirthday(day, month);
    if (daysLeft <= 14) {
      result.push({ name, daysLeft });
    }
  }
  result.sort((a, b) => a.daysLeft - b.daysLeft);
  return result;
}

function countUnreservedWishes(wishesData: unknown): number {
  if (!Array.isArray(wishesData)) return 0;
  return wishesData.filter(
    (w) => typeof w === 'object' && w && !(w as Record<string, unknown>).reservedById,
  ).length;
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

  const pem = FCM_PRIVATE_KEY_RAW.replace(/\\n/g, '\n');
  const privateKey = await importPrivateKey(pem);
  const accessToken = await getAccessToken(FCM_SERVICE_ACCOUNT_EMAIL, privateKey);

  const { data: rows, error } = await admin
    .from('user_data')
    .select('sync_key, profile_data, contacts_data, wishes_data')
    .not('user_id', 'is', null)
    .not('profile_data', 'is', null);

  if (error) return json({ error: 'DB query failed' }, 500);

  let pushesSent = 0;

  for (const row of (rows ?? [])) {
    if (typeof row.sync_key === 'string' &&
        (row.sync_key.startsWith('cprof_') || row.sync_key.startsWith('notif_'))) {
      continue;
    }

    const profile = row.profile_data as Record<string, unknown> | null;
    if (!profile) continue;
    const fcmToken = profile.fcmToken as string | undefined;
    if (!fcmToken || fcmToken.length < 10) continue;

    const birthdays = getUpcomingBirthdays(row.contacts_data);
    const unreserved = countUnreservedWishes(row.wishes_data);

    // Only send if there's something interesting to report
    if (birthdays.length === 0 && unreserved === 0) continue;

    const lines: string[] = [];
    if (birthdays.length > 0) {
      const names = birthdays.slice(0, 3).map((b) =>
        b.daysLeft === 0 ? `${b.name} (aujourd'hui !)` :
        b.daysLeft === 1 ? `${b.name} (demain)` :
        `${b.name} (${b.daysLeft}j)`
      );
      lines.push(`🎂 ${names.join(', ')}`);
    }
    if (unreserved > 0) {
      lines.push(`🎁 ${unreserved} envie${unreserved > 1 ? 's' : ''} sans réservation`);
    }

    const title = '📬 Ton résumé Pigio de la semaine';
    const body = lines.join('\n');

    const ok = await sendFcmPush(accessToken, fcmToken, title, body);
    if (ok) pushesSent++;
  }

  return json({ ok: true, pushes_sent: pushesSent });
});
