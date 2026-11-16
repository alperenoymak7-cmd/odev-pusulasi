-- Ödev Pusulası: güvenli başlangıç şeması
-- Supabase SQL Editor'de bir kez çalıştırın.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.teacher_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.classrooms (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references auth.users(id) on delete cascade,
  grade text not null,
  branch text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  display_name text not null,
  access_token_hash text unique,
  created_at timestamptz not null default now()
);

create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms(id) on delete cascade,
  title text not null,
  description text not null default '',
  week_start date not null,
  due_date date,
  is_open boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.responses (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  status text not null check (status in ('done','no','partial','confused')),
  comment text not null default '' check (char_length(comment) <= 1000),
  updated_at timestamptz not null default now(),
  unique (assignment_id, student_id)
);

create index if not exists classrooms_teacher_idx on public.classrooms(teacher_id);
create index if not exists students_classroom_idx on public.students(classroom_id);
create index if not exists assignments_classroom_week_idx on public.assignments(classroom_id, week_start desc);
create index if not exists responses_assignment_idx on public.responses(assignment_id);

-- Yeni öğretmen hesabı açıldığında özel profil kaydı oluştur.
create or replace function public.create_teacher_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.teacher_profiles (user_id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''))
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_teacher_profile on auth.users;
create trigger on_auth_user_created_teacher_profile
  after insert on auth.users
  for each row execute function public.create_teacher_profile();

alter table public.teacher_profiles enable row level security;
alter table public.classrooms enable row level security;
alter table public.students enable row level security;
alter table public.assignments enable row level security;
alter table public.responses enable row level security;

create policy "Teacher reads own profile" on public.teacher_profiles
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Teacher edits own profile" on public.teacher_profiles
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "Teacher manages own classrooms" on public.classrooms
  for all to authenticated using (teacher_id = (select auth.uid()))
  with check (teacher_id = (select auth.uid()));

create policy "Teacher manages students in own classrooms" on public.students
  for all to authenticated
  using (exists (select 1 from public.classrooms c where c.id = classroom_id and c.teacher_id = (select auth.uid())))
  with check (exists (select 1 from public.classrooms c where c.id = classroom_id and c.teacher_id = (select auth.uid())));

create policy "Teacher manages assignments in own classrooms" on public.assignments
  for all to authenticated
  using (exists (select 1 from public.classrooms c where c.id = classroom_id and c.teacher_id = (select auth.uid())))
  with check (exists (select 1 from public.classrooms c where c.id = classroom_id and c.teacher_id = (select auth.uid())));

create policy "Teacher reads responses in own classrooms" on public.responses
  for select to authenticated
  using (exists (
    select 1 from public.assignments a
    join public.classrooms c on c.id = a.classroom_id
    where a.id = assignment_id and c.teacher_id = (select auth.uid())
  ));

-- Öğrenci bağlantısı taşıyan gizli, rastgele anahtarı yeniler.
-- Önceki bağlantı yenileme anında geçersiz olur.
create or replace function public.create_student_access_link(p_student_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token text;
begin
  if auth.uid() is null then raise exception 'Öğretmen girişi gerekli'; end if;
  if not exists (
    select 1 from public.students s
    join public.classrooms c on c.id = s.classroom_id
    where s.id = p_student_id and c.teacher_id = auth.uid()
  ) then raise exception 'Bu öğrenciye erişim yetkiniz yok'; end if;
  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  update public.students
  set access_token_hash = encode(extensions.digest(v_token, 'sha256'), 'hex')
  where id = p_student_id;
  return v_token;
end;
$$;

-- Öğrenci bağlantısı sadece o öğrencinin adını, sınıfını, açık ödevlerini
-- ve kendi mevcut yanıtlarını döndürür. Roster veya başka öğrenciler dönmez.
create or replace function public.get_student_portal(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_id uuid;
  v_result jsonb;
begin
  if p_token is null or char_length(p_token) < 40 then raise exception 'Bağlantı geçersiz'; end if;
  select s.id into v_student_id
  from public.students s
  where s.access_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
  if v_student_id is null then raise exception 'Bağlantı geçersiz veya yenilenmiş'; end if;

  select jsonb_build_object(
    'student', jsonb_build_object('id', s.id, 'name', s.display_name),
    'classroom', jsonb_build_object('grade', c.grade, 'branch', c.branch),
    'assignments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'title', a.title, 'description', a.description,
        'week_start', a.week_start, 'due_date', a.due_date,
        'response_status', r.status, 'comment', r.comment
      ) order by a.week_start desc, a.created_at desc)
      from public.assignments a
      left join public.responses r on r.assignment_id = a.id and r.student_id = s.id
      where a.classroom_id = c.id and a.is_open = true
    ), '[]'::jsonb)
  ) into v_result
  from public.students s
  join public.classrooms c on c.id = s.classroom_id
  where s.id = v_student_id;
  return v_result;
end;
$$;

-- Öğrenci sadece linkindeki kimlik adına, kendi sınıfındaki açık ödeve yanıt verir.
create or replace function public.submit_student_response(
  p_token text,
  p_assignment_id uuid,
  p_status text,
  p_comment text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_id uuid;
begin
  if p_token is null or char_length(p_token) < 40 then raise exception 'Bağlantı geçersiz'; end if;
  if p_status not in ('done','no','partial','confused') then raise exception 'Yanıt seçimi geçersiz'; end if;
  if char_length(coalesce(p_comment,'')) > 1000 then raise exception 'Yorum en fazla 1000 karakter olabilir'; end if;
  select s.id into v_student_id from public.students s
  where s.access_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
  if v_student_id is null then raise exception 'Bağlantı geçersiz veya yenilenmiş'; end if;
  if not exists (
    select 1 from public.assignments a
    join public.students s on s.classroom_id = a.classroom_id
    where a.id = p_assignment_id and s.id = v_student_id and a.is_open = true
  ) then raise exception 'Bu ödeve yanıt verme yetkiniz yok'; end if;

  insert into public.responses (assignment_id, student_id, status, comment, updated_at)
  values (p_assignment_id, v_student_id, p_status,
    case when p_status = 'confused' then btrim(coalesce(p_comment,'')) else '' end,
    now())
  on conflict (assignment_id, student_id) do update
    set status = excluded.status, comment = excluded.comment, updated_at = now();
  return jsonb_build_object('saved', true);
end;
$$;

revoke all on function public.create_student_access_link(uuid) from public, anon;
revoke all on function public.get_student_portal(text) from public;
revoke all on function public.submit_student_response(text, uuid, text, text) from public;
grant execute on function public.create_student_access_link(uuid) to authenticated;
grant execute on function public.get_student_portal(text) to anon, authenticated;
grant execute on function public.submit_student_response(text, uuid, text, text) to anon, authenticated;

-- Browser istemcisi only gets table access protected by RLS.
grant select, insert, update, delete on public.teacher_profiles to authenticated;
grant select, insert, update, delete on public.classrooms to authenticated;
grant select, insert, update, delete on public.students to authenticated;
grant select, insert, update, delete on public.assignments to authenticated;
grant select on public.responses to authenticated;
revoke all on public.teacher_profiles, public.classrooms, public.students, public.assignments, public.responses from anon;



-- Student username/password login for existing Odev Pusulasi projects.
-- Run once in Supabase SQL Editor after deploying the matching website files.

alter table public.students add column if not exists username text;
create unique index if not exists students_username_lower_unique
  on public.students (lower(username)) where username is not null;

create table if not exists public.student_credentials (
  student_id uuid primary key references public.students(id) on delete cascade,
  password_hash text not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.student_sessions (
  token_hash text primary key,
  student_id uuid not null references public.students(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists student_sessions_student_idx on public.student_sessions(student_id);
create index if not exists student_sessions_expiry_idx on public.student_sessions(expires_at);

alter table public.student_credentials enable row level security;
alter table public.student_sessions enable row level security;
revoke all on public.student_credentials, public.student_sessions from public, anon, authenticated;

create or replace function public.set_student_credentials(
  p_student_id uuid,
  p_username text,
  p_password text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_username text := lower(btrim(coalesce(p_username, '')));
begin
  if auth.uid() is null then raise exception 'Öğretmen girişi gerekli'; end if;
  if char_length(v_username) < 3 or char_length(v_username) > 32
     or v_username !~ '^[a-z0-9._-]+$' then
    raise exception 'Kullanıcı adı 3-32 karakter olmalı; yalnızca İngilizce harf, sayı, nokta, tire veya alt çizgi kullan.';
  end if;
  if char_length(coalesce(p_password, '')) < 8 or octet_length(p_password) > 72 then
    raise exception 'Şifre 8-72 karakter arasında olmalı.';
  end if;
  if not exists (
    select 1 from public.students s
    join public.classrooms c on c.id = s.classroom_id
    where s.id = p_student_id and c.teacher_id = auth.uid()
  ) then raise exception 'Bu öğrenciye erişim yetkiniz yok'; end if;

  begin
    update public.students set username = v_username where id = p_student_id;
    insert into public.student_credentials(student_id, password_hash, updated_at)
      values (p_student_id, extensions.crypt(p_password, extensions.gen_salt('bf', 12)), now())
      on conflict (student_id) do update
        set password_hash = excluded.password_hash, updated_at = now();
    delete from public.student_sessions where student_id = p_student_id;
  exception when unique_violation then
    raise exception 'Bu kullanıcı adı kullanımda. Başka bir kullanıcı adı seç.';
  end;
  return v_username;
end;
$$;

create or replace function public.student_login(p_username text, p_password text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_id uuid;
  v_token text;
begin
  if char_length(coalesce(p_username, '')) < 3 or char_length(p_username) > 32
     or char_length(coalesce(p_password, '')) < 8 or octet_length(p_password) > 72 then
    raise exception 'Kullanıcı adı veya şifre hatalı.';
  end if;

  select s.id into v_student_id
  from public.students s
  join public.student_credentials c on c.student_id = s.id
  where lower(s.username) = lower(btrim(p_username))
    and extensions.crypt(p_password, c.password_hash) = c.password_hash;
  if v_student_id is null then raise exception 'Kullanıcı adı veya şifre hatalı.'; end if;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  delete from public.student_sessions where expires_at <= now();
  insert into public.student_sessions(token_hash, student_id, expires_at)
    values (encode(extensions.digest(v_token, 'sha256'), 'hex'), v_student_id, now() + interval '30 days');
  return v_token;
end;
$$;

create or replace function public.student_logout(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_token is not null and char_length(p_token) >= 40 then
    delete from public.student_sessions
    where token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
  end if;
  return jsonb_build_object('signed_out', true);
end;
$$;

create or replace function public.get_student_portal(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_id uuid;
  v_result jsonb;
begin
  if p_token is null or char_length(p_token) < 40 then raise exception 'Bağlantı geçersiz'; end if;
  select s.id into v_student_id from public.students s
  where s.access_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
  if v_student_id is null then
    select ss.student_id into v_student_id from public.student_sessions ss
    where ss.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex') and ss.expires_at > now();
  end if;
  if v_student_id is null then raise exception 'Bağlantı veya oturum geçersiz ya da süresi dolmuş'; end if;

  select jsonb_build_object(
    'student', jsonb_build_object('id', s.id, 'name', s.display_name),
    'classroom', jsonb_build_object('grade', c.grade, 'branch', c.branch),
    'assignments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'title', a.title, 'description', a.description,
        'week_start', a.week_start, 'due_date', a.due_date,
        'response_status', r.status, 'comment', r.comment
      ) order by a.week_start desc, a.created_at desc)
      from public.assignments a
      left join public.responses r on r.assignment_id = a.id and r.student_id = s.id
      where a.classroom_id = c.id and a.is_open = true
    ), '[]'::jsonb)
  ) into v_result
  from public.students s
  join public.classrooms c on c.id = s.classroom_id
  where s.id = v_student_id;
  return v_result;
end;
$$;

create or replace function public.submit_student_response(
  p_token text,
  p_assignment_id uuid,
  p_status text,
  p_comment text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_id uuid;
begin
  if p_token is null or char_length(p_token) < 40 then raise exception 'Bağlantı geçersiz'; end if;
  if p_status not in ('done','no','partial','confused') then raise exception 'Yanıt seçimi geçersiz'; end if;
  if char_length(coalesce(p_comment,'')) > 1000 then raise exception 'Yorum en fazla 1000 karakter olabilir'; end if;
  select s.id into v_student_id from public.students s
  where s.access_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
  if v_student_id is null then
    select ss.student_id into v_student_id from public.student_sessions ss
    where ss.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex') and ss.expires_at > now();
  end if;
  if v_student_id is null then raise exception 'Bağlantı veya oturum geçersiz ya da süresi dolmuş'; end if;
  if not exists (
    select 1 from public.assignments a
    join public.students s on s.classroom_id = a.classroom_id
    where a.id = p_assignment_id and s.id = v_student_id and a.is_open = true
  ) then raise exception 'Bu ödeve yanıt verme yetkiniz yok'; end if;

  insert into public.responses (assignment_id, student_id, status, comment, updated_at)
  values (p_assignment_id, v_student_id, p_status,
    case when p_status = 'confused' then btrim(coalesce(p_comment,'')) else '' end,
    now())
  on conflict (assignment_id, student_id) do update
    set status = excluded.status, comment = excluded.comment, updated_at = now();
  return jsonb_build_object('saved', true);
end;
$$;

revoke all on function public.set_student_credentials(uuid, text, text) from public, anon;
revoke all on function public.student_login(text, text) from public;
revoke all on function public.student_logout(text) from public;
revoke all on function public.get_student_portal(text) from public;
revoke all on function public.submit_student_response(text, uuid, text, text) from public;
grant execute on function public.set_student_credentials(uuid, text, text) to authenticated;
grant execute on function public.student_login(text, text) to anon, authenticated;
grant execute on function public.student_logout(text) to anon, authenticated;
grant execute on function public.get_student_portal(text) to anon, authenticated;
grant execute on function public.submit_student_response(text, uuid, text, text) to anon, authenticated;


-- Homework vocabulary and reflection fields.
-- Add required vocabulary and topic reflection to student homework responses.
alter table public.responses add column if not exists word_one text not null default '';
alter table public.responses add column if not exists word_two text not null default '';
alter table public.responses add column if not exists reflection text not null default '';

create or replace function public.get_student_portal(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_id uuid;
  v_result jsonb;
begin
  if p_token is null or char_length(p_token) < 40 then raise exception 'Bağlantı geçersiz'; end if;
  select s.id into v_student_id from public.students s
  where s.access_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
  if v_student_id is null then
    select ss.student_id into v_student_id from public.student_sessions ss
    where ss.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex') and ss.expires_at > now();
  end if;
  if v_student_id is null then raise exception 'Bağlantı veya oturum geçersiz ya da süresi dolmuş'; end if;
  select jsonb_build_object(
    'student', jsonb_build_object('id', s.id, 'name', s.display_name),
    'classroom', jsonb_build_object('grade', c.grade, 'branch', c.branch),
    'assignments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'title', a.title, 'description', a.description,
        'week_start', a.week_start, 'due_date', a.due_date,
        'response_status', r.status, 'comment', r.comment,
        'word_one', r.word_one, 'word_two', r.word_two, 'reflection', r.reflection
      ) order by a.week_start desc, a.created_at desc)
      from public.assignments a
      left join public.responses r on r.assignment_id = a.id and r.student_id = s.id
      where a.classroom_id = c.id and a.is_open = true
    ), '[]'::jsonb)
  ) into v_result
  from public.students s join public.classrooms c on c.id = s.classroom_id
  where s.id = v_student_id;
  return v_result;
end;
$$;

drop function if exists public.submit_student_response(text, uuid, text, text);
create function public.submit_student_response(
  p_token text,
  p_assignment_id uuid,
  p_status text,
  p_word_one text,
  p_word_two text,
  p_reflection text,
  p_comment text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_id uuid;
begin
  if p_token is null or char_length(p_token) < 40 then raise exception 'Bağlantı geçersiz'; end if;
  if p_status not in ('done','no','partial','confused') then raise exception 'Yanıt seçimi geçersiz'; end if;
  if char_length(btrim(coalesce(p_word_one,''))) < 1 or char_length(btrim(coalesce(p_word_two,''))) < 1 then raise exception 'İki yeni kelime de gereklidir'; end if;
  if char_length(coalesce(p_word_one,'')) > 80 or char_length(coalesce(p_word_two,'')) > 80 then raise exception 'Yeni kelimeler en fazla 80 karakter olabilir'; end if;
  if char_length(btrim(coalesce(p_reflection,''))) < 1 then raise exception 'Konu yorumu gereklidir'; end if;
  if char_length(coalesce(p_reflection,'')) > 1000 or char_length(coalesce(p_comment,'')) > 1000 then raise exception 'Yorumlar en fazla 1000 karakter olabilir'; end if;
  select s.id into v_student_id from public.students s
  where s.access_token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
  if v_student_id is null then
    select ss.student_id into v_student_id from public.student_sessions ss
    where ss.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex') and ss.expires_at > now();
  end if;
  if v_student_id is null then raise exception 'Bağlantı veya oturum geçersiz ya da süresi dolmuş'; end if;
  if not exists (
    select 1 from public.assignments a join public.students s on s.classroom_id = a.classroom_id
    where a.id = p_assignment_id and s.id = v_student_id and a.is_open = true
  ) then raise exception 'Bu ödeve yanıt verme yetkiniz yok'; end if;
  insert into public.responses (assignment_id, student_id, status, comment, word_one, word_two, reflection, updated_at)
  values (p_assignment_id, v_student_id, p_status, btrim(coalesce(p_comment,'')),
          btrim(p_word_one), btrim(p_word_two), btrim(p_reflection), now())
  on conflict (assignment_id, student_id) do update
    set status=excluded.status, comment=excluded.comment, word_one=excluded.word_one,
        word_two=excluded.word_two, reflection=excluded.reflection, updated_at=now();
  return jsonb_build_object('saved', true);
end;
$$;
revoke all on function public.submit_student_response(text, uuid, text, text, text, text, text) from public;
grant execute on function public.submit_student_response(text, uuid, text, text, text, text, text) to anon, authenticated;

-- Allow teachers to record a homework status directly for their own students.
create or replace function public.teacher_set_response_status(
  p_assignment_id uuid,
  p_student_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Öğretmen girişi gerekli'; end if;
  if p_status not in ('done','no','partial','confused') then raise exception 'Durum seçimi geçersiz'; end if;
  if not exists (
    select 1 from public.assignments a
    join public.classrooms c on c.id=a.classroom_id
    join public.students s on s.classroom_id=c.id
    where a.id=p_assignment_id and s.id=p_student_id and c.teacher_id=auth.uid()
  ) then raise exception 'Bu öğrenci ve ödev için erişim yetkiniz yok'; end if;
  insert into public.responses(assignment_id,student_id,status,updated_at)
  values(p_assignment_id,p_student_id,p_status,now())
  on conflict(assignment_id,student_id) do update
    set status=excluded.status,updated_at=now();
  return jsonb_build_object('saved',true);
end;
$$;
revoke all on function public.teacher_set_response_status(uuid,uuid,text) from public, anon;
grant execute on function public.teacher_set_response_status(uuid,uuid,text) to authenticated;

