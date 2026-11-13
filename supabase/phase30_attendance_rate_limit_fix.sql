-- phase25'teki deneme sınırı fiilen çalışmıyordu: kod yanlışsa
-- `raise exception 'invalid_code'` tüm transaction'ı geri alıyor, az önce
-- attendance_code_attempts'a eklenen deneme satırı da siliniyordu. Yani
-- hatalı denemeler hiç sayılmıyor, brute-force koruması yoktu.
--
-- Çözüm: hata durumlarında exception atmak yerine PostgREST'in
-- response.status ayarıyla 400 döndürüyoruz. Exception olmadığı için
-- transaction commit edilir ve deneme kaydı kalıcı olur.
--
-- İstemci uyumluluğu (uygulama/web güncellemesi GEREKMEZ):
--  * Başarılı: gövde eskisi gibi [{checked_meeting_id, checked_committee_name,
--    checked_meeting_number}] dizisi.
--  * Hatalı: HTTP 400 + {"message": "invalid_code" | "too_many_attempts" ...}.
--    supabase-dart ve supabase-js bunu exception/error.message olarak verir;
--    mevcut 'too_many_attempts' kontrolü aynen çalışır.

drop function if exists public.check_in_with_code(text);
create or replace function public.check_in_with_code(input_code text)
returns json as $$
declare
  matched_meeting_id bigint;
  matched_committee_name text;
  matched_meeting_number int;
  recent_attempts int;
begin
  if auth.uid() is null then
    perform set_config('response.status', '401', true);
    return json_build_object('code', 'P0001', 'message', 'not_authorized');
  end if;

  select count(*) into recent_attempts
  from attendance_code_attempts
  where user_id = auth.uid()
    and attempted_at > now() - interval '1 minute';

  if recent_attempts >= 5 then
    perform set_config('response.status', '400', true);
    return json_build_object('code', 'P0001', 'message', 'too_many_attempts');
  end if;

  insert into attendance_code_attempts (user_id) values (auth.uid());

  select ac.meeting_id, c.name, m.meeting_number
  into matched_meeting_id, matched_committee_name, matched_meeting_number
  from attendance_codes ac
  join meetings m on m.id = ac.meeting_id
  join committees c on c.id = m.committee_id
  where ac.code = input_code
    and (ac.expires_at is null or ac.expires_at > now())
  order by ac.created_at desc
  limit 1;

  if matched_meeting_id is null then
    perform set_config('response.status', '400', true);
    return json_build_object('code', 'P0001', 'message', 'invalid_code');
  end if;

  insert into attendance_records (meeting_id, user_id)
  values (matched_meeting_id, auth.uid())
  on conflict (meeting_id, user_id) do nothing;

  delete from attendance_code_attempts
  where attempted_at < now() - interval '1 day';

  return json_build_array(json_build_object(
    'checked_meeting_id', matched_meeting_id,
    'checked_committee_name', matched_committee_name,
    'checked_meeting_number', matched_meeting_number
  ));
end;
$$ language plpgsql security definer set search_path = public;

revoke all on function public.check_in_with_code(text) from public, anon;
grant execute on function public.check_in_with_code(text) to authenticated;
