-- Tolera espacios al copiar un PIN y recupera tokens Base64 de enlaces antiguos
-- donde un signo + pudo convertirse en espacio. No modifica datos existentes.
create or replace function public.update_resource_status(payload jsonb) returns void
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare rid uuid;valid boolean;supplied text:=coalesce(payload->>'token','');
begin
 select e.resource_id,(e.pin_hash=extensions.crypt(btrim(supplied),e.pin_hash)or e.secret_hash=extensions.crypt(supplied,e.secret_hash)or e.secret_hash=extensions.crypt(replace(supplied,' ','+'),e.secret_hash)) into rid,valid
 from public.edit_tokens e where e.resource_type=payload->>'resource_type' and e.resource_id=case payload->>'resource_type'
  when 'PERSON' then(select id from public.person_cases where public_id=payload->>'public_id')
  when 'POINT' then(select id from public.community_points where public_id=payload->>'public_id')
  when 'AID' then(select id from public.aid_requests where public_id=payload->>'public_id') end;
 if not coalesce(valid,false)then raise exception 'invalid_token';end if;
 if payload->>'resource_type'='PERSON' then
  if payload->>'status'='HIDDEN'then update public.person_cases set is_visible=false,updated_at=now()where id=rid;
  else update public.person_cases set status=(payload->>'status')::public.person_status,is_visible=true,updated_at=now()where id=rid;end if;
 elsif payload->>'resource_type'='POINT'then update public.community_points set is_active=payload->>'status'='ACTIVE',is_visible=payload->>'status'<>'HIDDEN',updated_at=now()where id=rid;
 elsif payload->>'resource_type'='AID'then
  if payload->>'status'='HIDDEN'then update public.aid_requests set is_visible=false,updated_at=now()where id=rid;
  else update public.aid_requests set status=(payload->>'status')::public.aid_status,is_visible=true,updated_at=now()where id=rid;end if;
 else raise exception 'invalid_resource_type';end if;
end;$$;

create or replace function public.update_person_details(payload jsonb)returns void
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare target_id uuid;valid boolean;supplied text:=coalesce(payload->>'token','');
begin
 select p.id,(e.pin_hash=extensions.crypt(btrim(supplied),e.pin_hash)or e.secret_hash=extensions.crypt(supplied,e.secret_hash)or e.secret_hash=extensions.crypt(replace(supplied,' ','+'),e.secret_hash))into target_id,valid from public.person_cases p join public.edit_tokens e on e.resource_type='PERSON'and e.resource_id=p.id where p.public_id=payload->>'public_id';
 if target_id is null or not coalesce(valid,false)then raise exception 'invalid_token';end if;
 update public.person_cases set living_place=nullif(payload->>'living_place',''),gender=nullif(payload->>'gender',''),physical_description=nullif(payload->>'physical_description',''),clothing_description=nullif(payload->>'clothing_description',''),reporter_relationship_public=nullif(payload->>'relationship',''),updated_at=now()where id=target_id;
end;$$;

create or replace function public.authorize_media_change(p_resource_type text,p_public_id text,p_token text,p_record_event boolean default true)returns uuid
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare target_id uuid;access_valid boolean;event_fingerprint text;supplied text:=coalesce(p_token,'');
begin
 if p_resource_type not in('PERSON','POINT','AID')then raise exception 'invalid_resource_type';end if;
 target_id:=case p_resource_type when 'PERSON'then(select id from public.person_cases where public_id=p_public_id)when 'POINT'then(select id from public.community_points where public_id=p_public_id)when 'AID'then(select id from public.aid_requests where public_id=p_public_id)end;
 select(e.pin_hash=extensions.crypt(btrim(supplied),e.pin_hash)or e.secret_hash=extensions.crypt(supplied,e.secret_hash)or e.secret_hash=extensions.crypt(replace(supplied,' ','+'),e.secret_hash))into access_valid from public.edit_tokens e where e.resource_type=p_resource_type and e.resource_id=target_id;
 if target_id is null or not coalesce(access_valid,false)then raise exception 'invalid_media_access';end if;
 if p_record_event then event_fingerprint:='media:'||p_resource_type||':'||target_id::text;if(select count(*)from public.technical_events where event_type='media_change'and fingerprint=event_fingerprint and created_at>now()-interval '1 hour')>=30 then raise exception 'media_rate_limit';end if;insert into public.technical_events(event_type,fingerprint)values('media_change',event_fingerprint);end if;
 return target_id;
end;$$;

revoke all on function public.update_resource_status(jsonb),public.update_person_details(jsonb)from public;
grant execute on function public.update_resource_status(jsonb),public.update_person_details(jsonb)to anon,authenticated;
revoke all on function public.authorize_media_change(text,text,text,boolean)from public,anon,authenticated;
grant execute on function public.authorize_media_change(text,text,text,boolean)to service_role;
