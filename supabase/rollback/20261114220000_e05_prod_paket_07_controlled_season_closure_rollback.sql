-- E05 PROD Paket 7 – guarded rollback
-- Entfernt nur die Paket-7-Objekte. Saison-/Sperrendaten werden NICHT restauriert.
-- Nur vor produktiver Verwendung und nur bei leerem Saisonabschluss-Audit ausführen.
begin;

do $guard$
begin
  if to_regclass('public.team_season_closure_audit') is null then
    raise exception 'Paket 7 Rollback: Audit-Tabelle fehlt; manueller Abgleich erforderlich';
  end if;
  if exists(select 1 from public.team_season_closure_audit) then
    raise exception 'Paket 7 Rollback gesperrt: Saisonabschluss-Auditdaten vorhanden; keine automatische Rücknahme';
  end if;
  if exists (
    select 1 from pg_trigger
    where tgrelid='public.team_season_closure_audit'::regclass
      and tgname='team_season_closure_audit_no_mutation'
      and not tgisinternal
  ) is false then
    raise exception 'Paket 7 Rollback: erwarteter Append-only-Trigger fehlt';
  end if;
end;
$guard$;

drop function public.close_team_season(uuid,text);
drop trigger team_season_closure_audit_no_mutation on public.team_season_closure_audit;
drop function public.e05_reject_season_closure_audit_mutation();
drop table public.team_season_closure_audit;

commit;
