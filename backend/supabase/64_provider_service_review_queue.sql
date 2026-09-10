-- =============================================================================
-- 64_provider_service_review_queue.sql
-- Separate pending *service* reviews from identity verification.
-- - pending_service_reviews on admin_dashboard_stats
-- - admin_inbox inbound notify when a service becomes pending
-- - category_name_ar (name_ar) on admin_list_service_reviews
-- - provider notify after review no longer swallowed
-- - REVOKE EXECUTE from anon on admin RPCs
-- Does NOT delete provider_services rows.
-- Safe to re-run. Prerequisites: 35, 45, 51, 57.
-- =============================================================================

do $$
begin
  if to_regclass('public.provider_services') is null then
    raise exception 'public.provider_services missing — run 09 then 57 first';
  end if;
  if to_regprocedure('public.is_admin()') is null then
    raise exception 'public.is_admin() missing — run 17_admin_role_patch.sql first';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) Resolve stored filter (e.g. طلبة) to human name_ar (e.g. عامل بناء)
-- ---------------------------------------------------------------------------
create or replace function public._service_category_name_ar(p_stored text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select c.name_ar
      from public.service_categories c
      where c.filter_ar is not distinct from p_stored
         or c.name_ar is not distinct from p_stored
         or c.slug is not distinct from p_stored
      order by
        case
          when c.filter_ar is not distinct from p_stored then 0
          when c.name_ar is not distinct from p_stored then 1
          else 2
        end
      limit 1
    ),
    p_stored
  );
$$;

revoke all on function public._service_category_name_ar(text) from public;
revoke all on function public._service_category_name_ar(text) from anon;

-- ---------------------------------------------------------------------------
-- 2) Inbound admin inbox (not the SQL 45/46 admin→user broadcast tables)
-- ---------------------------------------------------------------------------
create table if not exists public.admin_inbox (
  id uuid primary key default gen_random_uuid(),
  kind text not null,
  title text not null,
  body text not null,
  entity_type text,
  entity_id text,
  provider_id uuid,
  service_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_admin_inbox_created
  on public.admin_inbox (created_at desc);

create index if not exists idx_admin_inbox_unread
  on public.admin_inbox (created_at desc)
  where is_read = false;

create unique index if not exists uq_admin_inbox_unread_service_pending
  on public.admin_inbox (service_id)
  where kind = 'service_review_pending'
    and is_read = false
    and service_id is not null;

comment on table public.admin_inbox is
  'Inbound admin notifications (service pending, etc). Distinct from admin_notify_* outbound tables.';

alter table public.admin_inbox enable row level security;

drop policy if exists "Admins read admin_inbox" on public.admin_inbox;
create policy "Admins read admin_inbox"
  on public.admin_inbox for select
  to authenticated
  using (public.is_admin());

drop policy if exists "Admins update admin_inbox" on public.admin_inbox;
create policy "Admins update admin_inbox"
  on public.admin_inbox for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

grant select, update on table public.admin_inbox to authenticated;
revoke insert, delete on table public.admin_inbox from authenticated;
revoke all on table public.admin_inbox from anon;

create or replace function public.provider_services_notify_admin_pending()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_provider text;
  v_cat text;
  v_label text;
begin
  if new.verification_status is distinct from 'pending' then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.verification_status is not distinct from 'pending' then
    return new;
  end if;

  select p.full_name into v_provider
  from public.profiles p
  where p.id = new.provider_id;

  v_cat := public._service_category_name_ar(new.category);
  v_label := coalesce(nullif(trim(new.title), ''), v_cat, 'خدمة');

  insert into public.admin_inbox (
    kind, title, body, entity_type, entity_id, provider_id, service_id
  ) values (
    'service_review_pending',
    'خدمة بانتظار المراجعة',
    coalesce(nullif(trim(v_provider), ''), 'مزود')
      || ' — «' || v_label || '»',
    'provider_service',
    new.id::text,
    new.provider_id,
    new.id
  )
  on conflict (service_id)
    where kind = 'service_review_pending'
      and is_read = false
      and service_id is not null
  do nothing;

  return new;
end;
$$;

drop trigger if exists trg_provider_services_notify_admin_pending
  on public.provider_services;
create trigger trg_provider_services_notify_admin_pending
after insert or update on public.provider_services
for each row
execute function public.provider_services_notify_admin_pending();

-- Backfill unread inbox for already-pending services (do not delete rows).
insert into public.admin_inbox (
  kind, title, body, entity_type, entity_id, provider_id, service_id
)
select
  'service_review_pending',
  'خدمة بانتظار المراجعة',
  coalesce(nullif(trim(p.full_name), ''), 'مزود')
    || ' — «'
    || coalesce(nullif(trim(s.title), ''), public._service_category_name_ar(s.category), 'خدمة')
    || '»',
  'provider_service',
  s.id::text,
  s.provider_id,
  s.id
from public.provider_services s
left join public.profiles p on p.id = s.provider_id
where s.verification_status = 'pending'
  and not exists (
    select 1
    from public.admin_inbox i
    where i.service_id = s.id
      and i.kind = 'service_review_pending'
      and i.is_read = false
  );

create or replace function public.admin_list_inbox(p_limit int default 50)
returns table (
  id uuid,
  kind text,
  title text,
  body text,
  entity_type text,
  entity_id text,
  provider_id uuid,
  service_id uuid,
  is_read boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;
  return query
  select
    i.id,
    i.kind,
    i.title,
    i.body,
    i.entity_type,
    i.entity_id,
    i.provider_id,
    i.service_id,
    i.is_read,
    i.created_at
  from public.admin_inbox i
  order by i.is_read asc, i.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
end;
$$;

create or replace function public.admin_mark_inbox_read(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;
  update public.admin_inbox
  set is_read = true
  where id = p_id;
end;
$$;

create or replace function public.admin_mark_inbox_kind_read(p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;
  update public.admin_inbox
  set is_read = true
  where kind = p_kind
    and is_read = false;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Dashboard stats: pending services counted separately from identity
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
      where lower(coalesce(status, '')) not in ('completed', 'paid', 'cancelled', 'canceled')
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
    count(*) filter (
      where coalesce(support_open, false) = true
        or coalesce(notes, '') ilike '%نزاع%'
        or coalesce(notes, '') ilike '%شكوى%'
        or coalesce(notes, '') ilike '%dispute%'
    )
  into
    v_active, v_pending, v_negotiating, v_completed, v_cancelled,
    v_revenue, v_support_open
  from public.orders;

  select
    count(*) filter (where role = 'customer'),
    count(*) filter (where role = 'provider'),
    count(*) filter (where role = 'provider' and coalesce(is_verified, false)),
    count(*) filter (where role = 'provider' and not coalesce(is_verified, false)),
    count(*) filter (where coalesce(is_suspended, false)),
    count(*) filter (where role in ('customer', 'provider')),
    count(*) filter (
      where role = 'provider'
        and created_at >= (now() - interval '30 days')
    )
  into
    v_customers, v_providers, v_verified_providers, v_pending_verification,
    v_suspended, v_total_users, v_new_providers_30d
  from public.profiles;

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
    and coalesce(verification_status, 'approved') = 'approved';

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
-- 4) Admin list: human category name; keep stored category for filters
-- ---------------------------------------------------------------------------
drop function if exists public.admin_list_service_reviews(text, int);

create function public.admin_list_service_reviews(
  p_status text default 'pending',
  p_limit int default 100
)
returns table (
  id uuid,
  provider_id uuid,
  title text,
  description text,
  category text,
  category_name_ar text,
  price_from numeric,
  price_to numeric,
  city text,
  is_active boolean,
  created_at timestamptz,
  provider_name text,
  provider_phone text,
  verification_status text,
  rejection_reason text,
  proof_note text,
  proof_paths text[],
  reviewed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_status text := lower(trim(coalesce(p_status, 'pending')));
begin
  if not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;
  if v_status not in ('pending', 'approved', 'rejected', 'disabled', 'all') then
    v_status := 'pending';
  end if;

  return query
  select
    s.id,
    s.provider_id,
    s.title,
    s.description,
    s.category,
    public._service_category_name_ar(s.category),
    s.price_from,
    s.price_to,
    s.city,
    coalesce(s.is_active, true),
    s.created_at,
    p.full_name,
    p.phone,
    s.verification_status,
    s.rejection_reason,
    s.proof_note,
    s.proof_paths,
    s.reviewed_at
  from public.provider_services s
  left join public.profiles p on p.id = s.provider_id
  where v_status = 'all' or s.verification_status = v_status
  order by
    case s.verification_status
      when 'pending' then 0
      when 'rejected' then 1
      when 'disabled' then 2
      else 3
    end,
    s.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
end;
$$;

drop function if exists public.admin_list_provider_services(int);

create function public.admin_list_provider_services(p_limit int default 100)
returns table (
  id uuid,
  provider_id uuid,
  title text,
  description text,
  category text,
  category_name_ar text,
  price_from numeric,
  price_to numeric,
  city text,
  district text,
  is_active boolean,
  admin_hidden boolean,
  admin_note text,
  created_at timestamptz,
  provider_name text,
  verification_status text,
  rejection_reason text,
  proof_note text,
  proof_paths text[],
  reviewed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;
  return query
  select
    s.id,
    s.provider_id,
    s.title,
    s.description,
    s.category,
    public._service_category_name_ar(s.category),
    s.price_from,
    s.price_to,
    s.city,
    s.district,
    coalesce(s.is_active, true),
    coalesce(s.admin_hidden, false),
    s.admin_note,
    s.created_at,
    p.full_name,
    s.verification_status,
    s.rejection_reason,
    s.proof_note,
    s.proof_paths,
    s.reviewed_at
  from public.provider_services s
  left join public.profiles p on p.id = s.provider_id
  order by s.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Review RPC: notify provider via SQL 45 send path; raise on failure
-- ---------------------------------------------------------------------------
create or replace function public.admin_review_provider_service(
  p_service_id uuid,
  p_action text,
  p_reason text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.provider_services%rowtype;
  v_action text := lower(trim(coalesce(p_action, '')));
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_title text;
  v_body text;
  v_cat text;
begin
  if not public.is_admin() then
    raise exception 'صلاحية المشرف مطلوبة';
  end if;
  if v_action not in ('approve', 'reject', 'disable') then
    raise exception 'إجراء غير صالح';
  end if;
  if v_action = 'reject' and v_reason is null then
    raise exception 'أدخل سبب الرفض';
  end if;

  if v_action = 'approve' then
    update public.provider_services
    set
      verification_status = 'approved',
      rejection_reason = null,
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      is_active = true,
      admin_hidden = false
    where id = p_service_id
    returning * into v_row;
  elsif v_action = 'reject' then
    update public.provider_services
    set
      verification_status = 'rejected',
      rejection_reason = v_reason,
      reviewed_at = now(),
      reviewed_by = auth.uid()
    where id = p_service_id
    returning * into v_row;
  else
    update public.provider_services
    set
      verification_status = 'disabled',
      rejection_reason = coalesce(v_reason, rejection_reason),
      reviewed_at = now(),
      reviewed_by = auth.uid()
    where id = p_service_id
    returning * into v_row;
  end if;

  if not found then
    raise exception 'الخدمة غير موجودة';
  end if;

  insert into public.admin_audit_log (admin_id, action, entity_type, entity_id, meta)
  values (
    auth.uid(),
    'service_verification_' || v_action,
    'provider_service',
    v_row.id::text,
    json_build_object(
      'verification_status', v_row.verification_status,
      'category', v_row.category,
      'reason', v_row.rejection_reason
    )
  );

  update public.admin_inbox
  set is_read = true
  where service_id = v_row.id
    and kind = 'service_review_pending'
    and is_read = false;

  v_cat := coalesce(
    public._service_category_name_ar(v_row.category),
    v_row.category,
    v_row.title
  );

  if v_action = 'approve' then
    v_title := 'تم توثيق خدمتك';
    v_body := 'وافقت الإدارة على تصنيف «'
      || v_cat
      || '». سيظهر للعملاء مع شارة موثّق.';
  elsif v_action = 'reject' then
    v_title := 'رُفض طلب توثيق الخدمة';
    v_body := 'رُفض تصنيف «'
      || v_cat
      || '». السبب: '
      || coalesce(v_row.rejection_reason, '—')
      || '. يمكنك تعديل الإثبات وإعادة الإرسال.';
  else
    v_title := 'تم تعطيل التصنيف';
    v_body := 'عطّلت الإدارة تصنيف «'
      || v_cat
      || '» ولن يظهر للعملاء. حسابك ما زال فعّالاً.';
  end if;

  if to_regprocedure('public.admin_send_to_provider_one(uuid, text, text)') is not null then
    perform public.admin_send_to_provider_one(
      v_row.provider_id, v_title, v_body
    );
  elsif to_regclass('public.admin_notify_provider_one') is not null then
    insert into public.admin_notify_provider_one (
      recipient_id, title, body, admin_id
    ) values (
      v_row.provider_id, v_title, v_body, auth.uid()
    );
  else
    raise exception 'تعذّر إشعار المزود: جدول/دالة الإشعار غير موجودة';
  end if;

  return json_build_object(
    'id', v_row.id,
    'verification_status', v_row.verification_status,
    'rejection_reason', v_row.rejection_reason,
    'reviewed_at', v_row.reviewed_at
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 6) REVOKE anon; keep authenticated + is_admin() inside functions
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
        'admin_list_service_reviews',
        'admin_review_provider_service',
        'admin_list_provider_services',
        'admin_dashboard_stats',
        'admin_list_inbox',
        'admin_mark_inbox_read',
        'admin_mark_inbox_kind_read',
        '_service_category_name_ar'
      )
  loop
    execute format('revoke all on function %s from public', r.sig);
    execute format('revoke all on function %s from anon', r.sig);
    if r.proname <> '_service_category_name_ar' then
      execute format('grant execute on function %s to authenticated', r.sig);
    end if;
  end loop;
end $$;

select '64_provider_service_review_queue.sql applied' as status;
