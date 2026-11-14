-- Ergänzt die Paket-1-CI-Fixture um die minimalen Bestandsobjekte,
-- die die historische Paket-2-RPC tatsächlich verwendet.
alter table public.players add column team_id uuid;
alter table public.players add column name text;
alter table public.players add column active boolean not null default true;

create table public.trainings(
 id uuid primary key,
 team_id uuid not null,
 training_date date not null,
 name text,
 status text not null,
 season_id uuid
);
create table public.seasons(
 id uuid primary key,
 team_id uuid not null,
 name text not null,
 is_active boolean not null
);
create table public.attendance(
 training_id uuid not null,
 player_id uuid not null,
 present boolean not null,
 primary key(training_id,player_id)
);
create table public.team_member_roles(
 team_id uuid not null,
 user_id uuid not null,
 role text not null
);
create table public.global_user_roles(
 user_id uuid not null,
 role text not null
);
create or replace function public.has_selected_team_context(p_team_id uuid)
returns boolean language sql stable as $$ select false $$;
create or replace function auth.uid()
returns uuid language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
