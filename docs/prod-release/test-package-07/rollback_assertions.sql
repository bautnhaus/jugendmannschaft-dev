\set ON_ERROR_STOP on
do $assert$
begin
 if to_regclass('public.team_season_closure_audit') is not null then raise exception 'Rollback left audit table'; end if;
 if to_regprocedure('public.close_team_season(uuid,text)') is not null then raise exception 'Rollback left season closure RPC'; end if;
 if to_regprocedure('public.e05_reject_season_closure_audit_mutation()') is not null then raise exception 'Rollback left append-only trigger function'; end if;
end
$assert$;
