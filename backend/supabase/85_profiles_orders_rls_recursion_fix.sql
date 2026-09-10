-- =============================================================================
-- 85_profiles_orders_rls_recursion_fix.sql
-- Break profiles <-> orders RLS recursion (HTTP 500 / 42P17).
--
-- Cycle:
--   profiles "Providers can read customer names for orders" → SELECT orders
--   orders   "Providers can read open pending orders"     → SELECT profiles
--
-- Symptom: admin login gate (SELECT own profiles row) returns 500
--   "infinite recursion detected in policy for relation profiles"
--   and the admin app shows the generic patch-17 Arabic error.
--
-- Fix: is_provider() SECURITY DEFINER (same pattern as is_admin in patch 17)
-- so the orders policy does not read profiles under RLS.
-- Safe to re-run. Does not weaken admin checks.
-- =============================================================================

create or replace function public.is_provider()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'provider'
  );
$$;

revoke all on function public.is_provider() from public;
grant execute on function public.is_provider() to authenticated;

drop policy if exists "Providers can read open pending orders" on public.orders;
create policy "Providers can read open pending orders"
  on public.orders
  for select
  to authenticated
  using (
    provider_id is null
    and lower(trim(status)) in ('pending', 'new', 'cancelled', 'canceled')
    and public.is_provider()
  );

notify pgrst, 'reload schema';
