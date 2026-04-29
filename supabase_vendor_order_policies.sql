-- Vendor access policies for order visibility and status/payment updates.
-- Assumes:
--   brands.id is referenced by order_items.brand_id
--   brands.owner_id stores the vendor auth.users.id
--   orders.id is referenced by order_items.order_id and payments.order_id

alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.user_addresses enable row level security;
alter table public.profiles enable row level security;

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  status text not null,
  changed_at timestamptz not null default now(),
  changed_by uuid references auth.users(id)
);

create index if not exists order_status_history_order_id_changed_at_idx
on public.order_status_history (order_id, changed_at desc);

create index if not exists order_status_history_status_changed_at_idx
on public.order_status_history (status, changed_at desc);

alter table public.order_status_history enable row level security;

create or replace function public.vendor_owns_order(p_order_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.order_items oi
    join public.brands b on b.id = oi.brand_id
    where oi.order_id = p_order_id
      and b.owner_id = auth.uid()
  );
$$;

create or replace function public.record_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.order_status_history (order_id, status, changed_by)
    values (new.id, new.status, auth.uid());
    return new;
  end if;

  if new.status is distinct from old.status then
    insert into public.order_status_history (order_id, status, changed_by)
    values (new.id, new.status, auth.uid());
  end if;

  return new;
end;
$$;

drop trigger if exists orders_status_history_trigger on public.orders;
create trigger orders_status_history_trigger
after insert or update of status on public.orders
for each row execute function public.record_order_status_change();

create or replace function public.complete_overdue_in_delivery_orders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count integer;
begin
  update public.orders o
  set status = 'completed'
  where o.status in ('in-delivery', 'in_delivery', 'in delivery')
    and coalesce(
      (
        select max(h.changed_at)
        from public.order_status_history h
        where h.order_id = o.id
          and h.status in ('in-delivery', 'in_delivery', 'in delivery')
      ),
      o.created_at
    ) <= now() - interval '10 days';

  get diagnostics updated_count = row_count;
  return updated_count;
end;
$$;

-- Optional Supabase cron schedule, if pg_cron is enabled:
-- select cron.schedule(
--   'complete-overdue-in-delivery-orders',
--   '0 * * * *',
--   $$select public.complete_overdue_in_delivery_orders();$$
-- );

insert into public.order_status_history (order_id, status, changed_at, changed_by)
select o.id, o.status, coalesce(o.created_at, now()), o.customer_id
from public.orders o
where not exists (
  select 1
  from public.order_status_history h
  where h.order_id = o.id
);

drop policy if exists "Vendors can view orders for their brands" on public.orders;
create policy "Vendors can view orders for their brands"
on public.orders
for select
to authenticated
using (public.vendor_owns_order(id));

drop policy if exists "Vendors can update orders for their brands" on public.orders;
create policy "Vendors can update orders for their brands"
on public.orders
for update
to authenticated
using (public.vendor_owns_order(id))
with check (public.vendor_owns_order(id));

drop policy if exists "Vendors can view order items for their brands" on public.order_items;
create policy "Vendors can view order items for their brands"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.brands b
    where b.id = order_items.brand_id
      and b.owner_id = auth.uid()
  )
);

drop policy if exists "Vendors can update order items for their brands" on public.order_items;
create policy "Vendors can update order items for their brands"
on public.order_items
for update
to authenticated
using (
  exists (
    select 1
    from public.brands b
    where b.id = order_items.brand_id
      and b.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.brands b
    where b.id = order_items.brand_id
      and b.owner_id = auth.uid()
  )
);

drop policy if exists "Vendors can view payments for their brand orders" on public.payments;
create policy "Vendors can view payments for their brand orders"
on public.payments
for select
to authenticated
using (public.vendor_owns_order(order_id));

drop policy if exists "Customers can view payments for their orders" on public.payments;
create policy "Customers can view payments for their orders"
on public.payments
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = payments.order_id
      and o.customer_id = auth.uid()
  )
);

drop policy if exists "Vendors can update payments for their brand orders" on public.payments;
create policy "Vendors can update payments for their brand orders"
on public.payments
for update
to authenticated
using (public.vendor_owns_order(order_id))
with check (public.vendor_owns_order(order_id));

drop policy if exists "Vendors can view addresses for their brand orders" on public.user_addresses;
create policy "Vendors can view addresses for their brand orders"
on public.user_addresses
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.shipping_address_id = user_addresses.id
      and public.vendor_owns_order(o.id)
  )
);

drop policy if exists "Vendors can view profiles for their brand orders" on public.profiles;
create policy "Vendors can view profiles for their brand orders"
on public.profiles
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.customer_id = profiles.id
      and public.vendor_owns_order(o.id)
  )
);

drop policy if exists "Vendors can view status history for their brand orders" on public.order_status_history;
create policy "Vendors can view status history for their brand orders"
on public.order_status_history
for select
to authenticated
using (public.vendor_owns_order(order_id));

drop policy if exists "Customers can view status history for their orders" on public.order_status_history;
create policy "Customers can view status history for their orders"
on public.order_status_history
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_status_history.order_id
      and o.customer_id = auth.uid()
  )
);

-- Optional hardening: uncomment these if vendors should only update status
-- columns from the client, not every column covered by the update policies.
--
-- revoke update on public.orders from authenticated;
-- grant update (status) on public.orders to authenticated;
--
-- revoke update on public.payments from authenticated;
-- grant update (status) on public.payments to authenticated;
