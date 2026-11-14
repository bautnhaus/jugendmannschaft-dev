-- KADAssist / E05 – PROD Paket 2 Rollback
-- Entfernt ausschließlich die Paket-2-RPC, und nur vor Paket 3.
-- Kein CASCADE; keine Tabellen oder Daten werden gelöscht.

begin;

do $guard$
begin
  if to_regclass('public.training_suspensions') is not null
     or to_regclass('public.training_suspension_audit') is not null
     or to_regprocedure('public.e05_reconcile_suspensions_after_event_correction(uuid,uuid,text)') is not null
     or to_regprocedure('public.e05_assign_player_suspensions(uuid,uuid,uuid)') is not null then
    raise exception 'E05 Paket 2 Rollback abgebrochen: Paket 3 oder abhängige Sperrenlogik ist vorhanden';
  end if;
  if to_regprocedure('public.award_training_behavior_event(uuid,uuid,text,text)') is null then
    raise exception 'E05 Paket 2 Rollback abgebrochen: RPC ist nicht vorhanden';
  end if;
end;
$guard$;

drop function public.award_training_behavior_event(uuid, uuid, text, text);

commit;
