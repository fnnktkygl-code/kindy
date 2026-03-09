import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { getCorsHeaders } from '../_shared/cors.ts';
import { json } from '../_shared/response.ts';

Deno.serve(async (req: Request) => {
  const cors = getCorsHeaders(req);
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors });
  }

  try {
    const { level, tag, message, error, stack, userId } = await req.json();

    if (!tag || !message) {
      return json({ error: 'tag and message are required' }, 400, req);
    }

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    await admin.from('error_logs').insert({
      level: level ?? 'error',
      tag,
      message,
      error_detail: error ?? null,
      stack_trace: stack ? String(stack).slice(0, 4000) : null,
      user_id: userId ?? null,
    });

    return json({ ok: true }, 201, req);
  } catch (e) {
    return json({ error: 'internal error' }, 500, req);
  }
});
