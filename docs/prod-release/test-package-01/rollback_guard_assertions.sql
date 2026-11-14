\set ON_ERROR_STOP on

-- Guard 1: data must prevent rollback.
insert into public.training_behavior_events
(team_id,season_id,training_id,training_date_snapshot,training_name_snapshot,player_name_snapshot,event_type)
values
(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),current_date,'Rollback guard','Rollback guard','positive_star');

\set ON_ERROR_STOP off
\o /tmp/e05-rollback-data-guard.log
\i docs/prod-release/E05_PROD_PAKET_01_TRAININGSEREIGNISSE_2026-11-14_ROLLBACK.sql
\o
\set ON_ERROR_STOP on

-- A successful execution above would have removed the table; assert that it did not.
do $assert_data_guard$
begin
  if to_regclass('public.training_behavior_events') is null then
    raise exception 'Rollback data guard failed: table was removed despite data';
  end if;
end;
$assert_data_guard$;

-- Remove only the synthetic event (no audit row was created in this guard fixture).
delete from public.training_behavior_events;

-- Guard 2: an installed dependent package must prevent rollback.
create function public.award_training_behavior_event(uuid,uuid,text,text)
returns uuid language sql as $$ select null::uuid $$;

\set ON_ERROR_STOP off
\o /tmp/e05-rollback-dependency-guard.log
\i docs/prod-release/E05_PROD_PAKET_01_TRAININGSEREIGNISSE_2026-11-14_ROLLBACK.sql
\o
\set ON_ERROR_STOP on

do $assert_dependency_guard$
begin
  if to_regclass('public.training_behavior_events') is null then
    raise exception 'Rollback dependency guard failed: table was removed despite dependent RPC';
  end if;
end;
$assert_dependency_guard$;

drop function public.award_training_behavior_event(uuid,uuid,text,text);
