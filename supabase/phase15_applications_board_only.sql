-- Etkinlik başvurularını daha önce board + koordinatör görebiliyordu
-- (phase12'deki is_coordinator_or_board() politikası). Artık sadece board
-- görebilsin — hem mobil uygulama hem web panel bu politikaya göre çalışır.

drop policy if exists "Coordinators can read all applications" on event_applications;
create policy "Board can read all applications" on event_applications
  for select to authenticated
  using (public.is_board());
