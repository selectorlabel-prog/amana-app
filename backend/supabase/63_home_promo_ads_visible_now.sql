-- =============================================================================
-- 63_home_promo_ads_visible_now.sql
-- The published «كهرباء» row was scheduled to start 2026-08-18 22:00 UTC
-- (19 Aug 00:00 Khartoum). list_home_promo_ads hid it until then, so the
-- customer home showed hardcoded placeholders as if they were live ads.
--
-- Bring that active future-start ad into the live window immediately.
-- Does NOT DELETE any home_promo_ads rows.
--
-- Keeps list window (SQL 62):
--   (starts_at IS NULL OR starts_at <= now())
--   AND (ends_at IS NULL OR ends_at >= now())
-- NULL starts_at = immediate.
-- Safe to re-run.
-- =============================================================================

do $$
begin
  if to_regclass('public.home_promo_ads') is null then
    raise exception 'public.home_promo_ads missing — run 58_home_promo_ads.sql first';
  end if;
end $$;

comment on function public.list_home_promo_ads(text) is
  'Up to 7 active in-window home promo ads. NULL starts_at = immediate. City sorts matching ads first, never hides others.';

-- Activate the scheduled «كهرباء» campaign now. Never delete it.
update public.home_promo_ads
set
  starts_at = now(),
  updated_at = now()
where is_active = true
  and title = 'كهرباء'
  and starts_at is not null
  and starts_at > now();
