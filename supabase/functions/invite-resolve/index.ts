import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { getCorsHeaders } from '../_shared/cors.ts';
import { json } from '../_shared/response.ts';
import { sha256Hex } from '../_shared/crypto.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: getCorsHeaders(req) });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: 'Supabase env missing' }, 500);
    }

    // ── Optional authentication ──────────────────────────────────────────
    // Invite acceptance must also work for guest users (no Supabase session).
    // If a valid bearer token is provided, we store accepter_user_id.
    const authHeader = req.headers.get('Authorization');
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let accepterUserId: string | null = null;
    if (authHeader?.startsWith('Bearer ')) {
      const userToken = authHeader.slice(7);
      const { data: { user } } = await admin.auth.getUser(userToken);
      accepterUserId = user?.id ?? null;
    }
    // ───────────────────────────────────────────────────────────────────

    const body = await req.json();
    const incomingUrl = String(body.incomingUrl ?? '').trim();
    if (!incomingUrl) return json({ valid: false, error: 'incomingUrl required' }, 400);

    // Accepter's profile used for immediate bootstrap on inviter side.
    const accepterProfile = body.accepterProfile && typeof body.accepterProfile === 'object'
      ? {
          name: String(body.accepterProfile.name ?? '').substring(0, 100),
          handle: String(body.accepterProfile.handle ?? '').substring(0, 100),
          memberSince: typeof body.accepterProfile.memberSince === 'number' ? body.accepterProfile.memberSince : null,
          birthdate: body.accepterProfile.birthdate ? String(body.accepterProfile.birthdate).substring(0, 32) : null,
          address: body.accepterProfile.address ? String(body.accepterProfile.address).substring(0, 300) : null,
          mondialRelayPoint: body.accepterProfile.mondialRelayPoint
            ? String(body.accepterProfile.mondialRelayPoint).substring(0, 300)
            : null,
          hideBirthdate: Boolean(body.accepterProfile.hideBirthdate ?? false),
          hideAddress: Boolean(body.accepterProfile.hideAddress ?? false),
          hideMondialRelay: Boolean(body.accepterProfile.hideMondialRelay ?? false),
          avatarIcon: body.accepterProfile.avatarIcon
            ? String(body.accepterProfile.avatarIcon).substring(0, 200)
            : null,
          avatarColor: typeof body.accepterProfile.avatarColor === 'number' ? body.accepterProfile.avatarColor : null,
          fcmToken: body.accepterProfile.fcmToken ? String(body.accepterProfile.fcmToken).substring(0, 400) : null,
          sizes: Array.isArray(body.accepterProfile.sizes) ? body.accepterProfile.sizes : null,
          wishes: Array.isArray(body.accepterProfile.wishes) ? body.accepterProfile.wishes : null,
        }
      : null;

    let parsed: URL;
    try {
      parsed = new URL(incomingUrl);
    } catch {
      return json({ valid: false, error: 'invalid url' }, 400);
    }

    const token = parsed.searchParams.get('token') ?? parsed.searchParams.get('tokenId');
    // Enforce max length before hashing to prevent DoS via large inputs.
    if (!token || token.length > 256) return json({ valid: false });

    const tokenHash = await sha256Hex(token);

    const { data, error } = await admin
      .from('invites')
      .select('id, inviter_id, contact_id, group_id, expires_at, status, inviter_profile')
      .eq('token_hash', tokenHash)
      .maybeSingle();

    if (error || !data) return json({ valid: false });
    if (data.status !== 'pending') return json({ valid: false, tokenId: token, reason: 'already_consumed' });

    const expiresAt = new Date(data.expires_at);
    if (expiresAt.getTime() <= Date.now()) {
      await admin.from('invites').update({ status: 'expired' }).eq('id', data.id);
      return json({ valid: false, tokenId: token, expiresAt: expiresAt.toISOString(), reason: 'expired' });
    }

    // Atomically accept + store accepter profile + record accepter_user_id
    const updatePayload: Record<string, unknown> = {
      status: 'accepted',
      accepted_at: new Date().toISOString(),
      accepter_user_id: accepterUserId,
    };
    if (accepterProfile) {
      updatePayload.accepter_profile = accepterProfile;
    }

    const { error: updateErr } = await admin
      .from('invites')
      .update(updatePayload)
      .eq('id', data.id)
      .eq('status', 'pending');

    if (updateErr) return json({ valid: false, tokenId: token, reason: 'race_or_update_failed' });

    return json({
      valid: true,
      tokenId: token,
      inviterId: data.inviter_id,
      contactId: data.contact_id,
      groupId: data.group_id,
      expiresAt: expiresAt.toISOString(),
      inviterProfile: data.inviter_profile ?? null,
    });
  } catch {
    return json({ valid: false }, 500);
  }
});
