-- E05 PROD Paket 5: Spieltagsausnahmen bei Sperren
-- Quelle: DEV-Migrationen 20261108160747 und 20261108161109
-- Konsolidiert auf den final in DEV ausgelesenen Live-Stand.
-- Nur nach ausdrücklicher Freigabe in Supabase PROD ausführen.

begin;

do $preflight$
begin
  if to_regclass('public.training_suspensions') is null
     or to_regclass('public.training_suspension_audit') is null
     or to_regclass('public.matchdays') is null
     or to_regclass('public.players') is null then
    raise exception 'E05 Paket 5 abgebrochen: Paket-3/4-Basistabellen fehlen.';
  end if;
  if to_regclass('public.training_suspension_exceptions') is not null
     or to_regprocedure('public.grant_suspension_exception(uuid,uuid,text)') is not null then
    raise exception 'E05 Paket 5 abgebrochen: Ausnahme-Tabelle oder RPC existiert bereits; zuerst Bestand manuell abgleichen.';
  end if;
  if to_regprocedure('public.e05_assign_player_suspensions(uuid,uuid,uuid)') is null then
    raise exception 'E05 Paket 5 abgebrochen: Zuordnungsfunktion aus Paket 4 fehlt.';
  end if;
end
$preflight$;

create table public.training_suspension_exceptions (
  id uuid primary key default gen_random_uuid(),
  suspension_id uuid not null references public.training_suspensions(id) on delete restrict,
  team_id uuid not null,
  team_name_snapshot text not null,
  player_id uuid references public.players(id) on delete set null,
  player_name_snapshot text not null,
  matchday_id uuid not null,
  matchday_date_snapshot date not null,
  matchday_opponent_snapshot text,
  reason text not null,
  granted_by uuid references auth.users(id) on delete set null,
  granted_by_snapshot text,
  granted_at timestamptz not null default now(),
  revoked_by uuid references auth.users(id) on delete set null,
  revoked_by_snapshot text,
  revoked_at timestamptz,
  revoke_reason text,
  constraint training_suspension_exceptions_reason_check
    check (nullif(btrim(reason), '') is not null),
  constraint training_suspension_exceptions_revocation_check
    check (
      (revoked_at is null and revoked_by is null and revoke_reason is null)
      or
      (revoked_at is not null and nullif(btrim(revoke_reason), '') is not null)
    )
);

create unique index training_suspension_exceptions_one_active_per_suspension_matchd
  on public.training_suspension_exceptions (suspension_id, matchday_id)
  where revoked_at is null;

create index training_suspension_exceptions_matchday_idx
  on public.training_suspension_exceptions (team_id, matchday_id);

alter table public.training_suspension_exceptions enable row level security;

create policy training_suspension_exceptions_read
  on public.training_suspension_exceptions
  for select to authenticated
  using (is_team_member(team_id) or has_selected_team_context(team_id));

revoke all on table public.training_suspension_exceptions from public, anon, authenticated;
grant select on table public.training_suspension_exceptions to authenticated, service_role;

create or replace function public.grant_suspension_exception(
  p_suspension_id uuid,
  p_matchday_id uuid,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'auth'
as $function$
declare
  v_actor uuid := auth.uid();
  v_suspension public.training_suspensions%rowtype;
  v_matchday public.matchdays%rowtype;
  v_team_name text;
  v_player_name text;
  v_actor_name text;
  v_exception_id uuid;
  v_reassigned integer;
begin
  if v_actor is null then
    raise exception using errcode='42501',message='Authentication required';
  end if;
  if p_suspension_id is null or p_matchday_id is null
     or nullif(btrim(p_reason),'') is null then
    raise exception using errcode='22023',message='Suspension, matchday and reason are required';
  end if;

  select * into v_suspension
  from public.training_suspensions
  where id=p_suspension_id;
  if not found then
    raise exception using errcode='P0002',message='Suspension not found';
  end if;

  -- Lock player first. All grant/revoke operations for this player serialize
  -- before they lock suspension rows and recalculate their targets.
  if v_suspension.player_id is not null then
    perform 1 from public.players p where p.id=v_suspension.player_id for update;
  end if;

  select * into v_suspension
  from public.training_suspensions
  where id=p_suspension_id
  for update;
  if not found then
    raise exception using errcode='P0002',message='Suspension not found';
  end if;
  if v_suspension.status<>'open' then
    raise exception using errcode='23514',message='Only an open suspension can receive an exception';
  end if;

  if not exists (
    select 1 from public.team_member_roles r
    where r.team_id=v_suspension.team_id
      and r.user_id=v_actor and r.role in ('trainer','admin')
  ) and not (
    exists (
      select 1 from public.global_user_roles g
      where g.user_id=v_actor and g.role='super_admin'
    )
    and public.has_selected_team_context(v_suspension.team_id)
  ) then
    raise exception using errcode='42501',message='Team permission required';
  end if;

  select * into v_matchday
  from public.matchdays
  where id=p_matchday_id
  for update;
  if not found then
    raise exception using errcode='P0002',message='Matchday not found';
  end if;

  if v_matchday.team_id<>v_suspension.team_id
     or v_matchday.season_id is distinct from v_suspension.season_id
     or v_matchday.id is distinct from v_suspension.intended_matchday_id
     or v_matchday.status<>'planned' then
    raise exception using errcode='23514',
      message='Exception must refer to the currently assigned planned matchday in the same team and season';
  end if;

  select t.name into v_team_name from public.teams t where t.id=v_suspension.team_id;
  select p.name into v_player_name from public.players p where p.id=v_suspension.player_id;
  select pr.display_name into v_actor_name from public.profiles pr where pr.id=v_actor;

  insert into public.training_suspension_exceptions(
    suspension_id,team_id,team_name_snapshot,player_id,player_name_snapshot,
    matchday_id,matchday_date_snapshot,matchday_opponent_snapshot,
    reason,granted_by,granted_by_snapshot,granted_at
  ) values (
    v_suspension.id,v_suspension.team_id,coalesce(v_team_name,v_suspension.team_id::text),
    v_suspension.player_id,coalesce(v_player_name,v_suspension.player_name_snapshot),
    v_matchday.id,v_matchday.match_date,v_matchday.opponent,
    btrim(p_reason),v_actor,v_actor_name,now()
  ) returning id into v_exception_id;

  insert into public.training_suspension_audit(
    exception_id,action,old_values,new_values,reason,changed_by,changed_at
  ) values (
    v_exception_id,'exception_granted',null,
    jsonb_build_object(
      'suspension_id',v_suspension.id,
      'matchday_id',v_matchday.id,
      'matchday_date',v_matchday.match_date,
      'matchday_opponent',v_matchday.opponent,
      'reason',btrim(p_reason)
    ),
    btrim(p_reason),v_actor,now()
  );

  v_reassigned:=public.e05_assign_player_suspensions(
    v_suspension.team_id,v_suspension.player_id,v_actor
  );

  return v_exception_id;
end;
$function$;

alter function public.grant_suspension_exception(uuid,uuid,text) owner to postgres;
revoke all on function public.grant_suspension_exception(uuid,uuid,text) from public, anon, service_role;
grant execute on function public.grant_suspension_exception(uuid,uuid,text) to authenticated;

commit;
