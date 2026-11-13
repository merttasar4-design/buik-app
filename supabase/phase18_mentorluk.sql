-- Mentörlük programı: koordinatör-mezun 1-1 eşleştirme ve sohbet
create table if not exists mentorships (
  id uuid primary key default gen_random_uuid(),
  coordinator_id uuid not null references profiles(id) on delete cascade,
  mezun_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'ended')),
  created_at timestamptz not null default now(),
  ended_at timestamptz
);

-- Bir mezunun aynı anda yalnızca bir aktif mentörü olabilir
create unique index if not exists mentorships_one_active_per_mezun
  on mentorships (mezun_id)
  where status = 'active';

alter table mentorships enable row level security;

create policy "Participants can read own mentorship" on mentorships
  for select to authenticated
  using (auth.uid() = coordinator_id or auth.uid() = mezun_id);

create policy "Board can read all mentorships" on mentorships
  for select to authenticated
  using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.role = 'board'
    )
  );

create policy "Board can create mentorships" on mentorships
  for insert to authenticated
  with check (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.role = 'board'
    )
  );

create policy "Board can update mentorships" on mentorships
  for update to authenticated
  using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.role = 'board'
    )
  );

-- Mentörlük sohbet mesajları
create table if not exists mentorship_messages (
  id uuid primary key default gen_random_uuid(),
  mentorship_id uuid not null references mentorships(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

alter table mentorship_messages enable row level security;

create policy "Participants can read own mentorship messages" on mentorship_messages
  for select to authenticated
  using (
    exists (
      select 1 from mentorships
      where mentorships.id = mentorship_messages.mentorship_id
      and (mentorships.coordinator_id = auth.uid() or mentorships.mezun_id = auth.uid())
    )
  );

create policy "Participants can send own mentorship messages" on mentorship_messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from mentorships
      where mentorships.id = mentorship_messages.mentorship_id
      and mentorships.status = 'active'
      and (mentorships.coordinator_id = auth.uid() or mentorships.mezun_id = auth.uid())
    )
  );

-- Realtime: mesajların anlık olarak dinlenebilmesi için
alter publication supabase_realtime add table mentorship_messages;
