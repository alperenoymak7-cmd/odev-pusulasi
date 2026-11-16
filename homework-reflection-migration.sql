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
