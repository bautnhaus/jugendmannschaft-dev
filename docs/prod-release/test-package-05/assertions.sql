\set ON_ERROR_STOP on

do $assert$
declare
  fn oid;
begin
  if to_regclass('public.training_suspension_exceptions') is null then
    raise exception 'Package 5 exceptions table missing';
  end if;
  if to_regprocedure('public.grant_suspension_exception(uuid,uuid,text)') is null then
    raise exception 'Package 5 grant RPC missing';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.training_suspension_exceptions'::regclass) then
    raise exception 'RLS not enabled on exceptions';
  end if;
  if (select count(*) from pg_policies where schemaname='public' and tablename='training_suspension_exceptions') <> 1 then
    raise exception 'Unexpected exception policy count';
  end if;
  if has_table_privilege('authenticated','public.training_suspension_exceptions','INSERT')
     or has_table_privilege('authenticated','public.training_suspension_exceptions','UPDATE')
     or has_table_privilege('authenticated','public.training_suspension_exceptions','DELETE')
     or has_table_privilege('anon','public.training_suspension_exceptions','SELECT') then
    raise exception 'Unexpected direct exception table privileges';
  end if;
  select 'public.grant_suspension_exception(uuid,uuid,text)'::regprocedure into fn;
  if not (select prosecdef from pg_proc where oid=fn) then
    raise exception 'Grant RPC must be SECURITY DEFINER';
  end if;
  if (select proconfig from pg_proc where oid=fn) is distinct from array['search_path=pg_catalog, public, auth'] then
    raise exception 'Grant RPC search_path differs from reviewed DEV definition';
  end if;
  if not has_function_privilege('authenticated',fn,'EXECUTE')
     or has_function_privilege('anon',fn,'EXECUTE')
     or has_function_privilege('service_role',fn,'EXECUTE') then
    raise exception 'Unexpected grant RPC execute ACL';
  end if;
  if not exists(select 1 from pg_indexes where schemaname='public' and tablename='training_suspension_exceptions'
    and indexname='training_suspension_exceptions_one_active_per_suspension_matchd') then
    raise exception 'Unique active exception index missing';
  end if;
  if not exists(select 1 from pg_indexes where schemaname='public' and tablename='training_suspension_exceptions'
    and indexname='training_suspension_exceptions_matchday_idx') then
    raise exception 'Matchday lookup index missing';
  end if;
  if (select is_nullable from information_schema.columns where table_schema='public' and table_name='training_suspension_audit' and column_name='suspension_id') <> 'YES'
     or not exists(select 1 from information_schema.columns where table_schema='public' and table_name='training_suspension_audit' and column_name='exception_id')
     or not exists(select 1 from information_schema.columns where table_schema='public' and table_name='training_suspension_audit' and column_name='changed_by_snapshot') then
    raise exception 'Audit exception linkage columns not correctly installed';
  end if;
  if not exists(select 1 from pg_constraint where conrelid='public.training_suspension_audit'::regclass and conname='training_suspension_audit_one_subject_check')
     or not exists(select 1 from pg_constraint where conrelid='public.training_suspension_audit'::regclass and conname='training_suspension_audit_exception_id_fkey') then
    raise exception 'Audit exception constraints missing';
  end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='training_suspension_audit' and policyname='training_suspension_audit_select'
     and qual like '%exception_id%') then
    raise exception 'Audit read policy does not include exception path';
  end if;
  if (select count(*) from pg_trigger where tgrelid='public.training_suspension_audit'::regclass and not tgisinternal) <> 2 then
    raise exception 'Existing append-only audit triggers were not preserved';
  end if;
end;
$assert$;

-- Exercise the audit subject constraint in isolated PL/pgSQL subtransactions.
-- Each DO block catches only the expected database constraint violation.
do $test_missing_subject$
begin
  begin
    insert into public.training_suspension_audit(suspension_id,exception_id,action,new_values,reason)
    values(null,null,'exception_granted','{}'::jsonb,'CI invalid both subjects');
    raise exception 'Audit accepted a row without a subject';
  exception when check_violation then
    null;
  end;
end;
$test_missing_subject$;

do $test_two_subjects$
begin
  begin
    insert into public.training_suspension_audit(suspension_id,exception_id,action,new_values,reason)
    values(gen_random_uuid(),gen_random_uuid(),'exception_granted','{}'::jsonb,'CI invalid two subjects');
    raise exception 'Audit accepted two subjects';
  exception when check_violation then
    null;
  end;
end;
$test_two_subjects$;
