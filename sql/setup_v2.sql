-- 업무 TO-DO 개선·오류 접수 - 가입/로그인 방식으로 전환 (setup.sql 실행 후 이어서 한 번 실행)
-- 접수자 식별값(uid) = 로그인한 계정의 auth.uid(). 브라우저 식별값(x-uid)은 더 이상 쓰지 않는다.

-- 브라우저 식별값 기반 규칙 제거
drop policy if exists "feedback_anon_insert_own" on public.todo_feedback;
drop policy if exists "feedback_anon_select_own" on public.todo_feedback;
drop policy if exists "feedback_anon_delete_own" on public.todo_feedback;
drop policy if exists "feedback_admin_all" on public.todo_feedback;
drop function if exists public.request_uid();
revoke all on public.todo_feedback from anon;

-- 로그인 사용자: 자기 계정 행만 넣기/보기/지우기
create policy "feedback_user_insert_own" on public.todo_feedback
  for insert to authenticated with check (uid = auth.uid()::text);
create policy "feedback_user_select_own" on public.todo_feedback
  for select to authenticated using (uid = auth.uid()::text or public.is_feedback_admin());
create policy "feedback_user_delete_own" on public.todo_feedback
  for delete to authenticated using (uid = auth.uid()::text or public.is_feedback_admin());

grant select, insert, delete on public.todo_feedback to authenticated;
