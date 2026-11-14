\set ON_ERROR_STOP on

do $acl$
begin
 if not has_function_privilege('authenticated','public.award_training_behavior_event(uuid,uuid,text,text)','EXECUTE') then
   raise exception 'authenticated EXECUTE missing';
 end if;
 if has_function_privilege('anon','public.award_training_behavior_event(uuid,uuid,text,text)','EXECUTE')
    or has_function_privilege('service_role','public.award_training_behavior_event(uuid,uuid,text,text)','EXECUTE')
     then
   raise exception 'unexpected EXECUTE grant to anon/service_role/PUBLIC';
 end if;
 if not (select prosecdef from pg_proc where oid='public.award_training_behavior_event(uuid,uuid,text,text)'::regprocedure) then
   raise exception 'RPC is not SECURITY DEFINER';
 end if;
 if (select proconfig from pg_proc where oid='public.award_training_behavior_event(uuid,uuid,text,text)'::regprocedure)
    is distinct from array['search_path=pg_catalog, public, auth'] then
   raise exception 'Unexpected search_path';
 end if;
end;
$acl$;

begin;
do $functional$
declare
 v_actor uuid:=gen_random_uuid();
 v_no_role uuid:=gen_random_uuid();
 v_team uuid:=gen_random_uuid();
 v_season uuid:=gen_random_uuid();
 v_training uuid:=gen_random_uuid();
 v_cancelled uuid:=gen_random_uuid();
 v_player uuid:=gen_random_uuid();
 v_absent_player uuid:=gen_random_uuid();
 v_event uuid;
 v_count integer;
begin
 insert into auth.users(id) values(v_actor),(v_no_role);
 insert into public.seasons(id,team_id,name,is_active) values(v_season,v_team,'2026/27',true);
 insert into public.trainings(id,team_id,training_date,name,status,season_id)
 values(v_training,v_team,current_date,'Paket 2 CI','planned',v_season),
       (v_cancelled,v_team,current_date,'Cancelled CI','cancelled',v_season);
 insert into public.players(id,team_id,name,active)
 values(v_player,v_team,'CI Player',true),(v_absent_player,v_team,'Absent Player',true);
 insert into public.attendance(training_id,player_id,present) values(v_training,v_player,true);
 insert into public.team_member_roles(team_id,user_id,role) values(v_team,v_actor,'trainer');

 perform set_config('request.jwt.claim.sub',v_actor::text,true);

 v_event:=public.award_training_behavior_event(v_training,v_player,'yellow_card','CI reason');
 if v_event is null then raise exception 'RPC returned NULL event id'; end if;
 select count(*) into v_count from public.training_behavior_events where id=v_event and status='active';
 if v_count<>1 then raise exception 'Event row missing'; end if;
 select count(*) into v_count from public.training_behavior_event_audit where event_id=v_event and action='created';
 if v_count<>1 then raise exception 'Atomic audit row missing'; end if;

 -- Card and star may coexist for the same player/training.
 perform public.award_training_behavior_event(v_training,v_player,'positive_star',null);

 -- Duplicate active card is rejected by Paket-1 unique index.
 begin
   perform public.award_training_behavior_event(v_training,v_player,'red_card','duplicate');
   raise exception 'Duplicate active card unexpectedly accepted';
 exception when unique_violation then null;
 end;

 -- Missing attendance is rejected.
 begin
   perform public.award_training_behavior_event(v_training,v_absent_player,'positive_star',null);
   raise exception 'Absent player unexpectedly accepted';
 exception when check_violation then null;
 end;

 -- Cancelled training is rejected.
 begin
   perform public.award_training_behavior_event(v_cancelled,v_player,'positive_star',null);
   raise exception 'Cancelled training unexpectedly accepted';
 exception when check_violation then null;
 end;

 -- Missing card reason is rejected.
 begin
   perform public.award_training_behavior_event(v_training,v_absent_player,'yellow_card',null);
   raise exception 'Card without reason unexpectedly accepted';
 exception when invalid_parameter_value then null;
 end;

 -- User without target-team role is rejected.
 perform set_config('request.jwt.claim.sub',v_no_role::text,true);
 begin
   perform public.award_training_behavior_event(v_training,v_player,'positive_star',null);
   raise exception 'User without team role unexpectedly accepted';
 exception when insufficient_privilege then null;
 end;

 select count(*) into v_count from public.training_behavior_events;
 if v_count<>2 then raise exception 'Expected exactly two valid events, got %',v_count; end if;
 select count(*) into v_count from public.training_behavior_event_audit;
 if v_count<>2 then raise exception 'Expected exactly two audit rows, got %',v_count; end if;
end;
$functional$;
rollback;
