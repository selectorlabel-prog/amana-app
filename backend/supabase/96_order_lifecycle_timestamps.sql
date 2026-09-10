-- =============================================================================
-- 96_order_lifecycle_timestamps.sql
-- Canonical full file (columns + trigger + RPCs + admin list):
--   amana_app/supabase/96_order_lifecycle_timestamps.sql
-- This copy is the column/trigger portion only.
-- Applied remotely. Safe to re-run.
-- =============================================================================

alter table public.orders
  add column if not exists on_the_way_at timestamptz,
  add column if not exists arrived_at timestamptz,
  add column if not exists started_at timestamptz,
  add column if not exists work_done_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists cancelled_at timestamptz;

comment on column public.orders.on_the_way_at is
  'When status first became on_the_way.';
comment on column public.orders.arrived_at is
  'When status first became arrived.';
comment on column public.orders.started_at is
  'When status first became in_progress.';
comment on column public.orders.work_done_at is
  'When provider marked work done (awaiting_customer_confirm / work_done).';
comment on column public.orders.completed_at is
  'When status first became completed / paid.';
comment on column public.orders.cancelled_at is
  'When status first became cancelled.';

-- ---------------------------------------------------------------------------
-- Stamp on any status change (Dart direct write + RPCs + cancel paths)
-- ---------------------------------------------------------------------------
create or replace function public.orders_stamp_lifecycle_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new text := lower(trim(coalesce(new.status, '')));
  v_old text := lower(trim(coalesce(old.status, '')));
begin
  if v_new = v_old then
    return new;
  end if;

  if v_new = 'on_the_way' then
    new.on_the_way_at := coalesce(new.on_the_way_at, now());
  elsif v_new = 'arrived' then
    new.arrived_at := coalesce(new.arrived_at, now());
  elsif v_new = 'in_progress' then
    new.started_at := coalesce(new.started_at, now());
  elsif v_new in ('awaiting_customer_confirm', 'work_done') then
    new.work_done_at := coalesce(new.work_done_at, now());
  elsif v_new in ('completed', 'paid') then
    new.completed_at := coalesce(new.completed_at, now());
  elsif v_new in ('cancelled', 'canceled') then
    new.cancelled_at := coalesce(new.cancelled_at, now());
  end if;

  return new;
end;
$$;

drop trigger if exists trg_orders_stamp_lifecycle_at on public.orders;

create trigger trg_orders_stamp_lifecycle_at
  before update of status on public.orders
  for each row
  execute function public.orders_stamp_lifecycle_at();

comment on function public.orders_stamp_lifecycle_at() is
  'Sets lifecycle timestamptz columns on first status transition; never overwrites.';
