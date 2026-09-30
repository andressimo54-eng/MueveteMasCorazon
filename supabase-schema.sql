-- ❤️ MUÉVETE MÁS POR TU CORAZÓN — BASE CENTRAL v12
-- No usa sesiones anónimas. Cada participante debe tener una cuenta de correo/contraseña.
-- El reto tiene 30 días de actividad: 1 al 30 de octubre de 2026.
-- El 31 de octubre es día de cierre y consolidación.

create extension if not exists pgcrypto;

create table if not exists public.participants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  group_name text not null,
  activity_level text not null,
  started_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.health_data (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  condition_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_type text not null,
  duration_minutes integer not null check (duration_minutes in (10,25,52)),
  intensity text not null,
  activity_date timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.challenge_progress (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null unique references public.participants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  day integer not null default 1 check (day between 1 and 31),
  minutes_active integer not null default 0,
  steps integer not null default 0,
  points integer not null default 0,
  streak integer not null default 0,
  week_adjust integer not null default 0,
  completed_days jsonb not null default '[]'::jsonb,
  weekly_feedback jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.weekly_evaluations (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references public.participants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  week_number integer not null check (week_number between 1 and 4),
  feedback text not null check (feedback in ('easy','ok','hard','none')),
  created_at timestamptz not null default now(),
  unique(participant_id, week_number)
);

create index if not exists participants_user_id_idx on public.participants(user_id);
create index if not exists health_data_user_id_idx on public.health_data(user_id);
create index if not exists activities_user_id_idx on public.activities(user_id);
create index if not exists challenge_progress_user_id_idx on public.challenge_progress(user_id);
create index if not exists weekly_evaluations_user_id_idx on public.weekly_evaluations(user_id);

alter table public.participants enable row level security;
alter table public.health_data enable row level security;
alter table public.activities enable row level security;
alter table public.challenge_progress enable row level security;
alter table public.weekly_evaluations enable row level security;

drop policy if exists "participants_own_select" on public.participants;
drop policy if exists "participants_own_insert" on public.participants;
drop policy if exists "participants_own_update" on public.participants;
drop policy if exists "health_own_select" on public.health_data;
drop policy if exists "health_own_insert" on public.health_data;
drop policy if exists "health_own_update" on public.health_data;
drop policy if exists "activities_own_select" on public.activities;
drop policy if exists "activities_own_insert" on public.activities;
drop policy if exists "progress_own_select" on public.challenge_progress;
drop policy if exists "progress_own_insert" on public.challenge_progress;
drop policy if exists "progress_own_update" on public.challenge_progress;
drop policy if exists "evaluations_own_select" on public.weekly_evaluations;
drop policy if exists "evaluations_own_insert" on public.weekly_evaluations;
drop policy if exists "evaluations_own_update" on public.weekly_evaluations;

create policy "participants_own_select" on public.participants for select to authenticated using ((select auth.uid()) = user_id);
create policy "participants_own_insert" on public.participants for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "participants_own_update" on public.participants for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "health_own_select" on public.health_data for select to authenticated using ((select auth.uid()) = user_id);
create policy "health_own_insert" on public.health_data for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "health_own_update" on public.health_data for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "activities_own_select" on public.activities for select to authenticated using ((select auth.uid()) = user_id);
create policy "activities_own_insert" on public.activities for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "progress_own_select" on public.challenge_progress for select to authenticated using ((select auth.uid()) = user_id);
create policy "progress_own_insert" on public.challenge_progress for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "progress_own_update" on public.challenge_progress for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "evaluations_own_select" on public.weekly_evaluations for select to authenticated using ((select auth.uid()) = user_id);
create policy "evaluations_own_insert" on public.weekly_evaluations for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "evaluations_own_update" on public.weekly_evaluations for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

grant select, insert, update on public.participants to authenticated;
grant select, insert, update on public.health_data to authenticated;
grant select, insert on public.activities to authenticated;
grant select, insert, update on public.challenge_progress to authenticated;
grant select, insert, update on public.weekly_evaluations to authenticated;

-- Una cuenta corresponde a una sola inscripción.
-- Si ya existen duplicados, ejecuta primero v12-migration.sql y corrige los duplicados antes de crear este índice.
-- El índice evita la función "cambiar participante" y hace que la cuenta sea individual.

-- Ranking público: solo nombre, grupo, días, minutos y estrellas.
drop function if exists public.get_public_ranking();
create or replace function public.get_public_ranking()
returns table(participant_id uuid, display_name text, group_name text, active_days integer, total_minutes integer, points integer)
language sql security definer set search_path = public
as $$
  select p.id,p.name,p.group_name,
    count(distinct (a.activity_date at time zone 'America/Bogota')::date)::integer,
    coalesce(sum(a.duration_minutes),0)::integer,
    coalesce(cp.points,0)::integer
  from public.participants p
  left join public.activities a on a.participant_id=p.id
  left join public.challenge_progress cp on cp.participant_id=p.id
  where (a.activity_date is null or (a.activity_date at time zone 'America/Bogota')::date between date '2026-10-01' and date '2026-10-30')
  group by p.id,p.name,p.group_name,cp.points
  order by count(distinct (a.activity_date at time zone 'America/Bogota')::date) desc, coalesce(cp.points,0) desc, coalesce(sum(a.duration_minutes),0) desc, p.name asc;
$$;
revoke all on function public.get_public_ranking() from public;
grant execute on function public.get_public_ranking() to authenticated;
