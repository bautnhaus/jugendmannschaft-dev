-- AP02 P0 – candidate migration, NOT YET APPROVED FOR EXECUTION
-- Target: DEV only. Requires coordinated frontend + invite-trainer cutover.
-- Preconditions: role-set parity preflight passes; app/edge updates are ready.
begin;

-- Hard stop if the legacy and additive role sets differ. Do not auto-reconcile:
-- role loss or role invention must be reviewed before this cutover.
do $preflight$
begin
  if exists (
    select 1 from (
      select team_id,user_id,role from public.team_members
      except
      select team_id,user_id,role from public.team_member_roles
    ) legacy_only
  ) or exists (
    select 1 from (
      select team_id,user_id,role from public.team_member_roles
      except
      select team_id,user_id,role from public.team_members
    ) new_only
  ) then
    raise exception 'AP02 preflight failed: team_members and team_member_roles role sets differ. No changes applied.';
  end if;
end;
$preflight$;

-- Fixed search_path and SECURITY DEFINER are intentional: these helpers must read
-- role tables protected by RLS. EXECUTE is limited to authenticated callers.
create or replace function public.is_team_member(p_team_id uuid)
returns boolean
language sql stable security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null and exists (
    select 1 from public.team_member_roles r
    where r.team_id = p_team_id and r.user_id = auth.uid()
  );
$$;

create or replace function public.is_team_member(p_user_id uuid, p_team_id uuid)
returns boolean
language sql stable security definer
set search_path = pg_catalog, public
as $$
  select p_user_id is not null and exists (
    select 1 from public.team_member_roles r
    where r.team_id = p_team_id and r.user_id = p_user_id
  );
$$;

create or replace function public.is_team_admin(p_team_id uuid)
returns boolean
language sql stable security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null and exists (
    select 1 from public.team_member_roles r
    where r.team_id = p_team_id and r.user_id = auth.uid() and r.role = 'admin'
  );
$$;

create or replace function public.is_team_admin(p_user_id uuid, p_team_id uuid)
returns boolean
language sql stable security definer
set search_path = pg_catalog, public
as $$
  select p_user_id is not null and exists (
    select 1 from public.team_member_roles r
    where r.team_id = p_team_id and r.user_id = p_user_id and r.role = 'admin'
  );
$$;

-- All role mutations go through these RPCs. A role is added/removed independently;
-- the caller cannot accidentally overwrite the other role.
create or replace function public.admin_add_team_role(
  p_team_id uuid, p_user_id uuid, p_role text
)
returns void
language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null or not public.is_team_admin(auth.uid(), p_team_id) then
    raise exception 'Nicht berechtigt' using errcode = '42501';
  end if;
  if p_role not in ('admin','trainer') then
    raise exception 'Ungültige Teamrolle' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users u where u.id = p_user_id) then
    raise exception 'Benutzer nicht gefunden' using errcode = '22023';
  end if;

  insert into public.team_members(team_id,user_id,role)
  values (p_team_id,p_user_id,'trainer')
  on conflict (team_id,user_id) do nothing;

  insert into public.team_member_roles(team_id,user_id,role)
  values (p_team_id,p_user_id,p_role)
  on conflict (team_id,user_id,role) do nothing;
end;
$$;

create or replace function public.admin_remove_team_role(
  p_team_id uuid, p_user_id uuid, p_role text
)
returns void
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_admin_count integer;
begin
  if auth.uid() is null or not public.is_team_admin(auth.uid(), p_team_id) then
    raise exception 'Nicht berechtigt' using errcode = '42501';
  end if;
  if p_role not in ('admin','trainer') then
    raise exception 'Ungültige Teamrolle' using errcode = '22023';
  end if;

  -- Serialize role removals for this team so concurrent requests cannot remove
  -- the final admin simultaneously.
  perform 1 from public.teams t where t.id = p_team_id for update;
  if not found then raise exception 'Mannschaft nicht gefunden'; end if;

  if p_role = 'admin' then
    select count(*) into v_admin_count
    from public.team_member_roles r
    where r.team_id = p_team_id and r.role = 'admin';
    if exists (
      select 1 from public.team_member_roles r
      where r.team_id=p_team_id and r.user_id=p_user_id and r.role='admin'
    ) and v_admin_count <= 1 then
      raise exception 'Der letzte Team-Admin kann nicht entfernt werden'
        using errcode = '23514';
    end if;
  end if;

  delete from public.team_member_roles
  where team_id=p_team_id and user_id=p_user_id and role=p_role;

  -- Preserve team membership while any role remains; remove the legacy metadata
  -- row only when no roles remain (admin_label then disappears with membership).
  if not exists (
    select 1 from public.team_member_roles r
    where r.team_id=p_team_id and r.user_id=p_user_id
  ) then
    delete from public.team_members
    where team_id=p_team_id and user_id=p_user_id;
  end if;
end;
$$;

create or replace function public.get_team_trainers_v2(p_team_id uuid)
returns table(user_id uuid, role text, admin_label text, email text, roles text[])
language plpgsql stable security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if auth.uid() is null or not public.is_team_admin(auth.uid(), p_team_id) then
    raise exception 'Nicht berechtigt' using errcode = '42501';
  end if;

  return query
  select tm.user_id,
         case when bool_or(r.role='admin') then 'admin' else 'trainer' end,
         coalesce(tm.admin_label,''),
         u.email::text,
         array_agg(r.role order by r.role)
  from public.team_members tm
  join public.team_member_roles r
    on r.team_id=tm.team_id and r.user_id=tm.user_id
  left join auth.users u on u.id=tm.user_id
  where tm.team_id=p_team_id
  group by tm.user_id,tm.admin_label,u.email
  order by coalesce(tm.admin_label,''),u.email;
end;
$$;

-- Move last-admin protection to the authoritative additive-role table.
drop trigger if exists prevent_last_team_admin_removal on public.team_members;
create or replace function public.prevent_last_team_admin_removal()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_team_exists boolean; v_admin_exists boolean;
begin
  if old.role is distinct from 'admin' then return null; end if;
  if tg_op = 'UPDATE' and new.role = 'admin' and new.team_id = old.team_id then return null; end if;
  perform 1 from public.teams where id = old.team_id for update;
  v_team_exists := found;
  if not v_team_exists then return null; end if;
  select exists (
    select 1 from public.team_member_roles
    where team_id = old.team_id and role = 'admin'
  ) into v_admin_exists;
  if not v_admin_exists then
    raise exception 'Die letzte Admin-Rolle einer Mannschaft kann nicht entfernt werden.'
      using errcode = '23514';
  end if;
  return null;
end;
$$;

create constraint trigger prevent_last_team_admin_removal
after delete or update on public.team_member_roles
deferrable initially deferred
for each row execute function public.prevent_last_team_admin_removal();

-- Append-only audit log for team-role changes.
create table if not exists public.team_role_change_log (
  id bigint generated always as identity primary key,
  changed_at timestamptz not null default now(),
  actor_user_id uuid,
  affected_user_id uuid not null,
  team_id uuid not null references public.teams(id) on delete cascade,
  action text not null check (action in ('role_added','role_removed')),
  role text not null check (role in ('admin','trainer'))
);
alter table public.team_role_change_log enable row level security;
drop policy if exists team_role_change_log_read_admin on public.team_role_change_log;
create policy team_role_change_log_read_admin
on public.team_role_change_log for select to authenticated
using (public.is_team_admin(team_id));

create or replace function public.log_team_role_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.team_role_change_log(actor_user_id,affected_user_id,team_id,action,role)
    values (auth.uid(),new.user_id,new.team_id,'role_added',new.role);
    return new;
  else
    insert into public.team_role_change_log(actor_user_id,affected_user_id,team_id,action,role)
    values (auth.uid(),old.user_id,old.team_id,'role_removed',old.role);
    return old;
  end if;
end;
$$;
drop trigger if exists audit_team_role_insert on public.team_member_roles;
create trigger audit_team_role_insert after insert on public.team_member_roles
for each row execute function public.log_team_role_change();
drop trigger if exists audit_team_role_delete on public.team_member_roles;
create trigger audit_team_role_delete after delete on public.team_member_roles
for each row execute function public.log_team_role_change();
revoke insert, update, delete on public.team_role_change_log from authenticated;

-- Close the permissive legacy player-position policies. PostgreSQL ORs permissive
-- policies, so membership-only INSERT/DELETE policies bypassed the admin policies.
drop policy if exists "Team members can insert player positions" on public.player_positions;
drop policy if exists "Team members can delete player positions" on public.player_positions;

-- Old RPCs mutate/read the one-role legacy model and are not used by the
-- additive-role frontend. Remove authenticated/anonymous execute access.
-- Keep admin_set_trainer_label because the existing UI still uses it.
revoke all on function public.add_team_member_by_email(text,text,uuid) from public, anon, authenticated;
revoke all on function public.get_team_trainers(uuid) from public, anon, authenticated;
-- Until account deletion is redesigned for anonymization and new role tables, disable it server-side too.
revoke all on function public.delete_my_account() from public, anon, authenticated;

-- RLS is enabled on these role tables already, but there are currently no policies.
-- Deny direct client writes; privileged, explicitly checked RPCs perform mutations.
alter table public.team_member_roles enable row level security;
alter table public.club_member_roles enable row level security;
alter table public.global_user_roles enable row level security;
alter table public.club_members enable row level security;
alter table public.clubs enable row level security;

drop policy if exists team_member_roles_read_self_or_team_admin on public.team_member_roles;
create policy team_member_roles_read_self_or_team_admin
on public.team_member_roles for select to authenticated
using (user_id = auth.uid() or public.is_team_admin(team_id));

drop policy if exists club_member_roles_read_self on public.club_member_roles;
create policy club_member_roles_read_self
on public.club_member_roles for select to authenticated
using (user_id = auth.uid());

drop policy if exists global_user_roles_read_self on public.global_user_roles;
create policy global_user_roles_read_self
on public.global_user_roles for select to authenticated
using (user_id = auth.uid());

drop policy if exists club_members_read_self on public.club_members;
create policy club_members_read_self
on public.club_members for select to authenticated
using (user_id = auth.uid());

-- Do not expose club records or role-table writes in this team-role cutover.
-- Club Admin / Super Admin club-scoped policies belong to the separate AP02
-- club-access migration, which must be reviewed together with its UI.
revoke insert, update, delete on public.team_member_roles from authenticated;
-- Legacy role is no longer writable through the Data API. Keep only the
-- existing admin_label edit path; role/membership changes go through RPCs.
revoke insert, update, delete on public.team_members from authenticated;
grant update (admin_label) on public.team_members to authenticated;
revoke insert, update, delete on public.club_member_roles from authenticated;
revoke insert, update, delete on public.global_user_roles from authenticated;
revoke insert, update, delete on public.club_members from authenticated;
revoke insert, update, delete on public.clubs from authenticated;

revoke all on function public.admin_add_team_role(uuid,uuid,text) from public, anon;
revoke all on function public.admin_remove_team_role(uuid,uuid,text) from public, anon;
grant execute on function public.admin_add_team_role(uuid,uuid,text) to authenticated;
grant execute on function public.admin_remove_team_role(uuid,uuid,text) to authenticated;
revoke all on function public.get_team_trainers_v2(uuid) from public, anon;
grant execute on function public.get_team_trainers_v2(uuid) to authenticated;
revoke all on function public.log_team_role_change() from public, anon;

-- These replacements change authorization for every policy using these helpers.
-- Do not apply until frontend and Edge Function are ready for the same cutover.
revoke all on function public.is_team_member(uuid) from public, anon;
revoke all on function public.is_team_member(uuid,uuid) from public, anon;
revoke all on function public.is_team_admin(uuid) from public, anon;
revoke all on function public.is_team_admin(uuid,uuid) from public, anon;
grant execute on function public.is_team_member(uuid) to authenticated;
grant execute on function public.is_team_member(uuid,uuid) to authenticated;
grant execute on function public.is_team_admin(uuid) to authenticated;
grant execute on function public.is_team_admin(uuid,uuid) to authenticated;

commit;
