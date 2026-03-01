import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { getCorsHeaders } from '../_shared/cors.ts';
import { json } from '../_shared/response.ts';
import { sha256Hex } from '../_shared/crypto.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: getCorsHeaders(req) });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const invitePublicBase = Deno.env.get('INVITE_PUBLIC_BASE') ?? 'https://pigio.app';

    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: 'Supabase env missing' }, 500);
    }

    const body = await req.json();

    // Validate inviterId: must be a non-empty string ≤ 128 chars.
    // Spaces and accented characters are accepted; the DB stores it as-is.
    const rawInviterId = String(body.inviterId ?? '').trim();
    if (!rawInviterId || rawInviterId.length > 128) {
      return json({ error: 'inviterId invalid format' }, 400);
    }
    const inviterId = rawInviterId;

    // Validate contactId and groupId: UUIDs or null.
    const rawContactId = body.contactId ? String(body.contactId).trim() : null;
    const rawGroupId   = body.groupId   ? String(body.groupId).trim()   : null;
    if (rawContactId && !/^[0-9a-zA-Z\-_]{1,128}$/.test(rawContactId)) {
      return json({ error: 'contactId invalid format' }, 400);
    }
    if (rawGroupId && !/^[0-9a-zA-Z\-_]{1,128}$/.test(rawGroupId)) {
      return json({ error: 'groupId invalid format' }, 400);
    }
    const contactId = rawContactId;
    const groupId   = rawGroupId;

    const allowedChannels = ['copyLink', 'share', 'qr'] as const;
    const rawChannel = String(body.channel ?? 'copyLink').trim();
    const channel = allowedChannels.includes(rawChannel as typeof allowedChannels[number])
      ? rawChannel
      : 'copyLink';
    const ttlSeconds = Number(body.ttlSeconds ?? 172800);

    // Sender's profile used for initial contact bootstrap on the accepter side.
    // Keep all relevant sync fields (not only name/avatar) so both sides can
    // immediately see profile details before the first periodic pull.
    const inviterProfile = body.profile && typeof body.profile === 'object'
      ? {
          name: String(body.profile.name ?? '').substring(0, 100),
          handle: String(body.profile.handle ?? '').substring(0, 100),
          memberSince: typeof body.profile.memberSince === 'number' ? body.profile.memberSince : null,
          birthdate: body.profile.birthdate ? String(body.profile.birthdate).substring(0, 32) : null,
          address: body.profile.address ? String(body.profile.address).substring(0, 300) : null,
          mondialRelayPoint: body.profile.mondialRelayPoint
            ? String(body.profile.mondialRelayPoint).substring(0, 300)
            : null,
          hideBirthdate: Boolean(body.profile.hideBirthdate ?? false),
          hideAddress: Boolean(body.profile.hideAddress ?? false),
          hideMondialRelay: Boolean(body.profile.hideMondialRelay ?? false),
          avatarIcon: body.profile.avatarIcon ? String(body.profile.avatarIcon).substring(0, 200) : null,
          avatarColor: typeof body.profile.avatarColor === 'number' ? body.profile.avatarColor : null,
          fcmToken: body.profile.fcmToken ? String(body.profile.fcmToken).substring(0, 400) : null,
          sizes: Array.isArray(body.profile.sizes) ? body.profile.sizes : null,
          wishes: Array.isArray(body.profile.wishes) ? body.profile.wishes : null,
        }
      : null;

    if (!inviterId) return json({ error: 'inviterId is required' }, 400);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Rate limiting: max 20 invites per hour per inviterId
    const { count: inviterCount } = await admin
      .from('invites')
      .select('id', { count: 'exact', head: true })
      .eq('inviter_id', inviterId)
      .gte('created_at', new Date(Date.now() - 3600_000).toISOString());

    if (inviterCount && inviterCount > 20) {
      return json({ error: 'Rate limit exceeded' }, 429);
    }

    const now = Date.now();
    const expiresAt = new Date(now + Math.max(300, Math.min(ttlSeconds, 604800)) * 1000);

    const tokenBytes = crypto.getRandomValues(new Uint8Array(32));
    const token = btoa(String.fromCharCode(...tokenBytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
    const tokenHash = await sha256Hex(token);

    const { data, error } = await admin
      .from('invites')
      .insert({
        token_hash: tokenHash,
        inviter_id: inviterId,
        contact_id: contactId,
        group_id: groupId,
        channel,
        expires_at: expiresAt.toISOString(),
        inviter_profile: inviterProfile,
      })
      .select('id')
      .single();

    if (error || !data) {
      return json({ error: 'Failed to create invite', details: error?.message }, 500);
    }

    const inviteUrl = new URL('/functions/v1/invite-open', invitePublicBase);
    inviteUrl.searchParams.set('token', token);

    return json({
      invitationId: data.id,
      tokenId: token,
      inviteLink: inviteUrl.toString(),
      expiresAt: expiresAt.toISOString(),
    });
  } catch {
    return json({ error: 'Unexpected error' }, 500);
  }
});
