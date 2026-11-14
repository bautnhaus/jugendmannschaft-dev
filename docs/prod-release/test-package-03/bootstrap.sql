-- Ergänzt die Paket-1-/Paket-2-CI-Fixture nur um noch fehlende Tabellen.
-- Rollen, auth-Schema, auth.uid(), players, Teamrollen und Kontexthelfer
-- werden bereits durch die vorgelagerten Paket-1-/Paket-2-Fixtures erstellt.
\set ON_ERROR_STOP on

create table public.teams(
 id uuid primary key,
 name text not null
);
