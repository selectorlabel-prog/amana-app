-- =============================================================================
-- 71_provider_public_stats.sql
-- Public aggregate stats for the customer trust sheet (no PII, no reviews SELECT).
-- Fields mirror SQL 60 list_featured_providers rating + completed-order aggregates.
-- Safe to re-run. English comments only (UTF-8 hex lesson from SQL 70).
-- =============================================================================

drop function if exists public.get_provider_public_stats(uuid);

create function public.get_provider_public_stats(p_provider_id uuid)
returns table (
  avg_rating numeric,
  rating_count int,
  completed_orders int
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  select
    rv.avg_rating,
    coalesce(rv.rating_count, 0)::int as rating_count,
    coalesce(oc.completed_orders, 0)::int as completed_orders
  from (select p_provider_id as provider_id) x
  left join lateral (
    select
      round(avg(r.rating)::numeric, 1) as avg_rating,
      count(*)::int as rating_count
    from public.reviews r
    where p_provider_id is not null
      and r.provider_id = p_provider_id
      and coalesce(r.is_hidden, false) = false
  ) rv on true
  left join lateral (
    select
      count(*) filter (
        where lower(trim(coalesce(o.status, ''))) in ('completed', 'paid')
          and o.created_at >= now() - interval '90 days'
      )::int as completed_orders
    from public.orders o
    where p_provider_id is not null
      and o.provider_id = p_provider_id
  ) oc on true;
end;
$$;

revoke all on function public.get_provider_public_stats(uuid) from public;
revoke all on function public.get_provider_public_stats(uuid) from anon;
grant execute on function public.get_provider_public_stats(uuid) to authenticated;
grant execute on function public.get_provider_public_stats(uuid) to anon;

comment on function public.get_provider_public_stats(uuid) is
  'Public trust stats: avg_rating, rating_count, completed_orders (90d). SECURITY DEFINER, no PII, does not expose reviews rows.';
