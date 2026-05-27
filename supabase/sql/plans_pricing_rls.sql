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

alter table public.plans enable row level security;
alter table public.admin_payment_methods enable row level security;
alter table public.vendor_plan_orders enable row level security;
alter table public.vendor_plan_history enable row level security;

grant select on public.plans to anon, authenticated;
grant select on public.admin_payment_methods to authenticated;
grant select, insert on public.vendor_plan_orders to authenticated;
grant select, insert on public.vendor_plan_history to authenticated;
grant select, update on public.vendors to authenticated;
grant select, update on public.products to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'plans'
      and policyname = 'Anyone can view active plans'
  ) then
    create policy "Anyone can view active plans"
    on public.plans
    for select
    to anon, authenticated
    using (is_active = true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'plans'
      and policyname = 'Admins can manage plans'
  ) then
    create policy "Admins can manage plans"
    on public.plans
    for all
    to authenticated
    using (public.is_admin())
    with check (public.is_admin());
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'admin_payment_methods'
      and policyname = 'Vendors can view active admin payment methods'
  ) then
    create policy "Vendors can view active admin payment methods"
    on public.admin_payment_methods
    for select
    to authenticated
    using (
      is_active = true
      or public.is_admin()
    );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'admin_payment_methods'
      and policyname = 'Admins can manage admin payment methods'
  ) then
    create policy "Admins can manage admin payment methods"
    on public.admin_payment_methods
    for all
    to authenticated
    using (public.is_admin())
    with check (public.is_admin());
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'vendor_plan_orders'
      and policyname = 'Vendors can create their own plan orders'
  ) then
    create policy "Vendors can create their own plan orders"
    on public.vendor_plan_orders
    for insert
    to authenticated
    with check (
      exists (
        select 1
        from public.vendors
        where vendors.id = vendor_plan_orders.vendor_id
          and vendors.user_id = auth.uid()
      )
    );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'vendor_plan_orders'
      and policyname = 'Vendors can view their own plan orders'
  ) then
    create policy "Vendors can view their own plan orders"
    on public.vendor_plan_orders
    for select
    to authenticated
    using (
      public.is_admin()
      or exists (
        select 1
        from public.vendors
        where vendors.id = vendor_plan_orders.vendor_id
          and vendors.user_id = auth.uid()
      )
    );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'vendor_plan_orders'
      and policyname = 'Admins can update plan orders'
  ) then
    create policy "Admins can update plan orders"
    on public.vendor_plan_orders
    for update
    to authenticated
    using (public.is_admin())
    with check (public.is_admin());
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'vendor_plan_history'
      and policyname = 'Vendors can view their own plan history'
  ) then
    create policy "Vendors can view their own plan history"
    on public.vendor_plan_history
    for select
    to authenticated
    using (
      public.is_admin()
      or exists (
        select 1
        from public.vendors
        where vendors.id = vendor_plan_history.vendor_id
          and vendors.user_id = auth.uid()
      )
    );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'vendor_plan_history'
      and policyname = 'Admins can create plan history'
  ) then
    create policy "Admins can create plan history"
    on public.vendor_plan_history
    for insert
    to authenticated
    with check (public.is_admin());
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'vendors'
      and policyname = 'Vendors can view their own vendor profile'
  ) then
    create policy "Vendors can view their own vendor profile"
    on public.vendors
    for select
    to authenticated
    using (
      user_id = auth.uid()
      or public.is_admin()
    );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'vendors'
      and policyname = 'Vendors can update their own vendor profile'
  ) then
    create policy "Vendors can update their own vendor profile"
    on public.vendors
    for update
    to authenticated
    using (
      user_id = auth.uid()
      or public.is_admin()
    )
    with check (
      user_id = auth.uid()
      or public.is_admin()
    );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'products'
      and policyname = 'Vendors and admins can update vendor products'
  ) then
    create policy "Vendors and admins can update vendor products"
    on public.products
    for update
    to authenticated
    using (
      public.is_admin()
      or exists (
        select 1
        from public.brands
        where brands.id = products.brand_id
          and brands.owner_id = auth.uid()
      )
    )
    with check (
      public.is_admin()
      or exists (
        select 1
        from public.brands
        where brands.id = products.brand_id
          and brands.owner_id = auth.uid()
      )
    );
  end if;
end;
$$;
