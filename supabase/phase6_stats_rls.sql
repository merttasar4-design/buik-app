-- Onceki politika sonsuz donguye giriyordu (profiles kendi icinde subquery yapiyordu).
-- Duzeltme: security definer fonksiyon ile rol kontrolu RLS'i atlayarak yapiliyor.

drop policy if exists "Coordinators can read all profiles" on profiles;
drop policy if exists "Coordinators can read all attendance" on attendance_records;

create or replace function public.is_coordinator_or_board()
returns boolean as $$
  select exists (
    select 1 from profiles
    where id = auth.uid()
    and role in ('coordinator','board')
  );
$$ language sql security definer stable;

create policy "Coordinators can read all profiles" on profiles
  for select to authenticated
  using (public.is_coordinator_or_board());

create policy "Coordinators can read all attendance" on attendance_records
  for select to authenticated
  using (public.is_coordinator_or_board());
