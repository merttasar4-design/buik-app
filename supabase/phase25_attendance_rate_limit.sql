-- Yoklama kodu brute-force koruması: check_in_with_code 6 haneli sayısal
-- kod kullanıyor (1M kombinasyon) ve öncesinde deneme sınırı yoktu — bir
-- script 3 saatlik geçerlilik penceresinde tüm kodları deneyip fiziksel
-- katılım olmadan yoklamaya işlenebilirdi. Kullanıcı başına dakikada 5
-- denemeyle sınırlandırıyoruz (1M kodu taramak artık ~140 gün sürer).

create table if not exists attendance_code_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  attempted_at timestamptz not null default now()
);

alter table attendance_code_attempts enable row level security;
-- Bu tabloya yalnızca aşağıdaki security definer fonksiyon yazar/okur;
-- kullanıcılar için doğrudan erişim policy'si tanımlanmadı.

create index if not exists attendance_code_attempts_user_time_idx
  on attendance_code_attempts (user_id, attempted_at desc);

drop function if exists public.check_in_with_code(text);
create or replace function public.check_in_with_code(input_code text)
returns table(checked_meeting_id bigint, checked_committee_name text, checked_meeting_number int) as $$
declare
  matched_meeting_id bigint;
  matched_committee_name text;
  matched_meeting_number int;
  recent_attempts int;
begin
  select count(*) into recent_attempts
  from attendance_code_attempts
  where user_id = auth.uid()
    and attempted_at > now() - interval '1 minute';

  if recent_attempts >= 5 then
    raise exception 'too_many_attempts';
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
    raise exception 'invalid_code';
  end if;

  insert into attendance_records (meeting_id, user_id)
  values (matched_meeting_id, auth.uid())
  on conflict (meeting_id, user_id) do nothing;

  delete from attendance_code_attempts
  where attempted_at < now() - interval '1 day';

  return query select matched_meeting_id, matched_committee_name, matched_meeting_number;
end;
$$ language plpgsql security definer;
