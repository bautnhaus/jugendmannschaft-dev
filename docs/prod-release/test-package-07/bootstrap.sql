\set ON_ERROR_STOP on
create schema if not exists auth;
do $$ begin
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin; end if;
end $$;
create table auth.users(id uuid primary key);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create table public.teams(id uuid primary key);
create table public.seasons(
 id uuid primary key default gen_random_uuid(),
 team_id uuid not null references public.teams(id),
 name text not null,
 start_date date,
 end_date date,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.team_member_roles(team_id uuid,user_id uuid,role text);
create table public.global_user_roles(user_id uuid,role text);
create table public.profiles(id uuid primary key,display_name text);
create table public.training_suspensions(
 id uuid primary key default gen_random_uuid(),
 team_id uuid not null,
 season_id uuid not null,
 player_id uuid,
 player_name_snapshot text not null,
 source_event_id uuid not null,
 suspension_type text not null,
 status text not null default 'open',
 intended_matchday_id uuid,
 intended_matchday_date_snapshot date,
 intended_matchday_opponent_snapshot text,
 created_by uuid,
 created_at timestamptz not null default now(),
 served_at timestamptz,
 expired_at timestamptz,
 voided_by uuid,
 voided_at timestamptz,
 void_reason text
);
create table public.training_suspension_audit(
 id uuid primary key default gen_random_uuid(),
 suspension_id uuid not null,
 action text not null,
 old_values jsonb,
 new_values jsonb,
 reason text,
 changed_by uuid,
 changed_at timestamptz not null default now()
);
create or replace function public.is_team_member(p_team_id uuid) returns boolean
language sql stable as $$ select exists(select 1 from public.team_member_roles r where r.team_id=p_team_id and r.user_id=auth.uid()) $$;
create or replace function public.has_selected_team_context(p_team_id uuid) returns boolean
language sql stable as $$ select coalesce(current_setting('test.selected_team',true),'')=p_team_id::text $$;
