"use client";

import Link from "next/link";
import { Menu } from "lucide-react";
import { useRef } from "react";

export function MobileNav(){
 const details=useRef<HTMLDetailsElement>(null);
 const close=()=>details.current?.removeAttribute("open");
 return <details ref={details} className="relative md:hidden"><summary className="list-none" aria-label="Abrir menú de navegación"><Menu/></summary><nav className="absolute right-0 z-20 mt-3 grid w-64 gap-3 rounded-xl border bg-white p-4 shadow-xl"><Link href="/personas" onClick={close}>Personas</Link><Link href="/puntos" onClick={close}>Acopios y refugios</Link><Link href="/ayuda" onClick={close}>Ayuda urgente</Link><a href="https://portfolio-jesus-nu.vercel.app/" target="_blank" rel="noopener noreferrer" className="border-t pt-3 text-sm text-slate-500" onClick={close}>Desarrollado por <strong>ItssEduardo</strong></a></nav></details>;
}
