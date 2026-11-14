\set ON_ERROR_STOP on

-- Security and structure assertions.
do $assert$
begin
 if to_regclass('public.training_suspensions') is null
    or to_regclass('public.training_suspension_audit') is null then
   raise exception 'Package 3 tables missing';
 end if;
 if not (select relrowsecurity from pg_class where oid='public.training_suspensions'::regclass)
    or not (select relrowsecurity from pg_class where oid='public.training_suspension_audit'::regclass) then
   raise exception 'RLS not enabled';
 end if;
 if (select count(*) from pg_policies where schemaname='public' and tablename='training_suspensions')<>1
    or (select count(*) from pg_policies where schemaname='public' and tablename='training_suspension_audit')<>1 then
   raise exception 'Unexpected package 3 policy count';
 end if;
 if has_table_privilege('authenticated','public.training_suspensions','INSERT')
    or has_table_privilege('authenticated','public.training_suspensions','UPDATE')
    or has_table_privilege('authenticated','public.training_suspensions','DELETE')
    or has_table_privilege('anon','public.training_suspensions','SELECT') then
   raise exception 'Unexpected direct table privileges';
 end if;
 if not has_table_privilege('authenticated','public.training_suspensions','SELECT')
    or not has_table_privilege('service_role','public.training_suspensions','SELECT') then
   raise exception 'Expected SELECT privileges missing';
 end if;
 if not has_function_privilege('authenticated','public.award_training_behavior_event(uuid,uuid,text,text)','EXECUTE')
    or has_function_privilege('anon','public.award_training_behavior_event(uuid,uuid,text,text)','EXECUTE')
    or has_function_privilege('service_role','public.award_training_behavior_event(uuid,uuid,text,text)','EXECUTE') then
   raise exception 'Unexpected award RPC ACL';
 end if;
 if not (select prosecdef from pg_proc where oid='public.award_training_behavior_event(uuid,uuid,text,text)'::regprocedure) then
   raise exception 'Award RPC is not SECURITY DEFINER';
 end if;
 if (select proconfig from pg_proc where oid='public.award_training_behavior_event(uuid,uuid,text,text)'::regprocedure)
    is distinct from array['search_path=pg_catalog, public, auth'] then
   raise exception 'Unexpected award RPC search_path';
 end if;
 if (select count(*) from pg_trigger where tgrelid='public.training_suspension_audit'::regclass and not tgisinternal)<>2 then
   raise exception 'Expected two append-only audit triggers';
 end if;
end;
$assert$;

begin;
do $functional$
declare
 v_actor uuid:=gen_random_uuid();
 v_team uuid:=gen_random_uuid();
 v_season uuid:=gen_random_uuid();
 v_yellow_player uuid:=gen_random_uuid();
 v_red_player uuid:=gen_random_uuid();
 v_training uuid;
 v_event uuid;
 v_count integer;
 i integer;
begin
 insert into auth.users(id) values(v_actor);
 insert into public.teams(id,name) values(v_team,'CI Team');
 insert into public.seasons(id,team_id,name,is_active) values(v_season,v_team,'2026/27',true);
 insert into public.players(id,team_id,name,active)
 values(v_yellow_player,v_team,'Yellow CI',true),(v_red_player,v_team,'Red CI',true);
 insert into public.team_member_roles(team_id,user_id,role) values(v_team,v_actor,'trainer');
 perform set_config('request.jwt.claim.sub',v_actor::text,true);

 -- Four active yellow cards must not create a suspension.
 for i in 1..4 loop
   v_training:=gen_random_uuid();
   insert into public.trainings(id,team_id,training_date,name,status,season_id)
   values(v_training,v_team,current_date+i,'Yellow CI '||i,'planned',v_season);
   insert into public.attendance(training_id,player_id,present) values(v_training,v_yellow_player,true);
   perform public.award_training_behavior_event(v_training,v_yellow_player,'yellow_card','CI yellow');
 end loop;
 select count(*) into v_count from public.training_suspensions
 where player_id=v_yellow_player and suspension_type='yellow' and status='open';
 if v_count<>0 then raise exception 'Four yellow cards created a suspension'; end if;

 -- Fifth active yellow card creates exactly one open yellow suspension.
 v_training:=gen_random_uuid();
 insert into public.trainings(id,team_id,training_date,name,status,season_id)
 values(v_training,v_team,current_date+5,'Yellow CI 5','planned',v_season);
 insert into public.attendance(training_id,player_id,present) values(v_training,v_yellow_player,true);
 v_event:=public.award_training_behavior_event(v_training,v_yellow_player,'yellow_card','CI fifth yellow');
 select count(*) into v_count from public.training_suspensions
 where player_id=v_yellow_player and suspension_type='yellow' and status='open';
 if v_count<>1 then raise exception 'Fifth yellow did not create exactly one open suspension'; end if;
 if not exists(select 1 from public.training_suspensions where player_id=v_yellow_player and source_event_id is not null) then
   raise exception 'Yellow suspension source event missing';
 end if;
 select count(*) into v_count from public.training_suspension_audit sa
 join public.training_suspensions s on s.id=sa.suspension_id
 where s.player_id=v_yellow_player and sa.action='created';
 if v_count<>1 then raise exception 'Yellow suspension audit missing/duplicated'; end if;

 -- Red card creates exactly one red suspension with matching source event.
 v_training:=gen_random_uuid();
 insert into public.trainings(id,team_id,training_date,name,status,season_id)
 values(v_training,v_team,current_date+6,'Red CI','planned',v_season);
 insert into public.attendance(training_id,player_id,present) values(v_training,v_red_player,true);
 v_event:=public.award_training_behavior_event(v_training,v_red_player,'red_card','CI red');
 select count(*) into v_count from public.training_suspensions
 where player_id=v_red_player and suspension_type='red' and status='open' and source_event_id=v_event;
 if v_count<>1 then raise exception 'Red card did not create exactly one linked red suspension'; end if;

 -- Force suspension-audit failure: event, event-audit and suspension must roll back atomically.
 create or replace function public.ci_fail_suspension_audit()
 returns trigger language plpgsql as $$ begin raise exception 'forced audit failure'; end $$;
 create trigger ci_fail_suspension_audit before insert on public.training_suspension_audit
 for each row execute function public.ci_fail_suspension_audit();
 v_training:=gen_random_uuid();
 insert into public.trainings(id,team_id,training_date,name,status,season_id)
 values(v_training,v_team,current_date+7,'Atomicity CI','planned',v_season);
 insert into public.attendance(training_id,player_id,present) values(v_training,v_red_player,true);
 begin
   perform public.award_training_behavior_event(v_training,v_red_player,'red_card','CI atomic failure');
   raise exception 'Forced audit failure was not raised';
 exception when others then
   if sqlerrm='Forced audit failure was not raised' then raise; end if;
 end;
 drop trigger ci_fail_suspension_audit on public.training_suspension_audit;
 drop function public.ci_fail_suspension_audit();
 select count(*) into v_count from public.training_behavior_events e
 where e.training_id=v_training and e.player_id=v_red_player;
 if v_count<>0 then raise exception 'Event remained after suspension audit failure'; end if;
end;
$functional$;
rollback;
