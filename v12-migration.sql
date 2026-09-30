-- MUÉVETE MÁS · migración v11
-- Ejecutar una vez en Supabase SQL Editor.
-- Corrige duplicados del mismo día y evita que vuelvan a ocurrir.

-- 1) Conserva solo el primer registro de actividad de cada participante por día local.
with ranked as (
  select id,
         row_number() over (
           partition by participant_id, (activity_date at time zone 'America/Bogota')::date
           order by created_at asc, id asc
         ) as rn
  from public.activities
)
delete from public.activities a
using ranked r
where a.id=r.id and r.rn>1;

-- 2) Un solo bloque principal por participante y día.
create unique index if not exists activities_one_per_participant_day_idx
on public.activities (participant_id, ((activity_date at time zone 'America/Bogota')::date));

-- 3) Recalcular el progreso básico a partir de las actividades existentes.
with per_day as (
  select participant_id,
         count(distinct (activity_date at time zone 'America/Bogota')::date)::integer as active_days,
         coalesce(sum(duration_minutes),0)::integer as total_minutes
  from public.activities
  group by participant_id
)
update public.challenge_progress cp
set minutes_active=coalesce(pd.total_minutes,0),
    updated_at=now()
from per_day pd
where cp.participant_id=pd.participant_id;

-- 4) Los participantes sin actividad quedan en cero minutos.
update public.challenge_progress cp
set minutes_active=0, updated_at=now()
where not exists (select 1 from public.activities a where a.participant_id=cp.participant_id);

-- v12: la cuenta es individual y no debe tener más de una inscripción.
-- Este bloque NO borra participantes automáticamente.
-- Si detecta duplicados, detiene la migración para que puedan revisarse.
do $$
begin
  if exists (select 1 from public.participants group by user_id having count(*) > 1) then
    raise exception 'Existen cuentas con más de una inscripción. Revise public.participants antes de crear el índice único.';
  end if;
end $$;

create unique index if not exists participants_one_registration_per_user_idx
on public.participants(user_id);

-- v12: duración válida según los tres rangos de la app.
-- Los valores guardados por la app son 10, 25 y 52 minutos.
-- No modifica automáticamente datos históricos.

-- v12: recalcula minutos y estrellas desde las actividades existentes del reto.
with per_participant as (
  select p.id as participant_id,
         count(distinct (a.activity_date at time zone 'America/Bogota')::date)::integer as active_days,
         coalesce(sum(a.duration_minutes),0)::integer as total_minutes,
         coalesce(sum(case when a.duration_minutes >= 45 then 3 when a.duration_minutes >= 20 then 2 when a.duration_minutes >= 5 then 1 else 0 end),0)::integer as total_points
  from public.participants p
  left join public.activities a on a.participant_id=p.id
    and (a.activity_date at time zone 'America/Bogota')::date between date '2026-10-01' and date '2026-10-30'
  group by p.id
)
update public.challenge_progress cp
set minutes_active=pp.total_minutes,
    points=pp.total_points,
    updated_at=now()
from per_participant pp
where cp.participant_id=pp.participant_id;

-- v12: el ranking nunca confía en points enviados desde el navegador.
-- Las estrellas se calculan directamente desde las actividades registradas.
-- También limitamos los minutos a los tres rangos oficiales.
alter table public.activities drop constraint if exists activities_duration_minutes_check;
alter table public.activities add constraint activities_duration_minutes_check check (duration_minutes in (10,25,52));
