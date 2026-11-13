-- Oryantasyon standı kayıt sistemi: QR kod ile açılan web formundan
-- kendi telefonlarından self-servis kayıt (ad soyad, telefon, e-posta,
-- bölüm, sınıf). Çekiliş sisteminden (raffle_entries) tamamen bağımsız,
-- ayrı bir amaç: genel lead/kayıt toplama.
-- Web tarafı: buik-etkinlik-basvurulari projesi, /oryantasyon-kayit (form)
-- ve /oryantasyon-kayit/panel (board'a özel canlı takip).

create table if not exists orientation_registrations (
  id bigint generated always as identity primary key,
  full_name text not null,
  phone text not null,
  email text not null,
  department text not null,
  class_year text not null,
  created_at timestamptz not null default now()
);

-- Aynı kişi QR'ı iki kez okutursa mükerrer kayıt oluşmasın.
create unique index if not exists orientation_registrations_email_key
  on orientation_registrations (lower(email));

alter table orientation_registrations enable row level security;

-- Form herkese açık: kimliksiz (anon) ziyaretçi kayıt ekleyebilir ama
-- başkalarının kayıtlarını okuyamaz (aşağıdaki select policy sadece board'a).
drop policy if exists "Anyone can register" on orientation_registrations;
create policy "Anyone can register" on orientation_registrations
  for insert to anon, authenticated
  with check (true);

drop policy if exists "Board can read registrations" on orientation_registrations;
create policy "Board can read registrations" on orientation_registrations
  for select to authenticated
  using (public.is_board());

alter publication supabase_realtime add table orientation_registrations;
