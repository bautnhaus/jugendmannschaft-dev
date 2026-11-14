# KADAssist / E05 – PROD Release Paket 4
## Spieltagszuordnung und Ableistung von Sperren

- Ziel: Supabase PROD `qdugtpzgefpswnnqbusd` | DEV: `pzazqvvoruqnqhcorbwx`
- Branch: `develop` only. Not executed in PROD.
- Status: prepared; CI and final review pending. Explicit PROD approval still required.

## 1. DEV source and acceptance evidence

- Source SQL: `docs/E05_PAKET_04_SPIELTAG_ZUORDNUNG_UND_ABLEISTUNG_2026-11-08.sql`, blob `d4722150eba7a6894ebabc032ff9af8dcd2fbcf7`.
- DEV execution and acceptance record: `docs/E05_PAKET_04_FREIGABE_UND_AUSFUEHRUNG_2026-11-08.md`, blob `9f6c00f80ce1414edcb9a82d076c41fa32d517b5`.
- DEV migration: `20261108133922 e05_package_04_suspension_matchday_lifecycle`.
- DEV record reports successful table/RLS/policy/ACL checks and functional tests for club/team game-type settings, yellow-before-red assignment, one suspension per player per matchday, serving only on a relevant matchday with status `done`, reassignment after serving, rejection of irrelevant game type and unauthorized team role. Functional test data was synthetic and rolled back.

## 2. Scope

Three configuration tables:
- `club_suspension_settings`
- `team_suspension_game_type_settings`
- `team_suspension_game_types`

Four RPCs:
- `set_club_suspension_game_types(uuid,text[])`
- `set_team_suspension_game_types(uuid,boolean,text[])`
- `assign_next_suspension_matchday(uuid,uuid)`
- `serve_matchday_suspensions(uuid)`

Internal helper: `e05_assign_player_suspensions(uuid,uuid,uuid)`, not executable by API roles.

Rules:
1. A team override fully replaces the club default.
2. Without an override, the club default applies.
3. An explicit empty team override means no game type is relevant.
4. No club setting means no game type is silently assumed relevant.
5. Allowed values: `Meisterschaft`, `Freundschaftsspiel`, `Turnier`.
6. Only open suspensions in the same team/season are assigned to future planned matchdays of a relevant type.
7. Yellow suspensions precede red; at most one suspension per player per matchday.
8. A suspension is served only after the assigned matchday is actually `done` and relevant. The operation is audited; remaining open suspensions are reassigned.

## 3. PROD read-only preflight – 14.11.2026

Confirmed in PROD:
- Packages 1–3 registered; package 3 migration version `20261114174854`.
- `clubs`, `teams`, `matchdays`, `team_member_roles`, `user_club_context`, `training_suspensions`, `training_suspension_audit` exist.
- Required fields exist, including `teams.club_id`, matchday `season_id/match_date/game_type/status`, suspension `intended_matchday_id/served_matchday_id`.
- Context helpers `is_team_member(uuid)`, `has_selected_team_context(uuid)`, `can_manage_club_context(uuid)` exist, are SECURITY DEFINER with fixed search_path, and are executable by authenticated but not anon.
- Package 4 config tables and RPCs do not exist yet.
- Package 5+ functions/tables checked in DEV are not installed in PROD.
- PROD currently has 1 club, 1 team, 0 suspension rows and 0 suspension audit rows.
- DEV migration history contains package 4; PROD history currently contains packages 1–3 only.

## 4. Release artefacts

1. Migration: `supabase/migrations/20261114190000_e05_prod_paket_04_matchday_lifecycle.sql`
2. Guarded rollback: `supabase/rollback/20261114190000_e05_prod_paket_04_matchday_lifecycle_rollback.sql`
3. Read-only verification: `docs/prod-release/E05_PROD_PAKET_04_SPIELTAGSZUORDNUNG_2026-11-14_TESTQUERIES.sql`
4. Isolated test fixture: `docs/prod-release/test-package-04/`
5. CI workflow: `.github/workflows/e05-prod-package-04-test.yml`

Migration has a transaction-scoped preflight. It aborts if package-3 prerequisites or context helpers are missing, package-4 objects already exist, package-5+ objects are present, or expected columns are missing.

Rollback uses no CASCADE. It aborts if suspensions reference matchdays, if package-4 configuration contains data, or if package-5+ objects/functions are installed. It drops only package-4 functions/tables. It does not remove the Supabase migration-history entry.

## 5. CI scope and limitations

The isolated PostgreSQL 17.6 workflow rebuilds package 1–3 baseline, applies the exact PROD package-4 SQL, and checks:
- structure, RLS, policies, direct table privileges and RPC ACLs;
- club default, team override, restoring club defaults when override is disabled;
- explicit empty team override;
- no-op assignment/serving RPC behavior when no open suspension exists;
- guarded rollback and removal of package-4 objects.

This CI fixture does not connect to Supabase PROD or DEV. It does not replace the full DEV functional test record, nor does it re-run every scenario with persisted matchday/suspension fixture rows.

## 6. Explicit exclusions

Not part of package 4:
- frontend/app automatic invocation of `serve_matchday_suspensions` when matchday status becomes `done`;
- club settings UI and its end-to-end test;
- exceptions, season closure, early suspension reset, manual correction, event correction/void/restore.
These remain separate follow-up packages.

## 7. Approval checklist

- [x] DEV source SQL and execution/acceptance record found.
- [x] PROD packages 1–3 and prerequisite schema checked read-only.
- [x] Guarded PROD migration created.
- [x] Guarded rollback created.
- [x] Read-only verification SQL created.
- [x] Isolated PostgreSQL 17.6 fixture and CI workflow created.
- [x] CI successful and reviewed (Run 43624723426).
- [x] Final SQL/rollback review after CI.
- [x] Explicit PROD execution approval received.
- [ ] Immediate PROD preflight/hash check.
- [x] PROD migration executed (14.11.2026).
- [x] Read-only post-check passed.
- [x] Migration journal and execution record updated.

**Current state: release candidate prepared, not executed in PROD.**


## 8. CI-Auswertung und finale SQL-Prüfung – 14.11.2026

- **Finaler Workflow:** [Run 43624723426 – E05 PROD Paket 4](https://github.com/bautnhaus/jugendmannschaft/actions/runs/43624723426).
- **Ergebnis:** `success`, PostgreSQL 17.6; alle Schritte erfolgreich: Paket-1–3-Baseline, Club-/Kontext-Fixture, exakte PROD-Migration, Struktur-/ACL-/RPC-Assertions, guarded Rollback und Rollback-Assertions.
- **CI-Commit:** `16b4d93a2ca796db5ab3f3af0bc01a1341e365dc`.
- **Migration SHA:** `9618e5a3431d88b88eeee5efba6efa94813cbfae`.
- **Rollback SHA:** `859eb68407373b4a6c8940ed3c8f9c9b640efe0c`.
- **Nachkontroll-SQL SHA:** `bf6707f8b556fb64f5e3938baed5994bb883ac19`.
- **CI-Fixes:** Der erste CI-Lauf zeigte eine fehlende `matchdays`-Tabelle in der isolierten Fixture; diese wurde ergänzt. Ein weiterer Testlauf zeigte, dass der Test den absichtlich leeren Team-Override noch aktiv hatte, als er einen Meisterschaftsspieltag prüfte; der Test stellt vor diesem Schritt korrekt den Club-Standard wieder her. Die Rollback-Prüfung wurde danach auf eine dedizierte SQL-Assertion umgestellt. Ein finaler Lauf bestand vollständig.
- **Wichtige Abgrenzung:** Der CI-Lauf belegt die Migration, Struktur, Rechte, Konfigurations-RPCs, No-op-Verhalten und Rollback in isoliertem PostgreSQL. Die vollständigen Szenarien mit tatsächlich offenen Sperren und echten Spieltagszuordnungen sind durch das DEV-Abnahmeprotokoll belegt, nicht vollständig erneut in CI nachgestellt.
- **Finale statische Prüfung:** Migration und Rollback sind transaktional; Rollback ohne `CASCADE`; Daten- und Folgepaket-Gates vorhanden. Migration und Rollback wurden im erfolgreichen CI-Lauf exakt ausgeführt.

**Zwischenstand vor Freigabe:** CI und finale SQL-/Rollback-Prüfung bestanden; PROD-Ausführung stand zu diesem Zeitpunkt noch aus. Der tatsächliche PROD-Ausführungsstand ist in Abschnitt 9 dokumentiert.


## 9. PROD-Ausführung und Nachkontrolle – 14.11.2026

### Freigabe und Ausführung
- Ausdrückliche Nutzerfreigabe zur Umsetzung und Dokumentation erhalten.
- Direkt vor Ausführung erneuter read-only Preflight in Supabase PROD. Alle erwarteten Voraussetzungen vorhanden; alle Paket-4-Objekte/RPCs fehlten; keine Paket-5+-Abhängigkeiten vorhanden.
- Preflight-Datenbestand: 1 Club, 1 Team, 0 Sperren, 0 Sperren-Audit-Einträge, 0 bestehende Sperren-Spieltag-Referenzen.
- Ausgeführte Datei: `supabase/migrations/20261114190000_e05_prod_paket_04_matchday_lifecycle.sql`.
- Vor Ausführung geprüfter Git-Blob-SHA: `9618e5a3431d88b88eeee5efba6efa94813cbfae`; stimmte mit dem finalen CI-geprüften Artefakt überein.
- Supabase meldete `success: true`.
- Tatsächlicher PROD-Migrationseintrag: Version `20261114184029`, Name `e05_prod_paket_04_matchday_lifecycle_20261114`. Die Supabase-generierte Versionsnummer weicht vom Dateipräfix `20261114190000` ab; maßgeblich ist der registrierte PROD-Eintrag.

### Read-only Nachkontrolle
- Alle drei Konfigurationstabellen vorhanden.
- RLS auf allen drei Tabellen aktiv; genau drei Paket-4-Policies vorhanden.
- Direkte Schreibrechte für `authenticated` fehlen; SELECT ist vorhanden. `anon` hat keinen SELECT-Zugriff.
- Vier öffentliche RPCs sind SECURITY DEFINER mit festem `search_path = pg_catalog, public, auth`.
- EXECUTE für die vier vorgesehenen RPCs für `authenticated` vorhanden; kein EXECUTE für `anon`.
- Interner Helper `e05_assign_player_suspensions(uuid,uuid,uuid)` ist für authenticated nicht ausführbar.
- Zwei append-only Audit-Trigger weiterhin vorhanden.
- Datenbestand unverändert: 1 Club, 1 Team, 0 Sperren, 0 Sperren-Audit-Einträge. Keine bestehenden Sperr- oder Spieltagsdaten wurden verändert.
- Konfigurationsbestand nach Migration: 0 Club-Standard-Konfigurationen, 0 Team-Overrides und 0 Team-Spielarten-Einträge. Es wurde bewusst keine fachliche Voreinstellung erfunden oder eingetragen. Bis zur späteren Einrichtung einer Club-Standardliste bzw. eines Team-Overrides sind keine Spielarten als sperrrelevant konfiguriert.
- Migration `20261114184029` ist in der PROD-Migrationshistorie registriert.

### Supabase Advisor – Einordnung nach Paket 4
- Health Advisor: keine Findings.
- Security Advisor: meldet unter anderem `set_updated_at` mit mutable search_path sowie deaktivierten Leaked-Password-Schutz. Außerdem listet er SECURITY DEFINER-RPCs, die für authenticated ausführbar sind; die beiden neuen Paket-4-Konfigurations-RPCs sind absichtlich so freigegeben und besitzen serverseitige Berechtigungsprüfungen sowie festen search_path. Die Advisor-Ausgabe enthält darüber hinaus zahlreiche bestehende Funktionen. Keine pauschale Berechtigungsänderung an bestehenden Funktionen wurde vorgenommen.
- Performance Advisor: meldet bestehende Themen zu nicht indexierten Fremdschlüsseln, RLS-Initplans und mehrfach permissiven Policies. Für Paket 4 werden insbesondere die beiden `updated_by`-Fremdschlüssel als Teil dieser allgemeinen Index-Warnung aufgeführt. Keine zusätzliche Index-/Policy-Änderung wurde ohne separates Paket vorgenommen.

### Abschluss
**Paket 4 wurde erfolgreich in Supabase PROD ausgeführt und die Struktur, RLS, Berechtigungen, RPC-Konfiguration, Audit-Trigger und Datenbestände wurden read-only nachkontrolliert.**
Die vollständige funktionale Verifikation mit tatsächlichen Sperren und Matchdays bleibt auf die dokumentierten DEV-Abnahmetests und den isolierten CI-Test begrenzt; ein realer PROD-End-to-End-Sperrenablauf wurde nicht durch Testdaten ausgelöst.
