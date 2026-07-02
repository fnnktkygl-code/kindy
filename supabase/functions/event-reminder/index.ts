// Supabase Edge Function: event-reminder
// Deploy with: supabase functions deploy event-reminder
//
// Intended to be invoked daily by pg_cron or an external scheduler:
//   SELECT cron.schedule('event-reminder', '0 9 * * *',
//     $$ SELECT net.http_post(
//       url := '<SUPABASE_URL>/functions/v1/event-reminder',
//       headers := jsonb_build_object('Authorization', 'Bearer <CRON_SECRET>')
//     ) $$);
//
// Scans all user_data rows for custom events and birthdays that fall within
// their respective reminder thresholds. Respects global and per-entity muting
// from notification_prefs. Sends grouped notifications for group events.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { json } from '../_shared/response.ts';
import { importPrivateKey, getAccessToken, sendFcmPush } from '../_shared/fcm.ts';

const FCM_PROJECT_ID = Deno.env.get('FCM_PROJECT_ID') ?? '';
const FCM_SERVICE_ACCOUNT_EMAIL = Deno.env.get('FCM_SERVICE_ACCOUNT_EMAIL') ?? '';
const FCM_PRIVATE_KEY_RAW = Deno.env.get('FCM_PRIVATE_KEY') ?? '';
const CRON_SECRET = Deno.env.get('CRON_SECRET') ?? '';

interface ContactBirthday {
  id: string;
  name: string;
  day: number;
  month: number;
  year?: number;
}

interface CustomEvent {
  id: string;
  title: string;
  date: string; // ISO string
  isRecurring: boolean;
  typeEn: string;
  typeFr: string;
  contactId?: string;
  groupId?: string;
  notificationsEnabled?: boolean;
  reminderThresholds?: number[];
  mutedUntil?: string; // ISO string
}

function parseBirthdays(contactsData: unknown): ContactBirthday[] {
  if (!Array.isArray(contactsData)) return [];
  const result: ContactBirthday[] = [];
  for (const c of contactsData) {
    if (typeof c !== 'object' || !c) continue;
    const id = (c as Record<string, unknown>).id as string;
    const name = (c as Record<string, unknown>).name as string;
    const birthdate = (c as Record<string, unknown>).birthdate as string;
    if (!id || typeof name !== 'string' || typeof birthdate !== 'string') continue;
    const parts = birthdate.split('/');
    if (parts.length < 2) continue;
    const day = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10);
    const year = parts.length >= 3 ? parseInt(parts[2], 10) : undefined;
    if (isNaN(day) || isNaN(month)) continue;
    result.push({ id, name, day, month, year: isNaN(year!) ? undefined : year });
  }
  return result;
}

function parseCustomEvents(eventsData: unknown): CustomEvent[] {
  if (!Array.isArray(eventsData)) return [];
  const result: CustomEvent[] = [];
  for (const e of eventsData) {
    if (typeof e !== 'object' || !e) continue;
    const ev = e as Record<string, unknown>;
    if (typeof ev.id !== 'string' || typeof ev.title !== 'string' || typeof ev.date !== 'string') continue;
    result.push(ev as unknown as CustomEvent);
  }
  return result;
}

function getNextOccurrenceDays(dateIso: string, isRecurring: boolean): number | null {
  const date = new Date(dateIso);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  
  if (!isRecurring) {
    const eventDay = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    if (eventDay < today) return null;
    return Math.round((eventDay.getTime() - today.getTime()) / 86_400_000);
  }

  let nextOccur = new Date(now.getFullYear(), date.getMonth(), date.getDate());
  if (nextOccur < today) {
    nextOccur = new Date(now.getFullYear() + 1, date.getMonth(), date.getDate());
  }
  return Math.round((nextOccur.getTime() - today.getTime()) / 86_400_000);
}

const DEFAULT_THRESHOLDS = [7, 3, 1];

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
    .select('sync_key, user_id, profile_data, contacts_data, events_data, notification_prefs, reminders_sent')
    .not('user_id', 'is', null)
    .not('profile_data', 'is', null);

  if (error) return json({ error: 'DB query failed' }, 500);

  let pushesSent = 0;
  const currentYear = new Date().getFullYear();
  const nowMs = Date.now();

  for (const row of (rows ?? [])) {
    if (typeof row.sync_key === 'string' &&
        (row.sync_key.startsWith('cprof_') || row.sync_key.startsWith('notif_'))) {
      continue;
    }

    const profile = row.profile_data as Record<string, unknown> | null;
    if (!profile) continue;
    const fcmToken = profile.fcmToken as string | undefined;
    if (!fcmToken || fcmToken.length < 10) continue;

    // Check user locale (default fr)
    const locale = (profile.locale as string) ?? 'fr';
    const isFr = locale.startsWith('fr');

    const prefs = (row.notification_prefs as Record<string, unknown>) ?? {};
    if (prefs.globalMute === true) continue; // Global mute active

    const defaultThresholds = Array.isArray(prefs.defaultThresholds) ? prefs.defaultThresholds as number[] : DEFAULT_THRESHOLDS;
    const mutedContactIds = new Set(Array.isArray(prefs.mutedContactIds) ? prefs.mutedContactIds as string[] : []);
    const mutedEventIds = new Set(Array.isArray(prefs.mutedEventIds) ? prefs.mutedEventIds as string[] : []);

    const sentMap: Record<string, boolean> = (row.reminders_sent as Record<string, boolean>) ?? {};
    let sentMapDirty = false;

    // Process Contacts (Birthdays)
    const birthdays = parseBirthdays(row.contacts_data);
    for (const bd of birthdays) {
      if (mutedContactIds.has(bd.id)) continue;
      
      const bdIso = `${currentYear}-${bd.month.toString().padStart(2, '0')}-${bd.day.toString().padStart(2, '0')}T12:00:00Z`;
      const daysLeft = getNextOccurrenceDays(bdIso, true);
      if (daysLeft === null) continue;

      for (const threshold of defaultThresholds) {
        if (daysLeft !== threshold) continue;

        const sentKey = `birthday_${bd.id}_${threshold}d_${currentYear}`;
        if (sentMap[sentKey]) continue;

        let ageStr = '';
        if (bd.year) {
          const age = currentYear - bd.year + (daysLeft > 0 ? 1 : 0);
          ageStr = isFr ? ` (tourne ${age} ans)` : ` (turning ${age})`;
        }

        const title = threshold === 1
          ? (isFr ? `🎂 C'est demain !` : `🎂 It's tomorrow!`)
          : (isFr ? `🎂 Anniversaire dans ${threshold} jours` : `🎂 Birthday in ${threshold} days`);
        const body = threshold === 1
          ? (isFr ? `L'anniversaire de ${bd.name} est demain !${ageStr}` : `It's ${bd.name}'s birthday tomorrow!${ageStr}`)
          : (isFr ? `L'anniversaire de ${bd.name} approche (${threshold}j)${ageStr}` : `${bd.name}'s birthday is coming up (${threshold}d)${ageStr}`);

        const ok = await sendFcmPush(FCM_PROJECT_ID, accessToken, fcmToken, title, body, 'event_reminder');
        if (ok) {
          sentMap[sentKey] = true;
          sentMapDirty = true;
          pushesSent++;
        }
      }
    }

    // Process Custom Events
    const customEvents = parseCustomEvents(row.events_data);
    for (const ev of customEvents) {
      if (mutedEventIds.has(ev.id)) continue;
      if (ev.notificationsEnabled === false) continue;
      if (ev.mutedUntil && new Date(ev.mutedUntil).getTime() > nowMs) continue;

      const daysLeft = getNextOccurrenceDays(ev.date, ev.isRecurring);
      if (daysLeft === null) continue;

      const thresholds = ev.reminderThresholds ?? defaultThresholds;
      
      for (const threshold of thresholds) {
        if (daysLeft !== threshold) continue;

        const sentKey = `evt_${ev.id}_${threshold}d_${currentYear}`;
        if (sentMap[sentKey]) continue;

        let ageStr = '';
        if (ev.isRecurring) {
          const evYear = new Date(ev.date).getFullYear();
          const age = currentYear - evYear + (daysLeft > 0 ? 1 : 0);
          ageStr = age > 0 ? (isFr ? ` (${age} ans)` : ` (${age} years)`) : '';
        }

        const typeName = isFr ? ev.typeFr : ev.typeEn;
        
        const title = threshold === 1
          ? (isFr ? `${ev.emoji} C'est demain !` : `${ev.emoji} It's tomorrow!`)
          : (isFr ? `${ev.emoji} Événement dans ${threshold} jours` : `${ev.emoji} Event in ${threshold} days`);
        
        const body = threshold === 1
          ? (isFr ? `${ev.title} (${typeName}) est demain !${ageStr}` : `${ev.title} (${typeName}) is tomorrow!${ageStr}`)
          : (isFr ? `${ev.title} (${typeName}) approche (${threshold}j)${ageStr}` : `${ev.title} (${typeName}) is coming up (${threshold}d)${ageStr}`);

        const ok = await sendFcmPush(FCM_PROJECT_ID, accessToken, fcmToken, title, body, 'event_reminder');
        if (ok) {
          sentMap[sentKey] = true;
          sentMapDirty = true;
          pushesSent++;
        }
      }
    }

    if (sentMapDirty) {
      await admin
        .from('user_data')
        .update({ reminders_sent: sentMap })
        .eq('sync_key', row.sync_key);
    }
  }

  return json({ ok: true, pushes_sent: pushesSent });
});
