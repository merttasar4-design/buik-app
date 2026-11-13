-- 1) Calendar dates for existing events
alter table events add column if not exists start_date date;
alter table events add column if not exists end_date date;

update events set start_date = '2025-10-25', end_date = '2025-10-26' where title = 'Brandmarker Pazarlama Günleri';
update events set start_date = '2025-11-01', end_date = '2025-11-02' where title = 'Finance Break';
update events set start_date = '2025-11-22', end_date = '2025-11-23' where title = 'ADhere Reklamcılık Günleri';
update events set start_date = '2025-11-29', end_date = '2025-11-30' where title = 'Girişimcilik ve Yapay Zeka Zirvesi';
update events set start_date = '2025-12-06', end_date = '2025-12-07' where title = 'Yönetim ve Liderlik Zirvesi';
update events set start_date = '2026-02-15', end_date = '2026-02-15' where title = 'Boğaziçi Marka Ödülleri';
update events set start_date = '2026-02-19', end_date = '2026-02-22' where title = 'Finans ve Yatırım Akademisi';
update events set start_date = '2026-02-21', end_date = '2026-02-22' where title = 'Advise Reklamcılık Akademisi';
update events set start_date = '2026-03-01', end_date = '2026-04-30' where title = 'Investimate Sanal Yatırım Yarışması';
update events set start_date = '2026-03-01', end_date = '2026-04-30' where title = 'Business Case Challenge';
update events set start_date = '2026-03-01', end_date = '2026-04-30' where title = 'EnterPrize Girişimcilik Yarışması';
update events set start_date = '2026-04-04', end_date = '2026-04-05' where title = 'Boğaziçi Marka Zirvesi';
update events set start_date = '2026-04-18', end_date = '2026-04-18' where title = 'Boğaziçi Reklamcılık Ödülleri';
update events set start_date = '2026-05-02', end_date = '2026-05-03' where title = 'Boğaziçi Medya Festivali';
-- 'Dinamik Online' kasıtlı olarak tarihsiz bırakıldı (yıl boyu süren bir program, tek güne bağlı değil)

-- 2) Kullanıcı profilleri ve roller
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'member' check (role in ('member','coordinator','board')),
  full_name text,
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "Users can read own profile" on profiles
  for select to authenticated
  using (auth.uid() = id);

create policy "Users can update own profile" on profiles
  for update to authenticated
  using (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 3) Mevcut kullanıcılar için profil satırı oluştur (trigger'dan önce kayıt olanlar için)
insert into public.profiles (id, email)
select id, email from auth.users
on conflict (id) do nothing;

-- 4) Koordinatör/yönetim kurulu yeni etkinlik (toplantı) ekleyebilsin
create policy "Coordinators can create events" on events
  for insert to authenticated
  with check (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid()
      and profiles.role in ('coordinator','board')
    )
  );

-- 5) Yoklama kodları
create table if not exists attendance_codes (
  id bigint generated always as identity primary key,
  event_id bigint not null references events(id) on delete cascade,
  code text not null,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz
);

alter table attendance_codes enable row level security;

create policy "Coordinators can create codes" on attendance_codes
  for insert to authenticated
  with check (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid()
      and profiles.role in ('coordinator','board')
    )
  );

create policy "Coordinators can read own created codes" on attendance_codes
  for select to authenticated
  using (created_by = auth.uid());

-- 6) Yoklama kayıtları
create table if not exists attendance_records (
  id bigint generated always as identity primary key,
  event_id bigint not null references events(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  checked_in_at timestamptz not null default now(),
  unique (event_id, user_id)
);

alter table attendance_records enable row level security;

create policy "Users can read own attendance" on attendance_records
  for select to authenticated
  using (auth.uid() = user_id);

-- 7) Üye kodu girince güvenli şekilde yoklamaya işlesin
create or replace function public.check_in_with_code(input_code text)
returns table(event_id bigint, event_title text) as $$
declare
  matched_event_id bigint;
  matched_title text;
begin
  select ac.event_id, e.title into matched_event_id, matched_title
  from attendance_codes ac
  join events e on e.id = ac.event_id
  where ac.code = input_code
    and (ac.expires_at is null or ac.expires_at > now())
  order by ac.created_at desc
  limit 1;

  if matched_event_id is null then
    raise exception 'invalid_code';
  end if;

  insert into attendance_records (event_id, user_id)
  values (matched_event_id, auth.uid())
  on conflict (event_id, user_id) do nothing;

  return query select matched_event_id, matched_title;
end;
$$ language plpgsql security definer;

-- 8) Etkinliklere başvuru
create table if not exists event_applications (
  id bigint generated always as identity primary key,
  event_id bigint not null references events(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  applied_at timestamptz not null default now(),
  unique (event_id, user_id)
);

alter table event_applications enable row level security;

create policy "Users manage own applications" on event_applications
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 9) Duyurular
create table if not exists announcements (
  id bigint generated always as identity primary key,
  title text not null,
  body text not null,
  created_at timestamptz not null default now()
);

alter table announcements enable row level security;

create policy "Public read announcements" on announcements
  for select to anon, authenticated
  using (true);

create policy "Coordinators can create announcements" on announcements
  for insert to authenticated
  with check (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid()
      and profiles.role in ('coordinator','board')
    )
  );

-- 10) Güvenlik: kullanıcılar kendi rollerini değiştiremesin (sadece dashboard/SQL Editor üzerinden değiştirilebilir)
create or replace function public.prevent_role_self_escalation()
returns trigger as $$
begin
  if auth.role() = 'authenticated' and new.role is distinct from old.role then
    new.role := old.role;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists prevent_role_change on profiles;
create trigger prevent_role_change
  before update on profiles
  for each row execute procedure public.prevent_role_self_escalation();

-- 11) Düzeltme: check_in_with_code fonksiyonundaki isim çakışması (event_id ambiguous) hatası
drop function if exists public.check_in_with_code(text);
create or replace function public.check_in_with_code(input_code text)
returns table(checked_event_id bigint, checked_event_title text) as $$
declare
  matched_event_id bigint;
  matched_title text;
begin
  select ac.event_id, e.title into matched_event_id, matched_title
  from attendance_codes ac
  join events e on e.id = ac.event_id
  where ac.code = input_code
    and (ac.expires_at is null or ac.expires_at > now())
  order by ac.created_at desc
  limit 1;

  if matched_event_id is null then
    raise exception 'invalid_code';
  end if;

  insert into attendance_records (event_id, user_id)
  values (matched_event_id, auth.uid())
  on conflict (event_id, user_id) do nothing;

  return query select matched_event_id, matched_title;
end;
$$ language plpgsql security definer;

-- 12) Profil detayları: telefon, bölüm, sınıf, profil fotoğrafı
alter table profiles add column if not exists phone text;
alter table profiles add column if not exists department text;
alter table profiles add column if not exists class_year text;
alter table profiles add column if not exists avatar_url text;

-- Profil fotoğrafları için storage bucket
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "Avatar images are publicly readable"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'avatars');

create policy "Users can upload their own avatar"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can update their own avatar"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- 13) Alt kurullar ve toplantılar (yoklama artık genel etkinliklerden ayrı, kurul bazlı toplantılara bağlı)
create table if not exists committees (
  id bigint generated always as identity primary key,
  name text not null unique,
  sort_order int not null default 0
);

alter table committees enable row level security;

drop policy if exists "Public read committees" on committees;
create policy "Public read committees" on committees
  for select to anon, authenticated
  using (true);

insert into committees (name, sort_order) values
('İş Dünyası ve Yönetim', 1),
('Ekonomi ve Finans', 2),
('Reklamcılık', 3),
('Marka ve Pazarlama', 4),
('Dinamik ve Medya', 5),
('Girişimcilik ve Yapay Zeka', 6)
on conflict (name) do nothing;

create table if not exists meetings (
  id bigint generated always as identity primary key,
  committee_id bigint not null references committees(id) on delete cascade,
  meeting_number int not null,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  unique (committee_id, meeting_number)
);

alter table meetings enable row level security;

drop policy if exists "Authenticated can read meetings" on meetings;
create policy "Authenticated can read meetings" on meetings
  for select to authenticated
  using (true);

-- attendance_codes/attendance_records artık meetings'e bağlı
drop table if exists attendance_records;
drop table if exists attendance_codes;

create table if not exists attendance_codes (
  id bigint generated always as identity primary key,
  meeting_id bigint not null references meetings(id) on delete cascade,
  code text not null,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz
);

alter table attendance_codes enable row level security;

drop policy if exists "Coordinators can read own created codes" on attendance_codes;
create policy "Coordinators can read own created codes" on attendance_codes
  for select to authenticated
  using (created_by = auth.uid());

create table if not exists attendance_records (
  id bigint generated always as identity primary key,
  meeting_id bigint not null references meetings(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  checked_in_at timestamptz not null default now(),
  unique (meeting_id, user_id)
);

alter table attendance_records enable row level security;

drop policy if exists "Users can read own attendance" on attendance_records;
create policy "Users can read own attendance" on attendance_records
  for select to authenticated
  using (auth.uid() = user_id);

-- Koordinatorun kendi belirttigi toplanti numarasiyla kod uret (sadece coordinator/board)
create or replace function public.start_meeting_and_generate_code(
  p_committee_id bigint,
  p_meeting_number int
)
returns table(out_meeting_number int, out_code text) as $$
declare
  caller_role text;
  target_meeting_id bigint;
  generated_code text;
begin
  select role into caller_role from profiles where id = auth.uid();
  if caller_role is null or caller_role not in ('coordinator','board') then
    raise exception 'not_authorized';
  end if;

  insert into meetings (committee_id, meeting_number, created_by)
  values (p_committee_id, p_meeting_number, auth.uid())
  on conflict (committee_id, meeting_number)
    do update set created_by = excluded.created_by
  returning id into target_meeting_id;

  generated_code := lpad(floor(random() * 1000000)::int::text, 6, '0');

  insert into attendance_codes (meeting_id, code, created_by)
  values (target_meeting_id, generated_code, auth.uid());

  return query select p_meeting_number, generated_code;
end;
$$ language plpgsql security definer;

-- Uye kodu girince toplanti + alt kurul bilgisiyle yoklamaya isle
drop function if exists public.check_in_with_code(text);
create or replace function public.check_in_with_code(input_code text)
returns table(checked_meeting_id bigint, checked_committee_name text, checked_meeting_number int) as $$
declare
  matched_meeting_id bigint;
  matched_committee_name text;
  matched_meeting_number int;
begin
  select ac.meeting_id, c.name, m.meeting_number
  into matched_meeting_id, matched_committee_name, matched_meeting_number
  from attendance_codes ac
  join meetings m on m.id = ac.meeting_id
  join committees c on c.id = m.committee_id
  where ac.code = input_code
    and (ac.expires_at is null or ac.expires_at > now())
  order by ac.created_at desc
  limit 1;

  if matched_meeting_id is null then
    raise exception 'invalid_code';
  end if;

  insert into attendance_records (meeting_id, user_id)
  values (matched_meeting_id, auth.uid())
  on conflict (meeting_id, user_id) do nothing;

  return query select matched_meeting_id, matched_committee_name, matched_meeting_number;
end;
$$ language plpgsql security definer;
