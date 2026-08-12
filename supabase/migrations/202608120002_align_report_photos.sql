-- Alinea Storage con SUPABASE_STORAGE_BUCKET=report-photos.
-- No elimina objetos, tablas ni registros. Conserva referencias del bucket anterior.

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('report-photos','report-photos',true,3145728,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set
 public=excluded.public,
 file_size_limit=excluded.file_size_limit,
 allowed_mime_types=excluded.allowed_mime_types;

alter table public.media_assets add column if not exists bucket_id text;
update public.media_assets set bucket_id='community-media' where bucket_id is null;
alter table public.media_assets alter column bucket_id set default 'report-photos';
alter table public.media_assets alter column bucket_id set not null;

alter table public.person_cases add column if not exists photo_path text null;

do $$ begin
 alter table public.media_assets add constraint media_assets_report_photos_3mb_check
 check(bucket_id<>'report-photos' or byte_size<=3145728) not valid;
exception when duplicate_object then null;
end $$;

drop policy if exists "public report photos read" on storage.objects;
create policy "public report photos read" on storage.objects
for select to anon,authenticated
using(bucket_id='report-photos');

-- No se crean políticas INSERT/UPDATE/DELETE para anon o authenticated.
-- Solo la clave secreta del servidor puede modificar objetos.
