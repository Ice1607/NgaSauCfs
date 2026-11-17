-- MIGRATION: TẮT / BẬT BÌNH LUẬN CHO BÀI VIẾT
-- Chạy một lần trong Supabase > SQL Editor.
-- Bình luận cũ được giữ nguyên; chỉ chặn bình luận mới khi comments_enabled = false.

alter table public.confessions
  add column if not exists comments_enabled boolean not null default true;

create or replace function public.reject_comment_when_disabled()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.confessions c
    where c.id = new.confession_id
      and c.status = 'approved'
      and c.comments_enabled = true
  ) then
    raise exception 'Quản trị viên đã vô hiệu hóa tính năng bình luận của bài viết này';
  end if;
  return new;
end;
$$;

drop trigger if exists comments_require_enabled_post on public.comments;
create trigger comments_require_enabled_post
before insert on public.comments
for each row execute function public.reject_comment_when_disabled();

drop policy if exists "signed users comment on approved posts" on public.comments;
create policy "signed users comment on approved posts"
on public.comments for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.confessions c
    where c.id = confession_id
      and c.status = 'approved'
      and c.comments_enabled = true
  )
  and (
    parent_id is null
    or exists (
      select 1 from public.comments parent
      where parent.id = parent_id
        and parent.confession_id = confession_id
    )
  )
);
