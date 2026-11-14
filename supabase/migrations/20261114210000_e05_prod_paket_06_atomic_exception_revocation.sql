-- E05 PROD Paket 6: Widerruf einer Spieltagsausnahme
-- Abgeleitet aus dem in DEV ausgeführten SQL vom 13.11.2026.
-- DEV-Quelle SHA: 5b5ac4fd8c14be5bc00ff8d4774ad1d1ac9800b0
-- Konsolidiert auf den am 14.11.2026 live aus DEV ausgelesenen Funktionsstand.
-- Nur nach ausdrücklicher Freigabe in Supabase PROD ausführen.

begin;

-- PRE-FLIGHT: nur exakt erwartete Objekte akzeptieren.
do $preflight$
begin
  if to_regclass('public.training_suspension_exceptions') is null
     or to_regclass('public.training_suspensions') is null
     or to_regclass('public.training_suspension_audit') is null
     or to_regclass('public.matchdays') is null
     or to_regclass('public.matchday_players') is null then
    raise exception 'Preflight Paket 6: Paket-5-/Spieltags-Basistabellen fehlen';
  end if;
  if to_regprocedure('public.revoke_suspension_exception(uuid,text)') is not null
     or to_regprocedure('public.prevent_suspended_matchday_nomination()') is not null
     or exists (
       select 1 from pg_trigger
       where tgrelid='public.matchday_players'::regclass
         and tgname='matchday_players_prevent_suspended_nomination'
         and not tgisinternal
     ) then
    raise exception 'Preflight Paket 6: Widerrufs-RPC oder Nominierungsschutz ist bereits ganz/teilweise installiert; zuerst manuell abgleichen';
  end if;
end;
$preflight$;

-- 1) Nominierungs-Trigger: serialisiert jede neue/geänderte Zuordnung
--    pro Spieler gegen einen parallelen Ausnahme-Widerruf.
create or replace function public.prevent_suspended_matchday_nomination()
returns trigger
language plpgsql
set search_path to 'pg_catalog', 'public'
as $function$
declare
    v_team_id uuid;
    v_blocking_suspension_id uuid;
begin
    if tg_op = 'UPDATE'
       and new.matchday_id is not distinct from old.matchday_id
       and new.player_id is not distinct from old.player_id then
        return new;
    end if;

    -- Gleiche Sperre wie im Widerrufs-RPC. Bei Spielerwechsel beide IDs
    -- deterministisch sortiert sperren, um Lock-Inversionen zu vermeiden.
    if tg_op = 'UPDATE'
       and old.player_id is distinct from new.player_id then
        if old.player_id::text < new.player_id::text then
            perform pg_advisory_xact_lock(hashtextextended(old.player_id::text,0));
            perform pg_advisory_xact_lock(hashtextextended(new.player_id::text,0));
        else
            perform pg_advisory_xact_lock(hashtextextended(new.player_id::text,0));
            perform pg_advisory_xact_lock(hashtextextended(old.player_id::text,0));
        end if;
    else
        perform pg_advisory_xact_lock(hashtextextended(new.player_id::text,0));
    end if;

    select m.team_id
      into v_team_id
      from public.matchdays m
     where m.id = new.matchday_id;

    if v_team_id is null then
        raise exception
            'Der ausgewählte Spieltag wurde nicht gefunden.'
            using errcode = '23503';
    end if;

    select s.id
      into v_blocking_suspension_id
      from public.training_suspensions s
     where s.team_id = v_team_id
       and s.player_id = new.player_id
       and s.status = 'open'
       and s.intended_matchday_id = new.matchday_id
       and not exists (
           select 1
             from public.training_suspension_exceptions e
            where e.suspension_id = s.id
              and e.matchday_id = new.matchday_id
              and e.revoked_at is null
       )
     order by s.created_at, s.id
     limit 1;

    if v_blocking_suspension_id is not null then
        raise exception
            'Nominierung nicht möglich: Für diesen Spieler besteht eine Sperre für diesen Spieltag. Bitte zuerst eine Ausnahme erteilen.'
            using errcode = '23514';
    end if;

    return new;
end;
$function$;

-- PROD-Abweichung gegenüber DEV: In PROD ist der Sperr-Nominierungs-
-- Trigger nach Paketen 1–5 noch nicht vorhanden. Deshalb wird er hier
-- zusammen mit der synchronisierten Triggerfunktion angelegt.
do $trigger$
begin
  if not exists (
    select 1 from pg_trigger
    where tgrelid='public.matchday_players'::regclass
      and tgname='matchday_players_prevent_suspended_nomination'
      and not tgisinternal
  ) then
    create trigger matchday_players_prevent_suspended_nomination
      before insert or update of matchday_id, player_id
      on public.matchday_players
      for each row
      execute function public.prevent_suspended_matchday_nomination();
  end if;
end;
$trigger$;

-- 2) Widerrufs-RPC: bestehende Nominierung im selben Transaktionskontext
--    entfernen und ihren Snapshot im Audit sichern.
create or replace function public.revoke_suspension_exception(
  p_exception_id uuid,
  p_revoke_reason text
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog,public,auth
as $function$
declare
  v_actor uuid := auth.uid();
  v_exception public.training_suspension_exceptions%rowtype;
  v_suspension public.training_suspensions%rowtype;
  v_matchday public.matchdays%rowtype;
  v_actor_name text;
  v_old_values jsonb;
  v_new_values jsonb;
  v_reassigned integer := 0;
  v_nomination_snapshot jsonb;
begin
  if v_actor is null then
    raise exception using errcode='42501',message='Authentication required';
  end if;
  if p_exception_id is null or nullif(btrim(p_revoke_reason),'') is null then
    raise exception using errcode='22023',message='Exception and non-empty revocation reason are required';
  end if;

  select * into v_exception
  from public.training_suspension_exceptions
  where id=p_exception_id;
  if not found then
    raise exception using errcode='P0002',message='Suspension exception not found';
  end if;

  -- Mit Nominierungs-Trigger synchronisieren, bevor der Status geändert wird.
  if v_exception.player_id is not null then
    perform pg_advisory_xact_lock(hashtextextended(v_exception.player_id::text,0));
    perform 1 from public.players p
    where p.id=v_exception.player_id
    for update;
  end if;

  select * into v_suspension
  from public.training_suspensions
  where id=v_exception.suspension_id
  for update;
  if not found then
    raise exception using errcode='P0002',message='Related suspension not found';
  end if;

  select * into v_exception
  from public.training_suspension_exceptions
  where id=p_exception_id
  for update;
  if not found then
    raise exception using errcode='P0002',message='Suspension exception not found';
  end if;
  if v_exception.revoked_at is not null then
    raise exception using errcode='23514',message='Suspension exception has already been revoked';
  end if;
  if v_suspension.status<>'open' then
    raise exception using errcode='23514',message='Only an open suspension can have its exception revoked';
  end if;

  if v_suspension.team_id<>v_exception.team_id
     or v_suspension.player_id is distinct from v_exception.player_id then
    raise exception using errcode='23514',
      message='Exception and suspension ownership do not match';
  end if;

  if not exists (
    select 1 from public.team_member_roles r
    where r.team_id=v_exception.team_id
      and r.user_id=v_actor and r.role in ('trainer','admin')
  ) and not (
    exists (
      select 1 from public.global_user_roles g
      where g.user_id=v_actor and g.role='super_admin'
    )
    and public.has_selected_team_context(v_exception.team_id)
  ) then
    raise exception using errcode='42501',message='Team permission required';
  end if;

  select * into v_matchday
  from public.matchdays
  where id=v_exception.matchday_id
  for update;
  if not found then
    raise exception using errcode='P0002',message='Original matchday not found';
  end if;

  if v_matchday.team_id<>v_exception.team_id
     or v_matchday.season_id is distinct from v_suspension.season_id
     or v_matchday.status<>'planned'
     or v_matchday.match_date<current_date then
    raise exception using errcode='23514',
      message='An exception can only be revoked before its original matchday is held or has passed';
  end if;

  select pr.display_name into v_actor_name
  from public.profiles pr where pr.id=v_actor;

  update public.training_suspension_exceptions
  set revoked_by=v_actor,
      revoked_by_snapshot=v_actor_name,
      revoked_at=now(),
      revoke_reason=btrim(p_revoke_reason)
  where id=v_exception.id;

  -- Erst nach der regelkonformen Neuzuordnung feststellen, ob der widerrufene
  -- Spieler an genau diesem Spieltag tatsächlich wieder gesperrt ist.
  -- Das verhindert das Entfernen einer Nominierung, falls die offene Sperre
  -- aufgrund anderer gültiger Zielbindungen auf einen anderen Spieltag fällt.
  if v_suspension.player_id is not null then
    v_reassigned:=public.e05_assign_player_suspensions(
      v_suspension.team_id,v_suspension.player_id,v_actor
    );
  end if;

  if exists (
    select 1
      from public.training_suspensions s
     where s.team_id=v_exception.team_id
       and s.player_id=v_exception.player_id
       and s.status='open'
       and s.intended_matchday_id=v_exception.matchday_id
       and not exists (
         select 1
           from public.training_suspension_exceptions e
          where e.suspension_id=s.id
            and e.matchday_id=v_exception.matchday_id
            and e.revoked_at is null
       )
  ) then
    -- Nur eine dadurch wieder unzulässige Nominierung entfernen. Einen
    -- tatsächlichen Einsatz niemals löschen; in diesem Fall Rollback des
    -- gesamten Widerrufs inklusive Audit und Neuzuordnung.
    select to_jsonb(mp)
      into v_nomination_snapshot
      from public.matchday_players mp
     where mp.matchday_id=v_exception.matchday_id
       and mp.player_id=v_exception.player_id
     for update;

    if v_nomination_snapshot is not null
       and coalesce((v_nomination_snapshot->>'played')::boolean,false) is true then
      raise exception using errcode='23514',
        message='Widerruf abgebrochen: Für diesen Spieler ist bereits ein tatsächlicher Einsatz dokumentiert.';
    end if;

    if v_nomination_snapshot is not null then
      delete from public.matchday_players
       where matchday_id=v_exception.matchday_id
         and player_id=v_exception.player_id;
    end if;
  end if;

  v_old_values:=jsonb_build_object(
    'revoked_at',v_exception.revoked_at,
    'revoked_by',v_exception.revoked_by,
    'revoke_reason',v_exception.revoke_reason,
    'suspension_id',v_exception.suspension_id,
    'matchday_id',v_exception.matchday_id
  );

  v_new_values:=jsonb_build_object(
    'revoked_at',now(),
    'revoked_by',v_actor,
    'revoked_by_snapshot',v_actor_name,
    'revoke_reason',btrim(p_revoke_reason),
    'suspension_id',v_exception.suspension_id,
    'matchday_id',v_exception.matchday_id,
    'nomination_removed',v_nomination_snapshot is not null,
    'removed_nomination_snapshot',v_nomination_snapshot
  );

  insert into public.training_suspension_audit(
    exception_id,action,old_values,new_values,reason,changed_by,changed_at
  ) values (
    v_exception.id,'exception_revoked',v_old_values,v_new_values,
    btrim(p_revoke_reason),v_actor,now()
  );

  return v_exception.id;
end;
$function$;

-- CREATE OR REPLACE erhält die bestehenden ACLs; zur Sicherheit explizit
-- dieselbe dokumentierte RPC-Berechtigung setzen.
revoke all on function public.revoke_suspension_exception(uuid,text)
from public,anon,authenticated,service_role;
grant execute on function public.revoke_suspension_exception(uuid,text)
to authenticated;

commit;

-- Nach Freigabe zwingend:
-- 1) pg_get_functiondef/ACL erneut lesen.
-- 2) Positivtest: Ausnahme widerrufen ohne vorhandene Nominierung.
-- 3) Positivtest: bestehende Nominierung wird gelöscht und Snapshot auditiert.
-- 4) Negativtest: played=true blockiert den Widerruf vollständig (Rollback).
-- 5) Konkurrenztest: paralleler INSERT wartet auf Advisory Lock und wird nach
--    Widerruf durch den Trigger abgewiesen.
-- 6) Trainer/Admin/Superadmin-Kontext und unberechtigte Rolle testen.
-- 7) Kein Test mit echten Produktivdaten; ausschließlich DEV-Testdatensätze.
