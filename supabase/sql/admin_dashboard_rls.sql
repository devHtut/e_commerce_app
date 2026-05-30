create or replace function public.is_admin(user_id uuid default auth.uid())
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = user_id
      and lower(coalesce(user_type, '')) = 'admin'
  );
$$;

grant execute on function public.is_admin(uuid) to authenticated;

alter table public.users enable row level security;
alter table public.brands enable row level security;
alter table public.vendors enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.reports enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.product_views enable row level security;
alter table public.product_reviews enable row level security;
alter table public.plans enable row level security;
alter table public.admin_payment_methods enable row level security;
alter table public.vendor_plan_orders enable row level security;
alter table public.vendor_plan_history enable row level security;

grant select on public.users to authenticated;
grant select on public.brands to authenticated;
grant select on public.vendors to authenticated;
grant select on public.orders to authenticated;
grant select on public.order_items to authenticated;
grant select, update on public.reports to authenticated;
grant select on public.products to authenticated;
grant select on public.product_variants to authenticated;
grant select on public.product_views to authenticated;
grant select on public.product_reviews to authenticated;
grant select on public.product_review_summary to authenticated;
grant select, insert, update on public.plans to authenticated;
grant select, insert, update on public.admin_payment_methods to authenticated;
grant select, update on public.vendor_plan_orders to authenticated;
grant insert on public.vendor_plan_history to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'Admins can view users'
  ) then
    create policy "Admins can view users"
    on public.users
    for select
    to authenticated
    using (public.is_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'brands'
      and policyname = 'Admins can view brands'
  ) then
    create policy "Admins can view brands"
    on public.brands
    for select
    to authenticated
    using (public.is_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'vendors'
      and policyname = 'Admins can view vendors'
  ) then
    create policy "Admins can view vendors"
    on public.vendors
    for select
    to authenticated
    using (public.is_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'orders'
      and policyname = 'Admins can view orders'
  ) then
    create policy "Admins can view orders"
    on public.orders
    for select
    to authenticated
    using (public.is_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'order_items'
      and policyname = 'Admins can view order items'
  ) then
    create policy "Admins can view order items"
    on public.order_items
    for select
    to authenticated
    using (public.is_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'reports'
      and policyname = 'Admins can view reports'
  ) then
    create policy "Admins can view reports"
    on public.reports
    for select
    to authenticated
    using (public.is_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'reports'
      and policyname = 'Admins can update reports'
  ) then
    create policy "Admins can update reports"
    on public.reports
    for update
    to authenticated
    using (public.is_admin())
    with check (public.is_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'products'
      and policyname = 'Admins can view products'
  ) then
    create policy "Admins can view products"
    on public.products
    for select
    to authenticated
    using (public.is_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'product_variants'
      and policyname = 'Admins can view product variants'
  ) then
    create policy "Admins can view product variants"
    on public.product_variants
    for select
    to authenticated
    using (public.is_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'product_views'
      and policyname = 'Admins can view product views'
  ) then
    create policy "Admins can view product views"
    on public.product_views
    for select
    to authenticated
    using (public.is_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'product_reviews'
      and policyname = 'Admins can view product reviews'
  ) then
    create policy "Admins can view product reviews"
    on public.product_reviews
    for select
    to authenticated
    using (public.is_admin());
  end if;
end;
$$;
