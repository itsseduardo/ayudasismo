-- Fotografías seguras para Ayuda Sismo.
-- Idempotente, retrocompatible y no destructiva. No elimina registros existentes.

create extension if not exists pgcrypto with schema extensions;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('community-media', 'community-media', true, 5242880, array['image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.media_assets (
  id uuid primary key default extensions.gen_random_uuid(),
  resource_type text not null check (resource_type in ('PERSON','PET','POINT','AID')),
  resource_id uuid not null,
  position smallint not null check (position between 0 and 2),
  object_path text unique not null,
  width integer not null check (width > 0 and width <= 2000),
  height integer not null check (height > 0 and height <= 2000),
  byte_size integer not null check (byte_size > 0 and byte_size <= 5242880),
  mime_type text not null default 'image/webp' check (mime_type = 'image/webp'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (resource_type, resource_id, position)
);

create index if not exists media_assets_resource_idx
on public.media_assets(resource_type, resource_id, position);

create or replace function public.validate_media_asset()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.resource_type = 'PERSON' then
    if new.position <> 0 or not exists(select 1 from public.person_cases where id=new.resource_id) then
      raise exception 'invalid_person_media';
    end if;
  elsif new.resource_type = 'POINT' then
    if not exists(select 1 from public.community_points where id=new.resource_id) then
      raise exception 'invalid_point_media';
    end if;
  elsif new.resource_type = 'AID' then
    if not exists(select 1 from public.aid_requests where id=new.resource_id) then
      raise exception 'invalid_aid_media';
    end if;
  elsif new.resource_type = 'PET' then
    -- Reservado para el módulo de mascotas; no admite escrituras hasta que exista.
    raise exception 'pet_module_not_available';
  else
    raise exception 'invalid_resource_type';
  end if;
  return new;
end;
$$;

drop trigger if exists media_assets_validate_trigger on public.media_assets;
create trigger media_assets_validate_trigger
before insert or update on public.media_assets
for each row execute function public.validate_media_asset();

alter table public.media_assets enable row level security;
drop policy if exists "public media metadata" on public.media_assets;
create policy "public media metadata" on public.media_assets
for select to anon, authenticated
using (
  (resource_type='PERSON' and exists(select 1 from public.person_cases p where p.id=resource_id and p.is_visible))
  or (resource_type='POINT' and exists(select 1 from public.community_points p where p.id=resource_id and p.is_visible))
  or (resource_type='AID' and exists(select 1 from public.aid_requests a where a.id=resource_id and a.is_visible))
);

-- Solo lectura pública. Las escrituras usan exclusivamente la clave secreta en el servidor.
drop policy if exists "public community media read" on storage.objects;
create policy "public community media read" on storage.objects
for select to anon, authenticated
using (bucket_id='community-media');

create or replace function public.authorize_media_change(
  p_resource_type text,
  p_public_id text,
  p_token text,
  p_record_event boolean default true
) returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  target_id uuid;
  access_valid boolean;
  event_fingerprint text;
begin
  if p_resource_type not in ('PERSON','POINT','AID') then
    raise exception 'invalid_resource_type';
  end if;

  target_id := case p_resource_type
    when 'PERSON' then (select id from public.person_cases where public_id=p_public_id)
    when 'POINT' then (select id from public.community_points where public_id=p_public_id)
    when 'AID' then (select id from public.aid_requests where public_id=p_public_id)
  end;

  select (e.secret_hash=extensions.crypt(p_token,e.secret_hash)
       or e.pin_hash=extensions.crypt(p_token,e.pin_hash))
  into access_valid
  from public.edit_tokens e
  where e.resource_type=p_resource_type and e.resource_id=target_id;

  if target_id is null or not coalesce(access_valid,false) then
    raise exception 'invalid_media_access';
  end if;

  if p_record_event then
    event_fingerprint := 'media:' || p_resource_type || ':' || target_id::text;
    if (select count(*) from public.technical_events
        where event_type='media_change' and technical_events.fingerprint=event_fingerprint
          and created_at > now()-interval '1 hour') >= 30 then
      raise exception 'media_rate_limit';
    end if;
    insert into public.technical_events(event_type,fingerprint)
    values('media_change',event_fingerprint);
  end if;

  return target_id;
end;
$$;

revoke all on table public.media_assets from anon, authenticated;
grant select on table public.media_assets to anon, authenticated;
revoke all on function public.validate_media_asset() from public;
revoke all on function public.authorize_media_change(text,text,text,boolean) from public, anon, authenticated;

-- La clave de servicio puede invocar la función; los clientes anónimos no.
grant execute on function public.authorize_media_change(text,text,text,boolean) to service_role;
