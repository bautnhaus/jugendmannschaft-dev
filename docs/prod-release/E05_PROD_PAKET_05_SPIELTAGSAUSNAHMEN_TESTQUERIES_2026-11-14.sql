-- E05 PROD Paket 5: read-only post-deployment verification
-- Nach Ausführung der Migration vollständig ausführen.

select to_regclass('public.training_suspension_exceptions') as exceptions_table,
       to_regprocedure('public.grant_suspension_exception(uuid,uuid,text)') as grant_rpc;

select c.relrowsecurity,
       c.relforcerowsecurity
from pg_class c
where c.oid='public.training_suspension_exceptions'::regclass;

select policyname,cmd,roles,qual,with_check
from pg_policies
where schemaname='public'
  and tablename='training_suspension_exceptions';

select indexname,indexdef
from pg_indexes
where schemaname='public'
  and tablename='training_suspension_exceptions'
order by indexname;

select p.oid::regprocedure as signature,
       p.proowner::regrole as owner,
       p.prosecdef as security_definer,
       p.proconfig as function_settings,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
       has_function_privilege('service_role',p.oid,'EXECUTE') as service_role_execute
from pg_proc p
where p.oid='public.grant_suspension_exception(uuid,uuid,text)'::regprocedure;

select count(*) as exception_rows
from public.training_suspension_exceptions;

select count(*) as exception_audit_rows
from public.training_suspension_audit
where action='exception_granted';

-- Audit-Linkage und RLS-Sichtbarkeit
select column_name,data_type,is_nullable
from information_schema.columns
where table_schema='public'
  and table_name='training_suspension_audit'
  and column_name in ('suspension_id','exception_id','changed_by_snapshot')
order by column_name;

select conname,pg_get_constraintdef(oid) definition
from pg_constraint
where conrelid='public.training_suspension_audit'::regclass
  and conname in (
    'training_suspension_audit_exception_id_fkey',
    'training_suspension_audit_one_subject_check'
  );

select policyname,cmd,roles,qual
from pg_policies
where schemaname='public'
  and tablename='training_suspension_audit'
  and policyname='training_suspension_audit_select';
