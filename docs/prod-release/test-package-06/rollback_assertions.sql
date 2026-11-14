\set ON_ERROR_STOP on
do $assert$
declare v_def text;
begin
 if to_regprocedure('public.revoke_suspension_exception(uuid,text)') is null then
   raise exception 'Rollback removed revoke RPC unexpectedly';
 end if;
 select pg_get_functiondef('public.revoke_suspension_exception(uuid,text)'::regprocedure) into v_def;
 if position('pg_advisory_xact_lock' in v_def)>0 then
   raise exception 'Rollback did not restore prior revoke RPC';
 end if;
 select pg_get_functiondef('public.prevent_suspended_matchday_nomination()'::regprocedure) into v_def;
 if position('pg_advisory_xact_lock' in v_def)>0 then
   raise exception 'Rollback did not restore prior nomination trigger function';
 end if;
 if not exists(select 1 from pg_trigger where tgrelid='public.matchday_players'::regclass and tgname='matchday_players_prevent_suspended_nomination' and not tgisinternal) then
   raise exception 'Nomination trigger missing after rollback';
 end if;
end;
$assert$;
