import{MediaManager}from"@/components/media-manager";
export default async function PersonLayout({children,params}:{children:React.ReactNode;params:Promise<{id:string}>}){const{id}=await params;return <>{children}<div className="page !pt-0"><MediaManager resourceType="PERSON" publicId={id}/></div></>}
