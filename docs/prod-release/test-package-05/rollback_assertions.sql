\set ON_ERROR_STOP on
do $assert$
begin
 if to_regclass('public.training_suspension_exceptions') is not null
    or to_regprocedure('public.grant_suspension_exception(uuid,uuid,text)') is not null then
   raise exception 'Package 5 objects remain after rollback';
 end if;
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='training_suspension_audit' and column_name in ('exception_id','changed_by_snapshot')) then
   raise exception 'Package 5 audit columns remain after rollback';
 end if;
 if (select is_nullable from information_schema.columns where table_schema='public' and table_name='training_suspension_audit' and column_name='suspension_id') <> 'NO' then
   raise exception 'Audit suspension_id NOT NULL was not restored';
 end if;
 if exists(select 1 from pg_constraint where conrelid='public.training_suspension_audit'::regclass and conname in ('training_suspension_audit_one_subject_check','training_suspension_audit_exception_id_fkey')) then
   raise exception 'Package 5 audit constraints remain after rollback';
 end if;
 if (select count(*) from pg_trigger where tgrelid='public.training_suspension_audit'::regclass and not tgisinternal) <> 2 then
   raise exception 'Append-only audit triggers not preserved by rollback';
 end if;
end;
$assert$;
