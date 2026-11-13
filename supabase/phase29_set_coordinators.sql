-- Örnek: koordinatör listesi (gerçek mailler kaldırıldı) 'coordinator' rolüne yükseltilir.
update profiles
set role = 'coordinator'
where email in (
  'coordinator1@example.com',
  'coordinator2@example.com',
  'coordinator3@example.com',
  'coordinator4@example.com',
  'coordinator5@example.com',
  'coordinator6@example.com',
  'coordinator7@example.com',
  'coordinator8@example.com',
  'coordinator9@example.com',
  'coordinator10@example.com',
  'coordinator11@example.com',
  'coordinator12@example.com',
  'coordinator13@example.com',
  'coordinator14@example.com',
  'coordinator15@example.com',
  'coordinator16@example.com',
  'coordinator17@example.com',
  'coordinator18@example.com',
  'coordinator19@example.com',
  'coordinator20@example.com',
  'coordinator21@example.com',
  'coordinator22@example.com',
  'coordinator23@example.com',
  'coordinator24@example.com'
);
