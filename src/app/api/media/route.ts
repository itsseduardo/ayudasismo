import { NextResponse } from "next/server";
import { authorizeMedia,deleteMedia,isMediaResource,processImage,saveMedia } from "@/lib/media";
import { MAX_IMAGE_BYTES } from "@/lib/media-validation";

export const runtime="nodejs";

export async function POST(request:Request){
 try{
  const length=Number(request.headers.get("content-length")??0);
  if(length>4*1024*1024)return NextResponse.json({error:"La solicitud supera el límite permitido"},{status:413});
  const form=await request.formData();const resourceType=form.get("resourceType"),publicId=form.get("publicId"),token=form.get("token"),file=form.get("file"),position=Number(form.get("position")),consent=form.get("consent");
  if(!isMediaResource(resourceType)||typeof publicId!=="string"||typeof token!=="string"||!(file instanceof File)||file.size===0||consent!=="true")return NextResponse.json({error:"Datos o autorización incompletos"},{status:400});
  if(file.size>MAX_IMAGE_BYTES)return NextResponse.json({error:"La imagen supera 3 MB"},{status:413});
  const resourceId=await authorizeMedia(resourceType,publicId,token,true);const image=await processImage(Buffer.from(await file.arrayBuffer()));const asset=await saveMedia(resourceType,resourceId,position,image);return NextResponse.json({ok:true,asset});
 }catch(error){const message=error instanceof Error?error.message:"";const status=message==="INVALID_ACCESS"?403:message==="RATE_LIMIT"?429:message==="MISSING_STORAGE_BUCKET"?503:400;return NextResponse.json({error:status===403?"PIN o enlace privado inválido":status===429?"Límite de subidas alcanzado. Intenta más tarde.":status===503?"El bucket de fotografías no está configurado o no existe.":"Archivo inválido. Usa JPG, PNG o WebP de hasta 3 MB."},{status})}
}

export async function DELETE(request:Request){
 try{const body=await request.json();if(!isMediaResource(body.resourceType)||typeof body.publicId!=="string"||typeof body.token!=="string"||!Number.isInteger(body.position))return NextResponse.json({error:"Datos inválidos"},{status:400});const resourceId=await authorizeMedia(body.resourceType,body.publicId,body.token,true);await deleteMedia(body.resourceType,resourceId,body.position);return NextResponse.json({ok:true})}catch(error){const message=error instanceof Error?error.message:"";const status=message==="INVALID_ACCESS"?403:message==="RATE_LIMIT"?429:500;return NextResponse.json({error:status===403?"PIN o enlace privado inválido":status===429?"Límite de cambios alcanzado":"No se pudo eliminar la fotografía. Inténtalo de nuevo."},{status})}
}
