import { createClient } from "@supabase/supabase-js";

export function supabase() {
  const rawUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL;
  const url = rawUrl ? new URL(rawUrl).origin : undefined;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? process.env.SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error("Falta configurar Supabase");
  return createClient(url, key, { auth: { persistSession: false }, global: { headers: { "X-Client-Info": "ayuda-sismo-web" } } });
}

export function friendlyError(error: unknown) {
  const candidate=error as{message?:unknown;code?:unknown};
  const message = error instanceof Error ? error.message : typeof candidate?.message==="string"?candidate.message:"No fue posible completar la solicitud";
  if (message.includes("duplicate")) return "Este envío ya fue recibido.";
  if (message.includes("rate_limit")) return "Demasiados intentos. Espera unos minutos.";
  if(message.includes("Falta configurar Supabase"))return "La conexión con Supabase no está configurada en el servidor.";
  return "No se pudo guardar. Revisa la conexión e inténtalo de nuevo.";
}
