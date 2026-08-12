import Image from "next/image";
import { ImageIcon } from "lucide-react";
import { supabase } from "@/lib/supabase";

type ResourceType="PERSON"|"POINT"|"AID";
export async function MediaGallery({resourceType,resourceId,fallbackUrl,alt}:{resourceType:ResourceType;resourceId:string;fallbackUrl?:string|null;alt:string}){
 let assets:{id:string;object_path:string;bucket_id?:string|null;width:number;height:number;position:number}[]=[];
 try{const{data}=await supabase().from("media_assets").select("id,object_path,bucket_id,width,height,position").eq("resource_type",resourceType).eq("resource_id",resourceId).order("position");assets=data??[]}catch{}
 const configuredBucket=process.env.SUPABASE_STORAGE_BUCKET??"community-media";
 const urls=assets.map(asset=>({...asset,url:supabase().storage.from(asset.bucket_id??configuredBucket).getPublicUrl(asset.object_path).data.publicUrl}));
 if(!urls.length&&fallbackUrl)urls.push({id:"legacy",object_path:"",bucket_id:null,width:1200,height:900,position:0,url:fallbackUrl});
 if(!urls.length)return <div className="grid aspect-[4/3] max-h-80 place-items-center rounded-2xl bg-slate-100 text-slate-400"><div className="text-center"><ImageIcon className="mx-auto mb-2" size={42}/><span className="text-sm">Sin fotografía</span></div></div>;
 return <div className={`grid gap-3 ${urls.length>1?"sm:grid-cols-2":""}`}>{urls.map((asset,index)=><div className="relative aspect-[4/3] overflow-hidden rounded-2xl bg-slate-100" key={asset.id}><Image src={asset.url} alt={`${alt}${urls.length>1?` — fotografía ${index+1}`:""}`} fill sizes="(max-width: 640px) 100vw, 700px" className="object-cover" unoptimized/></div>)}</div>;
}

type Resource={id:string;photo_url?:string|null;full_name?:string;name?:string;area?:string};
export async function PublicMediaById({resourceType,publicId}:{resourceType:ResourceType;publicId:string}){
 const table=resourceType==="PERSON"?"person_cases":resourceType==="POINT"?"community_points":"aid_requests";
 let resource:Resource|null=null;
 try{const{data}=await supabase().from(table).select("*").eq("public_id",publicId).eq("is_visible",true).maybeSingle();resource=data as Resource|null}catch{}
 if(!resource)return null;
 return <section className="page !py-0"><h2 className="mb-3 text-2xl font-bold">Fotografías</h2><MediaGallery resourceType={resourceType} resourceId={resource.id} fallbackUrl={resource.photo_url} alt={resource.full_name??resource.name??resource.area??"Publicación comunitaria"}/></section>;
}
