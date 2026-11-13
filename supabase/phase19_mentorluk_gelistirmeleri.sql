-- Mentörlük sohbeti geliştirmeleri: görsel/dosya eki, görüldü bilgisi,
-- eşleşme taraflarının birbirinin profilini görebilmesi.

-- Ek dosya/görsel alanları
alter table mentorship_messages add column if not exists attachment_path text;
alter table mentorship_messages add column if not exists attachment_type text
  check (attachment_type in ('image', 'file'));
alter table mentorship_messages add column if not exists attachment_name text;
alter table mentorship_messages add column if not exists read_at timestamptz;

-- Ek varken boş body'e izin ver (attachment mesajlarında metin zorunlu değil)
alter table mentorship_messages drop constraint if exists mentorship_messages_body_check;
alter table mentorship_messages alter column body set default '';
alter table mentorship_messages add constraint mentorship_messages_body_check
  check (char_length(trim(body)) > 0 or attachment_path is not null);

-- Karşı taraf mesajı okuyunca read_at güncelleyebilsin
create policy "Participants can update read status" on mentorship_messages
  for update to authenticated
  using (
    exists (
      select 1 from mentorships
      where mentorships.id = mentorship_messages.mentorship_id
      and (mentorships.coordinator_id = auth.uid() or mentorships.mezun_id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from mentorships
      where mentorships.id = mentorship_messages.mentorship_id
      and (mentorships.coordinator_id = auth.uid() or mentorships.mezun_id = auth.uid())
    )
  );

-- Realtime UPDATE olaylarının da (read_at değişimi) dinlenebilmesi için
-- mentorship_messages zaten publication'da, ek işlem gerekmiyor.

-- Aktif mentörlük eşleşmesindeki iki taraf birbirinin temel profil
-- bilgisini (isim, e-posta, telefon, avatar vb.) görebilsin.
-- (Önceki durumda mezun rolü sadece kendi profilini okuyabiliyordu,
-- bu yüzden sohbet listesinde/karşı taraf profilinde isim görünmüyordu.)
create policy "Mentorship participants can read each other profile" on profiles
  for select to authenticated
  using (
    exists (
      select 1 from mentorships
      where mentorships.status = 'active'
      and (
        (mentorships.mezun_id = auth.uid() and mentorships.coordinator_id = profiles.id)
        or (mentorships.coordinator_id = auth.uid() and mentorships.mezun_id = profiles.id)
      )
    )
  );

-- Özel dosya/görsel deposu (sohbet içeriği herkese açık olmamalı)
insert into storage.buckets (id, name, public)
values ('mentorship-attachments', 'mentorship-attachments', false)
on conflict (id) do nothing;

-- Yol düzeni: {mentorship_id}/{dosya_adi} — ilk klasör adı mentorship_id
create policy "Mentorship participants can upload attachments"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'mentorship-attachments'
    and exists (
      select 1 from mentorships
      where mentorships.id::text = (storage.foldername(name))[1]
      and mentorships.status = 'active'
      and (mentorships.coordinator_id = auth.uid() or mentorships.mezun_id = auth.uid())
    )
  );

create policy "Mentorship participants can read attachments"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'mentorship-attachments'
    and exists (
      select 1 from mentorships
      where mentorships.id::text = (storage.foldername(name))[1]
      and (mentorships.coordinator_id = auth.uid() or mentorships.mezun_id = auth.uid())
    )
  );
