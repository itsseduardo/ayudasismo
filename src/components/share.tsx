"use client";

import { useSyncExternalStore } from "react";
import { Copy, MessageCircle } from "lucide-react";

export function Share({ text }: { text: string }) {
  const url = useSyncExternalStore(() => () => {}, () => location.href, () => "");
  return <div className="flex flex-wrap gap-2"><a className="btn-primary" href={`https://wa.me/?text=${encodeURIComponent(`${text}\n${url}`)}`} target="_blank" rel="noreferrer"><MessageCircle size={18}/> Compartir por WhatsApp</a><button className="btn-secondary" onClick={() => navigator.clipboard.writeText(location.href)}><Copy size={18}/> Copiar enlace</button></div>;
}
