-- Read-only verification queries for E05 PROD Paket 3
select
  to_regclass('public.training_suspensions') is not null as suspensions_table,
  to_regclass('public.training_suspension_audit') is not null as suspension_audit_table,
  to_regprocedure('public.e05_reject_suspension_audit_mutation()') is not null as audit_guard,
  (select relrowsecurity from pg_class where oid=to_regclass('public.training_suspensions')) as suspensions_rls,
  (select relrowsecurity from pg_class where oid=to_regclass('public.training_suspension_audit')) as audit_rls,
  (select count(*) from pg_policies where schemaname='public' and tablename='training_suspensions') as suspensions_policies,
  (select count(*) from pg_policies where schemaname='public' and tablename='training_suspension_audit') as audit_policies,
  (select count(*) from pg_indexes where schemaname='public' and tablename='training_suspensions') as suspensions_indexes,
  (select count(*) from pg_indexes where schemaname='public' and tablename='training_suspension_audit') as audit_indexes,
  (select count(*) from pg_trigger where tgrelid='public.training_suspension_audit'::regclass and not tgisinternal) as audit_triggers,
  has_table_privilege('authenticated','public.training_suspensions','SELECT') as auth_suspension_select,
  has_table_privilege('authenticated','public.training_suspensions','INSERT') as auth_suspension_insert,
  has_table_privilege('anon','public.training_suspensions','SELECT') as anon_suspension_select,
  has_function_privilege('authenticated','public.award_training_behavior_event(uuid,uuid,text,text)','EXECUTE') as auth_award_execute,
  has_function_privilege('anon','public.award_training_behavior_event(uuid,uuid,text,text)','EXECUTE') as anon_award_execute,
  has_function_privilege('service_role','public.award_training_behavior_event(uuid,uuid,text,text)','EXECUTE') as service_award_execute,
  pg_get_functiondef('public.award_training_behavior_event(uuid,uuid,text,text)'::regprocedure) like '%training_suspensions%' as award_contains_suspension_logic;
