-- Oryantasyon günleri (21-23 Eylül) özelliği: alt kurul WhatsApp yönlendirmesi + çekiliş

alter table committees add column if not exists whatsapp_link text;

-- Tek dokunuşla, hesapsız çekiliş katılımı (isim + telefon)
create table if not exists raffle_entries (
  id bigint generated always as identity primary key,
  full_name text not null,
  phone text not null,
  user_id uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create unique index if not exists raffle_entries_phone_key on raffle_entries (phone);

alter table raffle_entries enable row level security;

drop policy if exists "Anyone can join raffle" on raffle_entries;
create policy "Anyone can join raffle" on raffle_entries
  for insert to anon, authenticated
  with check (true);

drop policy if exists "Board can read raffle entries" on raffle_entries;
create policy "Board can read raffle entries" on raffle_entries
  for select to authenticated
  using (public.is_board());

-- Çekilen kazananlar (tek bir entry birden fazla kez kazanamaz).
-- winner_name burada denormalize saklanır: raffle_entries okuma izni
-- board'a özel olduğu için embed join herkese isim döndürmez.
create table if not exists raffle_winners (
  id bigint generated always as identity primary key,
  entry_id bigint not null references raffle_entries(id) on delete cascade unique,
  winner_name text not null,
  drawn_by uuid not null references profiles(id),
  drawn_at timestamptz not null default now()
);

alter table raffle_winners enable row level security;

drop policy if exists "Public read raffle winners" on raffle_winners;
create policy "Public read raffle winners" on raffle_winners
  for select to anon, authenticated
  using (true);

-- Herkesin görebileceği toplam katılımcı sayısı (isim/telefon sızdırmadan)
create or replace function public.raffle_entry_count()
returns bigint as $$
  select count(*) from raffle_entries;
$$ language sql stable security definer;

-- Kalan katılımcılar arasından rastgele bir kazanan çeker (sadece board)
create or replace function public.draw_raffle_winner()
returns table(winner_id bigint, winner_name text) as $$
declare
  caller_role text;
  picked_id bigint;
  picked_name text;
begin
  select role into caller_role from profiles where id = auth.uid();
  if caller_role is null or caller_role <> 'board' then
    raise exception 'not_authorized';
  end if;

  select re.id, re.full_name into picked_id, picked_name
  from raffle_entries re
  where re.id not in (select entry_id from raffle_winners)
  order by random()
  limit 1;

  if picked_id is null then
    raise exception 'no_entries_left';
  end if;

  insert into raffle_winners (entry_id, winner_name, drawn_by)
  values (picked_id, picked_name, auth.uid());

  return query select picked_id, picked_name;
end;
$$ language plpgsql security definer;

alter publication supabase_realtime add table raffle_winners;

-- Alt kurulların gerçek WhatsApp grup linkleri elde edilince tek tek doldurulmalı, örnek:
-- update committees set whatsapp_link = 'https://chat.whatsapp.com/XXXXXXXXXXXXXXXXXXXXXX' where name = 'İş Dünyası ve Yönetim';
-- update committees set whatsapp_link = 'https://chat.whatsapp.com/XXXXXXXXXXXXXXXXXXXXXX' where name = 'Ekonomi ve Finans';
-- update committees set whatsapp_link = 'https://chat.whatsapp.com/XXXXXXXXXXXXXXXXXXXXXX' where name = 'Reklamcılık';
-- update committees set whatsapp_link = 'https://chat.whatsapp.com/XXXXXXXXXXXXXXXXXXXXXX' where name = 'Marka ve Pazarlama';
-- update committees set whatsapp_link = 'https://chat.whatsapp.com/XXXXXXXXXXXXXXXXXXXXXX' where name = 'Dinamik ve Medya';
-- update committees set whatsapp_link = 'https://chat.whatsapp.com/XXXXXXXXXXXXXXXXXXXXXX' where name = 'Girişimcilik ve Yapay Zeka';
