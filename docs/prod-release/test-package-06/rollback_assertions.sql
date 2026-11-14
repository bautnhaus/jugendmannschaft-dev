\set ON_ERROR_STOP on
do $assert$
begin
 if to_regprocedure('public.revoke_suspension_exception(uuid,text)') is not null then
   raise exception 'Rollback left revoke RPC behind';
 end if;
 if to_regprocedure('public.prevent_suspended_matchday_nomination()') is not null then
   raise exception 'Rollback left nomination trigger function behind';
 end if;
 if exists(select 1 from pg_trigger where tgrelid='public.matchday_players'::regclass and tgname='matchday_players_prevent_suspended_nomination' and not tgisinternal) then
   raise exception 'Rollback left package 6 nomination trigger behind';
 end if;
 if (select count(*) from pg_trigger where tgrelid='public.matchday_players'::regclass and not tgisinternal) <> 2 then
   raise exception 'Rollback changed unrelated pre-existing matchday_players triggers';
 end if;
end;
$assert$;
