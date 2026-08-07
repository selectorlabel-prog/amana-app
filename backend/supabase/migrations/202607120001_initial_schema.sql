-- Amana milestone 1: central PostgreSQL schema.
-- Supabase Auth issues and verifies JWTs; application roles live in profiles.

create extension if not exists "pgcrypto";

create type public.app_role as enum ('customer', 'provider', 'admin');
create type public.order_status as enum (
  'draft', 'open', 'offered', 'accepted', 'in_progress',
  'completed', 'cancelled', 'disputed'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null default 'customer',
  full_name text not null default '',
  phone text,
  city text,
  district text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.provider_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  bio text not null default '',
  verified boolean not null default false,
  rating numeric(3,2) not null default 0 check (rating between 0 and 5),
  wallet_balance numeric(14,2) not null default 0 check (wallet_balance >= 0)
);

create table public.service_categories (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null,
  icon_key text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.services (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.provider_profiles(user_id) on delete cascade,
  category_id uuid not null references public.service_categories(id),
  title_ar text not null,
  description_ar text not null default '',
  base_price numeric(14,2) check (base_price is null or base_price >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id),
  provider_id uuid references public.provider_profiles(user_id),
  category_id uuid not null references public.service_categories(id),
  status public.order_status not null default 'draft',
  description text not null,
  city text not null,
  district text,
  agreed_price numeric(14,2) check (agreed_price is null or agreed_price >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.offers (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  provider_id uuid not null references public.provider_profiles(user_id),
  price numeric(14,2) not null check (price > 0),
  message text not null default '',
  created_at timestamptz not null default now(),
  unique (order_id, provider_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  body text not null check (length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create table public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.provider_profiles(user_id),
  order_id uuid references public.orders(id),
  amount numeric(14,2) not null check (amount <> 0),
  kind text not null check (kind in ('credit', 'commission', 'refund', 'adjustment')),
  created_at timestamptz not null default now()
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  customer_id uuid not null references public.profiles(id),
  provider_id uuid not null references public.provider_profiles(user_id),
  rating smallint not null check (rating between 1 and 5),
  comment text not null default '',
  created_at timestamptz not null default now()
);

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id),
  opened_by uuid not null references public.profiles(id),
  reason text not null,
  status text not null default 'open'
    check (status in ('open', 'reviewing', 'resolved', 'rejected')),
  resolution text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index orders_customer_idx on public.orders(customer_id, created_at desc);
create index orders_provider_idx on public.orders(provider_id, created_at desc);
create index messages_order_idx on public.messages(order_id, created_at);
create index offers_order_idx on public.offers(order_id, created_at);
create index notifications_user_idx
  on public.notifications(user_id, created_at desc);

create function public.current_role()
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.phone
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.provider_profiles enable row level security;
alter table public.service_categories enable row level security;
alter table public.services enable row level security;
alter table public.orders enable row level security;
alter table public.offers enable row level security;
alter table public.messages enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.reviews enable row level security;
alter table public.disputes enable row level security;
alter table public.notifications enable row level security;

-- Prevent a user from promoting their own JWT-backed application role.
revoke update on public.profiles from authenticated;
grant update (full_name, phone, city, district, updated_at)
  on public.profiles to authenticated;
revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

create policy "users and admins read profiles"
  on public.profiles for select to authenticated
  using (id = auth.uid() or public.current_role() = 'admin');
create policy "users update own profile"
  on public.profiles for update to authenticated using (id = auth.uid());

create policy "provider profiles are public to signed-in users"
  on public.provider_profiles for select to authenticated using (true);
create policy "providers update own profile"
  on public.provider_profiles for update to authenticated
  using (user_id = auth.uid() and public.current_role() = 'provider');

create policy "active categories are readable"
  on public.service_categories for select to authenticated using (active);
create policy "admins manage categories"
  on public.service_categories for all to authenticated
  using (public.current_role() = 'admin')
  with check (public.current_role() = 'admin');

create policy "active services are readable"
  on public.services for select to authenticated using (active);
create policy "providers manage own services"
  on public.services for all to authenticated
  using (provider_id = auth.uid())
  with check (provider_id = auth.uid() and public.current_role() = 'provider');

create policy "participants and admins read orders"
  on public.orders for select to authenticated
  using (
    customer_id = auth.uid()
    or provider_id = auth.uid()
    or public.current_role() = 'admin'
    or (status = 'open' and public.current_role() = 'provider')
  );
create policy "customers create own orders"
  on public.orders for insert to authenticated
  with check (customer_id = auth.uid() and public.current_role() = 'customer');
create policy "admins update orders until server workflows exist"
  on public.orders for update to authenticated
  using (public.current_role() = 'admin')
  with check (public.current_role() = 'admin');

create policy "order participants read offers"
  on public.offers for select to authenticated
  using (
    provider_id = auth.uid()
    or exists (
      select 1 from public.orders o
      where o.id = order_id and o.customer_id = auth.uid()
    )
    or public.current_role() = 'admin'
  );
create policy "providers create own offers"
  on public.offers for insert to authenticated
  with check (
    provider_id = auth.uid()
    and public.current_role() = 'provider'
    and exists (
      select 1 from public.orders o
      where o.id = order_id and o.status = 'open'
    )
  );

create policy "order participants read messages"
  on public.messages for select to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.customer_id = auth.uid() or o.provider_id = auth.uid())
    )
    or public.current_role() = 'admin'
  );
create policy "order participants send messages"
  on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.customer_id = auth.uid() or o.provider_id = auth.uid())
    )
  );

create policy "providers read own wallet"
  on public.wallet_transactions for select to authenticated
  using (provider_id = auth.uid() or public.current_role() = 'admin');

create policy "reviews readable by signed-in users"
  on public.reviews for select to authenticated using (true);
create policy "customers review completed own order"
  on public.reviews for insert to authenticated
  with check (
    customer_id = auth.uid()
    and exists (
      select 1 from public.orders o
      where o.id = order_id
        and o.customer_id = auth.uid()
        and o.provider_id = provider_id
        and o.status = 'completed'
    )
  );

create policy "dispute participants and admins read disputes"
  on public.disputes for select to authenticated
  using (
    opened_by = auth.uid()
    or public.current_role() = 'admin'
    or exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.customer_id = auth.uid() or o.provider_id = auth.uid())
    )
  );
create policy "participants create disputes"
  on public.disputes for insert to authenticated
  with check (
    opened_by = auth.uid()
    and exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.customer_id = auth.uid() or o.provider_id = auth.uid())
    )
  );
create policy "admins resolve disputes"
  on public.disputes for update to authenticated
  using (public.current_role() = 'admin')
  with check (public.current_role() = 'admin');

create policy "users read own notifications"
  on public.notifications for select to authenticated
  using (user_id = auth.uid() or public.current_role() = 'admin');
create policy "users mark own notifications read"
  on public.notifications for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Messages and order state changes are available through Supabase Realtime.
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.orders;
