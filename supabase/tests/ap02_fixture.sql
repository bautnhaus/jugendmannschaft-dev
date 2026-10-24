create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users (id uuid primary key, email text);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create table public.clubs (id uuid primary key, name text);
create table public.club_members (user_id uuid primary key references auth.users(id), club_id uuid references public.clubs(id));
create table public.global_user_roles (user_id uuid references auth.users(id), role text not null, primary key(user_id,role));
create table public.club_member_roles (user_id uuid references public.club_members(user_id), role text not null, primary key(user_id,role));
create table public.teams (id uuid primary key, name text);
create table public.team_members (
  team_id uuid not null references public.teams(id),
  user_id uuid not null references auth.users(id),
  role text not null check(role in ('admin','trainer')),
  admin_label text,
  primary key(team_id,user_id)
);
create table public.team_member_roles (
  team_id uuid not null references public.teams(id),
  user_id uuid not null references auth.users(id),
  role text not null check(role in ('admin','trainer')),
  primary key(team_id,user_id,role)
);
create table public.players (id uuid primary key, team_id uuid not null references public.teams(id));
create table public.positions (id uuid primary key, team_id uuid not null references public.teams(id));
create table public.player_positions (
  player_id uuid references public.players(id),
  position_id uuid references public.positions(id),
  primary key(player_id,position_id)
);

create function public.add_team_member_by_email(text,text,uuid) returns void language sql as $$ select; $$;
create function public.get_team_trainers(uuid) returns table(user_id uuid,role text,admin_label text,email text)
language sql as $$ select null::uuid,null::text,null::text,null::text where false; $$;
create function public.delete_my_account() returns void language sql as $$ select; $$;
create function public.is_team_admin(uuid) returns boolean language sql as $$ select false; $$;
create function public.is_team_admin(uuid,uuid) returns boolean language sql as $$ select false; $$;
create function public.is_team_member(uuid) returns boolean language sql as $$ select false; $$;
create function public.is_team_member(uuid,uuid) returns boolean language sql as $$ select false; $$;
create function public.prevent_last_team_admin_removal() returns trigger language plpgsql as $$ begin return null; end; $$;
create constraint trigger prevent_last_team_admin_removal
after delete or update on public.team_members
deferrable initially deferred for each row execute function public.prevent_last_team_admin_removal();

create policy "Team members can insert player positions" on public.player_positions
for insert to authenticated with check (true);
create policy "Team members can delete player positions" on public.player_positions
for delete to authenticated using (true);
create policy player_positions_insert on public.player_positions
for insert to authenticated with check (true);
create policy player_positions_delete on public.player_positions
for delete to authenticated using (true);
