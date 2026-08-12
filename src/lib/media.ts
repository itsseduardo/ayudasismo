import "server-only";
import { randomUUID } from "node:crypto";
import sharp from "sharp";
import { supabaseAdmin } from "./supabase-admin";
import { MAX_IMAGE_BYTES,validateImageInput } from "./media-validation";

export type MediaResource = "PERSON" | "POINT" | "AID";
const limits: Record<MediaResource, number> = { PERSON: 1, POINT: 3, AID: 3 };
export function mediaBucket(){const bucket=process.env.SUPABASE_STORAGE_BUCKET;if(!bucket)throw new Error("MISSING_STORAGE_BUCKET");return bucket}
function mediaFolder(type:MediaResource){return type==="PERSON"?"persons":type==="POINT"?"points":"aid"}
function logMediaError(operation:string,resourceType:MediaResource,error:unknown){const candidate=error as{code?:unknown;message?:unknown};console.error("[media]",{operation,resourceType,bucket:process.env.SUPABASE_STORAGE_BUCKET??"not-configured",code:typeof candidate?.code==="string"?candidate.code:"MEDIA_ERROR",message:typeof candidate?.message==="string"?candidate.message:"Unexpected media error"})}

export function isMediaResource(value: unknown): value is MediaResource {
  return value === "PERSON" || value === "POINT" || value === "AID";
}

export async function authorizeMedia(resourceType: MediaResource, publicId: string, token: string, recordEvent = true) {
  const { data, error } = await supabaseAdmin().rpc("authorize_media_change", { p_resource_type: resourceType, p_public_id: publicId, p_token: token, p_record_event: recordEvent });
  if (error || !data) throw new Error(error?.message.includes("rate_limit") ? "RATE_LIMIT" : "INVALID_ACCESS");
  return data as string;
}

export async function processImage(input: Buffer) {
  if (!validateImageInput(input.subarray(0,16),input.byteLength)) throw new Error("INVALID_FILE");
  try {
    const image = sharp(input, { failOn: "warning", limitInputPixels: 40_000_000 }).rotate().resize({ width: 1600, height: 1600, fit: "inside", withoutEnlargement: true });
    const output = await image.webp({ quality: 78, effort: 4 }).toBuffer();
    const metadata = await sharp(output).metadata();
    if (!metadata.width || !metadata.height || output.byteLength > MAX_IMAGE_BYTES) throw new Error("INVALID_FILE");
    return { output, width: metadata.width, height: metadata.height };
  } catch { throw new Error("INVALID_FILE"); }
}

export async function saveMedia(resourceType: MediaResource, resourceId: string, position: number, image: Awaited<ReturnType<typeof processImage>>) {
  if (!Number.isInteger(position) || position<0 || position>=limits[resourceType]) throw new Error("INVALID_POSITION");
  const admin=supabaseAdmin();const bucket=mediaBucket();
  try{const { data: old } = await admin.from("media_assets").select("object_path,bucket_id").eq("resource_type",resourceType).eq("resource_id",resourceId).eq("position",position).maybeSingle();
  const path=`${mediaFolder(resourceType)}/${resourceId}/${randomUUID()}.webp`;
  const upload=await admin.storage.from(bucket).upload(path,image.output,{contentType:"image/webp",upsert:false,cacheControl:"3600"});
  if(upload.error)throw upload.error;
  const saved=await admin.from("media_assets").upsert({resource_type:resourceType,resource_id:resourceId,position,object_path:path,bucket_id:bucket,width:image.width,height:image.height,byte_size:image.output.byteLength,mime_type:"image/webp",updated_at:new Date().toISOString()},{onConflict:"resource_type,resource_id,position"}).select().single();
  if(saved.error){await admin.storage.from(bucket).remove([path]);throw saved.error}
  if(old?.object_path&&old.object_path!==path)await admin.storage.from(old.bucket_id??bucket).remove([old.object_path]);
  if(resourceType==="PERSON"){const url=admin.storage.from(bucket).getPublicUrl(path).data.publicUrl;await admin.from("person_cases").update({photo_url:url,photo_path:path,updated_at:new Date().toISOString()}).eq("id",resourceId)}
  return saved.data}catch(error){logMediaError("save",resourceType,error);throw error}
}

export async function deleteMedia(resourceType: MediaResource, resourceId: string, position: number) {
  const admin=supabaseAdmin();const bucket=mediaBucket();const {data}=await admin.from("media_assets").select("object_path,bucket_id").eq("resource_type",resourceType).eq("resource_id",resourceId).eq("position",position).maybeSingle();
  if(data?.object_path)await admin.storage.from(data.bucket_id??bucket).remove([data.object_path]);
  await admin.from("media_assets").delete().eq("resource_type",resourceType).eq("resource_id",resourceId).eq("position",position);
  if(resourceType==="PERSON")await admin.from("person_cases").update({photo_url:null,photo_path:null,updated_at:new Date().toISOString()}).eq("id",resourceId);
}

export async function purgeMedia(resourceType: MediaResource, publicId: string) {
  const admin=supabaseAdmin();const table=resourceType==="PERSON"?"person_cases":resourceType==="POINT"?"community_points":"aid_requests";
  const {data:resource}=await admin.from(table).select("id").eq("public_id",publicId).maybeSingle();if(!resource)return;
  const {data:assets}=await admin.from("media_assets").select("object_path,bucket_id").eq("resource_type",resourceType).eq("resource_id",resource.id);
  if(assets?.length)for(const bucket of new Set(assets.map(x=>x.bucket_id??mediaBucket())))await admin.storage.from(bucket).remove(assets.filter(x=>(x.bucket_id??mediaBucket())===bucket).map(x=>x.object_path));
  await admin.from("media_assets").delete().eq("resource_type",resourceType).eq("resource_id",resource.id);
  if(resourceType==="PERSON")await admin.from("person_cases").update({photo_url:null,photo_path:null}).eq("id",resource.id);
}
