-- 2026-2027 akademik yıl takvimi (ETKİNLİKLER TAKVİMİ-2.xlsx, website'e de aynı kaynaktan işlendi).
-- Sadece events tablosundaki title ile birebir eşleşen satırlar güncellenir — eşleşmeyen
-- satır olursa "0 rows affected" görünür, sessizce hata vermez.

update events set start_date = '2026-11-07', end_date = '2026-11-08'
  where title = 'Finance Break';

update events set start_date = '2026-11-21', end_date = '2026-11-22'
  where title = 'Yönetim ve Liderlik Zirvesi';

update events set start_date = '2026-11-28', end_date = '2026-11-29'
  where title = 'ADhere Reklamcılık Günleri';

update events set start_date = '2026-12-05', end_date = '2026-12-06'
  where title = 'Brandmarker Pazarlama Günleri';

update events set start_date = '2027-03-01', end_date = '2027-05-02'
  where title = 'Investimate Sanal Yatırım Yarışması';

update events set start_date = '2027-03-01', end_date = '2027-04-25'
  where title = 'EnterPrize Girişimcilik Yarışması';

update events set start_date = '2027-03-07', end_date = '2027-04-17'
  where title = 'Business Case Challenge';

update events set start_date = '2027-04-03', end_date = '2027-04-04'
  where title = 'Advise Reklamcılık Akademisi';

update events set start_date = '2027-03-20', end_date = '2027-03-21'
  where title = 'Boğaziçi Marka Zirvesi';

update events set start_date = '2027-04-10', end_date = '2027-04-11'
  where title = 'Boğaziçi Medya Festivali';

-- Connection Days (GİYA — Girişimcilik ve Yapay Zeka alt kurulu ile birlikte), tabloda hiç
-- yoktu, yeni ekleniyor. İki ayrı tarih, iki ayrı satır.
insert into events (title, date_label, category, icon, start_date, end_date)
values
  ('Connection Days', '25 Ekim 2026', 'Girişimcilik ve Yapay Zeka', 'groups', '2026-10-25', '2026-10-25'),
  ('Connection Days', '12 Aralık 2026', 'Girişimcilik ve Yapay Zeka', 'groups', '2026-12-12', '2026-12-12');

-- Doğrulama: her satır kaç kayıt güncellendiğini gösterir, ardından güncel tabloyu listeler.
select id, title, start_date, end_date from events order by start_date nulls last;

-- "test" adlı deneme kaydı temizlendi.
delete from events where title = 'test' and id = 16;
