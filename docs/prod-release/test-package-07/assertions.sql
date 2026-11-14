\set ON_ERROR_STOP on
do $assert$
begin
 if to_regclass('public.team_season_closure_audit') is null then raise exception 'Closure audit table missing'; end if;
 if to_regprocedure('public.close_team_season(uuid,text)') is null then raise exception 'Close season RPC missing'; end if;
 if not (select relrowsecurity from pg_class where oid='public.team_season_closure_audit'::regclass) then raise exception 'RLS is not enabled'; end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='team_season_closure_audit' and policyname='team_season_closure_audit_select_team' and qual like '%has_selected_team_context%') then raise exception 'Selected team context read policy missing'; end if;
 if not exists(select 1 from pg_trigger where tgrelid='public.team_season_closure_audit'::regclass and tgname='team_season_closure_audit_no_mutation' and not tgisinternal) then raise exception 'Append-only trigger missing'; end if;
 if not (select prosecdef from pg_proc where oid='public.close_team_season(uuid,text)'::regprocedure) then raise exception 'RPC must be SECURITY DEFINER'; end if;
 if not has_function_privilege('authenticated','public.close_team_season(uuid,text)','EXECUTE') or has_function_privilege('anon','public.close_team_season(uuid,text)','EXECUTE') then raise exception 'Unexpected RPC ACL'; end if;
 if has_table_privilege('authenticated','public.team_season_closure_audit','INSERT') or has_table_privilege('authenticated','public.team_season_closure_audit','UPDATE') or has_table_privilege('authenticated','public.team_season_closure_audit','DELETE') then raise exception 'Authenticated has direct audit write privilege'; end if;
end
$assert$;

insert into auth.users(id) values ('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002');
insert into public.teams(id) values ('20000000-0000-0000-0000-000000000001');
insert into public.profiles(id,display_name) values ('10000000-0000-0000-0000-000000000001','Team Admin'),('10000000-0000-0000-0000-000000000002','Trainer');
insert into public.team_member_roles values ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','admin'),('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','trainer');
insert into public.global_user_roles values ('10000000-0000-0000-0000-000000000001','super_admin');
insert into public.seasons(id,team_id,name,is_active) values ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Test Season',true);
insert into public.training_suspensions(id,team_id,season_id,player_name_snapshot,source_event_id,suspension_type,status)
values
 ('40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Yellow Test','50000000-0000-0000-0000-000000000001','yellow','open'),
 ('40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Red Test','50000000-0000-0000-0000-000000000002','red','open'),
 ('40000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Served Test','50000000-0000-0000-0000-000000000003','yellow','served');
update public.training_suspensions set served_at=now() where id='40000000-0000-0000-0000-000000000003';

-- Negative authorization and input checks are tested in separate rollback scopes.
begin;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
do $negative$
begin
 begin perform public.close_team_season('30000000-0000-0000-0000-000000000001','Trainer denied'); raise exception 'Trainer unexpectedly closed season';
 exception when insufficient_privilege then null; end;
end
$negative$;
rollback;

begin;
select set_config('request.jwt.claim.sub','',true);
do $negative$
begin
 begin perform public.close_team_season('30000000-0000-0000-0000-000000000001','Unauth denied'); raise exception 'Unauthenticated call unexpectedly succeeded';
 exception when insufficient_privilege then null; end;
end
$negative$;
rollback;


begin;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select public.close_team_season('30000000-0000-0000-0000-000000000001','CI controlled season closure');
do $functional$
begin
 if (select is_active from public.seasons where id='30000000-0000-0000-0000-000000000001') then raise exception 'Season remained active'; end if;
 if (select count(*) from public.training_suspensions where status='expired')<>2 then raise exception 'Expected exactly two expired open suspensions'; end if;
 if (select status from public.training_suspensions where id='40000000-0000-0000-0000-000000000003')<>'served' then raise exception 'Served suspension was changed'; end if;
 if (select count(*) from public.training_suspension_audit where action='expired')<>2 then raise exception 'Expected two expired suspension audit records'; end if;
 if (select expired_suspensions_count from public.team_season_closure_audit limit 1)<>2 then raise exception 'Closure audit count incorrect'; end if;
 if (select reason from public.team_season_closure_audit limit 1)<>'CI controlled season closure' then raise exception 'Closure reason incorrect'; end if;
end
$functional$;
rollback;

-- Audit append-only behavior.
begin;
insert into public.team_season_closure_audit(team_id,season_id,reason,season_name_snapshot)
values('20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','test','Test');
do $negative$
begin
 begin update public.team_season_closure_audit set reason='tampered'; raise exception 'Audit UPDATE unexpectedly succeeded';
 exception when raise_exception then
   if sqlerrm='Audit UPDATE unexpectedly succeeded' then raise; end if;
 end;
end
$negative$;
rollback;

delete from public.training_suspensions where id::text like '40000000-%';
delete from public.seasons where id='30000000-0000-0000-0000-000000000001';
delete from public.team_member_roles where user_id::text like '10000000-%';
delete from public.global_user_roles where user_id::text like '10000000-%';
delete from public.profiles where id::text like '10000000-%';
delete from public.teams where id='20000000-0000-0000-0000-000000000001';
delete from auth.users where id::text like '10000000-%';
do $clean$
begin
 if exists(select 1 from public.team_season_closure_audit) then raise exception 'CI left audit fixtures behind'; end if;
 if exists(select 1 from public.training_suspensions where id::text like '40000000-%') then raise exception 'CI left suspension fixtures behind'; end if;
end
$clean$;
