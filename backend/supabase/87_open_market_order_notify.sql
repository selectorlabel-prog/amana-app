-- =============================================================================
-- 87_open_market_order_notify.sql
-- Open-market (provider_id IS NULL) inserts: inbox-notify a small set of
-- eligible working providers instead of returning immediately.
--
-- Targeting (do NOT mass-notify):
--   * profiles.is_working = true
--   * role is provider
--   * not the customer
--   * city match: customer profiles.city vs provider city OR an active
--     provider_services.city (orders have no city/category columns)
--   * service match: active provider_services title/category overlaps
--     orders.service_name
--   * LIMIT 25
--
-- If the customer has no city, skip the open-market bell (avoid spam).
-- Assigned orders (provider_id NOT NULL) still notify that provider only.
-- Never fail the order INSERT.
-- Safe to re-run.
-- =============================================================================

create or replace function public._notify_provider_new_order_one(
  p_provider_id uuid,
  p_order_id uuid,
  p_service_name text,
  p_title text,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_provider_id is null then
    return;
  end if;

  begin
    perform public._insert_user_notification(
      p_provider_id,
      p_title,
      p_body,
      'system',
      jsonb_build_object(
        'order_id', p_order_id,
        'event', 'new_order',
        'service_name', p_service_name
      )
    );
  exception
    when undefined_function then
      begin
        insert into public.user_notifications (user_id, title, body, type, meta)
        values (
          p_provider_id,
          left(p_title, 120),
          left(p_body, 2000),
          'system',
          jsonb_build_object(
            'order_id', p_order_id,
            'event', 'new_order',
            'service_name', p_service_name
          )
        );
      exception
        when others then
          raise notice 'new order notify insert skipped: %', SQLERRM;
      end;
    when others then
      raise notice 'new order notify skipped: %', SQLERRM;
  end;
end;
$$;

revoke all on function public._notify_provider_new_order_one(uuid, uuid, text, text, text) from public;

create or replace function public._notify_provider_new_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  -- 'طلب جديد'
  v_title text := convert_from(decode('d8b7d984d8a820d8acd8afd98ad8af', 'hex'), 'utf8');
  -- 'وصلك طلب جديد — افتح الطلبات للرد'
  v_body text := convert_from(
    decode(
      'd988d8b5d984d98320d8b7d984d8a820d8acd8afd98ad8af20e2809420d8a7d981d8aad8ad20d8a7d984d8b7d984d8a8d8a7d8aa20d984d984d8b1d8af',
      'hex'
    ),
    'utf8'
  );
  v_city text;
  v_svc text;
  v_pid uuid;
begin
  if NEW.provider_id is not null then
    perform public._notify_provider_new_order_one(
      NEW.provider_id, NEW.id, NEW.service_name, v_title, v_body
    );
    return NEW;
  end if;

  -- Open market: require a customer city so we never fan out to all providers.
  begin
    if to_regclass('public.profiles') is null
       or to_regclass('public.provider_services') is null then
      return NEW;
    end if;

    select lower(trim(coalesce(p.city, '')))
      into v_city
    from public.profiles p
    where p.id = NEW.customer_id;

    v_city := coalesce(v_city, '');
    if v_city = '' then
      return NEW;
    end if;

    v_svc := lower(trim(coalesce(NEW.service_name, '')));
    if v_svc = '' then
      return NEW;
    end if;

    for v_pid in
      select p.id
      from public.profiles p
      where coalesce(p.is_working, false) = true
        and p.id is distinct from NEW.customer_id
        and lower(trim(coalesce(p.role, ''))) = 'provider'
        and (
          lower(trim(coalesce(p.city, ''))) = v_city
          or exists (
            select 1
            from public.provider_services ps
            where ps.provider_id = p.id
              and coalesce(ps.is_active, true)
              and lower(trim(coalesce(ps.city, ''))) = v_city
          )
        )
        and exists (
          select 1
          from public.provider_services ps
          where ps.provider_id = p.id
            and coalesce(ps.is_active, true)
            and (
              strpos(lower(trim(coalesce(ps.title, ''))), v_svc) > 0
              or strpos(v_svc, lower(trim(coalesce(ps.title, '')))) > 0
              or (
                coalesce(ps.category, '') <> ''
                and (
                  strpos(lower(trim(ps.category)), v_svc) > 0
                  or strpos(v_svc, lower(trim(ps.category))) > 0
                )
              )
            )
        )
      limit 25
    loop
      perform public._notify_provider_new_order_one(
        v_pid, NEW.id, NEW.service_name, v_title, v_body
      );
    end loop;
  exception
    when others then
      raise notice 'open-market new order notify skipped: %', SQLERRM;
  end;

  return NEW;
end;
$$;

drop trigger if exists trg_orders_notify_provider_new on public.orders;

create trigger trg_orders_notify_provider_new
  after insert on public.orders
  for each row
  execute function public._notify_provider_new_order();

notify pgrst, 'reload schema';
