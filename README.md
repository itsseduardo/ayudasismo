# Ayuda Sismo

MVP comunitario, móvil y sin cuentas para una emergencia sísmica en Colombia. Permite buscar personas sin contacto, aportar novedades, publicar acopios/refugios y coordinar solicitudes urgentes. La información se identifica siempre como comunitaria y no oficial.

## Desarrollo

Requisitos: Node.js 20+, npm y un proyecto Supabase.

1. Configura en `.env.local` (no se versiona) `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY` y `SUPABASE_STORAGE_BUCKET=report-photos`. La URL debe ser la raíz HTTPS del proyecto, sin `/rest/v1` ni otras rutas. Se admiten `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` como compatibilidad local.
2. Pega y ejecuta el archivo completo `supabase/migrations/202608110001_initial_mvp.sql` en SQL Editor. Es idempotente y puede repetirse tras una ejecución parcial. Opcionalmente ejecuta `supabase/seed.sql`, que contiene solo información ficticia.
3. Para habilitar fotografías, ejecuta `supabase/migrations/202608120001_secure_media.sql` y, después, `supabase/migrations/202608120002_align_report_photos.sql`. La segunda migración crea/configura `report-photos` sin borrar referencias del bucket anterior.
4. Instala con `npm install` e inicia con `npm run dev`.

Las escrituras de formularios pasan por funciones SQL `security definer` limitadas. Las tablas privadas no tienen políticas de lectura pública. Los PIN se guardan con `pgcrypto`/bcrypt y el valor original se muestra una sola vez.

Las fotografías requieren `SUPABASE_SECRET_KEY` exclusivamente en el servidor y `SUPABASE_STORAGE_BUCKET=report-photos`. Nunca uses esas variables con prefijo `NEXT_PUBLIC_`. El navegador envía las imágenes a una Route Handler autenticada; solo el servidor puede escribir o borrar objetos del bucket.

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
