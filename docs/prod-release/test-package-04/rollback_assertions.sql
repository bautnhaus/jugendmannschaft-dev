\set ON_ERROR_STOP on
do $rollback_assert$
begin
 if to_regclass('public.club_suspension_settings') is not null
 or to_regclass('public.team_suspension_game_type_settings') is not null
 or to_regclass('public.team_suspension_game_types') is not null then
  raise exception 'Package 4 tables remain after rollback';
 end if;
 if to_regprocedure('public.serve_matchday_suspensions(uuid)') is not null
 or to_regprocedure('public.assign_next_suspension_matchday(uuid,uuid)') is not null
 or to_regprocedure('public.set_club_suspension_game_types(uuid,text[])') is not null then
  raise exception 'Package 4 RPC remains after rollback';
 end if;
end;
$rollback_assert$;
