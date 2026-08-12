"use server";
import { revalidatePath } from "next/cache";
import { aidSchema, formObject, personSchema, personUpdateSchema, pinSchema, pointSchema, splitList } from "@/lib/validation";
import { friendlyError, supabase } from "@/lib/supabase";
import { purgeMedia } from "@/lib/media";

export type ActionState = { ok?: boolean; error?: string; mediaError?: string; publicId?: string; pin?: string; editToken?: string };
const bad = (e: unknown): ActionState => ({ error: friendlyError(e) });

export async function createPerson(_: ActionState, form: FormData): Promise<ActionState> {
  try { const v = personSchema.parse(formObject(form)); const { data, error } = await supabase().rpc("create_person_case", { payload: v }); if (error) throw error;revalidatePath("/"); return { ok:true, publicId:data.public_id, pin:data.pin, editToken:data.edit_token }; } catch(e) { return bad(e); }
}
export async function addPersonUpdate(_: ActionState, form: FormData): Promise<ActionState> {
  try { const v = personUpdateSchema.parse(formObject(form)); const { error } = await supabase().rpc("add_person_update", { payload:v }); if(error) throw error; revalidatePath(`/personas/${form.get("public_id")}`); return {ok:true}; } catch(e){ return bad(e); }
}
export async function createPoint(_: ActionState, form: FormData): Promise<ActionState> {
  try { const v = pointSchema.parse(formObject(form)); const payload={...v,services:splitList(v.services),items:splitList(v.items)}; const {data,error}=await supabase().rpc("create_community_point",{payload}); if(error) throw error;revalidatePath("/puntos"); return {ok:true,publicId:data.public_id,pin:data.pin,editToken:data.edit_token}; } catch(e){return bad(e)}
}
export async function createAid(_: ActionState, form: FormData): Promise<ActionState> {
  try { const raw=formObject(form); const v=aidSchema.parse({...raw,needs:form.getAll("needs")}); const {data,error}=await supabase().rpc("create_aid_request",{payload:v}); if(error) throw error;revalidatePath("/ayuda"); return {ok:true,publicId:data.public_id,pin:data.pin,editToken:data.edit_token}; }catch(e){return bad(e)}
}
export async function updateWithPin(_: ActionState, form: FormData): Promise<ActionState> {
  try { const v=pinSchema.parse(formObject(form)); const {error}=await supabase().rpc("update_resource_status",{payload:v}); if(error) throw error; if(v.status==="HIDDEN")await purgeMedia(v.resource_type,v.public_id);revalidatePath("/"); return {ok:true}; } catch{return {error:"PIN o enlace inválido. No se realizó ningún cambio."}}
}
export async function communitySignal(_: ActionState, form: FormData): Promise<ActionState> {
  try { const {error}=await supabase().rpc("add_community_signal",{payload:{resource_type:String(form.get("resource_type")),resource_id:String(form.get("resource_id")),kind:String(form.get("kind")),message:String(form.get("message")||""),idempotency_key:String(form.get("idempotency_key"))}}); if(error) throw error; revalidatePath("/"); return {ok:true}; }catch(e){return bad(e)}
}
