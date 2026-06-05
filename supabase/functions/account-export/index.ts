import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { getCorsHeaders } from '../_shared/cors.ts';

Deno.serve(async (req: Request) => {
  const corsHeaders = getCorsHeaders(req);

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing authorization' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Verify the user's JWT
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Export all user data
    const userId = user.id;
    const email = user.email;

    // Fetch user_data — prefer user_id lookup, fallback to syncKey from body
    let userData: unknown[] = [];
    const { data: byUserId } = await supabase
      .from('user_data')
      .select('*')
      .eq('user_id', userId);

    if (byUserId && byUserId.length > 0) {
      userData = byUserId;
    } else {
      // Fallback for legacy rows without user_id column populated
      const body = await req.json().catch(() => ({})) as Record<string, unknown>;
      const syncKey = typeof body.syncKey === 'string' ? (body.syncKey as string).trim() : '';
      if (syncKey && syncKey.length >= 16) {
        const { data: byKey } = await supabase
          .from('user_data')
          .select('*')
          .eq('sync_key', syncKey);
        if (byKey) userData = byKey;
      }
    }

    // Fetch invites where user is inviter
    const { data: sentInvites } = await supabase
      .from('invites')
      .select('*')
      .eq('inviter_id', userId);

    const exportData = {
      exported_at: new Date().toISOString(),
      user: {
        id: userId,
        email: email,
        created_at: user.created_at,
      },
      user_data: userData || [],
      sent_invites: sentInvites || [],
    };

    return new Response(JSON.stringify(exportData, null, 2), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
        'Content-Disposition': `attachment; filename="pigio-export-${userId}.json"`,
      },
    });
  } catch {
    return new Response(JSON.stringify({ error: 'Internal error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
