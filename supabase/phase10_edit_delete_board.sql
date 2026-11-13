drop policy if exists "Board update announcements" on announcements;
create policy "Board update announcements" on announcements
  for update to authenticated
  using (public.is_board())
  with check (public.is_board());

drop policy if exists "Board delete announcements" on announcements;
create policy "Board delete announcements" on announcements
  for delete to authenticated using (public.is_board());

drop policy if exists "Board update sponsors" on sponsors;
create policy "Board update sponsors" on sponsors
  for update to authenticated
  using (public.is_board())
  with check (public.is_board());

drop policy if exists "Board update sponsor posts" on sponsor_posts;
create policy "Board update sponsor posts" on sponsor_posts
  for update to authenticated
  using (public.is_board())
  with check (public.is_board());
