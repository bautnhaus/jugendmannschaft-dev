do $$
declare v_count integer; v_failed boolean := false;
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='admin_add_team_role') then
    raise exception 'admin_add_team_role missing';
  end if;
  if not exists (select 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid where c.relname='team_member_roles' and t.tgname='prevent_last_team_admin_removal' and not t.tgisinternal) then
    raise exception 'last-admin trigger missing from additive roles table';
  end if;
  if exists (select 1 from pg_policies where schemaname='public' and tablename='player_positions' and policyname in ('Team members can insert player positions','Team members can delete player positions')) then
    raise exception 'permissive player_positions policy still exists';
  end if;
  if has_function_privilege('authenticated','public.add_team_member_by_email(text,text,uuid)','EXECUTE') then
    raise exception 'legacy add_team_member_by_email remains executable';
  end if;
  if has_function_privilege('authenticated','public.delete_my_account()','EXECUTE') then
    raise exception 'unsafe delete_my_account remains executable';
  end if;
  perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
  perform public.admin_add_team_role('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','admin');
  if not exists (select 1 from public.team_member_roles where team_id='20000000-0000-0000-0000-000000000001' and user_id='10000000-0000-0000-0000-000000000002' and role='admin')
     or not exists (select 1 from public.team_member_roles where team_id='20000000-0000-0000-0000-000000000001' and user_id='10000000-0000-0000-0000-000000000002' and role='trainer') then
    raise exception 'adding admin role overwrote trainer role';
  end if;
  perform public.admin_remove_team_role('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','admin');
  if not exists (select 1 from public.team_member_roles where team_id='20000000-0000-0000-0000-000000000001' and user_id='10000000-0000-0000-0000-000000000002' and role='trainer') then
    raise exception 'removing admin role removed trainer role';
  end if;
  begin
    perform public.admin_remove_team_role('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','admin');
    raise exception 'expected last-admin protection to reject removal';
  exception when check_violation then
    null;
  end;
  select count(*) into v_count from public.team_role_change_log;
  if v_count < 2 then raise exception 'role change audit log did not record changes'; end if;
  raise notice 'AP02 isolated migration and role checks passed';
end;
$$;
