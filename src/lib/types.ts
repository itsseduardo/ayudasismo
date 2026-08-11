export type PersonStatus = "SIN_CONTACTO" | "INFORMACION_NUEVA" | "REPORTADO_LOCALIZADO" | "LOCALIZADO_CONFIRMADO";
export type AidStatus = "AYUDA_SOLICITADA" | "ALGUIEN_RESPONDIO" | "AYUDA_EN_CAMINO" | "PARCIALMENTE_ATENDIDA" | "ATENDIDA";

export const personStatus: Record<PersonStatus, string> = {
  SIN_CONTACTO: "Aún sin contacto",
  INFORMACION_NUEVA: "Hay información nueva",
  REPORTADO_LOCALIZADO: "Alguien reportó haberla localizado",
  LOCALIZADO_CONFIRMADO: "Localizada y confirmada",
};

export const aidStatus: Record<AidStatus, string> = {
  AYUDA_SOLICITADA: "Ayuda solicitada",
  ALGUIEN_RESPONDIO: "Alguien respondió",
  AYUDA_EN_CAMINO: "Ayuda en camino",
  PARCIALMENTE_ATENDIDA: "Parcialmente atendida",
  ATENDIDA: "Atendida",
};

export type PersonCase = { id: string; public_id: string; full_name: string; approximate_age: number | null; department: string; municipality: string; area: string | null; last_seen_place: string | null; last_contact_at: string | null; description: string; status: PersonStatus; photo_url: string | null; reporter_name: string; public_phone: string | null; created_at: string; updated_at: string };
export type Point = { id: string; public_id: string; type: "COLLECTION" | "SHELTER"; name: string; department: string; municipality: string; area: string | null; address: string; reference: string | null; schedule: string | null; phone: string | null; services: string[]; items: string[]; capacity: number | null; last_confirmed_at: string; is_active: boolean; created_at: string; updated_at: string; confirmations?: number };
export type AidRequest = { id: string; public_id: string; department: string; municipality: string; area: string; reference: string | null; people_count: number | null; description: string; contact_name: string; contact_phone: string; urgency: "MEDIA" | "ALTA" | "CRITICA"; needs: string[]; status: AidStatus; created_at: string; updated_at: string };
