import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { getCorsHeaders } from '../_shared/cors.ts';
import { json } from '../_shared/response.ts';
import { sha256Hex } from '../_shared/crypto.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: getCorsHeaders(req) });
  if (req.method !== 'GET') return json({ error: 'Method not allowed' }, 405);

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: 'Supabase env missing' }, 500);
    }

    const url = new URL(req.url);
    const token = (url.searchParams.get('token') ?? url.searchParams.get('tokenId') ?? '').trim();
    // Cap before hashing to prevent DoS via large inputs.
    if (!token || token.length > 256) return json({ found: false, status: 'missing_token' }, 400);

    const tokenHash = await sha256Hex(token);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data, error } = await admin
      .from('invites')
      .select('id, inviter_id, contact_id, group_id, status, expires_at, accepted_at, accepter_profile')
      .eq('token_hash', tokenHash)
      .maybeSingle();

    if (error || !data) return json({ found: false, status: 'not_found' });

    return json({
      found: true,
      invitationId: data.id,
      inviterId: data.inviter_id,
      contactId: data.contact_id,
      groupId: data.group_id,
      status: data.status,
      expiresAt: data.expires_at,
      acceptedAt: data.accepted_at,
      accepterProfile: data.accepter_profile ?? null,
    });
  } catch {
    return json({ found: false, status: 'error' }, 500);
  }
});
