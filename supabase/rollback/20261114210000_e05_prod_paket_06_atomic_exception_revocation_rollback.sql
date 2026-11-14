-- E05 PROD Paket 6: guarded rollback
-- PROD-specific: Vor Paket 6 existierten weder revoke_suspension_exception
-- noch der Sperr-Nominierungs-Trigger in matchday_players.
-- Entfernte Nominierungen werden NICHT rekonstruiert.
-- Nur nach gesonderter ausdrücklicher Freigabe ausführen.

begin;

do $preflight$
begin
  if to_regprocedure('public.revoke_suspension_exception(uuid,text)') is null
     or to_regprocedure('public.prevent_suspended_matchday_nomination()') is null
     or not exists (
       select 1 from pg_trigger
       where tgrelid='public.matchday_players'::regclass
         and tgname='matchday_players_prevent_suspended_nomination'
         and not tgisinternal
     ) then
    raise exception 'Rollback Paket 6 abgebrochen: Paket-6-Objekte fehlen oder sind teilweise verändert.';
  end if;

  if exists (
    select 1
    from public.training_suspension_audit
    where action='exception_revoked'
       or coalesce(new_values->>'nomination_removed','false')='true'
  ) then
    raise exception 'Rollback Paket 6 abgebrochen: Widerrufe oder entfernte Nominierungen sind bereits dokumentiert.';
  end if;
end;
$preflight$;

drop trigger matchday_players_prevent_suspended_nomination on public.matchday_players;
drop function public.revoke_suspension_exception(uuid,text);
drop function public.prevent_suspended_matchday_nomination();

commit;
