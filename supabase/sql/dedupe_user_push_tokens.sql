-- Run once in Supabase SQL editor after deploying the app update.
-- Keeps one active token per exact FCM token and per user/platform pair.

with ranked_same_token as (
  select
    id,
    row_number() over (
      partition by token
      order by updated_at desc, created_at desc, id desc
    ) as row_number
  from public.user_push_tokens
  where is_active = true
)
update public.user_push_tokens tokens
set is_active = false
from ranked_same_token ranked
where tokens.id = ranked.id
  and ranked.row_number > 1;

with ranked_same_user_platform as (
  select
    id,
    row_number() over (
      partition by user_id, platform
      order by updated_at desc, created_at desc, id desc
    ) as row_number
  from public.user_push_tokens
  where is_active = true
)
update public.user_push_tokens tokens
set is_active = false
from ranked_same_user_platform ranked
where tokens.id = ranked.id
  and ranked.row_number > 1;

create unique index if not exists user_push_tokens_active_token_idx
  on public.user_push_tokens(token)
  where is_active = true;

create unique index if not exists user_push_tokens_active_user_platform_idx
  on public.user_push_tokens(user_id, platform)
  where is_active = true;

create or replace function public.claim_user_push_token(
  p_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required to claim a push token.'
      using errcode = '28000';
  end if;

  if nullif(trim(p_token), '') is null then
    raise exception 'Push token is required.'
      using errcode = '22023';
  end if;

  if nullif(trim(p_platform), '') is null then
    raise exception 'Push token platform is required.'
      using errcode = '22023';
  end if;

  update public.user_push_tokens
  set is_active = false
  where token = p_token
    and user_id <> v_user_id
    and is_active = true;

  update public.user_push_tokens
  set is_active = false
  where user_id = v_user_id
    and platform = p_platform
    and token <> p_token
    and is_active = true;

  insert into public.user_push_tokens (
    user_id,
    token,
    platform,
    is_active,
    updated_at
  )
  values (
    v_user_id,
    p_token,
    p_platform,
    true,
    now()
  )
  on conflict (user_id, token)
  do update set
    platform = excluded.platform,
    is_active = true,
    updated_at = now();
end;
$$;

grant execute on function public.claim_user_push_token(text, text)
  to authenticated;
