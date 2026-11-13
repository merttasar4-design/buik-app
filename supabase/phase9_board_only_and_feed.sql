-- Sadece board kontrolu icin yardimci fonksiyon
create or replace function public.is_board()
returns boolean as $$
  select exists (
    select 1 from profiles
    where id = auth.uid()
    and role = 'board'
  );
$$ language sql security definer stable;

-- Sponsorlar: ekleme/silme artik sadece board
drop policy if exists "Coordinators manage sponsors" on sponsors;
create policy "Board manage sponsors" on sponsors
  for insert to authenticated with check (public.is_board());

drop policy if exists "Coordinators delete sponsors" on sponsors;
create policy "Board delete sponsors" on sponsors
  for delete to authenticated using (public.is_board());

-- job_postings kaldiriliyor, yerine sponsor_posts (paylasim akisi) geliyor
drop table if exists job_postings;

create table if not exists sponsor_posts (
  id bigint generated always as identity primary key,
  sponsor_id bigint not null references sponsors(id) on delete cascade,
  content text not null,
  image_url text,
  link_url text,
  link_label text,
  created_at timestamptz not null default now()
);

alter table sponsor_posts enable row level security;

drop policy if exists "Public read sponsor posts" on sponsor_posts;
create policy "Public read sponsor posts" on sponsor_posts
  for select to anon, authenticated using (true);

drop policy if exists "Board manage sponsor posts" on sponsor_posts;
create policy "Board manage sponsor posts" on sponsor_posts
  for insert to authenticated with check (public.is_board());

drop policy if exists "Board delete sponsor posts" on sponsor_posts;
create policy "Board delete sponsor posts" on sponsor_posts
  for delete to authenticated using (public.is_board());

-- Galeri: ekleme/silme artik sadece board
drop policy if exists "Coordinators manage gallery" on gallery_photos;
create policy "Board manage gallery" on gallery_photos
  for insert to authenticated with check (public.is_board());

drop policy if exists "Coordinators delete gallery" on gallery_photos;
create policy "Board delete gallery" on gallery_photos
  for delete to authenticated using (public.is_board());

-- gallery_photos tablosuna depolama yolu ekle (guvenli silme icin)
alter table gallery_photos add column if not exists storage_path text;

-- Storage: gallery bucket icin yetkiler
drop policy if exists "Coordinators can upload gallery images" on storage.objects;
create policy "Board can upload gallery images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'gallery' and public.is_board());

drop policy if exists "Board can delete gallery images" on storage.objects;
create policy "Board can delete gallery images" on storage.objects
  for delete to authenticated
  using (bucket_id = 'gallery' and public.is_board());

-- Sponsor gonderi gorselleri icin yeni bucket
insert into storage.buckets (id, name, public)
values ('sponsor-posts', 'sponsor-posts', true)
on conflict (id) do nothing;

drop policy if exists "Sponsor post images publicly readable" on storage.objects;
create policy "Sponsor post images publicly readable" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'sponsor-posts');

drop policy if exists "Board can upload sponsor post images" on storage.objects;
create policy "Board can upload sponsor post images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'sponsor-posts' and public.is_board());
