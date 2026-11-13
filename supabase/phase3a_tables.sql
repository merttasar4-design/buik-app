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

