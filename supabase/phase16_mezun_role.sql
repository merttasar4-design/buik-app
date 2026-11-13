-- Kulüp mezunları için yeni rol: 'mezun'
alter table profiles drop constraint if exists profiles_role_check;
alter table profiles
  add constraint profiles_role_check
  check (role in ('member', 'coordinator', 'board', 'mezun'));
