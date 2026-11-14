\set ON_ERROR_STOP on
do $assert$
declare
  v_def text;
begin
  if to_regprocedure('public.revoke_suspension_exception(uuid,text)') is null then
    raise exception 'Package 6 revoke RPC missing';
  end if;
  if to_regprocedure('public.prevent_suspended_matchday_nomination()') is null then
    raise exception 'Package 6 nomination trigger function missing';
  end if;
  select pg_get_functiondef('public.revoke_suspension_exception(uuid,text)'::regprocedure) into v_def;
  if position('pg_advisory_xact_lock' in v_def)=0 then
    raise exception 'Revoke RPC lacks advisory serialization lock';
  end if;
  if position('nomination_removed' in v_def)=0 or position('removed_nomination_snapshot' in v_def)=0 then
    raise exception 'Revoke RPC does not audit removed nomination snapshot';
  end if;
  if position('played' in v_def)=0 or position('actual use' in lower(v_def))>0 then
    raise exception 'Revoke RPC does not protect played nominations';
  end if;
  if not (select prosecdef from pg_proc where oid='public.revoke_suspension_exception(uuid,text)'::regprocedure) then
    raise exception 'Revoke RPC must be SECURITY DEFINER';
  end if;
  if not has_function_privilege('authenticated','public.revoke_suspension_exception(uuid,text)','EXECUTE')
     or has_function_privilege('anon','public.revoke_suspension_exception(uuid,text)','EXECUTE')
     or has_function_privilege('service_role','public.revoke_suspension_exception(uuid,text)','EXECUTE') then
    raise exception 'Unexpected revoke RPC ACL';
  end if;
  select pg_get_functiondef('public.prevent_suspended_matchday_nomination()'::regprocedure) into v_def;
  if position('pg_advisory_xact_lock' in v_def)=0 then
    raise exception 'Nomination trigger lacks matching advisory lock';
  end if;
  if not exists(select 1 from pg_trigger where tgrelid='public.matchday_players'::regclass and tgname='matchday_players_prevent_suspended_nomination' and not tgisinternal) then
    raise exception 'Expected matchday nomination trigger missing';
  end if;
  if (select count(*) from pg_trigger where tgrelid='public.matchday_players'::regclass and not tgisinternal) < 3 then
    raise exception 'Expected package 6 nomination trigger plus pre-existing triggers';
  end if;
end;
$assert$;
