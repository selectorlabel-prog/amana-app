-- =============================================================================
-- 72_admin_orders_list_address.sql
-- Extend admin_list_orders_with_names with address / schedule / offer columns
-- already on public.orders (order_schedule_address). Admin receipt workspace.
-- No new tables. Safe to re-run. Arabic literals via UTF-8 hex (SQL 70).
-- =============================================================================

drop function if exists public.admin_list_orders_with_names(integer);

create function public.admin_list_orders_with_names(p_limit integer default 80)
returns table (
  id uuid,
  service_name text,
  status text,
  price numeric,
  notes text,
  support_open boolean,
  created_at timestamptz,
  customer_id uuid,
  provider_id uuid,
  customer_full_name text,
  provider_full_name text,
  price_confirmed_at timestamptz,
  service_lat double precision,
  service_lng double precision,
  tracking_active boolean,
  provider_lat double precision,
  provider_lng double precision,
  provider_updated_at timestamptz,
  service_address_text text,
  scheduled_at timestamptz,
  is_asap boolean,
  offer_price numeric,
  proposed_price numeric,
  offered_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_err_admin text := convert_from(decode('d984d984d985d8b4d8b1d981d98ad98620d981d982d8b7','hex'),'utf8');
begin
  if not public.is_admin() then
    raise exception '%', v_err_admin;
  end if;

  return query
  select
    o.id,
    o.service_name,
    o.status,
    o.price,
    o.notes,
    coalesce(o.support_open, false),
    o.created_at,
    o.customer_id,
    o.provider_id,
    nullif(trim(c.full_name), ''),
    nullif(trim(p.full_name), ''),
    o.price_confirmed_at,
    o.service_lat,
    o.service_lng,
    coalesce(t.tracking_active, false),
    t.provider_lat,
    t.provider_lng,
    t.provider_updated_at,
    nullif(trim(o.service_address_text), ''),
    o.scheduled_at,
    coalesce(o.is_asap, false),
    o.offer_price,
    o.proposed_price,
    o.offered_at
  from public.orders o
  left join public.profiles c on c.id = o.customer_id
  left join public.profiles p on p.id = o.provider_id
  left join public.order_live_locations t on t.order_id = o.id
  order by o.created_at desc
  limit greatest(1, least(coalesce(p_limit, 80), 200));
end;
$$;

grant execute on function public.admin_list_orders_with_names(integer) to authenticated;
grant execute on function public.admin_list_orders_with_names(integer) to anon;
grant execute on function public.admin_list_orders_with_names(integer) to service_role;

comment on function public.admin_list_orders_with_names(integer) is
  'Admin order list with names + address/schedule/offer fields (72).';
