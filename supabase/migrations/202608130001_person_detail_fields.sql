-- Campos opcionales para el detalle público de personas. No modifica datos existentes.
alter table public.person_cases add column if not exists living_place text null;
alter table public.person_cases add column if not exists gender text null;
alter table public.person_cases add column if not exists physical_description text null;
alter table public.person_cases add column if not exists clothing_description text null;
alter table public.person_cases add column if not exists reporter_relationship_public text null;

create or replace function public.create_person_case(payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare c public.person_cases;pin text:=lpad((floor(random()*1000000))::int::text,6,'0');secret text:=encode(extensions.gen_random_bytes(24),'base64');
begin
 insert into public.technical_events(event_type,fingerprint)values('create_person',payload->>'idempotency_key');
 insert into public.person_cases(full_name,approximate_age,department,municipality,area,last_seen_place,last_contact_at,description,reporter_name,public_phone,living_place,gender,physical_description,clothing_description,reporter_relationship_public)
 values(payload->>'full_name',nullif(payload->>'approximate_age','')::smallint,payload->>'department',payload->>'municipality',nullif(payload->>'area',''),nullif(payload->>'last_seen_place',''),nullif(payload->>'last_contact_at','')::timestamptz,payload->>'description',payload->>'reporter_name',case when coalesce((payload->>'show_phone')::boolean,false)then payload->>'phone'end,nullif(payload->>'living_place',''),nullif(payload->>'gender',''),nullif(payload->>'physical_description',''),nullif(payload->>'clothing_description',''),nullif(payload->>'relationship',''))returning*into c;
 insert into public.person_case_private_data(case_id,reporter_phone,relationship)values(c.id,payload->>'phone',payload->>'relationship');
 insert into public.edit_tokens(resource_type,resource_id,secret_hash,pin_hash)values('PERSON',c.id,extensions.crypt(secret,extensions.gen_salt('bf')),extensions.crypt(pin,extensions.gen_salt('bf')));
 return jsonb_build_object('public_id',c.public_id,'pin',pin,'edit_token',secret);
end;$$;

create or replace function public.update_person_details(payload jsonb)returns void
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare target_id uuid;valid boolean;
begin
 select p.id,(e.secret_hash=extensions.crypt(payload->>'token',e.secret_hash)or e.pin_hash=extensions.crypt(payload->>'token',e.pin_hash))into target_id,valid from public.person_cases p join public.edit_tokens e on e.resource_type='PERSON'and e.resource_id=p.id where p.public_id=payload->>'public_id';
 if target_id is null or not coalesce(valid,false)then raise exception 'invalid_token';end if;
 update public.person_cases set living_place=nullif(payload->>'living_place',''),gender=nullif(payload->>'gender',''),physical_description=nullif(payload->>'physical_description',''),clothing_description=nullif(payload->>'clothing_description',''),reporter_relationship_public=nullif(payload->>'relationship',''),updated_at=now()where id=target_id;
end;$$;
revoke all on function public.update_person_details(jsonb)from public;
grant execute on function public.update_person_details(jsonb)to anon,authenticated;
