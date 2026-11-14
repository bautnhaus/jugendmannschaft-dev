-- KADAssist / E05 PROD Paket 3
-- Sperrenfundament und automatische Sperrenauslösung
-- Ziel: Supabase PROD qdugtpzgefpswnnqbusd
-- Basis: freigegebener DEV-Paket-3-Quellstand aus docs/E05_PAKET_03_SUSPENSION_TRIGGER_2026-11-08.sql
-- Quelle Git-Blob: 74c77a6c3b1f346e404d88254533bf908a469662
-- Paket 1 und 2 müssen in PROD registriert und live vorhanden sein.
-- ACHTUNG: Dieses Paket aktiviert die automatische Erzeugung von Sperren.
-- Spieltagszuordnung/Ableistung/Ausnahmen/Korrektur folgen in späteren Paketen.
-- Keine Testdaten und keine bestehenden Datensätze werden geschrieben/geändert.

begin;

do $preflight$
declare
  v_def text;
begin
  if to_regclass('public.training_behavior_events') is null
     or to_regclass('public.training_behavior_event_audit') is null then
    raise exception 'E05 Paket 3: Paket-1-Ereignistabellen fehlen';
  end if;
  if to_regprocedure('public.award_training_behavior_event(uuid,uuid,text,text)') is null then
    raise exception 'E05 Paket 3: Paket-2-RPC fehlt';
  end if;
  if to_regclass('public.training_suspensions') is not null
     or to_regclass('public.training_suspension_audit') is not null
     or to_regprocedure('public.e05_reject_suspension_audit_mutation()') is not null then
    raise exception 'E05 Paket 3: Sperrenobjekte sind bereits teilweise/vollständig vorhanden; keine Wiederholung';
  end if;
  if exists (
    select 1 from pg_policies
    where schemaname='public'
      and tablename in ('training_suspensions','training_suspension_audit')
  ) then
    raise exception 'E05 Paket 3: unerwartete vorhandene Policies für Paket-3-Tabellen';
  end if;
  if to_regprocedure('public.is_team_member(uuid)') is null
     or to_regprocedure('public.has_selected_team_context(uuid)') is null
     or to_regclass('public.players') is null
     or to_regclass('public.team_member_roles') is null
     or to_regclass('public.global_user_roles') is null then
    raise exception 'E05 Paket 3: benötigte Rollen-/Kontext-/Spieler-Helfer fehlen';
  end if;
  if not has_function_privilege('authenticated',
       'public.award_training_behavior_event(uuid,uuid,text,text)','EXECUTE') then
    raise exception 'E05 Paket 3: authenticated EXECUTE auf Paket-2-RPC fehlt';
  end if;
  if has_function_privilege('anon',
       'public.award_training_behavior_event(uuid,uuid,text,text)','EXECUTE')
     or has_function_privilege('service_role',
       'public.award_training_behavior_event(uuid,uuid,text,text)','EXECUTE') then
    raise exception 'E05 Paket 3: unerwartete Paket-2-RPC-Berechtigungen';
  end if;
  v_def := pg_get_functiondef('public.award_training_behavior_event(uuid,uuid,text,text)'::regprocedure);
  if position('training_behavior_event_audit' in v_def)=0
     or position('Exactly one active team season is required' in v_def)=0
     or position('Player is not marked present' in v_def)=0
     or position('training_suspensions' in v_def)>0 then
    raise exception 'E05 Paket 3: Paket-2-RPC weicht vom erwarteten PROD-Baseline-Stand ab';
  end if;
end;
$preflight$;

create table public.training_suspensions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null,
  season_id uuid not null,
  player_id uuid references public.players(id) on delete set null,
  player_name_snapshot text not null
    check (nullif(btrim(player_name_snapshot), '') is not null),
  source_event_id uuid not null
    references public.training_behavior_events(id) on delete restrict,
  suspension_type text not null
    check (suspension_type in ('yellow', 'red')),
  status text not null default 'open'
    check (status in ('open', 'served', 'expired', 'voided')),
  intended_matchday_id uuid,
  intended_matchday_date_snapshot date,
  intended_matchday_opponent_snapshot text,
  served_matchday_id uuid,
  served_matchday_date_snapshot date,
  served_matchday_opponent_snapshot text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  served_at timestamptz,
  expired_at timestamptz,
  voided_by uuid references auth.users(id) on delete set null,
  voided_at timestamptz,
  void_reason text,
  constraint training_suspensions_served_metadata_check
    check (
      (status = 'served' and served_matchday_id is not null and served_at is not null)
      or (status <> 'served' and served_at is null and served_matchday_id is null)
    ),
  constraint training_suspensions_expired_metadata_check
    check (
      (status = 'expired' and expired_at is not null)
      or (status <> 'expired' and expired_at is null)
    ),
  constraint training_suspensions_void_metadata_check
    check (
      (status = 'voided' and voided_at is not null and nullif(btrim(void_reason), '') is not null)
      or (status <> 'voided' and voided_at is null and void_reason is null)
    )
);

create unique index training_suspensions_one_per_source_event
  on public.training_suspensions(source_event_id);

create index training_suspensions_open_player_idx
  on public.training_suspensions(team_id, season_id, player_id, created_at)
  where status = 'open';

create index training_suspensions_matchday_idx
  on public.training_suspensions(intended_matchday_id)
  where status = 'open';

create table public.training_suspension_audit (
  id uuid primary key default gen_random_uuid(),
  suspension_id uuid not null
    references public.training_suspensions(id) on delete restrict,
  action text not null
    check (action in ('created', 'target_changed', 'served', 'expired',
      'exception_granted', 'exception_revoked', 'corrected', 'voided', 'reinstated')),
  old_values jsonb,
  new_values jsonb not null,
  reason text,
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now(),
  constraint training_suspension_audit_reason_check
    check (action = 'created' or nullif(btrim(reason), '') is not null)
);

create index training_suspension_audit_suspension_idx
  on public.training_suspension_audit(suspension_id, changed_at desc);

create function public.e05_reject_suspension_audit_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $function$
begin
  raise exception 'E05 suspension audit is append-only; % is not permitted',
    TG_OP using errcode = '55000';
end;
$function$;

create trigger training_suspension_audit_no_update_delete
before update or delete on public.training_suspension_audit
for each row execute function public.e05_reject_suspension_audit_mutation();

create trigger training_suspension_audit_no_truncate
before truncate on public.training_suspension_audit
for each statement execute function public.e05_reject_suspension_audit_mutation();

revoke all on function public.e05_reject_suspension_audit_mutation()
from public, anon, authenticated, service_role;

revoke all on public.training_suspensions, public.training_suspension_audit
from public, anon, authenticated, service_role;

grant select on public.training_suspensions, public.training_suspension_audit
to authenticated, service_role;

alter table public.training_suspensions enable row level security;
alter table public.training_suspension_audit enable row level security;

create policy training_suspensions_select
on public.training_suspensions
for select to authenticated
using (public.is_team_member(team_id) or public.has_selected_team_context(team_id));

create policy training_suspension_audit_select
on public.training_suspension_audit
for select to authenticated
using (
  exists (
    select 1 from public.training_suspensions s
    where s.id = suspension_id
      and (public.is_team_member(s.team_id) or public.has_selected_team_context(s.team_id))
  )
);

create or replace function public.award_training_behavior_event(
  p_training_id uuid,
  p_player_id uuid,
  p_event_type text,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_actor uuid;
  v_team_id uuid;
  v_training_date date;
  v_training_name text;
  v_training_status text;
  v_training_season_id uuid;
  v_player_name text;
  v_player_active boolean;
  v_season_id uuid;
  v_season_name text;
  v_active_season_count integer;
  v_present boolean;
  v_event_id uuid;
  v_suspension_id uuid;
  v_suspension_source_event_id uuid;
  v_yellow_count integer;
  v_yellow_since timestamptz;
begin
  v_actor := auth.uid();

  if v_actor is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  if p_training_id is null or p_player_id is null then
    raise exception using errcode = '22023', message = 'Training and player are required';
  end if;

  if p_event_type is null
     or p_event_type not in ('yellow_card', 'red_card', 'positive_star') then
    raise exception using errcode = '22023', message = 'Unsupported event type';
  end if;

  if p_event_type in ('yellow_card', 'red_card')
     and nullif(btrim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'A reason is required for yellow and red cards';
  end if;

  select t.team_id, t.training_date,
         coalesce(nullif(btrim(t.name), ''), 'Training'),
         t.status, t.season_id
    into v_team_id, v_training_date, v_training_name,
         v_training_status, v_training_season_id
  from public.trainings t
  where t.id = p_training_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Training not found';
  end if;

  if v_training_status = 'cancelled' then
    raise exception using errcode = '23514', message = 'Cancelled training cannot receive events';
  end if;

  select p.name, p.active
    into v_player_name, v_player_active
  from public.players p
  where p.id = p_player_id and p.team_id = v_team_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Player not found in training team';
  end if;

  if v_player_active is not true then
    raise exception using errcode = '23514', message = 'Inactive player cannot receive events';
  end if;

  if not exists (
    select 1 from public.team_member_roles r
    where r.team_id = v_team_id
      and r.user_id = v_actor
      and r.role in ('trainer', 'admin')
  ) and not (
    exists (
      select 1 from public.global_user_roles gur
      where gur.user_id = v_actor and gur.role = 'super_admin'
    )
    and public.has_selected_team_context(v_team_id)
  ) then
    raise exception using errcode = '42501', message = 'Not authorized for this team';
  end if;

  select a.present into v_present
  from public.attendance a
  where a.training_id = p_training_id
    and a.player_id = p_player_id
  for update;

  if not found or v_present is not true then
    raise exception using errcode = '23514', message = 'Player is not marked present';
  end if;

  if v_training_season_id is not null then
    select s.id, s.name into v_season_id, v_season_name
    from public.seasons s
    where s.id = v_training_season_id
      and s.team_id = v_team_id
      and s.is_active is true;

    if not found then
      raise exception using errcode = '23514',
        message = 'Training season is not an active season of its team';
    end if;
  else
    select count(*)::integer, min(s.id::text)::uuid, min(s.name)
      into v_active_season_count, v_season_id, v_season_name
    from public.seasons s
    where s.team_id = v_team_id and s.is_active is true;

    if v_active_season_count <> 1 then
      raise exception using errcode = '23514',
        message = 'Exactly one active team season is required';
    end if;
  end if;

  insert into public.training_behavior_events (
    team_id, season_id, training_id, training_date_snapshot,
    training_name_snapshot, player_id, player_name_snapshot,
    event_type, reason, status, awarded_by, awarded_at
  )
  values (
    v_team_id, v_season_id, p_training_id, v_training_date,
    v_training_name, p_player_id, v_player_name,
    p_event_type, nullif(btrim(p_reason), ''), 'active', v_actor, now()
  )
  returning id into v_event_id;

  insert into public.training_behavior_event_audit (
    event_id, action, old_values, new_values, reason, changed_by, changed_at
  )
  values (
    v_event_id, 'created', null,
    jsonb_build_object(
      'id', v_event_id, 'team_id', v_team_id, 'season_id', v_season_id,
      'training_id', p_training_id, 'training_date_snapshot', v_training_date,
      'training_name_snapshot', v_training_name, 'player_id', p_player_id,
      'player_name_snapshot', v_player_name, 'event_type', p_event_type,
      'reason', nullif(btrim(p_reason), ''), 'status', 'active', 'awarded_by', v_actor
    ),
    null, v_actor, now()
  );

  -- Rot löst unmittelbar eine eigenständige rote Sperre aus.
  if p_event_type = 'red_card' then
    v_suspension_source_event_id := v_event_id;
    insert into public.training_suspensions (
      team_id, season_id, player_id, player_name_snapshot,
      source_event_id, suspension_type, status, created_by, created_at
    )
    values (
      v_team_id, v_season_id, p_player_id, v_player_name,
      v_event_id, 'red', 'open', v_actor, now()
    )
    returning id into v_suspension_id;

  -- Gelb löst beim fünften aktiven Ereignis eine gelbe Sperre aus.
  -- Eine bereits offene gelbe Sperre verhindert eine zweite parallele gelbe Sperre.
  elsif p_event_type = 'yellow_card' then
    select coalesce(max(s.served_at), '-infinity'::timestamptz)
      into v_yellow_since
    from public.training_suspensions s
    where s.team_id = v_team_id
      and s.season_id = v_season_id
      and s.player_id = p_player_id
      and s.suspension_type = 'yellow'
      and s.status = 'served';

    select count(*)::integer
      into v_yellow_count
    from public.training_behavior_events e
    where e.team_id = v_team_id
      and e.season_id = v_season_id
      and e.player_id = p_player_id
      and e.event_type = 'yellow_card'
      and e.status = 'active'
      and e.awarded_at > v_yellow_since;

    if v_yellow_count >= 5
       and not exists (
         select 1 from public.training_suspensions s
         where s.team_id = v_team_id
           and s.season_id = v_season_id
           and s.player_id = p_player_id
           and s.suspension_type = 'yellow'
           and s.status = 'open'
       ) then
      select e.id
        into v_suspension_source_event_id
      from public.training_behavior_events e
      where e.team_id = v_team_id
        and e.season_id = v_season_id
        and e.player_id = p_player_id
        and e.event_type = 'yellow_card'
        and e.status = 'active'
        and e.awarded_at > v_yellow_since
      order by e.awarded_at, e.id
      offset 4 limit 1;

      if v_suspension_source_event_id is not null then
        insert into public.training_suspensions (
          team_id, season_id, player_id, player_name_snapshot,
          source_event_id, suspension_type, status, created_by, created_at
        )
        values (
          v_team_id, v_season_id, p_player_id, v_player_name,
          v_suspension_source_event_id, 'yellow', 'open', v_actor, now()
        )
        returning id into v_suspension_id;
      end if;
    end if;
  end if;

  if v_suspension_id is not null then
    insert into public.training_suspension_audit (
      suspension_id, action, old_values, new_values, reason, changed_by, changed_at
    )
    values (
      v_suspension_id, 'created', null,
      jsonb_build_object(
        'id', v_suspension_id, 'team_id', v_team_id, 'season_id', v_season_id,
        'player_id', p_player_id, 'player_name_snapshot', v_player_name,
        'source_event_id', v_suspension_source_event_id,
        'suspension_type', case when p_event_type = 'red_card' then 'red' else 'yellow' end,
        'status', 'open', 'created_by', v_actor
      ),
      null, v_actor, now()
    );
  end if;

  return v_event_id;
end;
$function$;

revoke all on function public.award_training_behavior_event(uuid, uuid, text, text)
from public, anon, authenticated, service_role;

grant execute on function public.award_training_behavior_event(uuid, uuid, text, text)
to authenticated;

-- Paket 3 behält die SECURITY DEFINER-Signatur bei und vergibt EXECUTE
-- ausschließlich an authenticated. PUBLIC/anon/service_role bleiben ausgeschlossen.
revoke all on function public.award_training_behavior_event(uuid,uuid,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.award_training_behavior_event(uuid,uuid,text,text)
to authenticated;

commit;
