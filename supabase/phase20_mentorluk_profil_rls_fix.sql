-- phase19'daki "Mentorship participants can read each other profile" politikası
-- sonsuz döngüye giriyordu: profiles politikası mentorships'e bakıyor,
-- mentorships'in "Board can read all mentorships" politikası da profiles'a
-- bakıyor. Çözüm phase6_stats_rls.sql'deki gibi: security definer fonksiyon
-- ile RLS'i atlayarak kontrol yapmak.

drop policy if exists "Mentorship participants can read each other profile" on profiles;

create or replace function public.is_mentorship_partner(other_id uuid)
returns boolean as $$
  select exists (
    select 1 from mentorships
    where status = 'active'
    and (
      (mezun_id = auth.uid() and coordinator_id = other_id)
      or (coordinator_id = auth.uid() and mezun_id = other_id)
    )
  );
$$ language sql security definer stable;

create policy "Mentorship participants can read each other profile" on profiles
  for select to authenticated
  using (public.is_mentorship_partner(profiles.id));
