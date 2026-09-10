-- =============================================================================
-- 65_admin_dashboard_live_metrics.sql
-- Admin main dashboard: honest KPIs + daily series + realtime freshness.
-- - pending_verification = unverified providers WITH uploaded documents
--   (same predicate as fetchPendingVerificationProviders)
-- - dispute_like_orders = support_open on non-terminal orders only
-- - services_active = approved + active + not hidden (NULL status is not approved)
-- - admin_dashboard_series(p_days) for 7d/30d chart
-- - realtime: provider_services, admin_inbox, profiles, verification_documents
-- Does NOT delete rows. Does NOT mix identity queue with service reviews.
-- Safe to re-run. Prerequisites: 35, 57, 64.
-- =============================================================================

do $$
begin
  if to_regprocedure('public.is_admin()') is null then
    raise exception 'public.is_admin() missing — run 17_admin_role_patch.sql first';
  end if;
  if to_regclass('public.orders') is null then
    raise exception 'public.orders missing';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) Dashboard KPI aggregates
-- ---------------------------------------------------------------------------
create or replace function public.admin_dashboard_stats()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_active int;
  v_pending int;
  v_negotiating int;
  v_completed int;
  v_cancelled int;
  v_revenue numeric;
  v_customers int;
  v_providers int;
  v_verified_providers int;
  v_pending_verification int;
  v_suspended int;
  v_total_users int;
  v_support_open int;
  v_reviews int;
  v_avg_rating numeric;
  v_commission_earned numeric;
  v_services_active int;
  v_new_providers_30d int;
  v_pending_service_reviews int;
  v_unread_admin_inbox int;
begin
  if not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;

  select
    count(*) filter (
      where lower(coalesce(status, '')) not in (
        'completed', 'paid', 'cancelled', 'canceled'
      )
    ),
    count(*) filter (
      where lower(coalesce(status, '')) in ('pending', 'new')
    ),
    count(*) filter (
      where lower(coalesce(status, '')) in (
        'offer_sent', 'provider_proposed', 'customer_proposed', 'negotiating'
      )
    ),
    count(*) filter (
      where lower(coalesce(status, '')) in ('completed', 'paid')
    ),
    count(*) filter (
      where lower(coalesce(status, '')) in ('cancelled', 'canceled')
    ),
    coalesce(sum(price) filter (
      where lower(coalesce(status, '')) in ('completed', 'paid')
    ), 0),
    -- Open support that is actually open (exclude terminal orders).
    count(*) filter (
      where coalesce(support_open, false) = true
        and lower(coalesce(status, '')) not in (
          'completed', 'paid', 'cancelled', 'canceled'
        )
    )
  into
    v_active, v_pending, v_negotiating, v_completed, v_cancelled,
    v_revenue, v_support_open
  from public.orders;

  select
    count(*) filter (where p.role = 'customer'),
    count(*) filter (where p.role = 'provider'),
    count(*) filter (
      where p.role = 'provider' and coalesce(p.is_verified, false)
    ),
    count(*) filter (
      where p.role = 'provider'
        and not coalesce(p.is_verified, false)
        and exists (
          select 1
          from public.verification_documents d
          where d.user_id = p.id
        )
    ),
    count(*) filter (where coalesce(p.is_suspended, false)),
    count(*) filter (where p.role in ('customer', 'provider')),
    count(*) filter (
      where p.role = 'provider'
        and p.created_at >= (now() - interval '30 days')
    )
  into
    v_customers, v_providers, v_verified_providers, v_pending_verification,
    v_suspended, v_total_users, v_new_providers_30d
  from public.profiles p;

  select count(*), round(avg(rating)::numeric, 2)
  into v_reviews, v_avg_rating
  from public.reviews
  where coalesce(is_hidden, false) = false;

  select coalesce(sum(abs(amount)), 0)
  into v_commission_earned
  from public.wallet_transactions
  where lower(coalesce(type, '')) = 'commission';

  -- Match customer-visible list: approved only. NULL is not approved.
  select count(*)
  into v_services_active
  from public.provider_services
  where coalesce(is_active, true) = true
    and coalesce(admin_hidden, false) = false
    and verification_status = 'approved';

  -- Match admin_list_service_reviews('pending'): all pending rows.
  select count(*)
  into v_pending_service_reviews
  from public.provider_services
  where verification_status = 'pending';

  select count(*)
  into v_unread_admin_inbox
  from public.admin_inbox
  where is_read = false;

  return json_build_object(
    'active_orders', coalesce(v_active, 0),
    'pending_accept', coalesce(v_pending, 0),
    'negotiating', coalesce(v_negotiating, 0),
    'completed_orders', coalesce(v_completed, 0),
    'cancelled_orders', coalesce(v_cancelled, 0),
    'total_revenue', coalesce(v_revenue, 0),
    'customers', coalesce(v_customers, 0),
    'providers', coalesce(v_providers, 0),
    'verified_providers', coalesce(v_verified_providers, 0),
    'pending_verification', coalesce(v_pending_verification, 0),
    'pending_service_reviews', coalesce(v_pending_service_reviews, 0),
    'unread_admin_inbox', coalesce(v_unread_admin_inbox, 0),
    'suspended_users', coalesce(v_suspended, 0),
    'total_users', coalesce(v_total_users, 0),
    'dispute_like_orders', coalesce(v_support_open, 0),
    'new_providers', coalesce(v_new_providers_30d, 0),
    'reviews_count', coalesce(v_reviews, 0),
    'avg_rating', coalesce(v_avg_rating, 0),
    'commission_earned', coalesce(v_commission_earned, 0),
    'services_active', coalesce(v_services_active, 0)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2) Daily series for 7d / 30d chart (Africa/Khartoum calendar days)
-- ---------------------------------------------------------------------------
create or replace function public.admin_dashboard_series(p_days int default 30)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_days int;
  v_end date;
  v_start date;
begin
  if not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;

  v_days := greatest(1, least(coalesce(p_days, 30), 90));
  v_end := (current_timestamp at time zone 'Africa/Khartoum')::date;
  v_start := v_end - (v_days - 1);

  return coalesce((
    select json_agg(
      json_build_object(
        'day', to_char(g.day, 'YYYY-MM-DD'),
        'orders_count', coalesce(x.orders_count, 0),
        'revenue', coalesce(x.revenue, 0)
      )
      order by g.day
    )
    from generate_series(v_start, v_end, interval '1 day') as s(ts)
    cross join lateral (select s.ts::date as day) g
    left join (
      select
        (o.created_at at time zone 'Africa/Khartoum')::date as day,
        count(*)::int as orders_count,
        coalesce(sum(o.price) filter (
          where lower(coalesce(o.status, '')) in ('completed', 'paid')
        ), 0) as revenue
      from public.orders o
      where (o.created_at at time zone 'Africa/Khartoum')::date
            between v_start and v_end
      group by 1
    ) x on x.day = g.day
  ), '[]'::json);
end;
$$;

revoke all on function public.admin_dashboard_stats() from public;
revoke all on function public.admin_dashboard_stats() from anon;
grant execute on function public.admin_dashboard_stats() to authenticated;

revoke all on function public.admin_dashboard_series(int) from public;
revoke all on function public.admin_dashboard_series(int) from anon;
grant execute on function public.admin_dashboard_series(int) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Realtime publication so dashboard KPIs refresh beyond `orders`
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.provider_services') is not null then
    execute 'alter table public.provider_services replica identity full';
  end if;
  if to_regclass('public.admin_inbox') is not null then
    execute 'alter table public.admin_inbox replica identity full';
  end if;
  if to_regclass('public.profiles') is not null then
    execute 'alter table public.profiles replica identity full';
  end if;
  if to_regclass('public.verification_documents') is not null then
    execute 'alter table public.verification_documents replica identity full';
  end if;
end $$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'provider_services',
    'admin_inbox',
    'profiles',
    'verification_documents'
  ]
  loop
    if to_regclass('public.' || t) is null then
      continue;
    end if;
    begin
      execute format(
        'alter publication supabase_realtime add table public.%I',
        t
      );
    exception
      when duplicate_object then null;
      when undefined_object then
        raise notice 'supabase_realtime missing — skip %', t;
    end;
  end loop;
end $$;

select '65_admin_dashboard_live_metrics.sql applied' as status;
