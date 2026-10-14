# Proxy de IA de Balancore

Worker de Cloudflare que guarda la clave de Gemini en el servidor para que
**no haya que meterla en el APK** ni pagar Cloud Functions. La app le manda
solo el prompt; el Worker añade la clave y devuelve la respuesta de Gemini.

- Plan **gratuito** de Cloudflare Workers: 100.000 peticiones/día, sin tarjeta.
- La clave se guarda como *secreto* del Worker (`wrangler secret put`), nunca
  en el repositorio.

## Desplegar

```bash
cd server/ai_proxy

# 1) Login y despliegue (npx evita instalar nada globalmente)
npx wrangler login
npx wrangler deploy

# 2) Guardar la clave de Gemini como secreto (se pide en el momento)
npx wrangler secret put GEMINI_API_KEY
# Pega la clave de https://aistudio.google.com/apikey

# 3) (Opcional) token compartido para frenar abuso casual
npx wrangler secret put AI_PROXY_TOKEN
```

`wrangler deploy` imprime la URL pública, del tipo
`https://balancore-ai-proxy.TU-SUBDOMINIO.workers.dev`.

## Compilar la app apuntando al proxy

```bash
flutter run \
  --dart-define=AI_PROXY_URL=https://balancore-ai-proxy.TU-SUBDOMINIO.workers.dev \
  --dart-define=AI_PROXY_TOKEN=tu-token   # solo si configuraste el secreto
```

Con `AI_PROXY_URL` presente la IA queda disponible sin configurar ninguna clave
en el móvil; si además el usuario trae su propia clave en Ajustes, esa manda.

## Probar en local

```bash
npx wrangler dev
# Crea server/ai_proxy/.dev.vars (ignorado por git) con:
#   GEMINI_API_KEY="AIza..."
#   AI_PROXY_TOKEN="dev-token"
curl -X POST http://localhost:8787 \
  -H 'Content-Type: application/json' \
  -H 'x-ai-token: dev-token' \
  -d '{"prompt":"Responde solo con {\"days\":[]}"}'
```

## Frenar el abuso (recomendado, gratis)

El endpoint es público; el token frena lo casual. Para limitar por IP usa las
*Rate limiting rules* gratuitas de Cloudflare (panel → Security → WAF) sobre la
ruta del Worker.

## Alternativa: Deno Deploy

Deno Deploy también es gratis y sin tarjeta. El mismo `src/index.js` casi sirve:
cambia `export default { fetch }` por `Deno.serve(async (request) => { ... })` y
lee los secretos de `Deno.env.get('GEMINI_API_KEY')`.
