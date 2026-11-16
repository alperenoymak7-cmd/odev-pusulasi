-- English Time: secure, read-only administrator access.
-- Run in the Supabase SQL Editor. Then add an authorized admin email and
-- a long random code using the private setup statement in ADMIN-KURULUM.md.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table if not exists private.admin_allowlist (
  email text primary key,
  code_hash text not null,
  created_at timestamptz not null default now()
);
create table if not exists private.admin_sessions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  expires_at timestamptz not null
);
create table if not exists private.admin_code_attempts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  attempt_count integer not null default 0,
  window_started_at timestamptz not null default now(),
  locked_until timestamptz
);
alter table private.admin_allowlist enable row level security;
alter table private.admin_sessions enable row level security;
alter table private.admin_code_attempts enable row level security;
revoke all on all tables in schema private from public, anon, authenticated;

create or replace function private.has_valid_admin_session()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from private.admin_sessions s
    where s.user_id = (select auth.uid()) and s.expires_at > now()
  );
$$;
revoke all on function private.has_valid_admin_session() from public, anon, authenticated;
grant execute on function private.has_valid_admin_session() to authenticated;

create or replace function public.verify_admin_code(p_code text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_hash text;
  v_attempt private.admin_code_attempts%rowtype;
  v_has_attempt boolean := false;

begin
  if v_uid is null then return false; end if;
  select lower(email) into v_email from auth.users where id = v_uid;
  select * into v_attempt from private.admin_code_attempts where user_id = v_uid for update;
  v_has_attempt := found;
  if v_has_attempt and v_attempt.locked_until > now() then return false; end if;
  select a.code_hash into v_hash from private.admin_allowlist a where a.email = v_email;
  if v_hash is not null and coalesce(length(p_code),0) >= 12
     and extensions.crypt(p_code, v_hash) = v_hash then
    insert into private.admin_sessions(user_id, expires_at)
      values(v_uid, now() + interval '8 hours')
      on conflict(user_id) do update set expires_at = excluded.expires_at;
    delete from private.admin_code_attempts where user_id = v_uid;
    return true;
  end if;
  if not v_has_attempt or v_attempt.window_started_at < now() - interval '15 minutes' then
    insert into private.admin_code_attempts(user_id, attempt_count, window_started_at, locked_until)
      values(v_uid,1,now(),null)
      on conflict(user_id) do update set attempt_count=1,window_started_at=now(),locked_until=null;
  else
    update private.admin_code_attempts set attempt_count=attempt_count+1,
      locked_until=case when attempt_count+1 >= 5 then now()+interval '15 minutes' else locked_until end
      where user_id=v_uid;
  end if;
  return false;
end;
$$;

create or replace function public.has_admin_access()
returns boolean language sql stable security definer set search_path = '' as $$
  select private.has_valid_admin_session();
$$;
create or replace function public.revoke_admin_access()
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return false; end if;
  delete from private.admin_sessions where user_id = auth.uid();
  return true;
end;
$$;
revoke all on function public.verify_admin_code(text) from public, anon;
revoke all on function public.has_admin_access() from public, anon;
revoke all on function public.revoke_admin_access() from public, anon;
grant execute on function public.verify_admin_code(text) to authenticated;
grant execute on function public.has_admin_access() to authenticated;
grant execute on function public.revoke_admin_access() to authenticated;

drop policy if exists "Admin reads all teacher profiles" on public.teacher_profiles;
create policy "Admin reads all teacher profiles" on public.teacher_profiles for select to authenticated
  using ((select private.has_valid_admin_session()));
drop policy if exists "Admin reads all classrooms" on public.classrooms;
create policy "Admin reads all classrooms" on public.classrooms for select to authenticated
  using ((select private.has_valid_admin_session()));
drop policy if exists "Admin reads all students" on public.students;
create policy "Admin reads all students" on public.students for select to authenticated
  using ((select private.has_valid_admin_session()));
drop policy if exists "Admin reads all assignments" on public.assignments;
create policy "Admin reads all assignments" on public.assignments for select to authenticated
  using ((select private.has_valid_admin_session()));
drop policy if exists "Admin reads all responses" on public.responses;
create policy "Admin reads all responses" on public.responses for select to authenticated
  using ((select private.has_valid_admin_session()));
