import "server-only";
import { createClient } from "@supabase/supabase-js";

export function supabaseAdmin() {
  const rawUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL;
  const url = rawUrl ? new URL(rawUrl).origin : undefined;
  const secret = process.env.SUPABASE_SECRET_KEY;
  if (!url || !secret) throw new Error("Falta SUPABASE_URL o SUPABASE_SECRET_KEY en el servidor");
  return createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } });
}
