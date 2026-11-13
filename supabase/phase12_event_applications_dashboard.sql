-- Etkinlik başvuru panosu: şu ana kadar event_applications sadece kullanıcının
-- kendi satırını görebildiği bir "kara kutu" gibiydi — board/koordinatörler
-- kimlerin başvurduğunu göremiyordu. Bu politika mevcut is_coordinator_or_board()
-- fonksiyonunu kullanarak salt-okunur görünürlük ekliyor (mevcut "Users manage
-- own applications" politikasının yerini almıyor, üzerine ekleniyor).

drop policy if exists "Coordinators can read all applications" on event_applications;
create policy "Coordinators can read all applications" on event_applications
  for select to authenticated
  using (public.is_coordinator_or_board());
