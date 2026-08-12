import { NextResponse } from "next/server";
import { authorizeMedia, isMediaResource, mediaBucket } from "@/lib/media";
import { supabaseAdmin } from "@/lib/supabase-admin";

export async function POST(request:Request){
 try{const body=await request.json();if(!isMediaResource(body.resourceType)||typeof body.publicId!=="string"||typeof body.token!=="string")return NextResponse.json({error:"Datos inválidos"},{status:400});const resourceId=await authorizeMedia(body.resourceType,body.publicId,body.token,false);const admin=supabaseAdmin();const {data,error}=await admin.from("media_assets").select("position,object_path,bucket_id,width,height").eq("resource_type",body.resourceType).eq("resource_id",resourceId).order("position");if(error)throw error;return NextResponse.json({assets:(data??[]).map(x=>({...x,url:admin.storage.from(x.bucket_id??mediaBucket()).getPublicUrl(x.object_path).data.publicUrl}))})}catch(error){const message=error instanceof Error?error.message:"";return NextResponse.json({error:message==="MISSING_STORAGE_BUCKET"?"El almacenamiento no está configurado":"PIN o enlace privado inválido"},{status:message==="MISSING_STORAGE_BUCKET"?503:403})}
}
