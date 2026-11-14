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
  if exists (select 1 from public.training_suspension_audit where exception_id is not null or suspension_id is null) then
    raise exception 'Rollback Paket 5 abgebrochen: Audit-Einträge referenzieren Ausnahmen oder besitzen keinen Sperrenbezug.';
  end if;
end
$guard$;

drop function public.grant_suspension_exception(uuid,uuid,text);

drop policy if exists training_suspension_audit_select
  on public.training_suspension_audit;

create policy training_suspension_audit_select
  on public.training_suspension_audit
  for select to authenticated
  using (
    exists (
      select 1
      from public.training_suspensions s
      where s.id = training_suspension_audit.suspension_id
        and (is_team_member(s.team_id) or has_selected_team_context(s.team_id))
    )
  );

alter table public.training_suspension_audit
  drop constraint training_suspension_audit_one_subject_check,
  drop constraint training_suspension_audit_exception_id_fkey,
  drop column exception_id,
  drop column changed_by_snapshot,
  alter column suspension_id set not null;

drop table public.training_suspension_exceptions;

commit;
