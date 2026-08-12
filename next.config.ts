import type { NextConfig } from "next";

const rawSupabaseUrl=process.env.NEXT_PUBLIC_SUPABASE_URL??process.env.SUPABASE_URL;
const supabaseUrl=rawSupabaseUrl?new URL(rawSupabaseUrl).origin:undefined;
const nextConfig: NextConfig = {images:{remotePatterns:supabaseUrl?[new URL("/storage/v1/object/public/**",supabaseUrl)]:[]}};

export default nextConfig;
