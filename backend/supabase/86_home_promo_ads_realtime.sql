-- =============================================================================
-- 86_home_promo_ads_realtime.sql
-- Add home_promo_ads to supabase_realtime + REPLICA IDENTITY FULL so the
-- customer home carousel reloads when admin publishes / updates ads.
--
-- RLS unchanged (58): authenticated customers SELECT active ads in the
-- starts_at / ends_at window. Admin publish path stays RPC.
-- Safe to re-run.
-- =============================================================================

do $$
begin
  if to_regclass('public.home_promo_ads') is null then
    raise notice 'skip 86 — public.home_promo_ads missing (run 58 first)';
    return;
  end if;

  execute 'alter table public.home_promo_ads replica identity full';

  if exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'home_promo_ads'
  ) then
    raise notice 'already in supabase_realtime: home_promo_ads';
  else
    begin
      execute 'alter publication supabase_realtime add table public.home_promo_ads';
      raise notice 'added to supabase_realtime: home_promo_ads';
    exception
      when duplicate_object then
        raise notice 'already in supabase_realtime (race): home_promo_ads';
      when undefined_object then
        raise notice 'supabase_realtime publication missing — enable Realtime in project settings';
    end;
  end if;
end $$;

notify pgrst, 'reload schema';
