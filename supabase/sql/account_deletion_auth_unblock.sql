do $$
declare
  constraint_record record;
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'orders'
      and column_name = 'customer_id'
  ) then
    alter table public.orders alter column customer_id drop not null;

    for constraint_record in
      select conname
      from pg_constraint
      where conrelid = 'public.orders'::regclass
        and contype = 'f'
        and pg_get_constraintdef(oid) like '%customer_id%'
        and pg_get_constraintdef(oid) like '%auth.users%'
    loop
      execute format(
        'alter table public.orders drop constraint if exists %I',
        constraint_record.conname
      );
    end loop;

    alter table public.orders
      add constraint orders_customer_id_fkey
      foreign key (customer_id)
      references auth.users(id)
      on delete set null;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'product_reviews'
      and column_name = 'customer_id'
  ) then
    alter table public.product_reviews alter column customer_id drop not null;

    for constraint_record in
      select conname
      from pg_constraint
      where conrelid = 'public.product_reviews'::regclass
        and contype = 'f'
        and pg_get_constraintdef(oid) like '%customer_id%'
        and pg_get_constraintdef(oid) like '%auth.users%'
    loop
      execute format(
        'alter table public.product_reviews drop constraint if exists %I',
        constraint_record.conname
      );
    end loop;

    alter table public.product_reviews
      add constraint product_reviews_customer_id_fkey
      foreign key (customer_id)
      references auth.users(id)
      on delete set null;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'messages'
      and column_name = 'sender_id'
  ) then
    alter table public.messages alter column sender_id drop not null;

    for constraint_record in
      select conname
      from pg_constraint
      where conrelid = 'public.messages'::regclass
        and contype = 'f'
        and pg_get_constraintdef(oid) like '%sender_id%'
        and pg_get_constraintdef(oid) like '%auth.users%'
    loop
      execute format(
        'alter table public.messages drop constraint if exists %I',
        constraint_record.conname
      );
    end loop;

    alter table public.messages
      add constraint messages_sender_id_fkey
      foreign key (sender_id)
      references auth.users(id)
      on delete set null;
  end if;
end;
$$;
