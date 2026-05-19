create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_push_tokens enable row level security;

create index if not exists user_push_tokens_user_id_idx
  on public.user_push_tokens(user_id);

create unique index if not exists user_push_tokens_user_id_token_idx
  on public.user_push_tokens(user_id, token);

create or replace function public.set_user_push_tokens_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_user_push_tokens_updated_at
  on public.user_push_tokens;

create trigger set_user_push_tokens_updated_at
  before update on public.user_push_tokens
  for each row
  execute function public.set_user_push_tokens_updated_at();

drop policy if exists "Users can read their own push tokens"
  on public.user_push_tokens;

create policy "Users can read their own push tokens"
  on public.user_push_tokens
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own push tokens"
  on public.user_push_tokens;

create policy "Users can insert their own push tokens"
  on public.user_push_tokens
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own push tokens"
  on public.user_push_tokens;

create policy "Users can update their own push tokens"
  on public.user_push_tokens
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own push tokens"
  on public.user_push_tokens;

create policy "Users can delete their own push tokens"
  on public.user_push_tokens
  for delete
  to authenticated
  using (auth.uid() = user_id);
