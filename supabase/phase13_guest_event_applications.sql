-- Okul dışından gelen kişiler (hesabı olmayan) etkinliklere başvuramıyordu,
-- çünkü event_applications.user_id NOT NULL'dı ve tek başvuru yolu giriş
-- yapmış bir profile bağlıydı. Bu migration, hesapsız (misafir) başvuruyu
-- ad/e-posta/telefon ile mümkün kılıyor; mevcut üye başvuru akışına dokunmuyor.

alter table event_applications alter column user_id drop not null;

alter table event_applications add column if not exists guest_name text;
alter table event_applications add column if not exists guest_email text;
alter table event_applications add column if not exists guest_phone text;

alter table event_applications
  drop constraint if exists event_applications_identity_check;
alter table event_applications
  add constraint event_applications_identity_check
  check (
    user_id is not null
    or (guest_name is not null and guest_email is not null)
  );

drop policy if exists "Guests can apply without account" on event_applications;
create policy "Guests can apply without account" on event_applications
  for insert to anon, authenticated
  with check (
    user_id is null
    and guest_name is not null
    and guest_email is not null
  );

-- Üyeler için zaten unique(event_id, user_id) vardı; misafirler aynı e-posta
-- ile aynı etkinliğe yanlışlıkla (örn. çift dokunma) birden fazla başvuramasın.
create unique index if not exists event_applications_guest_unique
  on event_applications (event_id, guest_email)
  where user_id is null;
