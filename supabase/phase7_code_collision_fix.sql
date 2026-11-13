-- Eski kodlara geriye donuk 3 saatlik son kullanma tarihi ata (artik sonsuza kadar gecerli olmasinlar)
update attendance_codes
set expires_at = created_at + interval '3 hours'
where expires_at is null;

-- Kod uretirken aktif (suresi gecmemis) kodlar arasinda carpisma olmamasini garanti et
create or replace function public.start_meeting_and_generate_code(
  p_committee_id bigint,
  p_meeting_number int
)
returns table(out_meeting_number int, out_code text) as $$
declare
  caller_role text;
  target_meeting_id bigint;
  generated_code text;
  collision_exists boolean;
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

  loop
    generated_code := lpad(floor(random() * 1000000)::int::text, 6, '0');
    select exists(
      select 1 from attendance_codes
      where code = generated_code
      and expires_at > now()
    ) into collision_exists;
    exit when not collision_exists;
  end loop;

  insert into attendance_codes (meeting_id, code, created_by, expires_at)
  values (target_meeting_id, generated_code, auth.uid(), now() + interval '3 hours');

  return query select p_meeting_number, generated_code;
end;
$$ language plpgsql security definer;
