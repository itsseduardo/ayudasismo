-- Permite múltiples operaciones legítimas sin borrar eventos ni publicaciones.
drop index if exists public.technical_events_idempotency_idx;
create index if not exists technical_events_rate_lookup_idx on public.technical_events(event_type,fingerprint,created_at);

create or replace function public.authorize_media_change(p_resource_type text,p_public_id text,p_token text,p_record_event boolean default true) returns uuid
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare target_id uuid;access_valid boolean;event_fingerprint text;
begin
 if p_resource_type not in('PERSON','POINT','AID')then raise exception 'invalid_resource_type';end if;
 target_id:=case p_resource_type when 'PERSON' then(select id from public.person_cases where public_id=p_public_id) when 'POINT' then(select id from public.community_points where public_id=p_public_id) when 'AID' then(select id from public.aid_requests where public_id=p_public_id)end;
 select(e.secret_hash=extensions.crypt(p_token,e.secret_hash)or e.pin_hash=extensions.crypt(p_token,e.pin_hash))into access_valid from public.edit_tokens e where e.resource_type=p_resource_type and e.resource_id=target_id;
 if target_id is null or not coalesce(access_valid,false)then raise exception 'invalid_media_access';end if;
 if p_record_event then event_fingerprint:='media:'||p_resource_type||':'||target_id::text;if(select count(*)from public.technical_events where event_type='media_change'and fingerprint=event_fingerprint and created_at>now()-interval '1 hour')>=30 then raise exception 'media_rate_limit';end if;insert into public.technical_events(event_type,fingerprint)values('media_change',event_fingerprint);end if;
 return target_id;
end;$$;
revoke all on function public.authorize_media_change(text,text,text,boolean)from public,anon,authenticated;
grant execute on function public.authorize_media_change(text,text,text,boolean)to service_role;
