-- @buik.net mailiyle kayıt olanlar otomatik 'mezun' rolüyle başlar,
-- diğer tüm kayıtlar (kişisel mail) varsayılan 'member' olarak kalır.
-- Koordinatör/board rolleri hâlâ elle (admin tarafından) atanır, bu trigger'ı etkilemez.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, role)
  values (
    new.id,
    new.email,
    case when new.email ilike '%@buik.net' then 'mezun' else 'member' end
  );
  return new;
end;
$$ language plpgsql security definer;
