create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  report_type text not null check (report_type in ('product', 'chat')),
  product_id uuid references public.products(id) on delete set null,
  chat_id uuid references public.chats(id) on delete set null,
  reason text not null,
  details text,
  status text not null default 'open' check (
    status in ('open', 'reviewing', 'resolved', 'dismissed')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reports_target_check check (
    (
      report_type = 'product'
      and product_id is not null
      and chat_id is null
    )
    or (
      report_type = 'chat'
      and chat_id is not null
      and product_id is null
    )
  )
);

create index if not exists reports_reporter_id_idx
  on public.reports (reporter_id);

create index if not exists reports_product_id_idx
  on public.reports (product_id)
  where product_id is not null;

create index if not exists reports_chat_id_idx
  on public.reports (chat_id)
  where chat_id is not null;

create index if not exists reports_status_created_at_idx
  on public.reports (status, created_at desc);

create or replace function public.set_reports_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_reports_updated_at on public.reports;
create trigger set_reports_updated_at
before update on public.reports
for each row
execute function public.set_reports_updated_at();

alter table public.reports enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'reports'
      and policyname = 'Customers can create their own reports'
  ) then
    create policy "Customers can create their own reports"
    on public.reports
    for insert
    to authenticated
    with check (
      reporter_id = auth.uid()
      and (
        report_type = 'product'
        or exists (
          select 1
          from public.chat_members
          where chat_members.chat_id = reports.chat_id
            and chat_members.user_id = auth.uid()
        )
      )
    );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'reports'
      and policyname = 'Customers can view their own reports'
  ) then
    create policy "Customers can view their own reports"
    on public.reports
    for select
    to authenticated
    using (reporter_id = auth.uid());
  end if;
end;
$$;
