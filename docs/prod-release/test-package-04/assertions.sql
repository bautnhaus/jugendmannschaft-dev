\set ON_ERROR_STOP on
do $assert$
begin
 if to_regclass('public.club_suspension_settings') is null
 or to_regclass('public.team_suspension_game_type_settings') is null
 or to_regclass('public.team_suspension_game_types') is null then
 raise exception 'Package 4 configuration tables missing'; end if;
 if (select count(*) from pg_policies where schemaname='public' and tablename in
 ('club_suspension_settings','team_suspension_game_type_settings','team_suspension_game_types'))<>3 then
 raise exception 'Unexpected package 4 policy count'; end if;
 if exists(select 1 from pg_class where oid in
 ('public.club_suspension_settings'::regclass,'public.team_suspension_game_type_settings'::regclass,'public.team_suspension_game_types'::regclass)
 and not relrowsecurity) then raise exception 'RLS not enabled'; end if;
 if has_table_privilege('authenticated','public.club_suspension_settings','INSERT')
 or has_table_privilege('authenticated','public.team_suspension_game_types','DELETE')
 or has_table_privilege('anon','public.club_suspension_settings','SELECT') then
 raise exception 'Unexpected direct config table privileges'; end if;
 if not has_function_privilege('authenticated','public.set_club_suspension_game_types(uuid,text[])','EXECUTE')
 or not has_function_privilege('authenticated','public.set_team_suspension_game_types(uuid,boolean,text[])','EXECUTE')
 or not has_function_privilege('authenticated','public.assign_next_suspension_matchday(uuid,uuid)','EXECUTE')
 or not has_function_privilege('authenticated','public.serve_matchday_suspensions(uuid)','EXECUTE')
 or has_function_privilege('anon','public.serve_matchday_suspensions(uuid)','EXECUTE')
 or has_function_privilege('authenticated','public.e05_assign_player_suspensions(uuid,uuid,uuid)','EXECUTE') then
 raise exception 'Unexpected package 4 RPC ACL'; end if;
 if (select count(*) from pg_proc where proname in
 ('set_club_suspension_game_types','set_team_suspension_game_types','assign_next_suspension_matchday','serve_matchday_suspensions')
 and prosecdef)<>4 then raise exception 'Public package 4 RPCs must be SECURITY DEFINER'; end if;
end;
$assert$;

begin;
do $functional$
declare
 actor uuid:=gen_random_uuid();
 team uuid:=gen_random_uuid();
 club uuid:=gen_random_uuid();
 season uuid:=gen_random_uuid();
 player uuid:=gen_random_uuid();
 matchday uuid:=gen_random_uuid();
begin
 insert into auth.users(id) values(actor);
 insert into public.clubs(id,name) values(club,'CI Club');
 insert into public.teams(id,name,club_id) values(team,'CI Team',club);
 insert into public.seasons(id,team_id,name,is_active) values(season,team,'2026/27',true);
 insert into public.players(id,team_id,name,active) values(player,team,'CI Player',true);
 insert into public.team_member_roles(team_id,user_id,role) values(team,actor,'trainer');
 insert into public.user_club_context(user_id,club_id) values(actor,club);
 perform set_config('request.jwt.claim.sub',actor::text,true);

 perform public.set_club_suspension_game_types(club,array['Meisterschaft','Turnier']);
 if not exists(select 1 from public.club_suspension_settings where club_id=club and relevant_game_types @> array['Meisterschaft','Turnier']) then
 raise exception 'Club defaults not persisted'; end if;
 perform public.set_team_suspension_game_types(team,true,array['Freundschaftsspiel']);
 if not exists(select 1 from public.team_suspension_game_types where team_id=team and game_type='Freundschaftsspiel') then
 raise exception 'Team override not persisted'; end if;
 perform public.set_team_suspension_game_types(team,false,'{}');
 if exists(select 1 from public.team_suspension_game_type_settings where team_id=team) then
 raise exception 'Disabling override did not restore club defaults'; end if;
 perform public.set_team_suspension_game_types(team,true,'{}');
 if not exists(select 1 from public.team_suspension_game_type_settings where team_id=team)
 or exists(select 1 from public.team_suspension_game_types where team_id=team) then
 raise exception 'Explicit empty override not represented'; end if;
 if public.assign_next_suspension_matchday(team,player)<>0 then
 raise exception 'Assignment should return zero when player has no open suspensions'; end if;
 insert into public.matchdays(id,team_id,season_id,match_date,opponent,game_type,status)
 values(matchday,team,season,current_date,'CI Opponent','Meisterschaft','done');
 if public.serve_matchday_suspensions(matchday)<>0 then
 raise exception 'Serving should return zero without assigned suspensions'; end if;
end;
$functional$;
rollback;
