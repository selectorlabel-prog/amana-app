-- =============================================================================
-- 80_promo_provider_bio.sql
-- Home promo trust sheet needs profiles.bio for «نبذة مهنية».
-- SQL 75 returned service_description only, so the sheet had no provider_bio
-- until a live profiles fetch (and ads could not seed it).
-- Recreates list_home_promo_ads (DROP+CREATE; RETURNS TABLE cannot change
-- via CREATE OR REPLACE) with coalesce(nullif(trim(p.bio),''), null)
-- as provider_bio. Keeps the SQL 75 contract otherwise.
-- Safe to re-run. Prerequisites: 75 (this replaces that promo RPC).
-- =============================================================================

drop function if exists public.list_home_promo_ads(text);

create function public.list_home_promo_ads(p_city text default null)
returns table (
  id uuid,
  ad_type text,
  title text,
  headline text,
  subtitle text,
  image_url text,
  cta_label text,
  provider_id uuid,
  provider_service_id uuid,
  provider_name text,
  provider_avatar_url text,
  provider_is_working boolean,
  provider_bio text,
  service_title text,
  service_description text,
  service_category text,
  price_from numeric,
  avg_rating numeric,
  rating_count int,
  target_kind text,
  target_category text,
  city text,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean,
  sort_order int,
  updated_at timestamptz
)
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_city text := nullif(trim(coalesce(p_city, '')), '');
begin
  return query
  select
    a.id,
    a.ad_type,
    a.title,
    coalesce(nullif(trim(a.headline), ''), a.title) as headline,
    a.subtitle,
    nullif(trim(a.image_url), '') as image_url,
    a.cta_label,
    coalesce(a.provider_id, s.provider_id) as provider_id,
    a.provider_service_id,
    coalesce(
      nullif(trim(p.full_name), ''),
      case when a.ad_type = 'provider' then 'مزود موثّق' else null end
    ) as provider_name,
    p.avatar_url as provider_avatar_url,
    coalesce(p.is_working, false) as provider_is_working,
    coalesce(nullif(trim(p.bio), ''), null) as provider_bio,
    s.title as service_title,
    s.description as service_description,
    s.category as service_category,
    s.price_from,
    rv.avg_rating,
    coalesce(rv.rating_count, 0) as rating_count,
    a.target_kind,
    a.target_category,
    a.city,
    a.starts_at,
    a.ends_at,
    a.is_active,
    a.sort_order,
    a.updated_at
  from public.home_promo_ads a
  left join public.provider_services s on s.id = a.provider_service_id
  left join public.profiles p on p.id = coalesce(a.provider_id, s.provider_id)
  left join lateral (
    select
      round(avg(r.rating)::numeric, 1) as avg_rating,
      count(*)::int as rating_count
    from public.reviews r
    where r.provider_id = coalesce(a.provider_id, s.provider_id)
      and coalesce(r.is_hidden, false) = false
  ) rv on true
  where a.is_active = true
    and (a.starts_at is null or a.starts_at <= now())
    and (a.ends_at is null or a.ends_at >= now())
    and (
      a.ad_type = 'campaign'
      or (
        a.ad_type = 'provider'
        and s.id is not null
        and s.verification_status = 'approved'
        and coalesce(s.is_active, true) = true
        and coalesce(s.admin_hidden, false) = false
      )
    )
  order by
    case
      when v_city is not null
           and a.city is not null
           and (
             lower(trim(a.city)) = lower(v_city)
             or a.city ilike ('%' || v_city || '%')
             or v_city ilike ('%' || trim(a.city) || '%')
           )
      then 0
      else 1
    end,
    a.sort_order asc,
    a.updated_at desc,
    a.created_at desc
  limit 7;
end;
$$;

revoke all on function public.list_home_promo_ads(text) from public;
grant execute on function public.list_home_promo_ads(text) to authenticated;

comment on function public.list_home_promo_ads(text) is
  'Up to 7 active in-window home promo ads. City sorts matching ads first, never hides others. Includes provider_is_working, service_description, and profiles.bio as provider_bio.';

notify pgrst, 'reload schema';
