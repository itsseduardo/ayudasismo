"use client";

import { useActionState } from "react";
import type { ActionState } from "@/app/actions";
import { ensureIdempotency, Success } from "./form-kit";

export function ActionForm({ action, children }: {
  action: (state: ActionState, form: FormData) => Promise<ActionState>;
  children: React.ReactNode;
}) {
  const [state, formAction, pending] = useActionState(action, {});
  if (state.ok) return <Success />;
  return <form action={formAction} className="form-card" onSubmitCapture={(event) => ensureIdempotency(event.currentTarget)}><fieldset disabled={pending} className="grid gap-4">{children}<button className="btn-primary">{pending ? "Enviando…" : "Enviar información"}</button></fieldset>{state.error && <p className="error">{state.error}</p>}</form>;
}

export function Idempotency() {
  return <input type="hidden" name="idempotency_key" defaultValue="" />;
}
