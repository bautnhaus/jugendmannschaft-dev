-- Paket-4-Testfixture: ergänzt isolierte Paket-1–3-Baseline.
\set ON_ERROR_STOP on
create table public.clubs(id uuid primary key,name text not null);
alter table public.teams add column club_id uuid references public.clubs(id);
create table public.user_club_context(
 user_id uuid not null references auth.users(id),
 club_id uuid not null references public.clubs(id),
 selected_at timestamptz not null default now(),
 primary key(user_id,club_id)
);
create or replace function public.can_manage_club_context(p_club_id uuid)
returns boolean language sql stable security definer
set search_path=pg_catalog,public,auth
as $$
 select exists(select 1 from public.user_club_context c
 where c.user_id=auth.uid() and c.club_id=p_club_id)
$$;
revoke all on function public.can_manage_club_context(uuid) from public,anon;
grant execute on function public.can_manage_club_context(uuid) to authenticated;
