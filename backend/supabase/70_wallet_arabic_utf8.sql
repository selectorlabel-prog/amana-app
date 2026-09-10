-- =============================================================================
-- 70_wallet_arabic_utf8.sql
-- Recreate wallet/notification writers with UTF-8 hex literals so MCP/editor
-- WIN1256 cannot mojibake Arabic. Prefix-repair live wallet + wallet_credit
-- rows only (do not WIN1256-convert whole columns; do not delete rows).
--
-- Pattern: convert_from(decode('…','hex'),'utf8')  (see 50_order_agreement_notifications.sql)
-- Safe to re-run. Prerequisites: 36, 34, 37.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- A) admin_credit_wallet
-- ---------------------------------------------------------------------------
create or replace function public.admin_credit_wallet(
  p_provider_id uuid,
  p_amount numeric,
  p_note text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_role text;
  v_amount numeric(12, 2);
  v_note text;
  v_desc text;
  v_tx_id uuid;
  v_audit_id uuid;
  v_balance numeric;
  v_amount_label text;
  v_err_login text := convert_from(decode('d98ad8acd8a820d8aad8b3d8acd98ad98420d8a7d984d8afd8aed988d98420d983d985d8b4d8b1d981','hex'),'utf8');
  v_err_is_admin text := convert_from(decode('d8afd8a7d984d8a92069735f61646d696e20d8bad98ad8b120d985d988d8acd988d8afd8a9202d20d986d981d991d8b02032342f323920d8a3d988d984d8a7d98b','hex'),'utf8');
  v_err_admins text := convert_from(decode('d987d8b0d98720d8a7d984d8b9d985d984d98ad8a920d984d984d985d8b4d8b1d981d98ad98620d981d982d8b7','hex'),'utf8');
  v_err_pick text := convert_from(decode('d8a7d8aed8aad8b120d985d8b2d988d8afd8a7d98b','hex'),'utf8');
  v_err_missing text := convert_from(decode('d8a7d984d985d8b2d988d8af20d8bad98ad8b120d985d988d8acd988d8af','hex'),'utf8');
  v_err_direct text := convert_from(decode('d8a7d984d8b4d8add98620d8a7d984d985d8a8d8a7d8b4d8b120d984d984d985d8b2d988d8afd98ad98620d981d982d8b7','hex'),'utf8');
  v_err_amount text := convert_from(decode('d985d8a8d984d8ba20d8bad98ad8b120d8b5d8a7d984d8ad','hex'),'utf8');
  v_err_big text := convert_from(decode('d8a7d984d985d8a8d984d8ba20d983d8a8d98ad8b120d8acd8afd8a7d98b2028d8a7d984d8add8af20d985d984d98ad988d98620d8ac2ed8b329','hex'),'utf8');
  v_err_check text := convert_from(decode('d981d8b4d98420d8a7d984d8b4d8add9863a20d982d98ad8af20d8a7d984d986d988d8b920d981d98a2077616c6c65745f7472616e73616374696f6e7320d98ad8b1d981d8b62061646d696e5f6372656469742e20d8a3d8b9d8af20d8aad8b4d8bad98ad9842033365f77616c6c65745f6372656469745f68617264656e696e672e73716c20d983d8a7d985d984d8a7d98b2e','hex'),'utf8');
  v_err_insert text := convert_from(decode('d981d8b4d98420d8a5d8afd8b1d8a7d8ac20d8add8b1d983d8a920d8a7d984d985d8add981d8b8d8a93a20','hex'),'utf8');
  v_err_audit text := convert_from(decode('d8aad98520d8b1d981d8b620d8b3d8acd98420d8a7d984d8aad8afd982d98ad9823a20','hex'),'utf8');
  v_desc_admin text := convert_from(decode('d8b4d8add98620d8a5d8afd8a7d8b1d98a','hex'),'utf8');
  v_title text := convert_from(decode('d8b4d8add98620d985d8add981d8b8d8a920d985d98620d8a7d984d8a5d8afd8a7d8b1d8a9','hex'),'utf8');
  v_body_prefix text := convert_from(decode('d8aad98520d8b4d8add98620d985d8add981d8b8d8aad98320d8a8d985d8a8d984d8ba20','hex'),'utf8');
  v_sdg text := convert_from(decode('20d8ac2ed8b3','hex'),'utf8');
  v_balance_lbl text := convert_from(decode('20d8a7d984d8b1d8b5d98ad8af20d8a7d984d8add8a7d984d98a3a20','hex'),'utf8');
begin
  if v_admin is null then
    raise exception '%', v_err_login;
  end if;

  if to_regprocedure('public.is_admin()') is null then
    raise exception '%', v_err_is_admin;
  end if;

  if not public.is_admin() then
    raise exception '%', v_err_admins;
  end if;

  if p_provider_id is null then
    raise exception '%', v_err_pick;
  end if;

  select role into v_role
  from public.profiles
  where id = p_provider_id;

  if not found then
    raise exception '%', v_err_missing;
  end if;

  if lower(coalesce(v_role, '')) <> 'provider' then
    raise exception '%', v_err_direct;
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception '%', v_err_amount;
  end if;

  if p_amount > 1000000 then
    raise exception '%', v_err_big;
  end if;

  v_amount := round(p_amount, 2);
  v_note := nullif(trim(coalesce(p_note, '')), '');
  v_desc := v_desc_admin
    || case when v_note is null then '' else ' - ' || left(v_note, 120) end;

  begin
    insert into public.wallet_transactions (provider_id, amount, type, description)
    values (p_provider_id, v_amount, 'admin_credit', v_desc)
    returning id into v_tx_id;
  exception
    when check_violation then
      raise exception '%', v_err_check;
    when others then
      raise exception '%', v_err_insert || SQLERRM;
  end;

  begin
    insert into public.admin_wallet_credits (
      provider_id, admin_id, amount, note, wallet_tx_id
    ) values (
      p_provider_id, v_admin, v_amount, v_note, v_tx_id
    )
    returning id into v_audit_id;
  exception
    when others then
      raise exception '%', v_err_audit || SQLERRM;
  end;

  v_balance := public.provider_wallet_balance(p_provider_id);

  begin
    v_amount_label := trim(to_char(round(v_amount), 'FM999,999,999,999'));
  exception
    when others then
      v_amount_label := v_amount::text;
  end;

  begin
    perform public._insert_user_notification(
      p_provider_id,
      v_title,
      v_body_prefix || v_amount_label || v_sdg
        || case when v_note is null then '.' else ' - ' || v_note end
        || v_balance_lbl
        || trim(to_char(round(v_balance), 'FM999,999,999,999'))
        || v_sdg || '.',
      'wallet_credit',
      jsonb_build_object(
        'amount', v_amount,
        'balance', v_balance,
        'wallet_tx_id', v_tx_id,
        'audit_id', v_audit_id
      )
    );
  exception
    when undefined_function then null;
    when others then
      raise notice 'wallet credit notify skipped: %', SQLERRM;
  end;

  return json_build_object(
    'audit_id', v_audit_id,
    'wallet_tx_id', v_tx_id,
    'provider_id', p_provider_id,
    'amount', v_amount,
    'note', v_note,
    'balance', v_balance
  );
end;
$$;

revoke all on function public.admin_credit_wallet(uuid, numeric, text) from public;
revoke all on function public.admin_credit_wallet(uuid, numeric, text) from anon;
grant execute on function public.admin_credit_wallet(uuid, numeric, text) to authenticated;

-- ---------------------------------------------------------------------------
-- B) redeem_recharge_code
-- ---------------------------------------------------------------------------
create or replace function public.redeem_recharge_code(p_code text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.recharge_codes%rowtype;
  v_uid uuid := auth.uid();
  v_role text;
  v_suspended boolean;
  v_code text;
  v_stripped text;
  v_balance numeric;
  v_err_login text := convert_from(decode('d98ad8acd8a820d8aad8b3d8acd98ad98420d8a7d984d8afd8aed988d98420d984d8b4d8add98620d8a7d984d8b1d8b5d98ad8af','hex'),'utf8');
  v_err_enter text := convert_from(decode('d8a3d8afd8aed98420d983d988d8af20d8a7d984d8b4d8add986','hex'),'utf8');
  v_err_profile text := convert_from(decode('d8a7d984d985d984d98120d8a7d984d8b4d8aed8b5d98a20d8bad98ad8b120d985d988d8acd988d8af','hex'),'utf8');
  v_err_suspended text := convert_from(decode('d8a7d984d8add8b3d8a7d8a820d985d988d982d988d9812e20d8aad988d8a7d8b5d98420d985d8b920d8a7d984d8afd8b9d9852e','hex'),'utf8');
  v_err_role text := convert_from(decode('d8a7d984d8b4d8add98620d985d8aad8a7d8ad20d984d985d8b2d988d8afd98a20d8a7d984d8aed8afd985d8a920d981d982d8b7','hex'),'utf8');
  v_err_code text := convert_from(decode('d983d988d8af20d8a7d984d8b4d8add98620d8bad98ad8b120d8b5d8a7d984d8ad20d8a3d98820d985d8b3d8aad8aed8afd98520d985d8b3d8a8d982d8a7d98b','hex'),'utf8');
  v_desc_code text := convert_from(decode('d983d988d8af3a20','hex'),'utf8');
begin
  if v_uid is null then
    raise exception '%', v_err_login;
  end if;

  v_code := upper(regexp_replace(trim(coalesce(p_code, '')), '\s+', '', 'g'));

  if v_code = '' then
    raise exception '%', v_err_enter;
  end if;

  if v_code !~ '^AMANA-' then
    v_stripped := replace(v_code, '-', '');
    if length(v_stripped) = 10 and v_stripped ~ '^[A-Z0-9]{10}$' then
      v_code := v_stripped;
    end if;
  end if;

  select role, is_suspended
    into v_role, v_suspended
  from public.profiles
  where id = v_uid;

  if not found then
    raise exception '%', v_err_profile;
  end if;

  if coalesce(v_suspended, false) then
    raise exception '%', v_err_suspended;
  end if;

  if lower(coalesce(v_role, '')) <> 'provider' then
    raise exception '%', v_err_role;
  end if;

  select * into v_row
  from public.recharge_codes
  where upper(trim(code)) = v_code
    and is_used = false
  for update;

  if not found then
    raise exception '%', v_err_code;
  end if;

  update public.recharge_codes
  set is_used = true, used_by = v_uid
  where id = v_row.id;

  insert into public.wallet_transactions (provider_id, amount, type, description)
  values (v_uid, v_row.amount, 'recharge', v_desc_code || v_row.code);

  v_balance := public.provider_wallet_balance(v_uid);

  return json_build_object(
    'code', v_row.code,
    'amount', v_row.amount,
    'balance', v_balance
  );
end;
$$;

revoke all on function public.redeem_recharge_code(text) from public;
revoke all on function public.redeem_recharge_code(text) from anon;
grant execute on function public.redeem_recharge_code(text) to authenticated;

-- ---------------------------------------------------------------------------
-- C) charge_price_agree_commission (description writer)
-- ---------------------------------------------------------------------------
create or replace function public.charge_price_agree_commission(p_order_id uuid)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.orders%rowtype;
  v_provider uuid;
  v_price numeric(12, 2);
  v_commission numeric(12, 2);
  v_balance numeric(12, 2);
  v_short text;
  v_desc text;
  v_suspended boolean;
  v_pct numeric;
  v_frac numeric;
  v_err_suspended text := convert_from(decode('d8a7d984d8add8b3d8a7d8a820d985d988d982d988d9812e20d8aad988d8a7d8b5d98420d985d8b920d8a7d984d8afd8b9d9852e','hex'),'utf8');
  v_comm_prefix text := convert_from(decode('d8b9d985d988d984d8a920d985d986d8b5d8a920','hex'),'utf8');
  v_order_sep text := convert_from(decode('202d20d8b7d984d8a820','hex'),'utf8');
begin
  select * into v_row
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  v_provider := v_row.provider_id;
  if v_provider is null then
    raise exception 'order has no provider';
  end if;

  begin
    select is_suspended into v_suspended
    from public.profiles
    where id = v_provider;

    if coalesce(v_suspended, false) then
      raise exception '%', v_err_suspended;
    end if;
  exception
    when undefined_column then null;
  end;

  perform public.assert_app_enabled_for_role('provider');

  v_price := coalesce(v_row.price, v_row.proposed_price, v_row.offer_price, 0);
  if v_price is null or v_price <= 0 then
    raise exception 'invalid agreed price';
  end if;

  v_pct := public.get_commission_rate_percent();
  v_frac := v_pct / 100.0;
  v_commission := round(v_price * v_frac, 2);
  if v_commission <= 0 then
    return 0;
  end if;

  v_short := left(v_row.id::text, 8);
  v_desc := v_comm_prefix
    || public._format_percent_label(v_pct)
    || v_order_sep
    || v_short;

  if exists (
    select 1
    from public.wallet_transactions
    where provider_id = v_provider
      and lower(coalesce(type, '')) = 'commission'
      and description like '%' || v_short || '%'
  ) then
    return v_commission;
  end if;

  v_balance := public.provider_wallet_balance(v_provider);

  if v_balance < v_commission then
    raise exception '%',
      public._insufficient_commission_message(v_commission, v_balance, v_pct);
  end if;

  insert into public.wallet_transactions (provider_id, amount, type, description)
  values (
    v_provider,
    -v_commission,
    'commission',
    v_desc
  );

  return v_commission;
end;
$$;

revoke all on function public.charge_price_agree_commission(uuid) from public;
revoke all on function public.charge_price_agree_commission(uuid) from anon;
grant execute on function public.charge_price_agree_commission(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- D) _insert_user_notification fallback title
-- ---------------------------------------------------------------------------
create or replace function public._insert_user_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text default 'admin_message',
  p_meta jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_id uuid;
  v_type text := lower(trim(coalesce(p_type, 'admin_message')));
  v_title text := left(public._clean_notification_text(p_title), 120);
  v_body text := left(public._clean_notification_text(p_body), 2000);
  v_fallback text := convert_from(decode('d8b1d8b3d8a7d984d8a920d985d98620d8a5d8afd8a7d8b1d8a920d8a3d985d8a7d986d8a9','hex'),'utf8');
begin
  if p_user_id is null then
    return null;
  end if;
  if v_type not in ('admin_message', 'commission_change', 'wallet_credit', 'system') then
    v_type := 'admin_message';
  end if;
  if char_length(v_title) = 0 then
    v_title := v_fallback;
  end if;
  if char_length(v_body) = 0 then
    v_body := v_title;
  end if;

  insert into public.user_notifications (user_id, title, body, type, meta)
  values (p_user_id, v_title, v_body, v_type, p_meta)
  returning id into v_id;

  return v_id;
end;
$fn$;

revoke all on function public._insert_user_notification(uuid, text, text, text, jsonb)
  from public;
revoke all on function public._insert_user_notification(uuid, text, text, text, jsonb)
  from anon;

-- ---------------------------------------------------------------------------
-- E) Prefix-only repair of live garbled rows
-- ---------------------------------------------------------------------------
do $repair$
declare
  g_admin text := convert_from(decode('d8b7c2b4d8b7c2add8b8e280a020d8b7c2a5d8b7c2afd8b7c2a7d8b7c2b1d8b8d9b9','hex'),'utf8');
  f_admin text := convert_from(decode('d8b4d8add98620d8a5d8afd8a7d8b1d98a','hex'),'utf8');
  g_comm text := convert_from(decode('d8b7c2b9d8b8e280a6d8b8cb86d8b8e2809ed8b7c2a920d8b8e280a6d8b8e280a0d8b7c2b5d8b7c2a9','hex'),'utf8');
  f_comm text := convert_from(decode('d8b9d985d988d984d8a920d985d986d8b5d8a9','hex'),'utf8');
  g_code text := convert_from(decode('d8b8c692d8b8cb86d8b7c2af3a','hex'),'utf8');
  f_code text := convert_from(decode('d983d988d8af3a','hex'),'utf8');
  g_dash text := convert_from(decode('c3a2e282ace2809d','hex'),'utf8');
  g_title text := convert_from(decode('d8b7c2b4d8b7c2add8b8e280a020d8b8e280a6d8b7c2add8b8d9bed8b7c2b8d8b7c2a920d8b8e280a6d8b8e280a020d8b7c2a7d8b8e2809ed8b7c2a5d8b7c2afd8b7c2a7d8b7c2b1d8b7c2a9','hex'),'utf8');
  f_title text := convert_from(decode('d8b4d8add98620d985d8add981d8b8d8a920d985d98620d8a7d984d8a5d8afd8a7d8b1d8a9','hex'),'utf8');
  g_body text := convert_from(decode('d8b7dabed8b8e280a620d8b7c2b4d8b7c2add8b8e280a020d8b8e280a6d8b7c2add8b8d9bed8b7c2b8d8b7dabed8b8c69220d8b7c2a8d8b8e280a6d8b7c2a8d8b8e2809ed8b7d89b20','hex'),'utf8');
  f_body text := convert_from(decode('d8aad98520d8b4d8add98620d985d8add981d8b8d8aad98320d8a8d985d8a8d984d8ba20','hex'),'utf8');
  g_sdg text := convert_from(decode('20d8b7c2ac2ed8b7c2b3','hex'),'utf8');
  f_sdg text := convert_from(decode('20d8ac2ed8b3','hex'),'utf8');
  g_bal text := convert_from(decode('20d8b7c2a7d8b8e2809ed8b7c2b1d8b7c2b5d8b8d9b9d8b7c2af20d8b7c2a7d8b8e2809ed8b7c2add8b7c2a7d8b8e2809ed8b8d9b93a20','hex'),'utf8');
  f_bal text := convert_from(decode('20d8a7d984d8b1d8b5d98ad8af20d8a7d984d8add8a7d984d98a3a20','hex'),'utf8');
  g_pocket text := convert_from(decode('d985d8add981d8b8d8a9d983','hex'),'utf8');
  f_pocket text := convert_from(decode('d985d8add981d8b8d8aad983','hex'),'utf8');
  g_talab text := convert_from(decode('d8b7c2b7d8b8e2809ed8b7c2a8','hex'),'utf8');
  f_talab text := convert_from(decode('d8b7d984d8a8','hex'),'utf8');
  n_admin int;
  n_comm int;
  n_code int;
  n_dash int;
  n_title int;
  n_body int;
begin
  select count(*) into n_admin
  from public.wallet_transactions
  where lower(coalesce(type, '')) = 'admin_credit'
    and description like g_admin || '%';

  update public.wallet_transactions
  set description = f_admin || substr(description, char_length(g_admin) + 1)
  where lower(coalesce(type, '')) = 'admin_credit'
    and description like g_admin || '%';

  select count(*) into n_comm
  from public.wallet_transactions
  where lower(coalesce(type, '')) = 'commission'
    and description like g_comm || '%';

  update public.wallet_transactions
  set description = f_comm || substr(description, char_length(g_comm) + 1)
  where lower(coalesce(type, '')) = 'commission'
    and description like g_comm || '%';

  select count(*) into n_code
  from public.wallet_transactions
  where lower(coalesce(type, '')) = 'recharge'
    and description like g_code || '%';

  update public.wallet_transactions
  set description = f_code || substr(description, char_length(g_code) + 1)
  where lower(coalesce(type, '')) = 'recharge'
    and description like g_code || '%';

  update public.wallet_transactions
  set description = replace(replace(description, ' ' || g_dash || ' ', ' - '), g_dash, ' - ')
  where lower(coalesce(type, '')) in ('admin_credit', 'commission', 'recharge')
    and description like '%' || g_dash || '%';
  get diagnostics n_dash = row_count;

  select count(*) into n_title
  from public.user_notifications
  where type = 'wallet_credit'
    and title like g_title || '%';

  update public.user_notifications
  set title = f_title || substr(title, char_length(g_title) + 1)
  where type = 'wallet_credit'
    and title like g_title || '%';

  select count(*) into n_body
  from public.user_notifications
  where type = 'wallet_credit'
    and (
      body like g_body || '%'
      or body like '%' || g_sdg || '%'
      or body like '%' || g_bal || '%'
      or body like '%' || g_dash || '%'
    );

  update public.user_notifications
  set body = replace(replace(replace(replace(body, g_body, f_body), g_sdg, f_sdg), g_bal, f_bal), g_dash, ' - ')
  where type = 'wallet_credit'
    and (
      body like g_body || '%'
      or body like '%' || g_sdg || '%'
      or body like '%' || g_bal || '%'
      or body like '%' || g_dash || '%'
    );

  raise notice '70 repair wallet admin_credit=% commission=% recharge=% emdash=% notif_title=% notif_body=%',
    n_admin, n_comm, n_code, n_dash, n_title, n_body;

  update public.user_notifications
  set body = replace(body, g_pocket, f_pocket)
  where type = 'wallet_credit'
    and body like '%' || g_pocket || '%';

  update public.wallet_transactions
  set description = replace(description, g_talab, f_talab)
  where lower(coalesce(type, '')) = 'commission'
    and description like '%' || g_talab || '%';
end;
$repair$;

notify pgrst, 'reload schema';
