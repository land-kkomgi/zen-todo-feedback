-- 업무 TO-DO 개선·오류 접수 - Supabase 설정 SQL
-- Supabase 대시보드 > SQL Editor 에 전체를 붙여 넣고 Run 한 번.
-- 관리자 이메일은 아래 is_feedback_admin() 안의 주소 하나로 판정한다.

create table if not exists public.todo_feedback (
  id          uuid primary key default gen_random_uuid(),
  uid         text not null,                                   -- 접수자 브라우저 식별값(임의 UUID)
  menu        text not null check (menu in ('GWS200100','GWS200110','GWS200120','GWS200130','GWS200140','COMMON')),
  kind        text not null check (kind in ('bug','imp','ask')),
  priority    text not null default 'mid' check (priority in ('high','mid','low')),
  title       text not null check (char_length(title) between 2 and 120),
  body        text not null check (char_length(body) between 5 and 5000),
  reporter    text not null check (char_length(reporter) between 1 and 40),
  image       text check (image is null or (left(image, 23) = 'data:image/jpeg;base64,' and length(image) <= 200000)),
  created_at  timestamptz not null default now()
);

alter table public.todo_feedback enable row level security;

-- 요청 헤더 x-uid (화면이 보내는 접수자 식별값)
create or replace function public.request_uid() returns text
language sql stable as $$
  select nullif(current_setting('request.headers', true)::json ->> 'x-uid', '')
$$;

-- 관리자 판정: 로그인한 계정의 이메일이 아래 주소일 때만
create or replace function public.is_feedback_admin() returns boolean
language sql stable as $$
  select coalesce(auth.jwt() ->> 'email', '') = 'chaeeun@newzen.kr'
$$;

-- 접수자(비로그인): 자기 uid 행만 넣기/보기/지우기
create policy "feedback_anon_insert_own" on public.todo_feedback
  for insert to anon with check (uid = public.request_uid());
create policy "feedback_anon_select_own" on public.todo_feedback
  for select to anon using (uid = public.request_uid());
create policy "feedback_anon_delete_own" on public.todo_feedback
  for delete to anon using (uid = public.request_uid());

-- 관리자(로그인): 전체 보기/지우기
create policy "feedback_admin_all" on public.todo_feedback
  for all to authenticated using (public.is_feedback_admin()) with check (public.is_feedback_admin());

grant select, insert, delete on public.todo_feedback to anon, authenticated;

create index if not exists todo_feedback_uid_idx on public.todo_feedback (uid);
create index if not exists todo_feedback_created_idx on public.todo_feedback (created_at desc);
