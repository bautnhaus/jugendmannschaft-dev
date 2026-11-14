-- Minimal matchday_players fixture for package 6 CI.
-- The package 1–5 isolated baseline does not create this application table.
\set ON_ERROR_STOP on
create table if not exists public.matchday_players(
  matchday_id uuid not null,
  player_id uuid not null,
  available boolean not null default true,
  team_number integer,
  goalkeeper boolean not null default false,
  played boolean
);
