// Supabase Edge Function: birthday-reminder
// Deploy with: supabase functions deploy birthday-reminder
//
// Intended to be invoked daily by pg_cron or an external scheduler:
//   SELECT cron.schedule('birthday-reminder', '0 9 * * *',
//     $$ SELECT net.http_post(
//       url := '<SUPABASE_URL>/functions/v1/birthday-reminder',
//       headers := jsonb_build_object('Authorization', 'Bearer <CRON_SECRET>')
//     ) $$);
//
// Scans all user_data rows for contacts whose birthdays fall within 7, 3, or 1
// days and sends an FCM push to the user. A map in user_data.reminders_sent
// prevents duplicate pushes for the same birthday + threshold.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { json } from '../_shared/response.ts';

const FCM_PROJECT_ID = Deno.env.get('FCM_PROJECT_ID') ?? '';
const FCM_SERVICE_ACCOUNT_EMAIL = Deno.env.get('FCM_SERVICE_ACCOUNT_EMAIL') ?? '';
const FCM_PRIVATE_KEY_RAW = Deno.env.get('FCM_PRIVATE_KEY') ?? '';
const CRON_SECRET = Deno.env.get('CRON_SECRET') ?? '';

// --- FCM auth helpers (same as send-fcm) ---

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
        data: { type: 'birthday_reminder' },
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

// --- Birthday parsing ---

interface ContactBirthday {
  name: string;
  day: number;
  month: number;
}

function parseBirthdays(contactsData: unknown): ContactBirthday[] {
  if (!Array.isArray(contactsData)) return [];
  const result: ContactBirthday[] = [];
  for (const c of contactsData) {
    if (typeof c !== 'object' || !c) continue;
    const name = (c as Record<string, unknown>).name;
    const birthdate = (c as Record<string, unknown>).birthdate;
    if (typeof name !== 'string' || typeof birthdate !== 'string') continue;
    const parts = birthdate.split('/');
    if (parts.length < 2) continue;
    const day = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10);
    if (isNaN(day) || isNaN(month)) continue;
    result.push({ name, day, month });
  }
  return result;
}

function daysUntilBirthday(day: number, month: number): number {
  const now = new Date();
  const thisYear = now.getFullYear();
  let bd = new Date(thisYear, month - 1, day);
  // Strip time component for accurate day count
  const today = new Date(thisYear, now.getMonth(), now.getDate());
  if (bd < today) bd = new Date(thisYear + 1, month - 1, day);
  return Math.round((bd.getTime() - today.getTime()) / 86_400_000);
}

// --- Main ---

const THRESHOLDS = [7, 3, 1] as const;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { status: 200 });

  // Authenticate: require CRON_SECRET in Authorization header
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

  // Prepare FCM auth once for all pushes
  const pem = FCM_PRIVATE_KEY_RAW.replace(/\\n/g, '\n');
  const privateKey = await importPrivateKey(pem);
  const accessToken = await getAccessToken(FCM_SERVICE_ACCOUNT_EMAIL, privateKey);

  // Fetch all users who have synced data (profile with fcmToken + contacts)
  const { data: rows, error } = await admin
    .from('user_data')
    .select('sync_key, user_id, profile_data, contacts_data, reminders_sent')
    .not('user_id', 'is', null)
    .not('profile_data', 'is', null)
    .not('contacts_data', 'is', null);

  if (error) return json({ error: 'DB query failed' }, 500);

  let pushesSent = 0;

  for (const row of (rows ?? [])) {
    // Skip exchange keys (cprof_*, notif_*)
    if (typeof row.sync_key === 'string' &&
        (row.sync_key.startsWith('cprof_') || row.sync_key.startsWith('notif_'))) {
      continue;
    }

    const profile = row.profile_data as Record<string, unknown> | null;
    if (!profile) continue;
    const fcmToken = profile.fcmToken as string | undefined;
    if (!fcmToken || fcmToken.length < 10) continue;

    const birthdays = parseBirthdays(row.contacts_data);
    if (birthdays.length === 0) continue;

    // Track which reminders were already sent (persisted in DB)
    const sentMap: Record<string, boolean> = (row.reminders_sent as Record<string, boolean>) ?? {};
    let sentMapDirty = false;
    const year = new Date().getFullYear();

    for (const bd of birthdays) {
      const daysLeft = daysUntilBirthday(bd.day, bd.month);

      for (const threshold of THRESHOLDS) {
        if (daysLeft !== threshold) continue;

        const sentKey = `${bd.name}_${bd.month}_${bd.day}_${threshold}d_${year}`;
        if (sentMap[sentKey]) continue;

        // Build localized message
        const title = threshold === 1
          ? `🎂 C'est demain !`
          : `🎂 Anniversaire dans ${threshold} jours`;
        const body = threshold === 1
          ? `L'anniversaire de ${bd.name} est demain !`
          : `L'anniversaire de ${bd.name} approche (${threshold}j)`;

        const ok = await sendFcmPush(accessToken, fcmToken, title, body);
        if (ok) {
          sentMap[sentKey] = true;
          sentMapDirty = true;
          pushesSent++;
        }
      }
    }

    // Persist sent map back to DB to prevent duplicates across invocations
    if (sentMapDirty) {
      await admin
        .from('user_data')
        .update({ reminders_sent: sentMap })
        .eq('sync_key', row.sync_key);
    }
  }

  return json({ ok: true, pushes_sent: pushesSent });
});
