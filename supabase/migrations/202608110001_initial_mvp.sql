-- Ayuda Sismo MVP — migración inicial idempotente para Supabase PostgreSQL.
-- Puede ejecutarse de nuevo tras una ejecución parcial. No elimina tablas ni datos.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists unaccent with schema extensions;

-- IF NOT EXISTS conserva la ubicación de una extensión ya instalada. En Supabase
-- ambas deben residir en `extensions` para poder calificarlas de forma segura.
do $$
declare extension_name text;
begin
  foreach extension_name in array array['pgcrypto','unaccent'] loop
    if exists (
      select 1 from pg_extension e join pg_namespace n on n.oid=e.extnamespace
      where e.extname=extension_name and n.nspname<>'extensions'
    ) then
      execute format('alter extension %I set schema extensions',extension_name);
    end if;
  end loop;
end $$;

do $$ begin create type public.person_status as enum ('SIN_CONTACTO','INFORMACION_NUEVA','REPORTADO_LOCALIZADO','LOCALIZADO_CONFIRMADO'); exception when duplicate_object then null; end $$;
do $$ begin create type public.point_type as enum ('COLLECTION','SHELTER'); exception when duplicate_object then null; end $$;
do $$ begin create type public.aid_status as enum ('AYUDA_SOLICITADA','ALGUIEN_RESPONDIO','AYUDA_EN_CAMINO','PARCIALMENTE_ATENDIDA','ATENDIDA'); exception when duplicate_object then null; end $$;
do $$ begin create type public.urgency_level as enum ('MEDIA','ALTA','CRITICA'); exception when duplicate_object then null; end $$;

create table if not exists public.person_cases (
  id uuid primary key default extensions.gen_random_uuid(),
  public_id text unique not null default substr(encode(extensions.gen_random_bytes(8),'hex'),1,12),
  full_name text not null check (length(full_name) between 3 and 120),
  normalized_name text not null default '',
  approximate_age smallint check (approximate_age between 0 and 120),
  department text not null, municipality text not null, area text,
  last_seen_place text, last_contact_at timestamptz,
  description text not null check (length(description) <= 600),
  status public.person_status not null default 'SIN_CONTACTO',
  photo_url text, reporter_name text not null, public_phone text,
  is_visible boolean not null default true, report_count integer not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

-- Recupera de forma no destructiva una posible columna generada creada por una ejecución previa.
do $$
begin
  if exists (
    select 1 from pg_attribute
    where attrelid = 'public.person_cases'::regclass
      and attname = 'normalized_name' and attgenerated <> '' and not attisdropped
  ) then
    execute 'alter table public.person_cases alter column normalized_name drop expression';
  end if;
end $$;
alter table public.person_cases add column if not exists normalized_name text;

create or replace function public.set_person_normalized_name()
returns trigger
language plpgsql
set search_path = public, extensions, pg_temp
as $$
begin
  new.normalized_name := lower(extensions.unaccent(new.full_name));
  return new;
end;
$$;

drop trigger if exists person_cases_normalized_name_trigger on public.person_cases;
create trigger person_cases_normalized_name_trigger
before insert or update of full_name on public.person_cases
for each row execute function public.set_person_normalized_name();

-- Completa registros que pudieran existir antes de crear el trigger.
update public.person_cases
set normalized_name = lower(extensions.unaccent(full_name))
where normalized_name is null or normalized_name is distinct from lower(extensions.unaccent(full_name));
alter table public.person_cases alter column normalized_name set not null;

create table if not exists public.person_case_private_data (
  case_id uuid primary key references public.person_cases on delete cascade,
  reporter_phone text not null, relationship text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.person_updates (
  id uuid primary key default extensions.gen_random_uuid(),
  case_id uuid not null references public.person_cases on delete cascade,
  kind text not null, message text not null check(length(message)<=500),
  occurred_at timestamptz not null, place text, author_name text not null, phone text,
  is_sensitive boolean not null default false, idempotency_key uuid unique not null,
  created_at timestamptz not null default now()
);
create table if not exists public.community_points (
  id uuid primary key default extensions.gen_random_uuid(),
  public_id text unique not null default substr(encode(extensions.gen_random_bytes(8),'hex'),1,12),
  type public.point_type not null, name text not null, department text not null,
  municipality text not null, area text, address text not null, reference text,
  schedule text, phone text, services text[] not null default '{}', items text[] not null default '{}',
  capacity integer check(capacity>=0), observations text,
  last_confirmed_at timestamptz not null default now(), is_active boolean not null default true,
  is_visible boolean not null default true, report_count integer not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.point_confirmations (
  id uuid primary key default extensions.gen_random_uuid(),
  point_id uuid not null references public.community_points on delete cascade,
  kind text not null, message text, idempotency_key uuid unique not null,
  created_at timestamptz not null default now()
);
create table if not exists public.aid_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  public_id text unique not null default substr(encode(extensions.gen_random_bytes(8),'hex'),1,12),
  department text not null, municipality text not null, area text not null, reference text,
  people_count integer check(people_count>0), description text not null,
  contact_name text not null, contact_phone text not null,
  urgency public.urgency_level not null, needs text[] not null,
  status public.aid_status not null default 'AYUDA_SOLICITADA',
  is_visible boolean not null default true, report_count integer not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.aid_responses (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null references public.aid_requests on delete cascade,
  kind text not null, message text, idempotency_key uuid unique not null,
  created_at timestamptz not null default now()
);
create table if not exists public.community_reports (
  id uuid primary key default extensions.gen_random_uuid(), resource_type text not null,
  resource_id uuid not null, reason text, reporter_fingerprint text,
  created_at timestamptz not null default now(),
  unique(resource_type,resource_id,reporter_fingerprint)
);
create table if not exists public.edit_tokens (
  id uuid primary key default extensions.gen_random_uuid(), resource_type text not null,
  resource_id uuid not null, secret_hash text not null, pin_hash text not null,
  created_at timestamptz not null default now(), unique(resource_type,resource_id)
);
create table if not exists public.technical_events (
  id bigint generated always as identity primary key, event_type text not null,
  fingerprint text, created_at timestamptz not null default now()
);
create unique index if not exists technical_events_idempotency_idx on public.technical_events(event_type,fingerprint) where fingerprint is not null;

create or replace view public.collection_points with (security_invoker=true) as select * from public.community_points where type='COLLECTION';
create or replace view public.shelter_points with (security_invoker=true) as select * from public.community_points where type='SHELTER';
create index if not exists person_name_idx on public.person_cases using gin(to_tsvector('simple',normalized_name));
create index if not exists person_location_idx on public.person_cases(department,municipality);
create index if not exists points_location_idx on public.community_points(type,department,municipality);
create index if not exists aid_location_idx on public.aid_requests(department,municipality,status);
create index if not exists events_rate_idx on public.technical_events(fingerprint,event_type,created_at);

alter table public.person_cases enable row level security;
alter table public.person_case_private_data enable row level security;
alter table public.person_updates enable row level security;
alter table public.community_points enable row level security;
alter table public.point_confirmations enable row level security;
alter table public.aid_requests enable row level security;
alter table public.aid_responses enable row level security;
alter table public.community_reports enable row level security;
alter table public.edit_tokens enable row level security;
alter table public.technical_events enable row level security;

drop policy if exists "visible people" on public.person_cases;
create policy "visible people" on public.person_cases for select to anon,authenticated using(is_visible);
drop policy if exists "visible updates" on public.person_updates;
create policy "visible updates" on public.person_updates for select to anon,authenticated using(exists(select 1 from public.person_cases p where p.id=case_id and p.is_visible));
drop policy if exists "visible points" on public.community_points;
create policy "visible points" on public.community_points for select to anon,authenticated using(is_visible);
drop policy if exists "visible confirmations" on public.point_confirmations;
create policy "visible confirmations" on public.point_confirmations for select to anon,authenticated using(exists(select 1 from public.community_points p where p.id=point_id and p.is_visible));
drop policy if exists "visible aid" on public.aid_requests;
create policy "visible aid" on public.aid_requests for select to anon,authenticated using(is_visible);
drop policy if exists "visible responses" on public.aid_responses;
create policy "visible responses" on public.aid_responses for select to anon,authenticated using(exists(select 1 from public.aid_requests a where a.id=request_id and a.is_visible));

create or replace function public.create_person_case(payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare c public.person_cases; pin text:=lpad((floor(random()*1000000))::int::text,6,'0'); secret text:=encode(extensions.gen_random_bytes(24),'base64');
begin
  insert into public.technical_events(event_type,fingerprint) values('create_person',payload->>'idempotency_key');
  insert into public.person_cases(full_name,approximate_age,department,municipality,area,last_seen_place,last_contact_at,description,reporter_name,public_phone)
  values(payload->>'full_name',nullif(payload->>'approximate_age','')::smallint,payload->>'department',payload->>'municipality',nullif(payload->>'area',''),nullif(payload->>'last_seen_place',''),nullif(payload->>'last_contact_at','')::timestamptz,payload->>'description',payload->>'reporter_name',case when coalesce((payload->>'show_phone')::boolean,false) then payload->>'phone' end) returning * into c;
  insert into public.person_case_private_data(case_id,reporter_phone,relationship) values(c.id,payload->>'phone',payload->>'relationship');
  insert into public.edit_tokens(resource_type,resource_id,secret_hash,pin_hash) values('PERSON',c.id,extensions.crypt(secret,extensions.gen_salt('bf')),extensions.crypt(pin,extensions.gen_salt('bf')));
  return jsonb_build_object('public_id',c.public_id,'pin',pin,'edit_token',secret);
end $$;

create or replace function public.create_community_point(payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare c public.community_points; pin text:=lpad((floor(random()*1000000))::int::text,6,'0'); secret text:=encode(extensions.gen_random_bytes(24),'base64');
begin
  insert into public.technical_events(event_type,fingerprint) values('create_point',payload->>'idempotency_key');
  insert into public.community_points(type,name,department,municipality,area,address,reference,schedule,phone,services,items,capacity,observations)
  values((payload->>'type')::public.point_type,payload->>'name',payload->>'department',payload->>'municipality',nullif(payload->>'area',''),payload->>'address',nullif(payload->>'reference',''),nullif(payload->>'schedule',''),nullif(payload->>'phone',''),array(select jsonb_array_elements_text(coalesce(payload->'services','[]'::jsonb))),array(select jsonb_array_elements_text(coalesce(payload->'items','[]'::jsonb))),nullif(payload->>'capacity','')::int,nullif(payload->>'observations','')) returning * into c;
  insert into public.edit_tokens(resource_type,resource_id,secret_hash,pin_hash) values('POINT',c.id,extensions.crypt(secret,extensions.gen_salt('bf')),extensions.crypt(pin,extensions.gen_salt('bf')));
  return jsonb_build_object('public_id',c.public_id,'pin',pin,'edit_token',secret);
end $$;

create or replace function public.create_aid_request(payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare a public.aid_requests; pin text:=lpad((floor(random()*1000000))::int::text,6,'0'); secret text:=encode(extensions.gen_random_bytes(24),'base64');
begin
  insert into public.technical_events(event_type,fingerprint) values('create_aid',payload->>'idempotency_key');
  insert into public.aid_requests(department,municipality,area,reference,people_count,description,contact_name,contact_phone,urgency,needs)
  values(payload->>'department',payload->>'municipality',payload->>'area',nullif(payload->>'reference',''),nullif(payload->>'people_count','')::int,payload->>'description',payload->>'contact_name',payload->>'contact_phone',(payload->>'urgency')::public.urgency_level,array(select jsonb_array_elements_text(coalesce(payload->'needs','[]'::jsonb)))) returning * into a;
  insert into public.edit_tokens(resource_type,resource_id,secret_hash,pin_hash) values('AID',a.id,extensions.crypt(secret,extensions.gen_salt('bf')),extensions.crypt(pin,extensions.gen_salt('bf')));
  return jsonb_build_object('public_id',a.public_id,'pin',pin,'edit_token',secret);
end $$;

create or replace function public.add_person_update(payload jsonb) returns void
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
begin
  insert into public.person_updates(case_id,kind,message,occurred_at,place,author_name,phone,is_sensitive,idempotency_key)
  values((payload->>'case_id')::uuid,payload->>'kind',payload->>'message',(payload->>'occurred_at')::timestamptz,nullif(payload->>'place',''),payload->>'author_name',nullif(payload->>'phone',''),coalesce((payload->>'sensitive')::boolean,false),(payload->>'idempotency_key')::uuid);
  update public.person_cases set status=case when payload->>'kind'='LOCALIZADA' then 'REPORTADO_LOCALIZADO'::public.person_status else 'INFORMACION_NUEVA'::public.person_status end,updated_at=now()
  where id=(payload->>'case_id')::uuid and status<>'LOCALIZADO_CONFIRMADO';
end $$;

create or replace function public.update_resource_status(payload jsonb) returns void
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare rid uuid; valid boolean;
begin
  select e.resource_id,(e.secret_hash=extensions.crypt(payload->>'token',e.secret_hash) or e.pin_hash=extensions.crypt(payload->>'token',e.pin_hash)) into rid,valid
  from public.edit_tokens e where e.resource_type=payload->>'resource_type' and e.resource_id=case payload->>'resource_type'
    when 'PERSON' then(select id from public.person_cases where public_id=payload->>'public_id')
    when 'POINT' then(select id from public.community_points where public_id=payload->>'public_id')
    when 'AID' then(select id from public.aid_requests where public_id=payload->>'public_id') end;
  if not coalesce(valid,false) then raise exception 'invalid_token'; end if;
  if payload->>'resource_type'='PERSON' then
    if payload->>'status'='HIDDEN' then update public.person_cases set is_visible=false,updated_at=now() where id=rid;
    else update public.person_cases set status=(payload->>'status')::public.person_status,updated_at=now() where id=rid; end if;
  elsif payload->>'resource_type'='POINT' then
    update public.community_points set is_active=payload->>'status'='ACTIVE',is_visible=payload->>'status'<>'HIDDEN',updated_at=now() where id=rid;
  elsif payload->>'resource_type'='AID' then
    if payload->>'status'='HIDDEN' then update public.aid_requests set is_visible=false,updated_at=now() where id=rid;
    else update public.aid_requests set status=(payload->>'status')::public.aid_status,updated_at=now() where id=rid; end if;
  else raise exception 'invalid_resource_type'; end if;
end $$;

create or replace function public.add_community_signal(payload jsonb) returns void
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
begin
  if payload->>'resource_type'='POINT' then
    insert into public.point_confirmations(point_id,kind,message,idempotency_key) values((payload->>'resource_id')::uuid,payload->>'kind',nullif(payload->>'message',''),(payload->>'idempotency_key')::uuid);
    if payload->>'kind'='FUNCIONA' then update public.community_points set last_confirmed_at=now(),updated_at=now() where id=(payload->>'resource_id')::uuid; end if;
  elsif payload->>'resource_type'='AID' then
    insert into public.aid_responses(request_id,kind,message,idempotency_key) values((payload->>'resource_id')::uuid,payload->>'kind',nullif(payload->>'message',''),(payload->>'idempotency_key')::uuid);
  else raise exception 'invalid_resource_type'; end if;
  if payload->>'kind'='REPORT' then
    insert into public.community_reports(resource_type,resource_id,reason,reporter_fingerprint)
    values(
      payload->>'resource_type',
      (payload->>'resource_id')::uuid,
      nullif(payload->>'message',''),
      cast(payload->>'idempotency_key' as text)
    ) on conflict do nothing;
  end if;
end $$;

revoke all on table public.person_cases,public.person_case_private_data,public.person_updates,public.community_points,public.point_confirmations,public.aid_requests,public.aid_responses,public.community_reports,public.edit_tokens,public.technical_events from anon,authenticated;
grant select on table public.person_cases,public.person_updates,public.community_points,public.point_confirmations,public.aid_requests,public.aid_responses to anon,authenticated;
revoke all on function public.create_person_case(jsonb),public.create_community_point(jsonb),public.create_aid_request(jsonb),public.add_person_update(jsonb),public.update_resource_status(jsonb),public.add_community_signal(jsonb) from public;
revoke all on function public.set_person_normalized_name() from public;
grant execute on function public.create_person_case(jsonb),public.create_community_point(jsonb),public.create_aid_request(jsonb),public.add_person_update(jsonb),public.update_resource_status(jsonb),public.add_community_signal(jsonb) to anon,authenticated;
