-- =============================================================================
-- 69_ticket_dispute_control.sql
-- Ticket is no longer chat+status only: compact order summary fields,
-- required admin resolution note, cancel/complete from the ticket via
-- existing order RPCs (admin_cancel_order) plus admin_complete_order
-- (status only — no wallet / refunds).
--
-- - support_tickets.resolution_note / resolved_at / resolved_by
-- - admin_resolve_support_ticket(p_ticket_id, p_resolution_note) required
-- - Close channel, notify both order parties or opener only
-- - Do NOT append to orders.notes
-- - Do NOT auto-cancel/complete on resolve
-- Safe to re-run. Prerequisites: 26, 66, 68.
-- =============================================================================

do $$
begin
  if to_regprocedure('public.is_admin()') is null then
    raise exception 'public.is_admin() missing — run 17_admin_role_patch.sql first';
  end if;
  if to_regclass('public.support_tickets') is null then
    raise exception 'public.support_tickets missing — run 66_support_tickets.sql first';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) Resolution columns (keep existing ticket statuses)
-- ---------------------------------------------------------------------------
alter table public.support_tickets
  add column if not exists resolution_note text;

alter table public.support_tickets
  add column if not exists resolved_at timestamptz;

alter table public.support_tickets
  add column if not exists resolved_by uuid;

comment on column public.support_tickets.resolution_note is
  'قرار المشرف — required when resolving. Visible to ticket parties.';

comment on column public.support_tickets.resolved_at is
  'When the ticket was last marked resolved.';

comment on column public.support_tickets.resolved_by is
  'Admin profile id who last resolved the ticket.';

-- ---------------------------------------------------------------------------
-- 2) Compact order fields on ticket JSON (list + get)
-- ---------------------------------------------------------------------------
create or replace function public._support_ticket_json(p_id uuid)
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'id', t.id,
    'opener_id', t.opener_id,
    'opener_role', t.opener_role,
    'order_id', t.order_id,
    'subject', t.subject,
    'body', t.body,
    'status', t.status,
    'channel_open', t.channel_open,
    'channel_opened_at', t.channel_opened_at,
    'channel_closed_at', t.channel_closed_at,
    'resolution_note', t.resolution_note,
    'resolved_at', t.resolved_at,
    'resolved_by', t.resolved_by,
    'created_at', t.created_at,
    'updated_at', t.updated_at,
    'service_name', o.service_name,
    'order_status', o.status,
    'order_price', o.price,
    'opener_name', p.full_name,
    'customer_id', o.customer_id,
    'provider_id', o.provider_id,
    'customer_name', c.full_name,
    'provider_name', pr.full_name,
    'message_count', (
      select count(*)::int
      from public.support_ticket_messages m
      where m.ticket_id = t.id
    ),
    'last_message_body', (
      select m.body
      from public.support_ticket_messages m
      where m.ticket_id = t.id
      order by m.created_at desc
      limit 1
    ),
    'last_message_at', (
      select m.created_at
      from public.support_ticket_messages m
      where m.ticket_id = t.id
      order by m.created_at desc
      limit 1
    )
  )
  from public.support_tickets t
  left join public.orders o on o.id = t.order_id
  left join public.profiles p on p.id = t.opener_id
  left join public.profiles c on c.id = o.customer_id
  left join public.profiles pr on pr.id = o.provider_id
  where t.id = p_id;
$$;

revoke all on function public._support_ticket_json(uuid) from public;
revoke all on function public._support_ticket_json(uuid) from anon;
revoke all on function public._support_ticket_json(uuid) from authenticated;

-- ---------------------------------------------------------------------------
-- 3) Resolve — required قرار المشرف (Arabic-friendly empty check)
-- ---------------------------------------------------------------------------
drop function if exists public.admin_resolve_support_ticket(uuid, text);

create function public.admin_resolve_support_ticket(
  p_ticket_id uuid,
  p_resolution_note text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  t public.support_tickets%rowtype;
  v_prev text;
  v_note text := left(trim(coalesce(p_resolution_note, '')), 2000);
begin
  if v_admin is null or not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;

  if char_length(v_note) < 1 then
    raise exception 'أدخل قرار المشرف';
  end if;

  select * into t
  from public.support_tickets
  where id = p_ticket_id
  for update;

  if not found then
    raise exception 'التذكرة غير موجودة';
  end if;

  v_prev := t.status;

  insert into public.support_ticket_messages (
    ticket_id, sender_id, sender_role, body
  ) values (
    p_ticket_id, v_admin, 'admin', 'قرار المشرف: ' || v_note
  );

  update public.support_tickets
  set
    status = 'resolved',
    channel_open = false,
    channel_closed_at = now(),
    resolution_note = v_note,
    resolved_at = now(),
    resolved_by = v_admin
  where id = p_ticket_id
  returning * into t;

  update public.admin_inbox
  set is_read = true
  where kind = 'support_ticket'
    and entity_id = p_ticket_id::text
    and is_read = false;

  -- Never write into orders.notes. Never auto-cancel/complete the order.
  if v_prev is distinct from 'resolved' then
    perform public._notify_support_ticket_parties(
      t.id,
      'تم حل تذكرة الدعم',
      'أغلقت الإدارة تذكرتك «' || t.subject || '». راجع قرار المشرف.'
    );
  end if;

  return public._support_ticket_json(t.id);
end;
$$;

-- Status helper cannot resolve without a note.
create or replace function public.admin_set_support_ticket_status(
  p_id uuid,
  p_status text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text := lower(trim(coalesce(p_status, '')));
  v_row public.support_tickets%rowtype;
  v_prev text;
  v_title text;
  v_body text;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;

  if v_status not in ('open', 'in_progress', 'resolved') then
    raise exception 'حالة التذكرة غير صالحة';
  end if;

  if v_status = 'resolved' then
    raise exception 'أدخل قرار المشرف';
  end if;

  select status into v_prev
  from public.support_tickets
  where id = p_id
  for update;

  if not found then
    raise exception 'التذكرة غير موجودة';
  end if;

  update public.support_tickets
  set
    status = v_status,
    channel_open = case
      when v_status = 'open' then false
      else channel_open
    end
  where id = p_id
  returning * into v_row;

  if v_status = 'in_progress' then
    v_title := 'جاري معالجة تذكرة الدعم';
    v_body := 'بدأت الإدارة معالجة تذكرتك «' || v_row.subject || '».';
  else
    v_title := 'تحديث تذكرة الدعم';
    v_body := 'أُعيد فتح تذكرتك «' || v_row.subject || '».';
  end if;

  if v_prev is distinct from v_status then
    perform public._notify_support_ticket_opener(
      v_row.opener_id, v_row.opener_role, v_title, v_body
    );
  end if;

  return (
    public._support_ticket_json(v_row.id)::jsonb
    || jsonb_build_object('reused', false)
  )::json;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Admin complete — status only (no wallet / refunds). Cancel stays 26.
-- ---------------------------------------------------------------------------
create or replace function public.admin_complete_order(p_order_id uuid)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.orders%rowtype;
  v_status text;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;

  select * into v_row
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'الطلب غير موجود';
  end if;

  v_status := lower(trim(coalesce(v_row.status, '')));

  if v_status in ('completed', 'paid') then
    return v_row;
  end if;

  if v_status in ('cancelled', 'canceled') then
    raise exception 'لا يمكن إتمام طلب ملغى';
  end if;

  update public.orders
  set status = 'completed'
  where id = p_order_id
  returning * into v_row;

  if not found then
    raise exception 'تعذّر إتمام الطلب';
  end if;

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Grants — REVOKE anon on admin RPCs
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig, p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'list_my_support_tickets',
        'get_support_ticket',
        'admin_list_support_tickets',
        'admin_resolve_support_ticket',
        'admin_set_support_ticket_status',
        'admin_complete_order',
        '_support_ticket_json'
      )
  loop
    execute format('revoke all on function %s from public', r.sig);
    execute format('revoke all on function %s from anon', r.sig);
    if r.proname in (
      'list_my_support_tickets',
      'get_support_ticket',
      'admin_list_support_tickets',
      'admin_resolve_support_ticket',
      'admin_set_support_ticket_status',
      'admin_complete_order'
    ) then
      execute format('grant execute on function %s to authenticated', r.sig);
    else
      execute format('revoke all on function %s from authenticated', r.sig);
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';

select '69_ticket_dispute_control.sql applied' as status;
