-- Estado confirmado por el creador. No modifica reportes existentes.
alter type public.person_status add value if not exists 'DECESO_CONFIRMADO';

create or replace function public.add_person_update(payload jsonb) returns void
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
begin
 insert into public.person_updates(case_id,kind,message,occurred_at,place,author_name,phone,is_sensitive,idempotency_key)
 values((payload->>'case_id')::uuid,payload->>'kind',payload->>'message',(payload->>'occurred_at')::timestamptz,nullif(payload->>'place',''),payload->>'author_name',nullif(payload->>'phone',''),coalesce((payload->>'sensitive')::boolean,false),(payload->>'idempotency_key')::uuid);
 update public.person_cases set status=case when payload->>'kind'='LOCALIZADA' then 'REPORTADO_LOCALIZADO'::public.person_status else 'INFORMACION_NUEVA'::public.person_status end,updated_at=now()
 where id=(payload->>'case_id')::uuid and status::text not in('LOCALIZADO_CONFIRMADO','DECESO_CONFIRMADO');
end;$$;
revoke all on function public.add_person_update(jsonb)from public;
grant execute on function public.add_person_update(jsonb)to anon,authenticated;
