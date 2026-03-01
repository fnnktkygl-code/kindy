import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { getCorsHeaders } from '../_shared/cors.ts';
import { json } from '../_shared/response.ts';

/**
 * Cross-device data sync.
 *
 * GET  ?key=<sync_key>           -> pull all data for this user
 * POST { key, ...data fields }   -> push (upsert) data for this user
 *
 * Authentication: requires a valid Supabase JWT. The user_id from the JWT
 * is enforced on all queries so users can only access their own data.
 */
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: getCorsHeaders(req) });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: 'Supabase env missing' }, 500);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const isExchangeKey = (key: string) =>
      key.startsWith('cprof_inv_') ||
      key.startsWith('cprof_acc_') ||
      key.startsWith('notif_');

    let userId: string | null = null;

    async function requireAuth(): Promise<boolean> {
      const authHeader = req.headers.get('Authorization');
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return false;
      }
      const userToken = authHeader.slice(7);
      const { data: { user }, error: authError } = await admin.auth.getUser(userToken);
      if (authError || !user) return false;
      userId = user.id;
      return true;
    }

    // ─── PULL ───────────────────────────────────────────────────────
    if (req.method === 'GET') {
      const url = new URL(req.url);
      const key = (url.searchParams.get('key') ?? '').trim();
      if (!key || key.length < 16) return json({ error: 'Invalid sync key' }, 400);

      const exchange = isExchangeKey(key);
      if (!exchange) {
        const ok = await requireAuth();
        if (!ok) return json({ error: 'Missing or invalid authorization' }, 401);
      }

      const { data, error } = await admin
        .from('user_data')
        .select('*')
        .eq('sync_key', key)
        .maybeSingle();

      if (error) return json({ error: 'DB error' }, 500);
      if (!data) return json({ found: false });

      // Regular sync keys are private to the authenticated owner.
      // Exchange keys (cprof_*) are intentionally cross-user by token design.
      if (!exchange) {
        if (data.user_id && data.user_id !== userId) {
          return json({ error: 'Forbidden' }, 403);
        }

        // Backfill: stamp user_id on legacy rows that don't have it yet
        if (!data.user_id) {
          await admin
            .from('user_data')
            .update({ user_id: userId })
            .eq('sync_key', key);
        }
      }

      return json({
        found: true,
        contacts: data.contacts_data,
        circles: data.circles_data,
        pendingInvites: data.pending_invites_data,
        profile: data.profile_data,
        wishes: data.wishes_data,
        events: data.events_data,
        sizes: data.sizes_data,
        giftPots: data.gift_pots_data,
        updatedAt: data.updated_at,
      });
    }

    // ─── PUSH ───────────────────────────────────────────────────────
    if (req.method === 'POST') {
      const body = await req.json();
      const key = String(body.key ?? '').trim();
      if (!key || key.length < 16) return json({ error: 'Invalid sync key' }, 400);

      const exchange = isExchangeKey(key);
      if (!exchange) {
        const ok = await requireAuth();
        if (!ok) return json({ error: 'Missing or invalid authorization' }, 401);
      }

      // Check ownership: if this key already exists, it must belong to this user
      const { data: existing } = await admin
        .from('user_data')
        .select('user_id')
        .eq('sync_key', key)
        .maybeSingle();

      if (!exchange && existing && existing.user_id && existing.user_id !== userId) {
        return json({ error: 'Forbidden' }, 403);
      }

      const row: Record<string, unknown> = {
        sync_key: key,
        user_id: exchange ? null : userId,
        updated_at: new Date().toISOString(),
      };

      // Only update fields that are actually provided
      if (body.contacts !== undefined) row.contacts_data = body.contacts;
      if (body.circles !== undefined)  row.circles_data = body.circles;
      if (body.pendingInvites !== undefined) row.pending_invites_data = body.pendingInvites;
      if (body.profile !== undefined)  row.profile_data = body.profile;
      if (body.wishes !== undefined)   row.wishes_data = body.wishes;
      if (body.events !== undefined)   row.events_data = body.events;
      if (body.sizes !== undefined)    row.sizes_data = body.sizes;
      if (body.giftPots !== undefined) row.gift_pots_data = body.giftPots;

      const { error } = await admin
        .from('user_data')
        .upsert(row, { onConflict: 'sync_key' });

      if (error) return json({ error: 'DB error' }, 500);

      return json({ ok: true });
    }

    return json({ error: 'Method not allowed' }, 405);
  } catch {
    return json({ error: 'Unexpected error' }, 500);
  }
});
