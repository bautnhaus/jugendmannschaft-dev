-- E05 PROD Paket 5: guarded rollback
-- Nur nach separater ausdrücklicher Freigabe ausführen.
begin;

do $guard$
begin
  if to_regprocedure('public.revoke_suspension_exception(uuid,text)') is not null
     or to_regprocedure('public.e05_atomic_revoke_suspension_exception(uuid,text)') is not null then
    raise exception 'Rollback Paket 5 abgebrochen: Paket 6 oder ein Widerruf-Folgeobjekt ist installiert.';
  end if;
  if to_regclass('public.training_suspension_exceptions') is null then
    raise exception 'Rollback Paket 5 abgebrochen: Tabelle fehlt bereits.';
  end if;
  if exists (select 1 from public.training_suspension_exceptions) then
    raise exception 'Rollback Paket 5 abgebrochen: Ausnahmedaten vorhanden; keine Daten löschen.';
  end if;
  if exists (select 1 from public.training_suspension_audit where exception_id is not null) then
    raise exception 'Rollback Paket 5 abgebrochen: Audit-Einträge referenzieren Ausnahmen.';
  end if;
end
$guard$;

drop function public.grant_suspension_exception(uuid,uuid,text);
drop table public.training_suspension_exceptions;

commit;
