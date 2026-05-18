create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  email text,
  user_type text not null default 'customer',
  status text not null default 'pending'
    check (status in ('pending', 'completed', 'blocked', 'failed')),
  reason text,
  failure_reason text,
  requested_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists account_deletion_requests_user_id_idx
  on public.account_deletion_requests (user_id);

create index if not exists account_deletion_requests_status_idx
  on public.account_deletion_requests (status);

alter table public.account_deletion_requests enable row level security;

drop policy if exists "Users can create own deletion request"
  on public.account_deletion_requests;
create policy "Users can create own deletion request"
  on public.account_deletion_requests
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can view own deletion request"
  on public.account_deletion_requests;
create policy "Users can view own deletion request"
  on public.account_deletion_requests
  for select
  to authenticated
  using (auth.uid() = user_id);
