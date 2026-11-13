drop policy if exists "Board update events" on events;
create policy "Board update events" on events
  for update to authenticated
  using (public.is_board())
  with check (public.is_board());

drop policy if exists "Board delete events" on events;
create policy "Board delete events" on events
  for delete to authenticated using (public.is_board());
