-- Koordinatorun kendi belirttigi toplanti numarasiyla kod uret (sadece coordinator/board)
create or replace function public.start_meeting_and_generate_code(
  p_committee_id bigint,
  p_meeting_number int
)
returns table(out_meeting_number int, out_code text) as $$
declare
  caller_role text;
  target_meeting_id bigint;
  generated_code text;
begin
  select role into caller_role from profiles where id = auth.uid();
  if caller_role is null or caller_role not in ('coordinator','board') then
    raise exception 'not_authorized';
  end if;

  insert into meetings (committee_id, meeting_number, created_by)
  values (p_committee_id, p_meeting_number, auth.uid())
  on conflict (committee_id, meeting_number)
    do update set created_by = excluded.created_by
  returning id into target_meeting_id;

  generated_code := lpad(floor(random() * 1000000)::int::text, 6, '0');

  insert into attendance_codes (meeting_id, code, created_by)
  values (target_meeting_id, generated_code, auth.uid());

  return query select p_meeting_number, generated_code;
end;
$$ language plpgsql security definer;

-- Uye kodu girince toplanti + alt kurul bilgisiyle yoklamaya isle
drop function if exists public.check_in_with_code(text);
create or replace function public.check_in_with_code(input_code text)
returns table(checked_meeting_id bigint, checked_committee_name text, checked_meeting_number int) as $$
declare
  matched_meeting_id bigint;
  matched_committee_name text;
  matched_meeting_number int;
begin
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
    raise exception 'invalid_code';
  end if;

  insert into attendance_records (meeting_id, user_id)
  values (matched_meeting_id, auth.uid())
  on conflict (meeting_id, user_id) do nothing;

  return query select matched_meeting_id, matched_committee_name, matched_meeting_number;
end;
$$ language plpgsql security definer;
