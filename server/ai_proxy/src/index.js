// Proxy de IA de Balancore (Cloudflare Worker, plan gratuito).
//
// La app le manda SOLO el prompt; el Worker añade la clave de Gemini (que vive
// como secreto del servidor) y devuelve la respuesta del modelo tal cual. Así
// la clave nunca viaja al cliente.
//
// Secretos (se configuran con `wrangler secret put`, jamás en el repo):
//   GEMINI_API_KEY  (obligatorio)  clave de Google AI Studio
//   AI_PROXY_TOKEN  (opcional)     token que debe mandar la app en `x-ai-token`

const GEMINI_MODEL = 'gemini-3.8-flash';
const MAX_PROMPT_CHARS = 20000;

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }
    if (request.method !== 'POST') {
      return json({ error: 'Método no permitido' }, 405);
    }

    const expectedToken = (env.AI_PROXY_TOKEN || '').trim();
    if (expectedToken) {
      const got = request.headers.get('x-ai-token') || '';
      if (got !== expectedToken) return json({ error: 'No autorizado' }, 401);
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json({ error: 'JSON inválido' }, 400);
    }
    const prompt = typeof payload?.prompt === 'string' ? payload.prompt : '';
    if (prompt.trim().length === 0) return json({ error: 'Falta el prompt' }, 400);
    if (prompt.length > MAX_PROMPT_CHARS) {
      return json({ error: 'Prompt demasiado largo' }, 413);
    }

    const key = (env.GEMINI_API_KEY || '').trim();
    if (!key) return json({ error: 'Falta GEMINI_API_KEY en el servidor' }, 500);

    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${key}`;

    let upstream;
    try {
      upstream = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: 'application/json',
            temperature: 0.7,
          },
        }),
      });
    } catch {
      return json({ error: 'No se pudo contactar a Gemini' }, 502);
    }

    // Devolvemos la respuesta de Gemini tal cual: el cliente ya sabe parsearla.
    return new Response(upstream.body, {
      status: upstream.status,
      headers: { ...corsHeaders(), 'Content-Type': 'application/json' },
    });
  },
};

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, x-ai-token',
    'Access-Control-Max-Age': '86400',
  };
}

function json(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders(), 'Content-Type': 'application/json' },
  });
}
