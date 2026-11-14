-- Minimal Supabase-like fixture for E05 PROD package 3.
\set ON_ERROR_STOP on
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;

create schema auth;
create table auth.users(id uuid primary key);
create or replace function auth.uid()
returns uuid language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;

create table public.players(
 id uuid primary key,
 team_id uuid not null,
 name text not null,
 active boolean not null default true
);
create table public.teams(id uuid primary key,name text not null);
create table public.team_member_roles(team_id uuid,user_id uuid,role text);
create table public.global_user_roles(user_id uuid,role text);

create or replace function public.is_team_member(p_team_id uuid)
returns boolean language sql stable
as $$ select exists(select 1 from public.team_member_roles r where r.team_id=p_team_id and r.user_id=auth.uid()) $$;
create or replace function public.has_selected_team_context(p_team_id uuid)
returns boolean language sql stable
as $$ select false $$;

create table public.trainings(
 id uuid primary key,team_id uuid not null,training_date date not null,
 name text,status text not null,season_id uuid
);
create table public.seasons(
 id uuid primary key,team_id uuid not null,name text not null,is_active boolean not null
);
create table public.attendance(
 training_id uuid not null,player_id uuid not null,present boolean not null,
 primary key(training_id,player_id)
);
