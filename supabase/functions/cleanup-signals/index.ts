import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { json } from '../_shared/response.ts';

/**
 * Scheduled cleanup of sync_signals rows older than 24 hours.
 *
 * Invoke via Supabase Cron / pg_net / manual HTTP call:
 *   POST /functions/v1/cleanup-signals
 *
 * Requires Authorization: Bearer <service-role-key> or a valid JWT.
 */
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { status: 200 });
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

    // Delete signals older than 24 hours
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const { count, error } = await admin
      .from('sync_signals')
      .delete()
      .lt('created_at', cutoff)
      .select('id', { count: 'exact', head: true });

    if (error) {
      return json({ error: 'Cleanup failed', details: error.message }, 500);
    }

    return json({ ok: true, deletedBefore: cutoff, count: count ?? 0 });
  } catch {
    return json({ error: 'Unexpected error' }, 500);
  }
});
