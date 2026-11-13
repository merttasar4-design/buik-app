-- Hesap silme oncesi: created_by referanslarini nullable + on delete set null yap
-- (boylece bir koordinator hesabini silince gecmis toplanti/kod kayitlari kaybolmaz, sadece olusturan bilgisi bos kalir)

alter table meetings alter column created_by drop not null;
alter table meetings drop constraint if exists meetings_created_by_fkey;
alter table meetings add constraint meetings_created_by_fkey
  foreign key (created_by) references profiles(id) on delete set null;

alter table attendance_codes alter column created_by drop not null;
alter table attendance_codes drop constraint if exists attendance_codes_created_by_fkey;
alter table attendance_codes add constraint attendance_codes_created_by_fkey
  foreign key (created_by) references profiles(id) on delete set null;

-- Kullanicinin kendi hesabini silmesi icin RPC
-- (profiles -> auth.users zaten "on delete cascade", attendance_records ve
--  event_applications da profiles'a cascade bagli, dolayisiyla auth.users
--  silinince hepsi otomatik temizlenir)
create or replace function public.delete_my_account()
returns void as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$ language plpgsql security definer;
