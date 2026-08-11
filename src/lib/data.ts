import { supabase } from "./supabase";
import type { AidRequest, PersonCase, Point } from "./types";

export async function getPeople(q = "", municipality = "") {
  let query = supabase().from("person_cases").select("*").eq("is_visible", true).order("updated_at", { ascending: false }).limit(50);
  if (q) query = query.ilike("normalized_name", `%${q.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase()}%`);
  if (municipality) query = query.ilike("municipality", `%${municipality}%`);
  const { data } = await query; return (data ?? []) as PersonCase[];
}
export async function getPerson(id: string) { const { data } = await supabase().from("person_cases").select("*").eq("public_id", id).eq("is_visible", true).maybeSingle(); return data as PersonCase | null; }
export async function getPersonUpdates(id: string) { const { data } = await supabase().from("person_updates").select("*").eq("case_id", id).order("created_at", { ascending: false }); return data ?? []; }
export async function getPoints(type?: string) { let q = supabase().from("community_points").select("*").eq("is_visible", true).order("updated_at", { ascending: false }).limit(60); if (type) q = q.eq("type", type); const { data } = await q; return (data ?? []) as Point[]; }
export async function getPoint(id: string) { const { data } = await supabase().from("community_points").select("*").eq("public_id", id).eq("is_visible", true).maybeSingle(); return data as Point | null; }
export async function getAid() { const { data } = await supabase().from("aid_requests").select("*").eq("is_visible", true).order("created_at", { ascending: false }).limit(60); return (data ?? []) as AidRequest[]; }
export async function getAidOne(id: string) { const { data } = await supabase().from("aid_requests").select("*").eq("public_id", id).eq("is_visible", true).maybeSingle(); return data as AidRequest | null; }
export async function stats() { const db = supabase(); const [p,l,c,a] = await Promise.all([db.from("person_cases").select("id",{count:"exact",head:true}).eq("is_visible",true),db.from("person_cases").select("id",{count:"exact",head:true}).eq("status","LOCALIZADO_CONFIRMADO").eq("is_visible",true),db.from("community_points").select("id",{count:"exact",head:true}).eq("is_visible",true),db.from("aid_requests").select("id",{count:"exact",head:true}).eq("is_visible",true).neq("status","ATENDIDA")]); return { people:p.count??0, located:l.count??0, points:c.count??0, aid:a.count??0 }; }
