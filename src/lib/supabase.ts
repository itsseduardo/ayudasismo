import { createClient } from "@supabase/supabase-js";

export function supabase() {
  const url = process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error("Falta configurar Supabase");
  return createClient(url, key, { auth: { persistSession: false }, global: { headers: { "X-Client-Info": "ayuda-sismo-web" } } });
}

export function friendlyError(error: unknown) {
  const message = error instanceof Error ? error.message : "No fue posible completar la solicitud";
  if (message.includes("duplicate")) return "Este envío ya fue recibido.";
  if (message.includes("rate_limit")) return "Demasiados intentos. Espera unos minutos.";
  return "No se pudo guardar. Revisa la conexión e inténtalo de nuevo.";
}
