-- Drive senkronizasyonu icin gerekli alanlar
alter table committees add column if not exists drive_folder_id text;
alter table meetings add column if not exists sheet_file_id text;
alter table attendance_records add column if not exists synced_to_sheet boolean not null default false;

update committees set drive_folder_id = '19tbiypxElNuFiE2-NyFGUKgzgSZ11bil' where name = 'İş Dünyası ve Yönetim';
update committees set drive_folder_id = '1PgSMwikMqRypjQcWLU9i1ICHUn6hjJQ4' where name = 'Ekonomi ve Finans';
update committees set drive_folder_id = '1_I_6Uv0CWhCqi0whnxyuf1hwjSAHii9y' where name = 'Reklamcılık';
update committees set drive_folder_id = '1x3l0ogTvhtdHzyswhg2Z-UAQdplYCRy1' where name = 'Marka ve Pazarlama';
update committees set drive_folder_id = '12sCSo0zE1s2L53IU4wiJ5NXmEDX734Ve' where name = 'Dinamik ve Medya';
update committees set drive_folder_id = '1ClMabNyGI8s7BEBDAlvKzPzAYSZdHmyn' where name = 'Girişimcilik ve Yapay Zeka';
