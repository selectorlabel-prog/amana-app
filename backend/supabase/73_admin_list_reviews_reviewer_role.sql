-- =============================================================================
-- 73_admin_list_reviews_reviewer_role.sql
-- Extend admin_list_reviews with reviewer_id + reviewer_role (customer|provider).
-- Keep admin_set_review_hidden (soft hide only; no hard delete).
-- Arabic literals via UTF-8 hex (SQL 70). REVOKE anon on admin RPCs.
-- Safe to re-run. No new tables.
-- =============================================================================

drop function if exists public.admin_list_reviews(integer);

create function public.admin_list_reviews(p_limit integer default 100)
returns table (
  id uuid,
  order_id uuid,
  customer_id uuid,
  provider_id uuid,
  reviewer_id uuid,
  reviewer_role text,
  rating integer,
  comment text,
  qualities text[],
  is_hidden boolean,
  hidden_reason text,
  created_at timestamptz,
  customer_name text,
  provider_name text,
  service_name text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_err_admin text := convert_from(decode('d984d984d985d8b4d8b1d981d98ad98620d981d982d8b7','hex'),'utf8');
begin
  if not public.is_admin() then
    raise exception '%', v_err_admin;
  end if;

  return query
  select
    r.id,
    r.order_id,
    r.customer_id,
    r.provider_id,
    r.reviewer_id,
    coalesce(nullif(trim(r.reviewer_role), ''), 'customer'),
    r.rating,
    r.comment,
    r.qualities,
    coalesce(r.is_hidden, false),
    r.hidden_reason,
    r.created_at,
    nullif(trim(c.full_name), ''),
    nullif(trim(p.full_name), ''),
    nullif(trim(o.service_name), '')
  from public.reviews r
  left join public.profiles c on c.id = r.customer_id
  left join public.profiles p on p.id = r.provider_id
  left join public.orders o on o.id = r.order_id
  order by r.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
end;
$$;

revoke all on function public.admin_list_reviews(integer) from public;
revoke all on function public.admin_list_reviews(integer) from anon;
grant execute on function public.admin_list_reviews(integer) to authenticated;

create or replace function public.admin_set_review_hidden(
  p_review_id uuid,
  p_hidden boolean,
  p_reason text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.reviews%rowtype;
  v_err_admin text := convert_from(decode('d984d984d985d8b4d8b1d981d98ad98620d981d982d8b7','hex'),'utf8');
  v_err_missing text := convert_from(decode('d8a7d984d8aad982d98ad98ad98520d8bad98ad8b120d985d988d8acd988d8af','hex'),'utf8');
begin
  if not public.is_admin() then
    raise exception '%', v_err_admin;
  end if;

  update public.reviews
  set
    is_hidden = coalesce(p_hidden, true),
    hidden_reason = case
      when coalesce(p_hidden, true) then nullif(trim(coalesce(p_reason, '')), '')
      else null
    end
  where id = p_review_id
  returning * into v_row;

  if not found then
    raise exception '%', v_err_missing;
  end if;

  insert into public.admin_audit_log (admin_id, action, entity_type, entity_id, meta)
  values (
    auth.uid(),
    case when v_row.is_hidden then 'review_hide' else 'review_unhide' end,
    'review',
    v_row.id::text,
    json_build_object('reason', v_row.hidden_reason)
  );

  return json_build_object(
    'id', v_row.id,
    'is_hidden', v_row.is_hidden,
    'hidden_reason', v_row.hidden_reason
  );
end;
$$;

revoke all on function public.admin_set_review_hidden(uuid, boolean, text) from public;
revoke all on function public.admin_set_review_hidden(uuid, boolean, text) from anon;
grant execute on function public.admin_set_review_hidden(uuid, boolean, text) to authenticated;

comment on function public.admin_list_reviews(integer) is
  'Admin review list with reviewer_id/role (73). Soft hide via admin_set_review_hidden.';
