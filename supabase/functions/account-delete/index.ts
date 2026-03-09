import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { getCorsHeaders } from '../_shared/cors.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: getCorsHeaders(req) });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Missing authorization' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Verify the user's JWT
    const userToken = authHeader.slice(7);
    const { data: { user }, error: authError } = await supabase.auth.getUser(userToken);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const userId = user.id;

    // Delete user_data — prefer user_id, fallback to client-supplied syncKey
    const { count: deletedByUid } = await supabase
      .from('user_data')
      .delete({ count: 'exact' })
      .eq('user_id', userId);

    if (!deletedByUid || deletedByUid === 0) {
      // Fallback for legacy rows without user_id column populated
      const body = await req.json().catch(() => ({}));
      const syncKey = typeof body.syncKey === 'string' ? body.syncKey.trim() : '';
      if (syncKey && syncKey.length >= 16) {
        await supabase.from('user_data').delete().eq('sync_key', syncKey);
      }
    }

    // Nullify accepter_profile in invites where this user accepted (GDPR erasure)
    await supabase
      .from('invites')
      .update({ accepter_profile: null })
      .eq('accepter_user_id', userId);

    // Delete invites where this user is the inviter
    await supabase.from('invites').delete().eq('inviter_id', userId);

    // Hard-delete the auth user — irreversible
    const { error: deleteError } = await supabase.auth.admin.deleteUser(userId);
    if (deleteError) {
      return new Response(JSON.stringify({ error: 'Failed to delete account' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({
      ok: true,
      message: 'Account and all associated data have been permanently deleted.',
      deleted_at: new Date().toISOString(),
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch {
    return new Response(JSON.stringify({ error: 'Internal error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
