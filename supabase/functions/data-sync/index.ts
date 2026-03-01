import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { getCorsHeaders, corsHeaders } from '../_shared/cors.ts';
import { json } from '../_shared/response.ts';

/**
 * Cross-device data sync.
 *
 * GET  ?key=<sync_key>           → pull all data for this user
 * POST { key, ...data fields }   → push (upsert) data for this user
 *
 * The sync_key is a random UUID generated on first launch and shared
 * across the user's devices via a "Link Device" flow.
 */
Deno.serve(async (req) => {
  // GET is a read-only pull — broad CORS is acceptable.
  // POST mutates data — restrict to known origins.
  const isPost = req.method === 'POST';
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: isPost ? getCorsHeaders(req) : corsHeaders });
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

    // ─── PULL ───────────────────────────────────────────────
    if (req.method === 'GET') {
      const url = new URL(req.url);
      const key = (url.searchParams.get('key') ?? '').trim();
      if (!key || key.length < 16) return json({ error: 'Invalid sync key' }, 400);

      const { data, error } = await admin
        .from('user_data')
        .select('*')
        .eq('sync_key', key)
        .maybeSingle();

      if (error) return json({ error: 'DB error' }, 500);
      if (!data) return json({ found: false });

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

    // ─── PUSH ───────────────────────────────────────────────
    if (req.method === 'POST') {
      const body = await req.json();
      const key = String(body.key ?? '').trim();
      if (!key || key.length < 16) return json({ error: 'Invalid sync key' }, 400);

      const row: Record<string, unknown> = {
        sync_key: key,
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
