-- =============================================================================
-- 150_short_video_media.sql
-- Optional short video (image rows stay image):
--   * provider_portfolio_items.media_type  image | video
--   * order_attachments.media_type         filled from the file URL
--   * avatars + order-attachments buckets  allow mp4/mov/webm and at least 20MB
--     when a smaller limit is set. Portfolio files stay in the avatars bucket
--     under {userId}/portfolio/. Do not create a new bucket.
--
-- Run this yourself in the Supabase SQL editor. Do not remote-apply.
-- Safe to re-run. Prerequisite: 67_provider_portfolio.sql.
-- Photo-only clients keep calling add_provider_portfolio_item without
-- p_media_type; the new argument defaults to image.
-- =============================================================================

do $$
begin
  if to_regclass('public.provider_portfolio_items') is null then
    raise exception 'public.provider_portfolio_items missing — run 67_provider_portfolio.sql first';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) Portfolio media kind
-- ---------------------------------------------------------------------------
alter table public.provider_portfolio_items
  add column if not exists media_type text;

update public.provider_portfolio_items
set media_type = case
  when coalesce(storage_path, '') ~* '\.(mp4|mov|webm|m4v)$' then 'video'
  else 'image'
end
where media_type is null
   or media_type not in ('image', 'video')
   or (
     media_type = 'image'
     and coalesce(storage_path, '') ~* '\.(mp4|mov|webm|m4v)$'
   );

alter table public.provider_portfolio_items
  alter column media_type set default 'image';

alter table public.provider_portfolio_items
  alter column media_type set not null;

alter table public.provider_portfolio_items
  drop constraint if exists provider_portfolio_items_media_type_chk;

alter table public.provider_portfolio_items
  add constraint provider_portfolio_items_media_type_chk
  check (media_type in ('image', 'video'));

comment on column public.provider_portfolio_items.media_type is
  'image (default) or video. Short gallery clip, still counted in the 12-item cap.';

-- ---------------------------------------------------------------------------
-- 2) Guard: keep photos, accept mp4/mov/webm/m4v as video
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
    new.media_type := old.media_type;
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
  new.media_type := lower(trim(coalesce(new.media_type, 'image')));

  if new.media_type not in ('image', 'video') then
    raise exception 'نوع الملف غير مدعوم';
  end if;

  if new.title = '' then
    raise exception 'أدخل عنوان العمل';
  end if;
  if new.storage_path = '' or new.url = '' then
    if new.media_type = 'video' then
      raise exception 'الفيديو مطلوب';
    end if;
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

  if new.storage_path ~* '\.(mp4|mov|webm|m4v)$' then
    new.media_type := 'video';
  elsif new.media_type = 'video' then
    raise exception 'الفيديو يجب أن يكون MP4 أو MOV أو WEBM';
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
-- 3) Customer RPCs — extra media_type column
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
  media_type text,
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
    i.media_type,
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
  sort_order int,
  media_type text
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
  select x.provider_id, x.url, x.title, x.sort_order, x.media_type
  from unnest(v_ids) as t(pid)
  cross join lateral (
    select i.provider_id, i.url, i.title, i.sort_order, i.media_type
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
  'Visible gallery items for one provider, including media_type. Cap 12.';
comment on function public.list_provider_portfolio_thumbs(uuid[]) is
  'Up to 3 visible thumbs per provider, including media_type.';

-- ---------------------------------------------------------------------------
-- 4) Provider add — optional p_media_type (default image)
-- ---------------------------------------------------------------------------
drop function if exists public.add_provider_portfolio_item(text, text, text, text, uuid);
drop function if exists public.add_provider_portfolio_item(text, text, text, text, uuid, text);

create function public.add_provider_portfolio_item(
  p_title text,
  p_caption text,
  p_storage_path text,
  p_url text,
  p_service_id uuid default null,
  p_media_type text default 'image'
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
    provider_id, service_id, title, caption, storage_path, url, media_type
  ) values (
    v_uid,
    p_service_id,
    p_title,
    p_caption,
    p_storage_path,
    p_url,
    coalesce(nullif(lower(trim(coalesce(p_media_type, ''))), ''), 'image')
  )
  returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

comment on function public.add_provider_portfolio_item(text, text, text, text, uuid, text) is
  'Insert one gallery image or short video. p_media_type defaults to image. Trigger caps at 12.';

-- ---------------------------------------------------------------------------
-- 5) Admin list includes media_type. Hide behavior unchanged.
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
  media_type text,
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
    i.media_type,
    i.sort_order,
    i.is_hidden,
    i.created_at
  from public.provider_portfolio_items i
  where i.provider_id = p_provider_id
  order by i.sort_order asc, i.created_at asc;
end;
$$;

comment on function public.admin_list_provider_portfolio(uuid) is
  'Admin: all gallery rows for a provider, including hidden and media_type. No deletes.';

-- ---------------------------------------------------------------------------
-- 6) Grants for replaced signatures
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

-- ---------------------------------------------------------------------------
-- 7) Order problem clips. Client insert stays (order_id, uploader_id, url,
--    storage_path). The trigger classifies video from the URL so photo
--    inserts do not need a new column in the payload.
-- ---------------------------------------------------------------------------
create or replace function public.tg_order_attachment_media_type()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if coalesce(new.url, '') ~* '\.(mp4|mov|webm|m4v)(\?|#|$)' then
    new.media_type := 'video';
  elsif new.media_type is null
     or btrim(new.media_type) not in ('image', 'video') then
    new.media_type := 'image';
  else
    new.media_type := lower(btrim(new.media_type));
  end if;
  return new;
end;
$$;

revoke all on function public.tg_order_attachment_media_type() from public;
revoke all on function public.tg_order_attachment_media_type() from anon, authenticated;

do $$
begin
  if to_regclass('public.order_attachments') is null then
    raise notice 'order_attachments missing — skipped media_type. Run 15_storage_images_patch.sql if order photos are not set up yet.';
    return;
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'order_attachments'
      and column_name = 'url'
  ) then
    raise notice 'order_attachments.url missing — skipped media_type';
    return;
  end if;

  alter table public.order_attachments
    add column if not exists media_type text;

  update public.order_attachments
  set media_type = case
    when coalesce(url, '') ~* '\.(mp4|mov|webm|m4v)(\?|#|$)' then 'video'
    else 'image'
  end
  where media_type is null
     or media_type not in ('image', 'video')
     or (
       media_type is distinct from 'video'
       and coalesce(url, '') ~* '\.(mp4|mov|webm|m4v)(\?|#|$)'
     );

  alter table public.order_attachments
    alter column media_type set default 'image';

  alter table public.order_attachments
    alter column media_type set not null;

  alter table public.order_attachments
    drop constraint if exists order_attachments_media_type_chk;

  alter table public.order_attachments
    add constraint order_attachments_media_type_chk
    check (media_type in ('image', 'video'));

  execute 'drop trigger if exists trg_order_attachment_media_type on public.order_attachments';
  execute 'create trigger trg_order_attachment_media_type
    before insert or update on public.order_attachments
    for each row execute function public.tg_order_attachment_media_type()';

  execute 'comment on column public.order_attachments.media_type is
    ''image (default) or video. Set from the file URL for short problem clips.''';
end $$;

-- ---------------------------------------------------------------------------
-- 8) Bucket size / MIME. Null allowed_mime_types means every type is already
--    allowed. A bucket limited under 20MB is raised; a higher limit is kept.
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('storage.buckets') is null then
    raise notice 'storage.buckets missing — skipped bucket video limits';
    return;
  end if;

  update storage.buckets b
  set file_size_limit = greatest(coalesce(b.file_size_limit, 0), 20971520)
  where b.id in ('avatars', 'order-attachments')
    and (b.file_size_limit is null or b.file_size_limit < 20971520);

  update storage.buckets b
  set allowed_mime_types = (
    select array_agg(distinct mime)
    from unnest(
      b.allowed_mime_types || array[
        'video/mp4',
        'video/quicktime',
        'video/webm'
      ]::text[]
    ) as mime
  )
  where b.id in ('avatars', 'order-attachments')
    and b.allowed_mime_types is not null;
end $$;

notify pgrst, 'reload schema';
