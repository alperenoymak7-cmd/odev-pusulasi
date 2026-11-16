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
