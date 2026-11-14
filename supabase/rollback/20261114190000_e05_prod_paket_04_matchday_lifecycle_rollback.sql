-- KADAssist E05 PROD Paket 4 – guarded rollback
-- Removes only package 4 objects/functions. Never use CASCADE.
begin;
do $guard$
begin
 if exists (select 1 from public.training_suspensions where intended_matchday_id is not null or served_matchday_id is not null) then
   raise exception 'Rollback blocked: suspension rows reference package 4 matchday lifecycle';
 end if;
 if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname in (
    'create_matchday_suspension_exception','revoke_matchday_suspension_exception',
    'close_team_season','schedule_early_suspension_reset','cancel_early_suspension_reset',
    'correct_training_behavior_event','grant_suspension_exception','revoke_suspension_exception',
    'correct_suspension','e05_reconcile_suspensions_after_event_correction'
   )) then
   raise exception 'Rollback blocked: downstream E05 functions are installed';
 end if;
 if exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname in (
    'training_suspension_exceptions','team_season_closure_audit',
    'matchday_early_suspension_resets','matchday_early_suspension_reset_audit'
   )) then
   raise exception 'Rollback blocked: downstream E05 tables are installed';
 end if;
 if exists (select 1 from public.club_suspension_settings)
    or exists (select 1 from public.team_suspension_game_type_settings)
    or exists (select 1 from public.team_suspension_game_types) then
   raise exception 'Rollback blocked: package 4 settings data exists; preserve configuration and use recovery';
 end if;
end;
$guard$;

drop function if exists public.serve_matchday_suspensions(uuid);
drop function if exists public.assign_next_suspension_matchday(uuid,uuid);
drop function if exists public.e05_assign_player_suspensions(uuid,uuid,uuid);
drop function if exists public.set_team_suspension_game_types(uuid,boolean,text[]);
drop function if exists public.set_club_suspension_game_types(uuid,text[]);
drop table public.team_suspension_game_types;
drop table public.team_suspension_game_type_settings;
drop table public.club_suspension_settings;
commit;
