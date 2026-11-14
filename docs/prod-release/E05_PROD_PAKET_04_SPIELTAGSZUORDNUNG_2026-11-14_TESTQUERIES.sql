-- E05 PROD Paket 4 – read-only verification
select to_regclass('public.club_suspension_settings') is not null as club_settings,
to_regclass('public.team_suspension_game_type_settings') is not null as team_override,
to_regclass('public.team_suspension_game_types') is not null as team_types,
(select count(*)=3 from pg_policies where schemaname='public' and tablename in ('club_suspension_settings','team_suspension_game_type_settings','team_suspension_game_types')) as policy_count_ok,
(select bool_and(relrowsecurity) from pg_class where oid in ('public.club_suspension_settings'::regclass,'public.team_suspension_game_type_settings'::regclass,'public.team_suspension_game_types'::regclass)) as rls_ok,
has_table_privilege('authenticated','public.club_suspension_settings','SELECT') as auth_select,
has_table_privilege('authenticated','public.club_suspension_settings','INSERT') as auth_insert,
has_table_privilege('anon','public.club_suspension_settings','SELECT') as anon_select,
has_function_privilege('authenticated','public.set_club_suspension_game_types(uuid,text[])','EXECUTE') as auth_club_rpc,
has_function_privilege('authenticated','public.set_team_suspension_game_types(uuid,boolean,text[])','EXECUTE') as auth_team_rpc,
has_function_privilege('authenticated','public.assign_next_suspension_matchday(uuid,uuid)','EXECUTE') as auth_assign_rpc,
has_function_privilege('authenticated','public.serve_matchday_suspensions(uuid)','EXECUTE') as auth_serve_rpc,
has_function_privilege('anon','public.serve_matchday_suspensions(uuid)','EXECUTE') as anon_serve_rpc,
has_function_privilege('authenticated','public.e05_assign_player_suspensions(uuid,uuid,uuid)','EXECUTE') as auth_internal_helper;
select p.proname,pg_get_function_identity_arguments(p.oid) args,p.prosecdef,p.proconfig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('set_club_suspension_game_types','set_team_suspension_game_types','e05_assign_player_suspensions','assign_next_suspension_matchday','serve_matchday_suspensions') order by p.proname;
