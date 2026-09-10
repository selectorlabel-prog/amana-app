-- =============================================================================
-- 66_support_tickets.sql
-- User-filed support tickets (customer | provider) — not a third chat.
-- - Table public.support_tickets
-- - One open/in_progress ticket per (opener, order_id) when order_id is set
-- - Inbox: extend SQL 64 admin_inbox kind = support_ticket (no new notify table)
-- - KPI: dispute_like_orders = open_support_tickets (open | in_progress)
--   Do NOT count cancelled/completed orders.support_open as the KPI
-- - admin_open_support_thread: set linked tickets in_progress; do NOT append «نزاع»
--   into order notes. Order chat bodies still must not spam user_notifications (SQL 56)
-- Does NOT delete order rows. Does NOT mass-clear support_open flags.
-- Safe to re-run. Prerequisites: 17, 30, 41/45, 56, 64, 65.
-- =============================================================================

do $$
begin
  if to_regprocedure('public.is_admin()') is null then
    raise exception 'public.is_admin() missing — run 17_admin_role_patch.sql first';
  end if;
  if to_regclass('public.orders') is null then
    raise exception 'public.orders missing';
  end if;
  if to_regclass('public.admin_inbox') is null then
    raise exception 'public.admin_inbox missing — run 64_provider_service_review_queue.sql first';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) Table
-- ---------------------------------------------------------------------------
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  opener_id uuid not null references public.profiles (id),
  opener_role text not null,
  order_id uuid references public.orders (id) on delete set null,
  subject text not null,
  body text not null,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_tickets_opener_role_check
    check (lower(opener_role) in ('customer', 'provider')),
  constraint support_tickets_status_check
    check (lower(status) in ('open', 'in_progress', 'resolved'))
);

create index if not exists idx_support_tickets_opener_created
  on public.support_tickets (opener_id, created_at desc);

create index if not exists idx_support_tickets_status_created
  on public.support_tickets (status, created_at desc);

create index if not exists idx_support_tickets_order
  on public.support_tickets (order_id)
  where order_id is not null;

create unique index if not exists uq_support_tickets_open_per_order
  on public.support_tickets (opener_id, order_id)
  where order_id is not null
    and status in ('open', 'in_progress');

comment on table public.support_tickets is
  'User-filed support tickets. Not a chat. One open/in_progress row per opener+order.';

comment on column public.support_tickets.status is
  'open | in_progress | resolved. Not auto-closed when the order completes.';

create unique index if not exists uq_admin_inbox_unread_support_ticket
  on public.admin_inbox (entity_id)
  where kind = 'support_ticket'
    and is_read = false
    and entity_id is not null;

create or replace function public.tg_support_tickets_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_support_tickets_updated_at on public.support_tickets;
create trigger trg_support_tickets_updated_at
before update on public.support_tickets
for each row
execute function public.tg_support_tickets_set_updated_at();

alter table public.support_tickets enable row level security;

drop policy if exists "Openers select own support tickets" on public.support_tickets;
create policy "Openers select own support tickets"
  on public.support_tickets for select
  to authenticated
  using (opener_id = auth.uid());

drop policy if exists "Openers insert own support tickets" on public.support_tickets;
create policy "Openers insert own support tickets"
  on public.support_tickets for insert
  to authenticated
  with check (
    opener_id = auth.uid()
    and lower(opener_role) in ('customer', 'provider')
  );

drop policy if exists "Admins select support tickets" on public.support_tickets;
create policy "Admins select support tickets"
  on public.support_tickets for select
  to authenticated
  using (public.is_admin());

drop policy if exists "Admins update support tickets" on public.support_tickets;
create policy "Admins update support tickets"
  on public.support_tickets for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

grant select, insert on table public.support_tickets to authenticated;
revoke update, delete on table public.support_tickets from authenticated;
revoke all on table public.support_tickets from anon;

-- ---------------------------------------------------------------------------
-- 2) Helpers
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
    'created_at', t.created_at,
    'updated_at', t.updated_at,
    'service_name', o.service_name,
    'order_status', o.status,
    'opener_name', p.full_name,
    'customer_id', o.customer_id,
    'provider_id', o.provider_id,
    'customer_name', c.full_name,
    'provider_name', pr.full_name
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

create or replace function public._notify_support_ticket_opener(
  p_opener_id uuid,
  p_opener_role text,
  p_title text,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := lower(trim(coalesce(p_opener_role, '')));
  v_title text := left(trim(coalesce(p_title, '')), 120);
  v_body text := left(trim(coalesce(p_body, '')), 2000);
begin
  if p_opener_id is null then
    return;
  end if;
  if char_length(v_title) = 0 then
    v_title := 'تحديث تذكرة الدعم';
  end if;
  if char_length(v_body) = 0 then
    v_body := v_title;
  end if;

  begin
    if v_role = 'provider'
       and to_regprocedure('public.admin_send_to_provider_one(uuid, text, text)') is not null then
      perform public.admin_send_to_provider_one(p_opener_id, v_title, v_body);
      return;
    end if;
    if v_role = 'customer'
       and to_regprocedure('public.admin_send_to_customer_one(uuid, text, text)') is not null then
      perform public.admin_send_to_customer_one(p_opener_id, v_title, v_body);
      return;
    end if;
  exception
    when others then
      raise notice 'admin_notify one-to-one skipped: %', SQLERRM;
  end;

  if to_regprocedure(
       'public._insert_user_notification(uuid, text, text, text, jsonb)'
     ) is not null then
    perform public._insert_user_notification(
      p_opener_id, v_title, v_body, 'admin_message',
      jsonb_build_object('source', 'support_ticket')
    );
  end if;
end;
$$;

revoke all on function public._notify_support_ticket_opener(uuid, text, text, text)
  from public;
revoke all on function public._notify_support_ticket_opener(uuid, text, text, text)
  from anon;

-- ---------------------------------------------------------------------------
-- 3) User RPCs
-- ---------------------------------------------------------------------------
create or replace function public.open_my_support_ticket(
  p_order_id uuid default null,
  p_subject text default null,
  p_body text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_subject text := left(trim(coalesce(p_subject, '')), 120);
  v_body text := left(trim(coalesce(p_body, '')), 2000);
  v_order public.orders%rowtype;
  v_existing public.support_tickets%rowtype;
  v_row public.support_tickets%rowtype;
  v_name text;
  v_json json;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول لفتح تذكرة';
  end if;

  if to_regprocedure('public.is_current_user_suspended()') is not null
     and public.is_current_user_suspended() then
    raise exception 'حسابك موقوف';
  end if;

  if char_length(v_subject) < 2 then
    raise exception 'أدخل موضوع التذكرة';
  end if;
  if char_length(v_body) < 4 then
    raise exception 'أدخل تفاصيل التذكرة';
  end if;

  select p.role, p.full_name
    into v_role, v_name
  from public.profiles p
  where p.id = v_uid;

  if not found then
    raise exception 'الملف الشخصي غير موجود';
  end if;

  v_role := lower(trim(coalesce(v_role, '')));

  if p_order_id is not null then
    select * into v_order
    from public.orders
    where id = p_order_id;

    if not found then
      raise exception 'الطلب غير موجود';
    end if;

    if v_order.customer_id is distinct from v_uid
       and v_order.provider_id is distinct from v_uid then
      raise exception 'لست طرفاً في هذا الطلب';
    end if;

    if v_role not in ('customer', 'provider') then
      if v_order.customer_id = v_uid then
        v_role := 'customer';
      else
        v_role := 'provider';
      end if;
    end if;

    select * into v_existing
    from public.support_tickets t
    where t.opener_id = v_uid
      and t.order_id = p_order_id
      and t.status in ('open', 'in_progress')
    order by t.created_at desc
    limit 1;

    if found then
      v_json := public._support_ticket_json(v_existing.id);
      return (v_json::jsonb || jsonb_build_object('reused', true))::json;
    end if;
  else
    if v_role not in ('customer', 'provider') then
      raise exception 'يجب أن تكون عميلاً أو مزوداً لفتح تذكرة';
    end if;
  end if;

  begin
    insert into public.support_tickets (
      opener_id, opener_role, order_id, subject, body, status
    ) values (
      v_uid, v_role, p_order_id, v_subject, v_body, 'open'
    )
    returning * into v_row;
  exception
    when unique_violation then
      select * into v_existing
      from public.support_tickets t
      where t.opener_id = v_uid
        and t.order_id is not distinct from p_order_id
        and t.status in ('open', 'in_progress')
      order by t.created_at desc
      limit 1;
      if found then
        v_json := public._support_ticket_json(v_existing.id);
        return (v_json::jsonb || jsonb_build_object('reused', true))::json;
      end if;
      raise;
  end;

  insert into public.admin_inbox (
    kind, title, body, entity_type, entity_id, provider_id
  ) values (
    'support_ticket',
    'تذكرة دعم جديدة',
    coalesce(nullif(trim(v_name), ''), case when v_role = 'provider' then 'مزود' else 'عميل' end)
      || ' — «' || v_subject || '»',
    'support_ticket',
    v_row.id::text,
    case when v_role = 'provider' then v_uid else null end
  )
  on conflict (entity_id)
    where kind = 'support_ticket'
      and is_read = false
      and entity_id is not null
  do nothing;

  v_json := public._support_ticket_json(v_row.id);
  return (v_json::jsonb || jsonb_build_object('reused', false))::json;
end;
$$;

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
      where t.opener_id = v_uid
    ),
    '[]'::json
  );
end;
$$;

revoke all on function public.open_my_support_ticket(uuid, text, text) from public;
revoke all on function public.open_my_support_ticket(uuid, text, text) from anon;
grant execute on function public.open_my_support_ticket(uuid, text, text)
  to authenticated;

revoke all on function public.list_my_support_tickets() from public;
revoke all on function public.list_my_support_tickets() from anon;
grant execute on function public.list_my_support_tickets() to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Admin RPCs
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_support_tickets(
  p_status text default null
)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_status text := lower(trim(coalesce(p_status, '')));
begin
  if not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;

  if v_status in ('', 'all') then
    v_status := null;
  elsif v_status not in ('open', 'in_progress', 'resolved') then
    raise exception 'حالة التذكرة غير صالحة';
  end if;

  return coalesce(
    (
      select json_agg(public._support_ticket_json(t.id) order by t.created_at desc)
      from public.support_tickets t
      where v_status is null or t.status = v_status
    ),
    '[]'::json
  );
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
  v_title text;
  v_body text;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;

  if v_status not in ('open', 'in_progress', 'resolved') then
    raise exception 'حالة التذكرة غير صالحة';
  end if;

  update public.support_tickets
  set status = v_status
  where id = p_id
  returning * into v_row;

  if not found then
    raise exception 'التذكرة غير موجودة';
  end if;

  if v_status = 'resolved' then
    update public.admin_inbox
    set is_read = true
    where kind = 'support_ticket'
      and entity_id = p_id::text
      and is_read = false;
    v_title := 'تم حل تذكرة الدعم';
    v_body := 'أغلقت الإدارة تذكرتك «' || v_row.subject || '».';
  elsif v_status = 'in_progress' then
    v_title := 'جاري معالجة تذكرة الدعم';
    v_body := 'بدأت الإدارة معالجة تذكرتك «' || v_row.subject || '».';
  else
    v_title := 'تحديث تذكرة الدعم';
    v_body := 'أُعيد فتح تذكرتك «' || v_row.subject || '».';
  end if;

  perform public._notify_support_ticket_opener(
    v_row.opener_id, v_row.opener_role, v_title, v_body
  );

  return (
    public._support_ticket_json(v_row.id)::jsonb
    || jsonb_build_object('reused', false)
  )::json;
end;
$$;

-- Open order support chat without writing «نزاع» into notes.
-- Linked tickets for that order move to in_progress; opener is notified.
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
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_body text;
  t record;
begin
  if v_admin is null or not public.is_admin() then
    raise exception 'admin only';
  end if;

  select * into v_row
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'الطلب غير موجود';
  end if;

  update public.orders
  set support_open = true
  where id = p_order_id
  returning * into v_row;

  v_body := coalesce(
    'فتح قناة دعم من المشرف'
      || case when v_note is null then '' else ': ' || v_note end,
    'فتح قناة دعم من المشرف'
  );

  insert into public.order_messages (order_id, sender_id, body, sender_role)
  values (p_order_id, v_admin, v_body, 'admin');

  for t in
    select id, opener_id, opener_role, subject, status
    from public.support_tickets
    where order_id = p_order_id
      and status in ('open', 'in_progress')
  loop
    if t.status = 'open' then
      update public.support_tickets
      set status = 'in_progress'
      where id = t.id;
    end if;
    perform public._notify_support_ticket_opener(
      t.opener_id,
      t.opener_role,
      'رد الإدارة على تذكرة الدعم',
      'فتحت الإدارة محادثة دعم بخصوص تذكرتك «' || t.subject || '».'
    );
  end loop;

  return v_row;
end;
$$;

revoke all on function public.admin_list_support_tickets(text) from public;
revoke all on function public.admin_list_support_tickets(text) from anon;
grant execute on function public.admin_list_support_tickets(text) to authenticated;

revoke all on function public.admin_set_support_ticket_status(uuid, text) from public;
revoke all on function public.admin_set_support_ticket_status(uuid, text) from anon;
grant execute on function public.admin_set_support_ticket_status(uuid, text)
  to authenticated;

revoke all on function public.admin_open_support_thread(uuid, text) from public;
revoke all on function public.admin_open_support_thread(uuid, text) from anon;
grant execute on function public.admin_open_support_thread(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Dashboard KPI = open | in_progress tickets (not leftover support_open)
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
  v_open_tickets int;
  v_reviews int;
  v_avg_rating numeric;
  v_commission_earned numeric;
  v_services_active int;
  v_new_providers_30d int;
  v_pending_service_reviews int;
  v_unread_admin_inbox int;
  v_unread_support_ticket_inbox int;
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
    ), 0)
  into
    v_active, v_pending, v_negotiating, v_completed, v_cancelled, v_revenue
  from public.orders;

  select count(*)
  into v_open_tickets
  from public.support_tickets
  where status in ('open', 'in_progress');

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

  select count(*)
  into v_services_active
  from public.provider_services
  where coalesce(is_active, true) = true
    and coalesce(admin_hidden, false) = false
    and verification_status = 'approved';

  select count(*)
  into v_pending_service_reviews
  from public.provider_services
  where verification_status = 'pending';

  select count(*)
  into v_unread_admin_inbox
  from public.admin_inbox
  where is_read = false;

  select count(*)
  into v_unread_support_ticket_inbox
  from public.admin_inbox
  where is_read = false
    and kind = 'support_ticket';

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
    'unread_support_ticket_inbox', coalesce(v_unread_support_ticket_inbox, 0),
    'suspended_users', coalesce(v_suspended, 0),
    'total_users', coalesce(v_total_users, 0),
    'open_support_tickets', coalesce(v_open_tickets, 0),
    'dispute_like_orders', coalesce(v_open_tickets, 0),
    'new_providers', coalesce(v_new_providers_30d, 0),
    'reviews_count', coalesce(v_reviews, 0),
    'avg_rating', coalesce(v_avg_rating, 0),
    'commission_earned', coalesce(v_commission_earned, 0),
    'services_active', coalesce(v_services_active, 0)
  );
end;
$$;

revoke all on function public.admin_dashboard_stats() from public;
revoke all on function public.admin_dashboard_stats() from anon;
grant execute on function public.admin_dashboard_stats() to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Realtime + grants
-- ---------------------------------------------------------------------------
do $$
begin
  execute 'alter table public.support_tickets replica identity full';
exception
  when others then
    raise notice 'replica identity skipped: %', SQLERRM;
end $$;

do $$
begin
  begin
    execute 'alter publication supabase_realtime add table public.support_tickets';
  exception
    when duplicate_object then null;
    when undefined_object then
      raise notice 'supabase_realtime missing — skip support_tickets';
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
        'open_my_support_ticket',
        'list_my_support_tickets',
        'admin_list_support_tickets',
        'admin_set_support_ticket_status',
        'admin_open_support_thread',
        'admin_dashboard_stats',
        '_support_ticket_json',
        '_notify_support_ticket_opener',
        'tg_support_tickets_set_updated_at'
      )
  loop
    execute format('revoke all on function %s from public', r.sig);
    execute format('revoke all on function %s from anon', r.sig);
    if r.proname in (
      'open_my_support_ticket',
      'list_my_support_tickets',
      'admin_list_support_tickets',
      'admin_set_support_ticket_status',
      'admin_open_support_thread',
      'admin_dashboard_stats'
    ) then
      execute format('grant execute on function %s to authenticated', r.sig);
    else
      execute format('revoke all on function %s from authenticated', r.sig);
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';

select '66_support_tickets.sql applied' as status;
