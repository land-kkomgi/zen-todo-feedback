-- 업무 TO-DO 개선·오류 접수 - 처리 상태(접수/완료) + 댓글 (setup_v2.sql 이후 한 번 실행)

-- 1) 처리 상태: new(확인 대기, 보낸 직후) → acked(접수, 관리자가 확인) → done(완료). 관리자만 바꿀 수 있다.
alter table public.todo_feedback add column if not exists state text not null default 'new';
alter table public.todo_feedback drop constraint if exists todo_feedback_state_check;
alter table public.todo_feedback add constraint todo_feedback_state_check check (state in ('new','acked','done'));
alter table public.todo_feedback add column if not exists acked_at timestamptz;
alter table public.todo_feedback add column if not exists done_at timestamptz;

drop policy if exists "feedback_admin_update" on public.todo_feedback;
create policy "feedback_admin_update" on public.todo_feedback
  for update to authenticated using (public.is_feedback_admin()) with check (public.is_feedback_admin());
grant update on public.todo_feedback to authenticated;

-- 2) 댓글: 담당자와 접수자(본인 건)만 달 수 있고, 같은 사람들만 볼 수 있다.
create table if not exists public.todo_feedback_comment (
  id           uuid primary key default gen_random_uuid(),
  feedback_id  uuid not null references public.todo_feedback(id) on delete cascade,
  uid          text not null,
  author       text not null check (char_length(author) between 1 and 40),
  body         text not null check (char_length(body) between 1 and 2000),
  is_admin     boolean not null default false,
  created_at   timestamptz not null default now()
);
alter table public.todo_feedback_comment enable row level security;

drop policy if exists "comment_select" on public.todo_feedback_comment;
drop policy if exists "comment_insert" on public.todo_feedback_comment;
drop policy if exists "comment_delete" on public.todo_feedback_comment;

create policy "comment_select" on public.todo_feedback_comment
  for select to authenticated
  using (public.is_feedback_admin()
         or exists (select 1 from public.todo_feedback f where f.id = feedback_id and f.uid = auth.uid()::text));

create policy "comment_insert" on public.todo_feedback_comment
  for insert to authenticated
  with check (uid = auth.uid()::text
              and is_admin = public.is_feedback_admin()
              and (public.is_feedback_admin()
                   or exists (select 1 from public.todo_feedback f where f.id = feedback_id and f.uid = auth.uid()::text)));

create policy "comment_delete" on public.todo_feedback_comment
  for delete to authenticated using (uid = auth.uid()::text or public.is_feedback_admin());

grant select, insert, delete on public.todo_feedback_comment to authenticated;
create index if not exists todo_feedback_comment_fid_idx on public.todo_feedback_comment (feedback_id, created_at);
