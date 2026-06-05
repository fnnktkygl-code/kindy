import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { getCorsHeaders } from '../_shared/cors.ts';
import { json } from '../_shared/response.ts';

/**
 * AI Proxy — proxies Vertex AI (Gemini) requests so the API key stays server-side.
 *
 * Required secrets:
 *   supabase secrets set VERTEX_AI_KEY=your-vertex-ai-key
 *   supabase secrets set VERTEX_PROJECT_ID=your-project-id
 *
 * POST { systemPrompt, userPrompt, maxOutputTokens?, temperature?, useThinking? }
 * Returns { text } or { error }
 */

// Per-user rate limiter: max 30 AI requests per hour.
const userRateMap = new Map<string, { count: number; resetAt: number }>();
const USER_RATE_LIMIT = 30;
const USER_RATE_WINDOW_MS = 3_600_000;

function isUserRateLimited(userId: string): boolean {
  const now = Date.now();
  const entry = userRateMap.get(userId);
  if (!entry || now >= entry.resetAt) {
    userRateMap.set(userId, { count: 1, resetAt: now + USER_RATE_WINDOW_MS });
    return false;
  }
  entry.count++;
  return entry.count > USER_RATE_LIMIT;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: getCorsHeaders(req) });
  }
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const vertexApiKey = Deno.env.get('VERTEX_AI_KEY') ?? '';
    const vertexProjectId = Deno.env.get('VERTEX_PROJECT_ID') ?? '';
    const vertexRegion = 'europe-west9';
    const vertexModel = 'gemini-2.5-flash';

    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: 'Supabase env missing' }, 500);
    }
    if (!vertexApiKey || !vertexProjectId) {
      return json({ error: 'AI not configured' }, 500);
    }

    // ── Authentication ─────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return json({ error: 'Missing authorization' }, 401);
    }
    const userToken = authHeader.slice(7);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: { user }, error: authError } = await admin.auth.getUser(userToken);
    if (authError || !user) {
      return json({ error: 'Invalid token' }, 401);
    }

    if (isUserRateLimited(user.id)) {
      return json({ error: 'Rate limit exceeded' }, 429);
    }
    // ───────────────────────────────────────────────────────────────────

    const body = await req.json();
    const systemPrompt = typeof body.systemPrompt === 'string' ? body.systemPrompt.substring(0, 2000) : '';
    const userPrompt = typeof body.userPrompt === 'string' ? body.userPrompt.substring(0, 4000) : '';
    const maxOutputTokens = typeof body.maxOutputTokens === 'number' ? Math.min(body.maxOutputTokens, 200) : 80;
    const temperature = typeof body.temperature === 'number' ? Math.min(Math.max(body.temperature, 0), 2) : 0.9;
    const useThinking = Boolean(body.useThinking ?? false);

    if (!systemPrompt || !userPrompt) {
      return json({ error: 'systemPrompt and userPrompt are required' }, 400);
    }

    const vertexUrl = `https://${vertexRegion}-aiplatform.googleapis.com/v1/projects/${vertexProjectId}/locations/${vertexRegion}/publishers/google/models/${vertexModel}:generateContent`;

    const vertexBody = {
      systemInstruction: {
        role: 'system',
        parts: [{ text: systemPrompt }],
      },
      contents: [
        {
          role: 'user',
          parts: [{ text: userPrompt }],
        },
      ],
      generationConfig: {
        ...(!useThinking ? { thinkingConfig: { thinkingBudget: 0 } } : {}),
        maxOutputTokens,
        temperature,
      },
    };

    const vertexResp = await fetch(vertexUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': vertexApiKey,
      },
      body: JSON.stringify(vertexBody),
    });

    if (!vertexResp.ok) {
      return json({ error: 'AI request failed' }, 502);
    }

    const data = await vertexResp.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? null;

    return json({ text });
  } catch {
    return json({ error: 'Unexpected error' }, 500);
  }
});
