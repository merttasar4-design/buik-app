drop policy if exists "Board can update sponsor post images" on storage.objects;
create policy "Board can update sponsor post images" on storage.objects
  for update to authenticated
  using (bucket_id = 'sponsor-posts' and public.is_board())
  with check (bucket_id = 'sponsor-posts' and public.is_board());
