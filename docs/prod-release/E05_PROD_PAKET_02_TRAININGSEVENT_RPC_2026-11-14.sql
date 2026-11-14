-- E05 / AP05 – Paket 2: RPC zur Vergabe von Trainingsereignissen
-- Ziel: Supabase PROD (Projekt qdugtpzgefpswnnqbusd)
-- Status: Release-Kandidat – Ausführung erst nach ausdrücklicher Freigabe.
-- Quelle: exakt die am 08.11.2026 in DEV ausgeführte Paket-2-RPC-Fassung.
-- Spätere Sperrenlogik aus Paket 3 ist ausdrücklich NICHT Bestandteil dieses Pakets.
-- Abhängigkeit: Paket 1 (training_behavior_events + training_behavior_event_audit).
-- Umfang: ausschließlich award_training_behavior_event(...).
-- Keine Sperrenauslösung in diesem Paket; diese folgt in Paket 3.
-- Keine Änderungen an bestehenden Tabellen, Daten, Rollen oder Policies.
-- Idempotenz: CREATE OR REPLACE FUNCTION ist wiederholbar; ACL wird explizit gesetzt.

begin;

-- PROD-Vorbedingungs-Gate: Paket 1 muss vorhanden sein; Paket 2 darf
-- noch nicht installiert sein. Paket-3-Objekte dürfen nicht vorgezogen sein.
do $preflight$
begin
  if to_regclass('public.training_behavior_events') is null
     or to_regclass('public.training_behavior_event_audit') is null then
    raise exception 'E05 PROD Paket 2 abgebrochen: Paket-1-Ereignistabellen fehlen';
  end if;
  if to_regprocedure('public.award_training_behavior_event(uuid,uuid,text,text)') is not null then
    raise exception 'E05 PROD Paket 2 abgebrochen: RPC existiert bereits; Zustand prüfen';
  end if;
  if to_regclass('public.training_suspensions') is not null
     or to_regclass('public.training_suspension_audit') is not null then
    raise exception 'E05 PROD Paket 2 abgebrochen: Paket-3-Sperrenobjekte sind bereits vorhanden';
  end if;
  if to_regprocedure('auth.uid()') is null
     or to_regprocedure('public.has_selected_team_context(uuid)') is null then
    raise exception 'E05 PROD Paket 2 abgebrochen: Auth-/Teamkontext-Helper fehlen';
  end if;
  if to_regclass('public.trainings') is null
     or to_regclass('public.players') is null
     or to_regclass('public.attendance') is null
     or to_regclass('public.seasons') is null
     or to_regclass('public.team_member_roles') is null
     or to_regclass('public.global_user_roles') is null then
    raise exception 'E05 PROD Paket 2 abgebrochen: erforderliche Bestandstabellen fehlen';
  end if;
  if not has_column_privilege(current_user, 'public.trainings', 'team_id', 'SELECT')
     or not has_column_privilege(current_user, 'public.attendance', 'present', 'SELECT') then
    raise exception 'E05 PROD Paket 2 abgebrochen: erwartete Bestandsfelder fehlen';
  end if;
end;
$preflight$;

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
begin
  v_actor := auth.uid();

  if v_actor is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication required';
  end if;

  if p_training_id is null or p_player_id is null then
    raise exception using
      errcode = '22023',
      message = 'Training and player are required';
  end if;

  if p_event_type is null
     or p_event_type not in ('yellow_card', 'red_card', 'positive_star') then
    raise exception using
      errcode = '22023',
      message = 'Unsupported event type';
  end if;

  if p_event_type in ('yellow_card', 'red_card')
     and nullif(btrim(p_reason), '') is null then
    raise exception using
      errcode = '22023',
      message = 'A reason is required for yellow and red cards';
  end if;

  -- Training und Spieler sperren, damit konkurrierende Schreibvorgänge
  -- dieselben Zuordnungsdaten nicht gleichzeitig verändern.
  select t.team_id, t.training_date, coalesce(nullif(btrim(t.name), ''), 'Training'),
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
  where p.id = p_player_id
    and p.team_id = v_team_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Player not found in training team';
  end if;

  if v_player_active is not true then
    raise exception using errcode = '23514', message = 'Inactive player cannot receive events';
  end if;

  -- Trainer oder Mannschaftsadmin; Superadmin ausschließlich im
  -- ausdrücklich ausgewählten Teamkontext.
  if not exists (
    select 1
    from public.team_member_roles r
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

  -- Nur bestätigte tatsächliche Anwesenheit zählt.
  select a.present into v_present
  from public.attendance a
  where a.training_id = p_training_id
    and a.player_id = p_player_id
  for update;

  if not found or v_present is not true then
    raise exception using errcode = '23514', message = 'Player is not marked present';
  end if;

  -- Saison aus dem Training übernehmen, sofern sie aktiv und teamgleich ist.
  -- Bei NULL wird genau eine aktive Saison des Teams verlangt.
  if v_training_season_id is not null then
    select s.id, s.name
      into v_season_id, v_season_name
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
    where s.team_id = v_team_id
      and s.is_active is true;

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
    v_event_id,
    'created',
    null,
    jsonb_build_object(
      'id', v_event_id,
      'team_id', v_team_id,
      'season_id', v_season_id,
      'training_id', p_training_id,
      'training_date_snapshot', v_training_date,
      'training_name_snapshot', v_training_name,
      'player_id', p_player_id,
      'player_name_snapshot', v_player_name,
      'event_type', p_event_type,
      'reason', nullif(btrim(p_reason), ''),
      'status', 'active',
      'awarded_by', v_actor
    ),
    null,
    v_actor,
    now()
  );

  return v_event_id;
end;
$function$;

revoke all on function public.award_training_behavior_event(uuid, uuid, text, text)
from public, anon, authenticated, service_role;

grant execute on function public.award_training_behavior_event(uuid, uuid, text, text)
to authenticated;

commit;
