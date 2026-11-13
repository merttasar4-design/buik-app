-- Sponsor silindiginde gönderilerin de silinmesini (cascade) kaldırıyoruz.
-- Sponsor silinince postlar kalir, sadece sponsor_id null olur.
alter table sponsor_posts alter column sponsor_id drop not null;

alter table sponsor_posts drop constraint if exists sponsor_posts_sponsor_id_fkey;
alter table sponsor_posts
  add constraint sponsor_posts_sponsor_id_fkey
  foreign key (sponsor_id) references sponsors(id) on delete set null;
