-- E05 PROD Paket 6: guarded rollback
-- Grundlage: docs/E05_SQL_ROLLBACK_ENTWURF_WIDERRUF_AUSNAHME_2026-11-12.sql
-- Der Rollback stellt die vorherigen Funktionsdefinitionen wieder her.
-- Entfernte Nominierungen werden NICHT rekonstruiert.
-- Nur nach gesonderter ausdrücklicher Freigabe ausführen.

begin;

do $preflight$
begin
  if exists (
    select 1
    from public.training_suspension_audit
    where action = 'exception_revoked'
       or coalesce(new_values->>'nomination_removed','false') = 'true'
  ) then
    raise exception 'Rollback Paket 6 abgebrochen: Widerrufe oder entfernte Nominierungen sind bereits produktiv dokumentiert. Audit-Historie und Nominierungen werden nicht automatisch rekonstruiert.';
  end if;
end;
$preflight$;

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

  -- Match the grant RPC lock order: player, suspension, exception, matchday.
  if v_exception.player_id is not null then
    perform 1 from public.players p where p.id=v_exception.player_id for update;
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

  v_old_values:=jsonb_build_object(
    'revoked_at',v_exception.revoked_at,
    'revoked_by',v_exception.revoked_by,
    'revoke_reason',v_exception.revoke_reason,
    'suspension_id',v_exception.suspension_id,
    'matchday_id',v_exception.matchday_id
  );

  update public.training_suspension_exceptions
  set revoked_by=v_actor,
      revoked_by_snapshot=v_actor_name,
      revoked_at=now(),
      revoke_reason=btrim(p_revoke_reason)
  where id=v_exception.id;

  v_new_values:=jsonb_build_object(
    'revoked_at',now(),
    'revoked_by',v_actor,
    'revoked_by_snapshot',v_actor_name,
    'revoke_reason',btrim(p_revoke_reason),
    'suspension_id',v_exception.suspension_id,
    'matchday_id',v_exception.matchday_id
  );

  insert into public.training_suspension_audit(
    exception_id,action,old_values,new_values,reason,changed_by,changed_at
  ) values (
    v_exception.id,'exception_revoked',v_old_values,v_new_values,
    btrim(p_revoke_reason),v_actor,now()
  );

  if v_suspension.player_id is not null then
    v_reassigned:=public.e05_assign_player_suspensions(
      v_suspension.team_id,v_suspension.player_id,v_actor
    );
  end if;

  return v_exception.id;
end;
$function$;

revoke all on function public.revoke_suspension_exception(uuid,text)
from public,anon,authenticated,service_role;
grant execute on function public.revoke_suspension_exception(uuid,text)
to authenticated;

commit;
