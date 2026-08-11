"use client";

import { useActionState, useSyncExternalStore } from "react";
import type { ActionState } from "@/app/actions";
import { CheckCircle2, Copy, WifiOff } from "lucide-react";

export const input = "w-full rounded-xl border border-slate-300 bg-white px-4 py-3 text-base outline-none focus:border-teal-700 focus:ring-2 focus:ring-teal-100";
export const label = "grid gap-1.5 text-sm font-semibold text-slate-800";

const subscribeConnection = (notify: () => void) => {
  addEventListener("online", notify);
  addEventListener("offline", notify);
  return () => {
    removeEventListener("online", notify);
    removeEventListener("offline", notify);
  };
};

export function ensureIdempotency(form: HTMLFormElement) {
  const field = form.elements.namedItem("idempotency_key");
  if (field instanceof HTMLInputElement && !field.value) {
    field.value = crypto.randomUUID();
  }
}

export function SubmitButton({ children }: { children: React.ReactNode }) {
  return <button className="btn-primary w-full" type="submit">{children}</button>;
}

export function ManagedForm({ action, children, draftKey, successPath }: {
  action: (state: ActionState, form: FormData) => Promise<ActionState>;
  children: React.ReactNode;
  draftKey: string;
  successPath: (id: string, token?: string) => string;
}) {
  const [state, formAction, pending] = useActionState(action, {});
  const online = useSyncExternalStore(subscribeConnection, () => navigator.onLine, () => true);

  if (state.ok && state.publicId) {
    return <Credentials state={state} path={successPath(state.publicId, state.editToken)} />;
  }

  return (
    <form
      action={formAction}
      className="form-card"
      onSubmitCapture={(event) => ensureIdempotency(event.currentTarget)}
      onInput={(event) => {
        const values = Object.fromEntries(new FormData(event.currentTarget).entries());
        localStorage.setItem(draftKey, JSON.stringify(values));
      }}
    >
      {!online && <div className="notice warning"><WifiOff size={18}/> Sin conexión. Tu borrador se guarda en este dispositivo.</div>}
      <input type="hidden" name="idempotency_key" defaultValue="" />
      <input className="hidden" tabIndex={-1} autoComplete="off" name="website" />
      <fieldset disabled={pending} className="grid gap-5">
        {children}
        <SubmitButton>{pending ? "Enviando…" : "Publicar ahora"}</SubmitButton>
      </fieldset>
      {state.error && <p className="error" role="alert">{state.error}</p>}
    </form>
  );
}

function Credentials({ state, path }: { state: ActionState; path: string }) {
  const origin = useSyncExternalStore(() => () => {}, () => location.origin, () => "");
  const url = `${origin}${path}`;
  return <section className="form-card border-teal-300"><CheckCircle2 className="text-teal-700" size={36}/><h2 className="text-2xl font-bold">Publicación creada</h2><p>Guarda estos datos ahora. El PIN no volverá a mostrarse.</p><div className="rounded-xl bg-slate-950 p-4 text-white"><span className="text-xs uppercase text-slate-300">PIN privado</span><strong className="block text-3xl tracking-[.3em]">{state.pin}</strong></div><button className="btn-secondary" onClick={() => navigator.clipboard.writeText(url)}><Copy size={18}/> Copiar enlace privado</button><a className="btn-primary" href={path}>Abrir publicación</a></section>;
}

export function Success({ message = "Información recibida" }: { message?: string }) {
  return <p className="notice success"><CheckCircle2 size={18}/>{message}</p>;
}
