#!/usr/bin/env bash
set -euo pipefail

ROLLBACK_SQL="docs/prod-release/E05_PROD_PAKET_01_TRAININGSEREIGNISSE_2026-11-14_ROLLBACK.sql"

# Guard 1: existing data must stop rollback.
psql -v ON_ERROR_STOP=1 -c "
  INSERT INTO public.training_behavior_events
    (team_id,season_id,training_id,training_date_snapshot,training_name_snapshot,player_name_snapshot,event_type)
  VALUES
    (gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),current_date,'Rollback guard','Rollback guard','positive_star');
"

if psql -v ON_ERROR_STOP=1 -f "$ROLLBACK_SQL" >/tmp/e05-rollback-data-guard.log 2>&1; then
  echo "ERROR: rollback unexpectedly succeeded while event data existed"
  exit 1
fi
grep -q "tables contain data" /tmp/e05-rollback-data-guard.log

# Remove the synthetic guard row; no audit row was created.
psql -v ON_ERROR_STOP=1 -c "DELETE FROM public.training_behavior_events;"

# Guard 2: an installed dependent RPC must stop rollback.
psql -v ON_ERROR_STOP=1 -c "
  CREATE FUNCTION public.award_training_behavior_event(uuid,uuid,text,text)
  RETURNS uuid LANGUAGE sql AS \$\$ SELECT NULL::uuid \$\$;
"

if psql -v ON_ERROR_STOP=1 -f "$ROLLBACK_SQL" >/tmp/e05-rollback-dependency-guard.log 2>&1; then
  echo "ERROR: rollback unexpectedly succeeded while dependent RPC existed"
  exit 1
fi
grep -q "Paket 2 RPC exists" /tmp/e05-rollback-dependency-guard.log

psql -v ON_ERROR_STOP=1 -c "DROP FUNCTION public.award_training_behavior_event(uuid,uuid,text,text);"
echo "Rollback data and dependency guards both rejected unsafe rollback as expected."
