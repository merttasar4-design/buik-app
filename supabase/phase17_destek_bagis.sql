-- Destek bölümü: mezunlardan aidat/bağış toplama (iyzico Checkout Form)
create table if not exists donations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  type text not null check (type in ('aidat', 'bagis')),
  amount numeric(10, 2) not null check (amount > 0),
  currency text not null default 'TRY',
  status text not null default 'pending' check (status in ('pending', 'success', 'failed')),
  conversation_id text not null unique,
  iyzico_token text,
  iyzico_payment_id text,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table donations enable row level security;

create policy "Users can read own donations" on donations
  for select to authenticated
  using (auth.uid() = user_id);

create policy "Board can read all donations" on donations
  for select to authenticated
  using (
    exists (
      select 1 from profiles
      where profiles.id = auth.uid()
      and profiles.role = 'board'
    )
  );

create policy "Users can create own pending donations" on donations
  for insert to authenticated
  with check (auth.uid() = user_id and status = 'pending');

-- Durum güncellemesi (pending -> success/failed) sadece edge function'ın
-- kullandığı service role ile yapılır; authenticated kullanıcılar için
-- update policy'si kasıtlı olarak tanımlanmadı.
