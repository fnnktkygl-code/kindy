import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { getCorsHeaders } from '../_shared/cors.ts';
import { json } from '../_shared/response.ts';
import { sha256Hex } from '../_shared/crypto.ts';

/**
 * Emit a Realtime sync signal so the target user's WebSocket subscription
 * triggers an immediate pull instead of waiting for the fallback timer.
 *
 * Exchange key patterns:
 *   cprof_inv_<tokenId>       → inviter pushed → notify accepter
 *   cprof_acc_<tokenId>       → accepter pushed → notify inviter
 *   notif_cprof_inv_<tokenId> → inviter pushed notif → notify accepter
 *   notif_cprof_acc_<tokenId> → accepter pushed notif → notify inviter
 */
async function emitSyncSignal(
  admin: ReturnType<typeof createClient>,
  exchangeKey: string,
): Promise<void> {
  // Strip optional notif_ prefix to get the bare exchange key.
  let bare = exchangeKey;
  if (bare.startsWith('notif_')) bare = bare.slice(6);

  // Determine direction and extract raw token.
  let targetColumn: 'accepter_user_id' | 'inviter_id';
  let rawToken: string;

  if (bare.startsWith('cprof_inv_')) {
    rawToken = bare.slice('cprof_inv_'.length);
    targetColumn = 'accepter_user_id'; // inviter pushed → notify accepter
  } else if (bare.startsWith('cprof_acc_')) {
    rawToken = bare.slice('cprof_acc_'.length);
    targetColumn = 'inviter_id'; // accepter pushed → notify inviter
  } else {
    return; // Unknown exchange key pattern — skip.
  }

  if (!rawToken || rawToken.length < 16) return;

  const tokenHash = await sha256Hex(rawToken);

  const { data: invite } = await admin
    .from('invites')
    .select(`${targetColumn}`)
    .eq('token_hash', tokenHash)
    .eq('status', 'accepted')
    .maybeSingle();

  const targetUserId = invite?.[targetColumn];
  if (!targetUserId || typeof targetUserId !== 'string') return;
  // Skip guest_ IDs — they don't have Realtime subscriptions.
  if (targetUserId.startsWith('guest_')) return;

  const signalType = exchangeKey.startsWith('notif_') ? 'notification' : 'profile';

  await admin.from('sync_signals').insert({
    target_user_id: targetUserId,
    signal_type: signalType,
  });
}

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
    // ── Payload size guard (1 MB) ──────────────────────────────────
    const contentLength = Number(req.headers.get('content-length') ?? '0');
    if (contentLength > 1_048_576) {
      return json({ error: 'Payload too large' }, 413);
    }

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

      // E2E encrypted backup: if profile_data contains __e2e marker,
      // extract the encrypted blob and salt from it
      let encryptedBlob = data.encrypted_blob;
      let backupSalt = data.backup_salt;
      if (!encryptedBlob && data.profile_data?.__e2e) {
        encryptedBlob = data.profile_data.encrypted_blob;
        backupSalt = data.profile_data.backup_salt;
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
        // E2E fields
        encrypted_blob: encryptedBlob ?? null,
        backup_salt: backupSalt ?? null,
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

        // Rate limit: max 60 pushes per minute per user
        const { count: recentPushes } = await admin
          .from('user_data')
          .select('sync_key', { count: 'exact', head: true })
          .eq('user_id', userId)
          .gte('updated_at', new Date(Date.now() - 60_000).toISOString());

        if (recentPushes && recentPushes > 60) {
          return json({ error: 'Rate limit exceeded' }, 429);
        }
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

      // E2E encrypted backup: extract blob and salt from profile.__e2e pattern
      if (body.profile?.__e2e === true) {
        row.encrypted_blob = body.profile.encrypted_blob ?? null;
        row.backup_salt = body.profile.backup_salt ?? null;
      }

      const { error } = await admin
        .from('user_data')
        .upsert(row, { onConflict: 'sync_key' });

      if (error) return json({ error: 'DB error' }, 500);

      // ── Emit Realtime signal for exchange keys ─────────────────────
      // When a user pushes to an exchange key, notify the OTHER user via
      // the sync_signals table so their Realtime subscription triggers a pull.
      if (exchange) {
        try {
          await emitSyncSignal(admin, key);
        } catch {
          // Signal emission is best-effort; don't fail the push.
        }
      }

      return json({ ok: true });
    }

    return json({ error: 'Method not allowed' }, 405);
  } catch {
    return json({ error: 'Unexpected error' }, 500);
  }
});
