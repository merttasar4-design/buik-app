-- Misafir başvurularında telefon artık opsiyonel değil, uygulama tarafında
-- zorunlu kılındı. Veritabanı kısıtını da buna göre sıkılaştırıyoruz.

alter table event_applications
  drop constraint if exists event_applications_identity_check;
alter table event_applications
  add constraint event_applications_identity_check
  check (
    user_id is not null
    or (
      guest_name is not null
      and guest_email is not null
      and guest_phone is not null
    )
  );

drop policy if exists "Guests can apply without account" on event_applications;
create policy "Guests can apply without account" on event_applications
  for insert to anon, authenticated
  with check (
    user_id is null
    and guest_name is not null
    and guest_email is not null
    and guest_phone is not null
  );
