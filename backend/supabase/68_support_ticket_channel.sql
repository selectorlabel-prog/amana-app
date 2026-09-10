-- =============================================================================
-- 68_support_ticket_channel.sql
-- Dispute 3-way channel lives on the ticket — never in order_messages.
-- - Table public.support_ticket_messages
-- - Admin opens the channel FROM a ticket (admin_open_ticket_channel)
-- - Price / offer talk stays in order_messages (محادثة الطلب)
-- - Resolve closes the channel and notifies both parties if order-linked
-- - Do NOT append «نزاع» to orders.notes
-- - Do NOT auto-close tickets when an order completes
-- - send_my_order_message / admin_send_order_message do not reopen support
-- Safe to re-run. Prerequisites: 17, 30, 53, 56, 66.
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
-- 1) Ticket channel flags
-- ---------------------------------------------------------------------------
alter table public.support_tickets
  add column if not exists channel_open boolean not null default false;

alter table public.support_tickets
  add column if not exists channel_opened_at timestamptz;

alter table public.support_tickets
  add column if not exists channel_closed_at timestamptz;

comment on column public.support_tickets.channel_open is
  'True while the 3-way dispute channel is open. Independent of order_messages.';

comment on table public.support_tickets is
  'User-filed support tickets. Dispute chat is support_ticket_messages, not order_messages.';

-- ---------------------------------------------------------------------------
-- 2) Messages table (separate from price/offer chat)
-- ---------------------------------------------------------------------------
create table if not exists public.support_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets (id) on delete cascade,
  sender_id uuid not null references public.profiles (id),
  sender_role text not null,
  body text not null,
  created_at timestamptz not null default now(),
  constraint support_ticket_messages_role_check
    check (lower(sender_role) in ('customer', 'provider', 'admin')),
  constraint support_ticket_messages_body_check
    check (char_length(trim(body)) > 0)
);

create index if not exists idx_support_ticket_messages_ticket_created
  on public.support_ticket_messages (ticket_id, created_at);

comment on table public.support_ticket_messages is
  '3-way dispute messages for a support ticket. Never mixed into order_messages.';

alter table public.support_ticket_messages enable row level security;

-- ---------------------------------------------------------------------------
-- 3) Access helper + RLS
-- ---------------------------------------------------------------------------
create or replace function public._current_can_access_ticket(p_ticket_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  t public.support_tickets%rowtype;
  o public.orders%rowtype;
begin
  if v_uid is null or p_ticket_id is null then
    return false;
  end if;

  if public.is_admin() then
    return true;
  end if;

  select * into t
  from public.support_tickets
  where id = p_ticket_id;

  if not found then
    return false;
  end if;

  if t.opener_id = v_uid then
    return true;
  end if;

  -- Other party: only after admin opened the dispute channel
  if t.order_id is null or t.channel_opened_at is null then
    return false;
  end if;

  select * into o
  from public.orders
  where id = t.order_id;

  if not found then
    return false;
  end if;

  return o.customer_id = v_uid or o.provider_id = v_uid;
end;
$$;

revoke all on function public._current_can_access_ticket(uuid) from public;
revoke all on function public._current_can_access_ticket(uuid) from anon;
revoke all on function public._current_can_access_ticket(uuid) from authenticated;

drop policy if exists "Openers select own support tickets" on public.support_tickets;
drop policy if exists "Participants select support tickets" on public.support_tickets;
create policy "Participants select support tickets"
  on public.support_tickets for select
  to authenticated
  using (public._current_can_access_ticket(id));

drop policy if exists "Ticket parties select messages" on public.support_ticket_messages;
create policy "Ticket parties select messages"
  on public.support_ticket_messages for select
  to authenticated
  using (public._current_can_access_ticket(ticket_id));

grant select on table public.support_ticket_messages to authenticated;
revoke insert, update, delete on table public.support_ticket_messages from authenticated;
revoke all on table public.support_ticket_messages from anon;

-- ---------------------------------------------------------------------------
-- 4) JSON helpers
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
    'created_at', t.created_at,
    'updated_at', t.updated_at,
    'service_name', o.service_name,
    'order_status', o.status,
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

create or replace function public._ticket_message_json(p_id uuid)
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'id', m.id,
    'ticket_id', m.ticket_id,
    'sender_id', m.sender_id,
    'sender_role', m.sender_role,
    'body', m.body,
    'created_at', m.created_at,
    'sender_name', p.full_name
  )
  from public.support_ticket_messages m
  left join public.profiles p on p.id = m.sender_id
  where m.id = p_id;
$$;

revoke all on function public._ticket_message_json(uuid) from public;
revoke all on function public._ticket_message_json(uuid) from anon;
revoke all on function public._ticket_message_json(uuid) from authenticated;

create or replace function public._notify_support_ticket_parties(
  p_ticket_id uuid,
  p_title text,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  t public.support_tickets%rowtype;
  o public.orders%rowtype;
begin
  select * into t
  from public.support_tickets
  where id = p_ticket_id;

  if not found then
    return;
  end if;

  perform public._notify_support_ticket_opener(
    t.opener_id, t.opener_role, p_title, p_body
  );

  if t.order_id is null then
    return;
  end if;

  select * into o
  from public.orders
  where id = t.order_id;

  if not found then
    return;
  end if;

  if o.customer_id is not null and o.customer_id is distinct from t.opener_id then
    perform public._notify_support_ticket_opener(
      o.customer_id, 'customer', p_title, p_body
    );
  end if;

  if o.provider_id is not null and o.provider_id is distinct from t.opener_id then
    perform public._notify_support_ticket_opener(
      o.provider_id, 'provider', p_title, p_body
    );
  end if;
end;
$$;

revoke all on function public._notify_support_ticket_parties(uuid, text, text)
  from public;
revoke all on function public._notify_support_ticket_parties(uuid, text, text)
  from anon;
revoke all on function public._notify_support_ticket_parties(uuid, text, text)
  from authenticated;

-- ---------------------------------------------------------------------------
-- 5) User RPCs
-- ---------------------------------------------------------------------------
create or replace function public.list_my_support_tickets()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول لعرض التذاكر';
  end if;

  return coalesce(
    (
      select json_agg(public._support_ticket_json(t.id) order by t.created_at desc)
      from public.support_tickets t
      left join public.orders o on o.id = t.order_id
      where t.opener_id = v_uid
         or (
           t.order_id is not null
           and t.channel_opened_at is not null
           and (o.customer_id = v_uid or o.provider_id = v_uid)
         )
    ),
    '[]'::json
  );
end;
$$;

create or replace function public.get_support_ticket(p_ticket_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول';
  end if;
  if not public._current_can_access_ticket(p_ticket_id) then
    raise exception 'التذكرة غير موجودة';
  end if;
  return public._support_ticket_json(p_ticket_id);
end;
$$;

create or replace function public.list_ticket_messages(p_ticket_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول';
  end if;
  if not public._current_can_access_ticket(p_ticket_id) then
    raise exception 'التذكرة غير موجودة';
  end if;

  return coalesce(
    (
      select json_agg(public._ticket_message_json(m.id) order by m.created_at)
      from public.support_ticket_messages m
      where m.ticket_id = p_ticket_id
    ),
    '[]'::json
  );
end;
$$;

create or replace function public.send_ticket_message(
  p_ticket_id uuid,
  p_body text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_body text := left(trim(coalesce(p_body, '')), 2000);
  t public.support_tickets%rowtype;
  o public.orders%rowtype;
  v_role text;
  v_row public.support_ticket_messages%rowtype;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول لإرسال رسالة';
  end if;

  if char_length(v_body) < 1 then
    raise exception 'أدخل نص الرسالة';
  end if;

  if to_regprocedure('public.is_current_user_suspended()') is not null
     and public.is_current_user_suspended() then
    raise exception 'حسابك موقوف';
  end if;

  select * into t
  from public.support_tickets
  where id = p_ticket_id
  for update;

  if not found then
    raise exception 'التذكرة غير موجودة';
  end if;

  if not public._current_can_access_ticket(p_ticket_id) then
    raise exception 'التذكرة غير موجودة';
  end if;

  if not coalesce(t.channel_open, false) then
    raise exception 'قناة النزاع غير مفتوحة';
  end if;

  if t.status = 'resolved' then
    raise exception 'قناة النزاع مغلقة';
  end if;

  if public.is_admin() then
    v_role := 'admin';
  elsif t.opener_id = v_uid then
    v_role := t.opener_role;
  elsif t.order_id is not null then
    select * into o from public.orders where id = t.order_id;
    if found and o.customer_id = v_uid then
      v_role := 'customer';
    elsif found and o.provider_id = v_uid then
      v_role := 'provider';
    else
      raise exception 'لست طرفاً في قناة النزاع';
    end if;
  else
    raise exception 'لست طرفاً في قناة النزاع';
  end if;

  insert into public.support_ticket_messages (
    ticket_id, sender_id, sender_role, body
  ) values (
    p_ticket_id, v_uid, v_role, v_body
  )
  returning * into v_row;

  -- Do NOT insert into user_notifications (SQL 56: chat is not inbox spam).
  return public._ticket_message_json(v_row.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6) Admin RPCs
-- ---------------------------------------------------------------------------
create or replace function public.admin_open_ticket_channel(p_ticket_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  t public.support_tickets%rowtype;
  v_was_open boolean;
begin
  if v_admin is null or not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;

  select * into t
  from public.support_tickets
  where id = p_ticket_id
  for update;

  if not found then
    raise exception 'التذكرة غير موجودة';
  end if;

  v_was_open := coalesce(t.channel_open, false);

  update public.support_tickets
  set
    status = 'in_progress',
    channel_open = true,
    channel_opened_at = coalesce(channel_opened_at, now()),
    channel_closed_at = null
  where id = p_ticket_id
  returning * into t;

  -- Seed the original complaint into the channel (not into order_messages).
  if not exists (
    select 1 from public.support_ticket_messages m where m.ticket_id = p_ticket_id
  ) then
    insert into public.support_ticket_messages (
      ticket_id, sender_id, sender_role, body
    ) values (
      p_ticket_id, t.opener_id, t.opener_role, t.body
    );
    insert into public.support_ticket_messages (
      ticket_id, sender_id, sender_role, body
    ) values (
      p_ticket_id,
      v_admin,
      'admin',
      'فتحت الإدارة قناة النزاع. هذه المحادثة منفصلة عن محادثة الطلب.'
    );
  elsif not v_was_open then
    insert into public.support_ticket_messages (
      ticket_id, sender_id, sender_role, body
    ) values (
      p_ticket_id,
      v_admin,
      'admin',
      'أُعيد فتح قناة النزاع.'
    );
  end if;

  if not v_was_open then
    perform public._notify_support_ticket_parties(
      t.id,
      'قناة النزاع',
      'فتحت الإدارة قناة نزاع بخصوص «' || t.subject || '». راجع المساعدة والدعم.'
    );
  end if;

  -- Never write «نزاع» into orders.notes. Never insert into order_messages.
  return public._support_ticket_json(t.id);
end;
$$;

create or replace function public.admin_resolve_support_ticket(
  p_ticket_id uuid,
  p_note text default null
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
  v_note text := left(trim(coalesce(p_note, '')), 2000);
begin
  if v_admin is null or not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;

  select * into t
  from public.support_tickets
  where id = p_ticket_id
  for update;

  if not found then
    raise exception 'التذكرة غير موجودة';
  end if;

  v_prev := t.status;

  if char_length(v_note) > 0 then
    insert into public.support_ticket_messages (
      ticket_id, sender_id, sender_role, body
    ) values (
      p_ticket_id, v_admin, 'admin', v_note
    );
  end if;

  update public.support_tickets
  set
    status = 'resolved',
    channel_open = false,
    channel_closed_at = now()
  where id = p_ticket_id
  returning * into t;

  update public.admin_inbox
  set is_read = true
  where kind = 'support_ticket'
    and entity_id = p_ticket_id::text
    and is_read = false;

  if v_prev is distinct from 'resolved' then
    perform public._notify_support_ticket_parties(
      t.id,
      'تم حل تذكرة الدعم',
      'أغلقت الإدارة تذكرتك «' || t.subject || '».'
    );
  end if;

  return public._support_ticket_json(t.id);
end;
$$;

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

  select status into v_prev
  from public.support_tickets
  where id = p_id
  for update;

  if not found then
    raise exception 'التذكرة غير موجودة';
  end if;

  if v_status = 'resolved' then
    return public.admin_resolve_support_ticket(p_id, null);
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

-- Thin wrapper: open the TICKET channel. Do not dump admin into order_messages.
create or replace function public.admin_open_support_thread(
  p_order_id uuid,
  p_note text default null
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_row public.orders%rowtype;
  v_ticket_id uuid;
begin
  if v_admin is null or not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;

  select * into v_row
  from public.orders
  where id = p_order_id;

  if not found then
    raise exception 'الطلب غير موجود';
  end if;

  select t.id into v_ticket_id
  from public.support_tickets t
  where t.order_id = p_order_id
    and t.status in ('open', 'in_progress')
  order by t.created_at desc
  limit 1;

  if v_ticket_id is null then
    raise exception
      'لا توجد تذكرة دعم لهذا الطلب. افتح قناة النزاع من التذكرة.';
  end if;

  perform public.admin_open_ticket_channel(v_ticket_id);

  -- Intentionally do NOT set support_open, do NOT insert order_messages,
  -- do NOT append «نزاع» to notes.
  return v_row;
end;
$$;

-- Admin booking-chat send must not reopen "support" on the order.
create or replace function public.admin_send_order_message(
  p_order_id uuid,
  p_body text
)
returns public.order_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_body text := trim(coalesce(p_body, ''));
  v_row public.order_messages%rowtype;
begin
  if v_admin is null or not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;

  if char_length(v_body) = 0 then
    raise exception 'أدخل نص الرسالة';
  end if;

  if not exists (select 1 from public.orders where id = p_order_id) then
    raise exception 'الطلب غير موجود';
  end if;

  insert into public.order_messages (order_id, sender_id, body, sender_role)
  values (p_order_id, v_admin, v_body, 'admin')
  returning * into v_row;

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7) Realtime + grants
-- ---------------------------------------------------------------------------
do $$
begin
  execute 'alter table public.support_ticket_messages replica identity full';
exception
  when others then
    raise notice 'replica identity skipped: %', SQLERRM;
end $$;

do $$
begin
  begin
    execute 'alter publication supabase_realtime add table public.support_ticket_messages';
  exception
    when duplicate_object then null;
    when undefined_object then
      raise notice 'supabase_realtime missing — skip support_ticket_messages';
  end;
end $$;

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
        'list_ticket_messages',
        'send_ticket_message',
        'admin_open_ticket_channel',
        'admin_resolve_support_ticket',
        'admin_set_support_ticket_status',
        'admin_open_support_thread',
        'admin_send_order_message',
        '_support_ticket_json',
        '_ticket_message_json',
        '_notify_support_ticket_parties',
        '_current_can_access_ticket'
      )
  loop
    execute format('revoke all on function %s from public', r.sig);
    execute format('revoke all on function %s from anon', r.sig);
    if r.proname in (
      'list_my_support_tickets',
      'get_support_ticket',
      'list_ticket_messages',
      'send_ticket_message',
      'admin_open_ticket_channel',
      'admin_resolve_support_ticket',
      'admin_set_support_ticket_status',
      'admin_open_support_thread',
      'admin_send_order_message'
    ) then
      execute format('grant execute on function %s to authenticated', r.sig);
    else
      execute format('revoke all on function %s from authenticated', r.sig);
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';

select '68_support_ticket_channel.sql applied' as status;
