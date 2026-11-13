-- Sponsorlar
create table if not exists sponsors (
  id bigint generated always as identity primary key,
  name text not null,
  logo_url text,
  description text,
  website_url text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table sponsors enable row level security;

drop policy if exists "Public read sponsors" on sponsors;
create policy "Public read sponsors" on sponsors
  for select to anon, authenticated using (true);

drop policy if exists "Coordinators manage sponsors" on sponsors;
create policy "Coordinators manage sponsors" on sponsors
  for insert to authenticated with check (public.is_coordinator_or_board());

drop policy if exists "Coordinators delete sponsors" on sponsors;
create policy "Coordinators delete sponsors" on sponsors
  for delete to authenticated using (public.is_coordinator_or_board());

-- Is / staj ilanlari
create table if not exists job_postings (
  id bigint generated always as identity primary key,
  title text not null,
  company text not null,
  description text,
  application_url text,
  deadline date,
  created_at timestamptz not null default now()
);

alter table job_postings enable row level security;

drop policy if exists "Public read job postings" on job_postings;
create policy "Public read job postings" on job_postings
  for select to anon, authenticated using (true);

drop policy if exists "Coordinators manage job postings" on job_postings;
create policy "Coordinators manage job postings" on job_postings
  for insert to authenticated with check (public.is_coordinator_or_board());

drop policy if exists "Coordinators delete job postings" on job_postings;
create policy "Coordinators delete job postings" on job_postings
  for delete to authenticated using (public.is_coordinator_or_board());

-- Galeri
create table if not exists gallery_photos (
  id bigint generated always as identity primary key,
  photo_url text not null,
  caption text,
  uploaded_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table gallery_photos enable row level security;

drop policy if exists "Public read gallery" on gallery_photos;
create policy "Public read gallery" on gallery_photos
  for select to anon, authenticated using (true);

drop policy if exists "Coordinators manage gallery" on gallery_photos;
create policy "Coordinators manage gallery" on gallery_photos
  for insert to authenticated with check (public.is_coordinator_or_board());

drop policy if exists "Coordinators delete gallery" on gallery_photos;
create policy "Coordinators delete gallery" on gallery_photos
  for delete to authenticated using (public.is_coordinator_or_board());

-- Galeri fotograflari icin storage bucket
insert into storage.buckets (id, name, public)
values ('gallery', 'gallery', true)
on conflict (id) do nothing;

drop policy if exists "Gallery images publicly readable" on storage.objects;
create policy "Gallery images publicly readable" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'gallery');

drop policy if exists "Coordinators can upload gallery images" on storage.objects;
create policy "Coordinators can upload gallery images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'gallery' and public.is_coordinator_or_board());
