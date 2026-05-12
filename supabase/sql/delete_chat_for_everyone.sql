create or replace function public.delete_chat_for_everyone(target_chat_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.chat_members
    where chat_id = target_chat_id
      and user_id = auth.uid()
  ) then
    raise exception 'Not allowed to delete this chat' using errcode = '42501';
  end if;

  delete from public.message_reactions reactions
  using public.messages messages
  where reactions.message_id = messages.id
    and messages.chat_id = target_chat_id;

  delete from public.messages
  where chat_id = target_chat_id;

  delete from public.chat_members
  where chat_id = target_chat_id;

  delete from public.chats
  where id = target_chat_id;
end;
$$;

revoke all on function public.delete_chat_for_everyone(uuid) from public;
grant execute on function public.delete_chat_for_everyone(uuid) to authenticated;

create or replace function public.delete_chat_for_me(target_chat_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  select public.delete_chat_for_everyone(target_chat_id);
$$;

revoke all on function public.delete_chat_for_me(uuid) from public;
grant execute on function public.delete_chat_for_me(uuid) to authenticated;
