-- =============================================================================
-- 67_provider_portfolio.sql
-- Provider «معرض الأعمال»: public gallery of photos the provider uploads.
-- - Table public.provider_portfolio_items (max 12 per provider)
-- - Storage: existing avatars bucket, path {userId}/portfolio/{file}
--   Do NOT create a fourth bucket.
--   Do NOT copy service-proofs or order-attachments into this gallery.
-- - Public/authenticated SELECT: is_hidden = false and provider not suspended
-- - Customer thumbs: list_provider_portfolio / list_provider_portfolio_thumbs
-- - Admin: hide only (is_hidden). No moderation queue. No row deletes.
-- Safe to re-run. Prerequisites: 09, 15, 17, 19, 41 (is_suspended), 57.
-- =============================================================================

do $$
begin
  if to_regclass('public.profiles') is null then
    raise exception 'public.profiles missing';
  end if;
  if to_regclass('public.provider_services') is null then
    raise exception 'public.provider_services missing — run 09 then 57 first';
  end if;
  if to_regprocedure('public.is_admin()') is null then
    raise exception 'public.is_admin() missing — run 17_admin_role_patch.sql first';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) Table
-- ---------------------------------------------------------------------------
create table if not exists public.provider_portfolio_items (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.profiles (id) on delete cascade,
  service_id uuid references public.provider_services (id) on delete set null,
  title text not null,
  caption text,
  storage_path text not null,
  url text not null,
  sort_order int not null default 0,
  is_hidden boolean not null default false,
  created_at timestamptz not null default now(),
  constraint provider_portfolio_items_title_nonempty
    check (char_length(trim(title)) > 0),
  constraint provider_portfolio_items_title_len
    check (char_length(title) <= 120),
  constraint provider_portfolio_items_caption_len
    check (caption is null or char_length(caption) <= 500),
  constraint provider_portfolio_items_url_nonempty
    check (char_length(trim(url)) > 0),
  constraint provider_portfolio_items_path_nonempty
    check (char_length(trim(storage_path)) > 0)
);

create index if not exists idx_provider_portfolio_provider_sort
  on public.provider_portfolio_items (provider_id, sort_order, created_at);

create index if not exists idx_provider_portfolio_visible
  on public.provider_portfolio_items (provider_id, sort_order)
  where is_hidden = false;

comment on table public.provider_portfolio_items is
  'Provider-uploaded public gallery. Max 12. Not service-proofs or order attachments.';

comment on column public.provider_portfolio_items.storage_path is
  'Must be {provider_id}/portfolio/... inside the avatars bucket.';

comment on column public.provider_portfolio_items.service_id is
  'Optional FK to an approved provider_services row owned by the same provider.';

comment on column public.provider_portfolio_items.is_hidden is
  'Admin hide from customers. Does not delete the row or storage object.';

-- ---------------------------------------------------------------------------
-- 2) Guards: max 12, approved own service, portfolio folder only
-- ---------------------------------------------------------------------------
create or replace function public.tg_provider_portfolio_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_svc public.provider_services%rowtype;
begin
  -- Admin hide/unhide only (no deletes). Skip owner-path checks.
  if tg_op = 'UPDATE' and public.is_admin() then
    new.provider_id := old.provider_id;
    new.storage_path := old.storage_path;
    new.url := old.url;
    new.service_id := old.service_id;
    new.created_at := old.created_at;
    return new;
  end if;

  if new.provider_id is distinct from auth.uid() then
    raise exception 'لا يمكنك تعديل معرض مزود آخر';
  end if;

  new.title := trim(coalesce(new.title, ''));
  new.caption := nullif(trim(coalesce(new.caption, '')), '');
  new.storage_path := trim(coalesce(new.storage_path, ''));
  new.url := trim(coalesce(new.url, ''));

  if new.title = '' then
    raise exception 'أدخل عنوان العمل';
  end if;
  if new.storage_path = '' or new.url = '' then
    raise exception 'صورة العمل مطلوبة';
  end if;

  -- Refuse service-proofs / order-attachments / avatar root copies.
  if split_part(new.storage_path, '/', 1) is distinct from new.provider_id::text
     or split_part(new.storage_path, '/', 2) is distinct from 'portfolio' then
    raise exception 'معرض الأعمال يُحفظ في مجلد المزود/portfolio فقط';
  end if;

  if position('/service-proofs/' in new.url) > 0
     or position('/order-attachments/' in new.url) > 0
     or position('/verification/' in new.url) > 0 then
    raise exception 'لا يُسمح بنسخ إثباتات الخدمة أو مرفقات الطلب إلى المعرض';
  end if;

  if new.service_id is not null then
    select * into v_svc
    from public.provider_services s
    where s.id = new.service_id;
    if not found then
      raise exception 'الخدمة غير موجودة';
    end if;
    if v_svc.provider_id is distinct from new.provider_id then
      raise exception 'اربط العمل بفئة من خدماتك فقط';
    end if;
    if coalesce(v_svc.verification_status, '') is distinct from 'approved' then
      raise exception 'اربط العمل بفئة معتمدة فقط';
    end if;
  end if;

  if tg_op = 'INSERT' then
    select count(*) into v_count
    from public.provider_portfolio_items
    where provider_id = new.provider_id;
    if coalesce(v_count, 0) >= 12 then
      raise exception 'الحد الأقصى 12 عملاً في المعرض';
    end if;
    if new.sort_order is null or new.sort_order = 0 then
      select coalesce(max(sort_order), -1) + 1 into new.sort_order
      from public.provider_portfolio_items
      where provider_id = new.provider_id;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_provider_portfolio_guard on public.provider_portfolio_items;
create trigger trg_provider_portfolio_guard
before insert or update on public.provider_portfolio_items
for each row
execute function public.tg_provider_portfolio_guard();

-- ---------------------------------------------------------------------------
-- 3) RLS
-- ---------------------------------------------------------------------------
alter table public.provider_portfolio_items enable row level security;

drop policy if exists "Providers manage own portfolio" on public.provider_portfolio_items;
create policy "Providers manage own portfolio"
  on public.provider_portfolio_items
  for all
  to authenticated
  using (provider_id = auth.uid())
  with check (provider_id = auth.uid());

drop policy if exists "Public read visible portfolio" on public.provider_portfolio_items;
create policy "Public read visible portfolio"
  on public.provider_portfolio_items
  for select
  to anon, authenticated
  using (
    is_hidden = false
    and exists (
      select 1
      from public.profiles p
      where p.id = provider_id
        and coalesce(p.role, '') = 'provider'
        and coalesce(p.is_suspended, false) = false
    )
  );

drop policy if exists "Admins read all portfolio" on public.provider_portfolio_items;
create policy "Admins read all portfolio"
  on public.provider_portfolio_items
  for select
  to authenticated
  using (public.is_admin());

drop policy if exists "Admins hide portfolio items" on public.provider_portfolio_items;
create policy "Admins hide portfolio items"
  on public.provider_portfolio_items
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

grant select, insert, update, delete on table public.provider_portfolio_items
  to authenticated;
grant select on table public.provider_portfolio_items to anon;
revoke insert, update, delete on table public.provider_portfolio_items from anon;

-- ---------------------------------------------------------------------------
-- 4) Customer RPCs (visible items only)
-- ---------------------------------------------------------------------------
drop function if exists public.list_provider_portfolio(uuid, int);
drop function if exists public.list_provider_portfolio(uuid);

create function public.list_provider_portfolio(
  p_provider_id uuid,
  p_limit int default 12
)
returns table (
  id uuid,
  provider_id uuid,
  service_id uuid,
  title text,
  caption text,
  storage_path text,
  url text,
  sort_order int,
  is_hidden boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 12), 12));
begin
  if p_provider_id is null then
    return;
  end if;

  return query
  select
    i.id,
    i.provider_id,
    i.service_id,
    i.title,
    i.caption,
    i.storage_path,
    i.url,
    i.sort_order,
    i.is_hidden,
    i.created_at
  from public.provider_portfolio_items i
  join public.profiles p on p.id = i.provider_id
  where i.provider_id = p_provider_id
    and i.is_hidden = false
    and coalesce(p.role, '') = 'provider'
    and coalesce(p.is_suspended, false) = false
  order by i.sort_order asc, i.created_at asc
  limit v_limit;
end;
$$;

drop function if exists public.list_provider_portfolio_thumbs(uuid[]);

create function public.list_provider_portfolio_thumbs(p_provider_ids uuid[])
returns table (
  provider_id uuid,
  url text,
  title text,
  sort_order int
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_ids uuid[] := coalesce(p_provider_ids, array[]::uuid[]);
begin
  if coalesce(array_length(v_ids, 1), 0) > 48 then
    v_ids := v_ids[1:48];
  end if;
  if coalesce(array_length(v_ids, 1), 0) = 0 then
    return;
  end if;

  return query
  select x.provider_id, x.url, x.title, x.sort_order
  from unnest(v_ids) as t(pid)
  cross join lateral (
    select i.provider_id, i.url, i.title, i.sort_order
    from public.provider_portfolio_items i
    join public.profiles p on p.id = i.provider_id
    where i.provider_id = t.pid
      and i.is_hidden = false
      and coalesce(p.role, '') = 'provider'
      and coalesce(p.is_suspended, false) = false
      and char_length(trim(i.url)) > 0
    order by i.sort_order asc, i.created_at asc
    limit 3
  ) x;
end;
$$;

comment on function public.list_provider_portfolio(uuid, int) is
  'Visible gallery items for one provider (hidden/suspended excluded). Cap 12.';
comment on function public.list_provider_portfolio_thumbs(uuid[]) is
  'Up to 3 visible thumbnail urls per provider for marketplace cards.';

-- ---------------------------------------------------------------------------
-- 5) Provider add RPC (limit + approved service + path)
-- ---------------------------------------------------------------------------
drop function if exists public.add_provider_portfolio_item(text, text, text, text, uuid);

create function public.add_provider_portfolio_item(
  p_title text,
  p_caption text,
  p_storage_path text,
  p_url text,
  p_service_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_suspended boolean;
  v_row public.provider_portfolio_items;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول لإضافة عمل';
  end if;

  select p.role, p.is_suspended
    into v_role, v_suspended
  from public.profiles p
  where p.id = v_uid;

  if coalesce(v_role, '') is distinct from 'provider' then
    raise exception 'معرض الأعمال للمزودين فقط';
  end if;
  if coalesce(v_suspended, false) then
    raise exception 'حسابك موقوف';
  end if;

  insert into public.provider_portfolio_items (
    provider_id, service_id, title, caption, storage_path, url
  ) values (
    v_uid, p_service_id, p_title, p_caption, p_storage_path, p_url
  )
  returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

comment on function public.add_provider_portfolio_item(text, text, text, text, uuid) is
  'Insert one gallery item for the signed-in provider. Trigger enforces max 12.';

-- ---------------------------------------------------------------------------
-- 6) Admin hide (no queue, no deletes)
-- ---------------------------------------------------------------------------
drop function if exists public.admin_list_provider_portfolio(uuid);

create function public.admin_list_provider_portfolio(p_provider_id uuid)
returns table (
  id uuid,
  provider_id uuid,
  service_id uuid,
  title text,
  caption text,
  storage_path text,
  url text,
  sort_order int,
  is_hidden boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'غير مصرح';
  end if;
  if p_provider_id is null then
    return;
  end if;

  return query
  select
    i.id,
    i.provider_id,
    i.service_id,
    i.title,
    i.caption,
    i.storage_path,
    i.url,
    i.sort_order,
    i.is_hidden,
    i.created_at
  from public.provider_portfolio_items i
  where i.provider_id = p_provider_id
  order by i.sort_order asc, i.created_at asc;
end;
$$;

drop function if exists public.admin_set_portfolio_hidden(uuid, boolean);

create function public.admin_set_portfolio_hidden(
  p_id uuid,
  p_hidden boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'غير مصرح';
  end if;
  if p_id is null then
    raise exception 'معرّف العمل غير صالح';
  end if;

  update public.provider_portfolio_items
  set is_hidden = coalesce(p_hidden, true)
  where id = p_id;
end;
$$;

comment on function public.admin_list_provider_portfolio(uuid) is
  'Admin: all gallery rows for a provider, including hidden. No deletes.';
comment on function public.admin_set_portfolio_hidden(uuid, boolean) is
  'Admin: hide/unhide one gallery item. Does not delete.';

-- ---------------------------------------------------------------------------
-- 7) Grants — REVOKE anon on admin RPCs
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
        'tg_provider_portfolio_guard',
        'list_provider_portfolio',
        'list_provider_portfolio_thumbs',
        'add_provider_portfolio_item',
        'admin_list_provider_portfolio',
        'admin_set_portfolio_hidden'
      )
  loop
    execute format('revoke all on function %s from public', r.sig);
    execute format('revoke all on function %s from anon', r.sig);
    if r.proname in (
      'list_provider_portfolio',
      'list_provider_portfolio_thumbs',
      'add_provider_portfolio_item',
      'admin_list_provider_portfolio',
      'admin_set_portfolio_hidden'
    ) then
      execute format('grant execute on function %s to authenticated', r.sig);
    end if;
    if r.proname in (
      'list_provider_portfolio',
      'list_provider_portfolio_thumbs'
    ) then
      execute format('grant execute on function %s to anon', r.sig);
    end if;
  end loop;
end $$;
