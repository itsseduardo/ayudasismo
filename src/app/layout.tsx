import type { Metadata, Viewport } from "next";
import { Geist } from "next/font/google";
import { Header, Footer } from "@/components/site";
import { Pwa } from "@/components/pwa";
import "./globals.css";
const geist=Geist({variable:"--font-geist",subsets:["latin"]});
export const metadata:Metadata={title:{default:"Ayuda Sismo Colombia",template:"%s | Ayuda Sismo"},description:"Red comunitaria para buscar personas, encontrar refugios y coordinar ayuda.",manifest:"/manifest.webmanifest",icons:{apple:"/icon.svg"}};
export const viewport:Viewport={themeColor:"#0f766e",width:"device-width",initialScale:1};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="es"><body className={geist.variable}><Pwa/><Header/><main className="flex-1">{children}</main><Footer/></body></html>}
