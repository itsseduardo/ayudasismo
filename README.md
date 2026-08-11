# Ayuda Sismo

MVP comunitario, móvil y sin cuentas para una emergencia sísmica en Colombia. Permite buscar personas sin contacto, aportar novedades, publicar acopios/refugios y coordinar solicitudes urgentes. La información se identifica siempre como comunitaria y no oficial.

## Desarrollo

Requisitos: Node.js 20+, npm y un proyecto Supabase.

1. Conserva en `.env.local` (no se versiona) `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`. También se admiten los nombres `NEXT_PUBLIC_SUPABASE_URL` y `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` por compatibilidad.
2. Pega y ejecuta el archivo completo `supabase/migrations/202608110001_initial_mvp.sql` en SQL Editor. Es idempotente y puede repetirse tras una ejecución parcial. Opcionalmente ejecuta `supabase/seed.sql`, que contiene solo información ficticia.
3. Instala con `npm install` e inicia con `npm run dev`.

No hace falta una service-role key: las escrituras públicas pasan por funciones SQL `security definer` limitadas. Las tablas privadas no tienen políticas de lectura pública. Los PIN se guardan con `pgcrypto`/bcrypt y el valor original se muestra una sola vez.

## Verificación

```bash
npm run typecheck
npm run lint
npm test
npm run build
```

Las pruebas automatizadas cubren validación, sanitización, honeypot y la imposibilidad de que una actualización comunitaria establezca `LOCALIZADO_CONFIRMADO`. Para probar RLS y flujos completos contra una base local, aplica la migración y usa los tres formularios; la publicación devuelve el PIN y enlace privado necesarios para las actualizaciones.

## Despliegue en Vercel

Importa el repositorio, configura las dos variables públicas de Supabase en Vercel y despliega. No agregues claves administrativas al cliente. El manifiesto y service worker convierten la interfaz en PWA instalable y almacenan una navegación pública mínima para conexiones inestables.

## Seguridad y límites del MVP

Hay validación Zod, límites de longitud, campo trampa anti-bot, claves de idempotencia, RLS, separación de teléfonos privados y denuncias comunitarias. Antes de tráfico real se recomienda configurar Turnstile y rate limiting perimetral en Vercel/Supabase; el esquema ya incluye eventos técnicos para ello. La recuperación de PIN por SMS, WhatsApp o correo queda expresamente fuera del MVP.
