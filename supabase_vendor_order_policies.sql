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

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  audience text not null check (audience in ('customer', 'vendor')),
  title text not null,
  message text not null,
  type text not null default 'general',
  order_id uuid references public.orders(id) on delete cascade,
  metadata jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_recipient_created_at_idx
on public.notifications (recipient_id, created_at desc);

create index if not exists notifications_recipient_read_at_idx
on public.notifications (recipient_id, read_at);

create index if not exists notifications_order_id_idx
on public.notifications (order_id);

alter table public.notifications enable row level security;

create table if not exists public.order_stock_reservations (
  order_id uuid not null references public.orders(id) on delete cascade,
  product_variant_id uuid not null references public.product_variants(id) on delete cascade,
  quantity integer not null check (quantity > 0),
  reserved_at timestamptz not null default now(),
  released_at timestamptz,
  primary key (order_id, product_variant_id)
);

create index if not exists order_stock_reservations_released_at_idx
on public.order_stock_reservations (released_at);

alter table public.order_stock_reservations enable row level security;

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

create or replace function public.reserve_variant_stock(
  p_order_id uuid,
  p_product_variant_id uuid,
  p_quantity integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_stock integer;
  changed_count integer;
begin
  if p_quantity <= 0 then
    return;
  end if;

  select stock_quantity
    into current_stock
  from public.product_variants
  where id = p_product_variant_id
  for update;

  if current_stock is null then
    raise exception 'Product variant % was not found', p_product_variant_id;
  end if;

  if current_stock < p_quantity then
    raise exception 'Not enough stock for product variant %', p_product_variant_id;
  end if;

  insert into public.order_stock_reservations (
    order_id,
    product_variant_id,
    quantity
  )
  values (p_order_id, p_product_variant_id, p_quantity)
  on conflict (order_id, product_variant_id)
  do update set
    quantity = public.order_stock_reservations.quantity + excluded.quantity,
    released_at = null
  where public.order_stock_reservations.released_at is null;

  get diagnostics changed_count = row_count;
  if changed_count = 0 then
    raise exception 'Stock for order % was already released', p_order_id;
  end if;

  update public.product_variants
  set stock_quantity = stock_quantity - p_quantity
  where id = p_product_variant_id;
end;
$$;

create or replace function public.reserve_order_stock(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  item record;
  already_reserved integer;
  quantity_to_reserve integer;
begin
  for item in
    select product_variant_id, sum(quantity)::integer as quantity
    from public.order_items
    where order_id = p_order_id
      and product_variant_id is not null
    group by product_variant_id
  loop
    select coalesce(quantity, 0)
      into already_reserved
    from public.order_stock_reservations
    where order_id = p_order_id
      and product_variant_id = item.product_variant_id
      and released_at is null
    for update;

    quantity_to_reserve = item.quantity - coalesce(already_reserved, 0);
    if quantity_to_reserve > 0 then
      perform public.reserve_variant_stock(
        p_order_id,
        item.product_variant_id,
        quantity_to_reserve
      );
    end if;
  end loop;
end;
$$;

create or replace function public.restore_order_stock(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  reservation record;
begin
  for reservation in
    select product_variant_id, quantity
    from public.order_stock_reservations
    where order_id = p_order_id
      and released_at is null
    for update
  loop
    update public.product_variants
    set stock_quantity = stock_quantity + reservation.quantity
    where id = reservation.product_variant_id;
  end loop;

  update public.order_stock_reservations
  set released_at = now()
  where order_id = p_order_id
    and released_at is null;
end;
$$;

create or replace function public.reserve_stock_for_order_item()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  order_status text;
begin
  select status into order_status
  from public.orders
  where id = new.order_id;

  if new.product_variant_id is not null and
     order_status in ('pending', 'confirmed', 'confirm') then
    perform public.reserve_variant_stock(
      new.order_id,
      new.product_variant_id,
      new.quantity
    );
  end if;

  return new;
end;
$$;

drop trigger if exists order_items_stock_reservation_trigger on public.order_items;
create trigger order_items_stock_reservation_trigger
after insert on public.order_items
for each row execute function public.reserve_stock_for_order_item();

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

    if new.status in ('cancel', 'canceled', 'cancelled') and
       old.status not in ('cancel', 'canceled', 'cancelled', 'refund', 'refunded') then
      perform public.restore_order_stock(new.id);
    end if;
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

drop policy if exists "Users can view their notifications" on public.notifications;
create policy "Users can view their notifications"
on public.notifications
for select
to authenticated
using (recipient_id = auth.uid());

drop policy if exists "Users can mark their notifications read" on public.notifications;
create policy "Users can mark their notifications read"
on public.notifications
for update
to authenticated
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

drop policy if exists "Authenticated users can create notifications" on public.notifications;
create policy "Authenticated users can create notifications"
on public.notifications
for insert
to authenticated
with check (actor_id = auth.uid() or actor_id is null);

-- Optional hardening: uncomment these if vendors should only update status
-- columns from the client, not every column covered by the update policies.
--
-- revoke update on public.orders from authenticated;
-- grant update (status) on public.orders to authenticated;
--
-- revoke update on public.payments from authenticated;
-- grant update (status) on public.payments to authenticated;
