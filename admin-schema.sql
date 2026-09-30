-- ❤️ MUÉVETE MÁS POR TU CORAZÓN — PANEL ADMINISTRATIVO SEGURO v12
-- Ejecutar después de supabase-schema.sql y v12-migration.sql.
-- La condición crónica solo es visible para administradores autorizados.

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;
drop policy if exists "admin_users_self_select" on public.admin_users;
revoke all on table public.admin_users from anon, authenticated;

drop function if exists public.is_admin();
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.admin_users where user_id=(select auth.uid())); $$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

drop function if exists public.admin_dashboard_summary();
create or replace function public.admin_dashboard_summary()
returns table(participants_count bigint,active_participants bigint,total_active_days bigint,total_minutes bigint,total_points bigint,completed_30_days bigint)
language plpgsql stable security definer set search_path=public
as $$
begin
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  return query
  with per_participant as (
    select p.id,
      count(distinct (a.activity_date at time zone 'America/Bogota')::date)::bigint as active_days,
      coalesce(sum(a.duration_minutes),0)::bigint as minutes,
      coalesce(sum(case when a.duration_minutes>=45 then 3 when a.duration_minutes>=20 then 2 when a.duration_minutes>=5 then 1 else 0 end),0)::bigint as points
    from public.participants p
    left join public.activities a on a.participant_id=p.id
      and (a.activity_date at time zone 'America/Bogota')::date between date '2026-10-01' and date '2026-10-30'
    group by p.id
  )
  select
    (select count(*) from public.participants),
    (select count(*) from per_participant where active_days>0),
    coalesce((select sum(active_days) from per_participant),0),
    coalesce((select sum(minutes) from per_participant),0),
    coalesce((select sum(points) from per_participant),0),
    (select count(*) from per_participant where active_days>=30);
end;
$$;
revoke all on function public.admin_dashboard_summary() from public;
grant execute on function public.admin_dashboard_summary() to authenticated;

drop function if exists public.admin_ranking();
create or replace function public.admin_ranking()
returns table(position bigint,participant_id uuid,display_name text,group_name text,activity_level text,active_days bigint,total_minutes bigint,points integer,condition_name text,registered_at timestamptz)
language plpgsql stable security definer set search_path=public
as $$
begin
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  return query
  with base as (
    select p.id,p.name,p.group_name,p.activity_level,p.created_at,
      count(distinct (a.activity_date at time zone 'America/Bogota')::date)::bigint as days,
      coalesce(sum(a.duration_minutes),0)::bigint as minutes,
      coalesce(sum(case when a.duration_minutes>=45 then 3 when a.duration_minutes>=20 then 2 when a.duration_minutes>=5 then 1 else 0 end),0)::integer as pts,
      coalesce(max(h.condition_name),'Ninguno registrado')::text as condition_name
    from public.participants p
    left join public.activities a on a.participant_id=p.id
      and (a.activity_date at time zone 'America/Bogota')::date between date '2026-10-01' and date '2026-10-30'
    left join public.health_data h on h.participant_id=p.id
    group by p.id,p.name,p.group_name,p.activity_level,p.created_at
  ), ranked as (
    select *,row_number() over(order by days desc,pts desc,minutes desc,name asc) as pos from base
  )
  select pos,id,name,group_name,activity_level,days,minutes,pts,condition_name,created_at from ranked order by pos;
end;
$$;
revoke all on function public.admin_ranking() from public;
grant execute on function public.admin_ranking() to authenticated;

drop function if exists public.admin_group_stats();
create or replace function public.admin_group_stats()
returns table(group_name text,participants_count bigint,active_participants bigint,active_days bigint,total_minutes bigint,total_points bigint)
language plpgsql stable security definer set search_path=public
as $$
begin
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  return query
  with per_participant as (
    select p.id,p.group_name,
      count(distinct (a.activity_date at time zone 'America/Bogota')::date)::bigint as active_days,
      coalesce(sum(a.duration_minutes),0)::bigint as total_minutes,
      coalesce(sum(case when a.duration_minutes>=45 then 3 when a.duration_minutes>=20 then 2 when a.duration_minutes>=5 then 1 else 0 end),0)::bigint as total_points,
      case when count(a.id)>0 then 1 else 0 end::bigint as active
    from public.participants p
    left join public.activities a on a.participant_id=p.id
      and (a.activity_date at time zone 'America/Bogota')::date between date '2026-10-01' and date '2026-10-30'
    group by p.id,p.group_name
  )
  select group_name,count(*)::bigint,sum(active),sum(active_days),sum(total_minutes),sum(total_points)
  from per_participant group by group_name order by group_name;
end;
$$;
revoke all on function public.admin_group_stats() from public;
grant execute on function public.admin_group_stats() to authenticated;

drop function if exists public.admin_export_results();
create or replace function public.admin_export_results()
returns table(participant_name text,group_name text,activity_level text,active_days bigint,total_minutes bigint,points integer,registered_at timestamptz)
language plpgsql stable security definer set search_path=public
as $$
begin
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  return query
  select r.display_name,r.group_name,r.activity_level,r.active_days,r.total_minutes,r.points,r.registered_at
  from public.admin_ranking() r order by r.position;
end;
$$;
revoke all on function public.admin_export_results() from public;
grant execute on function public.admin_export_results() to authenticated;

-- Ejecuta una sola vez para autorizar la cuenta administrativa:
-- insert into public.admin_users(user_id)
-- select id from auth.users
-- where lower(email)=lower('TU_CORREO_ADMINISTRADOR@DOMINIO.COM')
-- on conflict (user_id) do nothing;
