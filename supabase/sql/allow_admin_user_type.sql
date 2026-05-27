alter table public.users
drop constraint if exists users_user_type_check;

alter table public.users
add constraint users_user_type_check
check (user_type in ('customer', 'vendor', 'admin'));
