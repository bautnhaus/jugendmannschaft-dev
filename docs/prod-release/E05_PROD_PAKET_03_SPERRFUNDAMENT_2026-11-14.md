# KADAssist / E05 – PROD Release Paket 3
## Sperrenfundament und automatische Sperrenauslösung

- **Zielumgebung:** Supabase PROD `qdugtpzgefpswnnqbusd` (PostgreSQL 17.6)
- **DEV-Referenz:** Supabase DEV `pzazqvvoruqnqhcorbwx`
- **Branch:** ausschließlich `develop`
- **Status:** Technische Abschlussprüfung bestanden; **zur ausdrücklichen PROD-Freigabe vorgelegt; NICHT in PROD ausgeführt**
- **Freigabe:** Nutzer hat die Vorbereitung beauftragt. Eine Freigabe zur PROD-Ausführung liegt noch nicht vor.
- **Chronologie:** E05 Paket 1 und 2 sind in PROD registriert. Paket 3 ist das nächste fehlende Fundamentpaket.
- **Grundsatz:** keine Änderungen an DEV oder GitHub `main`; keine PROD-Ausführung ohne separate ausdrückliche Freigabe.

## 1. Ziel und fachlicher Umfang

Paket 3 legt das Datenbankfundament für offene und historische gelbe/rote Sperren an und erweitert die Paket-2-RPC `public.award_training_behavior_event(uuid,uuid,text,text)`. Ereignis, Sperre und jeweilige Audit-Einträge werden atomar innerhalb derselben Transaktion geschrieben.

### Rote Karte
- Jede gültig vergebene rote Karte erzeugt sofort genau eine offene rote Sperre.
- `source_event_id` verbindet die Sperre eindeutig mit dem auslösenden Ereignis.
- Das gelbe Kartenkonto bleibt unberührt.

### Gelbe Karten
- Die fünfte aktive gelbe Karte im aktuellen Zählkonto erzeugt eine offene gelbe Sperre.
- Vier aktive gelbe Karten erzeugen keine Sperre.
- Während eine gelbe Sperre offen ist, wird keine zweite parallele gelbe Sperre erzeugt.
- Die Auswertung ist auf Spieler, Team und Saison begrenzt.
- **Chronologische Folgepakete:** Der historische Paket-3-Quellstand zählt zunächst anhand `awarded_at`. DEV-Paket 10 stellt die fachlich inzwischen verbindliche Trainingsdatum-Chronologie (`training_date_snapshot`) her und ergänzt Reconciliation/Neuzuordnung. Paket 3 ist deshalb nur der erste Schritt der chronologischen Rolloutfolge und darf nicht als finaler E05-Sperrenworkflow verstanden werden.

## 2. Enthaltene Datenbankobjekte

Neue Tabellen:
- `public.training_suspensions`
- `public.training_suspension_audit`

Zusätzlich:
- `public.e05_reject_suspension_audit_mutation()`
- zwei Append-only-Trigger auf `training_suspension_audit`
- RLS und je eine Teamkontext-Lese-Policy für die neuen Tabellen
- SELECT-Grants für `authenticated` und `service_role`; keine direkten API-Schreibrechte
- Erweiterte SECURITY DEFINER-RPC `award_training_behavior_event(...)`; EXECUTE nur für `authenticated`

Keine vorhandenen fachlichen Datensätze werden durch die Migration verändert. Es werden keine Testdaten geschrieben.

## 3. Quellen und unveränderliche Baselines

- **DEV-Paket-3-Quell-SQL:** `docs/E05_PAKET_03_SUSPENSION_TRIGGER_2026-11-08.sql`, Git-Blob-SHA `74c77a6c3b1f346e404d88254533bf908a469662`.
- **DEV-Abnahme-/Ausführungsprotokoll:** `docs/E05_PAKET_03_FREIGABE_UND_AUSFUEHRUNG_2026-11-08.md`.
- **Paket-2-PROD-Baseline für Rollback:** `docs/prod-release/E05_PROD_PAKET_02_TRAININGSEVENT_RPC_2026-11-14.sql`, Git-Blob-SHA `bea5a140587a1e9cee4f49504e7bf983283bdda9`.
- Die PROD-Paket-3-Migration ist eine eigene, guarded Releasefassung; sie kopiert nicht blind eine alte DEV-Migration und enthält Vorbedingungen für den aktuell live geprüften Paket-2-Stand.
- Rollback stellt die vor Paket 3 live geprüfte Paket-2-RPC wieder her. Die Paket-2-Fassung wurde aus dem unveränderten PROD-Release-SQL abgeleitet.

## 4. Read-only Vorprüfung – 14.11.2026

### DEV
- Sperren- und Sperren-Audit-Tabelle vorhanden.
- Ausnahmen-Tabelle vorhanden.
- Paket-3-RPC und nachfolgende E05-Funktionen vorhanden.
- RLS und Policies vorhanden.
- DEV-Migrationshistorie enthält die Folgepakete 04–10 sowie DB-MIG-010/011 und atomaren Ausnahme-Widerruf.

### PROD
- Paket 1 und Paket 2 in der Migrationshistorie vorhanden:
  - `20261114162646 e05_prod_paket_01_trainingsereignisse_20261114`
  - `20261114165213 e05_prod_paket_02_trainingsevent_rpc_20261114`
- `training_suspensions` fehlt.
- `training_suspension_audit` fehlt.
- Paket-3-Audit-Guard und Policies fehlen.
- Paket-2-RPC ist vorhanden; aktuelle Definition wurde read-only ausgelesen und entspricht der Paket-2-Fassung.
- `is_team_member(uuid)`, `has_selected_team_context(uuid)`, `players`, `team_member_roles`, `global_user_roles`, Paket-1-Tabellen und erforderliche Eventfelder sind vorhanden.
- Die Paket-3-Vorbedingungen sind damit aktuell erfüllt. Die Migration enthält dennoch ein eigenes Preflight-Gate, das unmittelbar bei Ausführung erneut prüft und bei Drift vollständig abbricht.

## 5. Ausführungsartefakte

1. Migration: `supabase/migrations/20261114180000_e05_prod_paket_03_suspension_foundation.sql`
2. Guarded Rollback: `supabase/rollback/20261114180000_e05_prod_paket_03_suspension_foundation_rollback.sql`
3. Read-only Nachkontrolle: `docs/prod-release/E05_PROD_PAKET_03_SPERRFUNDAMENT_2026-11-14_TESTQUERIES.sql`
4. Isolierte PostgreSQL-17.6-Test-Fixture: `docs/prod-release/test-package-03/`
5. CI-Workflow: `.github/workflows/e05-prod-package-03-test.yml`

### Schutzmechanismen der Migration
- Abbruch, falls Paket 1 oder Paket 2 fehlt.
- Abbruch, falls Sperrenobjekte bereits ganz oder teilweise vorhanden sind.
- Abbruch, falls erwartete Rollen-/Kontext-Helfer oder Paket-2-ACLs fehlen.
- Abbruch, falls die live vorhandene Paket-2-RPC nicht dem erwarteten Baseline-Muster entspricht.
- Transaktionale Ausführung; Fehler rollen alle DDL-Änderungen zurück.

### Rollback-Grenzen
- Kein `CASCADE`.
- Abbruch, wenn Ereignis-, Ereignis-Audit-, Sperren- oder Sperren-Audit-Daten vorhanden sind.
- Abbruch, sobald Paket 4 oder spätere abhängige Sperren-/Ausnahme-/Korrekturfunktionen installiert sind.
- Rollback stellt die Paket-2-RPC wieder her und entfernt ausschließlich Paket-3-Objekte.
- Rollback wurde nicht in PROD ausgeführt. Der CI-Test prüft ihn isoliert.

## 6. Isolierter Testumfang

Der Workflow richtet eine temporäre PostgreSQL-17.6-Datenbank ein und verbindet sich weder mit Supabase DEV noch PROD.

Prüfungen:
- Paket-1-/Paket-2-Baseline lässt sich aufbauen.
- Paket-3-Migration läuft auf der Fixture.
- RLS, Policies, Indizes, Trigger und Grants entsprechen dem Paket.
- `award_training_behavior_event` bleibt SECURITY DEFINER mit festem search_path und nur `authenticated` EXECUTE.
- Vier gelbe Karten erzeugen keine Sperre; die fünfte erzeugt genau eine offene gelbe Sperre samt Audit.
- Rote Karte erzeugt genau eine rote Sperre mit passendem Quellereignis.
- Ein erzwungener Fehler beim Sperren-Audit rollt Ereignis, Ereignis-Audit und Sperre gemeinsam zurück.
- Guarded Rollback entfernt Paket 3 und stellt die Paket-2-RPC wieder her.

**Wichtige Testgrenze:** Der CI-Test belegt die technische Paket-3-Grundfunktion. Er ersetzt weder die vollständige DEV-Praxistesthistorie noch die späteren Folgepakete, die Zielspieltagzuordnung, Ausnahmen, Korrektur, Trainingsdatum-Chronologie und Sperren-/Nominierungs-Guard ergänzen.

## 7. Betriebsrisiko / Reihenfolge

Paket 3 aktiviert die automatische Sperrenerzeugung, enthält aber selbst noch keine Spieltagszuordnung oder Ausnahme-/Widerrufs-/Korrektur-Workflows. Deshalb:
- Paket 3 ist nur als erster Schritt der vollständigen E05-Produktivkette vorgesehen.
- Vor der Nutzung des vollständigen Trainerworkflows müssen die nachfolgenden DEV-bewährten Pakete in ihrer dokumentierten Reihenfolge separat vorbereitet, geprüft und freigegeben werden.
- Die fachliche Trainingsdatum-Chronologie wird erst durch das spätere Paket 10 hergestellt.
- Dieses Paket allein ist kein vollständiger Trainerworkflow und darf nicht als solcher kommuniziert werden.

## 8. Freigabe-Checkliste

- [x] DEV-Quelle und DEV-Ausführungsprotokoll gefunden.
- [x] Paket-1-/Paket-2-Abhängigkeiten in PROD read-only bestätigt.
- [x] PROD-Baseline der Paket-2-RPC und ACL read-only ausgelesen.
- [x] PROD-Vorbedingungen read-only geprüft.
- [x] PROD-Migration mit Preflight-Gates erstellt.
- [x] Rollback mit Daten- und Folgepaket-Gates erstellt.
- [x] Read-only Nachkontroll-SQL erstellt.
- [x] Isolierte PostgreSQL-17.6-Fixture, Assertions und CI-Workflow erstellt.
- [x] CI-Lauf erfolgreich abgeschlossen und geprüft (Run 43620391604, Commit 4b36272b781c3afa648abdd3dce7327728ebbdfb).
- [x] Finale SQL-/Rollback-Prüfung nach CI.
- [ ] Nutzerfreigabe zur PROD-Ausführung.
- [ ] Unmittelbare PROD-Vorprüfung und Hash-Abgleich.
- [ ] PROD-Migration ausgeführt.
- [ ] Read-only Nachkontrolle bestanden.
- [ ] DB-Migrationsjournal und Ausführungsprotokoll mit tatsächlichen Ergebnissen ergänzt.

## 9. CI-Auswertung – 14.11.2026

- **Finaler Workflow-Run:** [43620906226 – E05 PROD Paket 3 – isolated PostgreSQL validation](https://github.com/bautnhaus/jugendmannschaft/actions/runs/43620906226)
- **Commit:** `b75e1789aafd3d3c68702ff40633e41bae5944fb`
- Vorheriger erfolgreicher Lauf: [43620391604](https://github.com/bautnhaus/jugendmannschaft/actions/runs/43620391604). Nach der zusätzlichen Härtung des Rollback-Abhängigkeits-Gates wurde der vollständige Test erneut ausgeführt.
- **Ergebnis:** `success` auf PostgreSQL 17.6.
- **Finale SQL-Prüfung:** Der Funktionskörper der live vorhandenen PROD-Paket-2-RPC stimmt nach Normalisierung mit dem Paket-2-Release-SQL und der im Paket-3-Rollback wiederhergestellten Funktionsfassung überein. Die Migration prüft vor Ausführung die erwartete Paket-2-Baseline und die ACLs. Migration-SHA: `7f519980342bcde70379d884144a231a864a9de2`; Rollback-SHA: `f50eec5491a741138e3a23f7934b36fb05caeeb5`; Nachkontroll-SQL-SHA: `21f6800801e53c2765a8a46e1ea0b9b55e39ff1e`.
- **Rollback-Härtung:** Das Abhängigkeits-Gate deckt nun zusätzlich Paket-4-Einstellungen/-RPCs, Paket-5/6-Ausnahmen, Paket-7-Saisonabschluss, Paket-8-vorzeitigen Ausgleich, Paket-9-Korrekturen, Paket-10-Reconciliation sowie spätere Nominierungs-Trigger/-Funktionen ab.
- **Erfolgreiche Schritte:** Baseline Paket 1/2; Paket-3-Fixture; Ausführung der exakten PROD-Paket-3-Migrationsdatei; Struktur-/RLS-/Policy-/ACL-/Trigger-Prüfungen; gelbe Karten 1–4 ohne Sperre und Karte 5 mit genau einer gelben Sperre; rote Karte mit genau einer verknüpften roten Sperre; erzwungener Auditfehler mit atomarem Rollback; guarded Paket-3-Rollback und Wiederherstellung der Paket-2-RPC.
- **Fehlerbehebung vor dem erfolgreichen Lauf:** Die ersten drei Läufe scheiterten ausschließlich beim Fixture-Setup, weil Paket-3-Bootstrap Rollen und Auth-Objekte erneut anlegte, die bereits von Paket 1/2 erzeugt wurden (`role "anon" already exists`). Das Bootstrap wurde auf die noch fehlende Team-Fixture reduziert. Der erfolgreiche Lauf wurde anschließend mit dem korrigierten Fixture vollständig neu ausgeführt.
- **Testgrenze:** Dies ist ein isolierter PostgreSQL-Test, kein Supabase-PROD-Test und kein Nachweis eines PROD-Backups. Er belegt die getesteten Paket-3-SQL-Pfade innerhalb der Fixture.

## 10. Finale SQL-/Rollback-Prüfung – 14.11.2026

### Unveränderliche Artefakt-Hashes
- PROD-Migration: `supabase/migrations/20261114180000_e05_prod_paket_03_suspension_foundation.sql` – Git-Blob `7f519980342bcde70379d884144a231a864a9de2`.
- Guarded Rollback: `supabase/rollback/20261114180000_e05_prod_paket_03_suspension_foundation_rollback.sql` – Git-Blob `2bef2818bce64fac90ca17c1d27794baeac69255`.
- CI-Assertions: `docs/prod-release/test-package-03/assertions.sql` – Git-Blob `5eff3a6dd0da81f33c088d549c7d4163ce93e244`.
- CI-Fixture: `docs/prod-release/test-package-03/bootstrap.sql` – Git-Blob `db2fcdc2fe18dfc7bbf50c3cd34a380d4655ac48`.
- Die vier genannten Blobs wurden mit dem erfolgreichen CI-Commit `4b36272b781c3afa648abdd3dce7327728ebbdfb` verglichen; alle stimmen bytegenau mit den aktuellen Dateien auf `develop` überein. Der erfolgreiche CI-Lauf hat somit exakt diese Migration und dieses Rollback getestet.

### Quell- und Rollbackvergleich
- Der Funktionsblock `award_training_behavior_event(...)` in der PROD-Migration ist nach normalisiertem SQL-Text identisch mit dem Funktionsblock aus dem DEV-Paket-3-Quell-SQL.
- Die Tabellen-/Index-/Trigger-/Policy-DDL der PROD-Migration ist nach normalisiertem SQL-Text identisch mit dem entsprechenden DEV-Paket-3-Quellabschnitt.
- Der im Rollback wiederhergestellte Funktionsblock ist nach normalisiertem SQL-Text identisch mit der freigegebenen Paket-2-PROD-Baseline.
- Beide Skripte enden mit `COMMIT`; die Migration besitzt ein transaktionales Preflight-Gate. Der Rollback verwendet kein `CASCADE`.

### Unmittelbare read-only PROD-Nachprüfung
- PostgreSQL-Version: 17.6.
- Paket-1-Ereignis- und Audit-Tabellen vorhanden; beide enthalten aktuell 0 Datensätze.
- Paket-2-RPC vorhanden; Owner `postgres`; SECURITY DEFINER; fester `search_path=pg_catalog, public, auth`; EXECUTE nur für `authenticated`, nicht für `anon` oder `service_role`.
- Alle von der Migration/Funktion benötigten Spalten in `trainings`, `players`, `attendance`, `seasons`, `team_member_roles` und `global_user_roles` vorhanden.
- Rollen-/Teamkontext-Helfer vorhanden.
- Sperrentabellen, Audit-Guard und zugehörige Policies fehlen weiterhin wie erwartet.
- Die PROD-Vorbedingungen sind zum Prüfzeitpunkt vollständig erfüllt. Das SQL prüft sie bei Ausführung erneut und bricht bei zwischenzeitlicher Abweichung ab.

### Rollback-Betriebsgrenze
- Das Rollback stellt den Schema-/Funktionsstand von Paket 2 wieder her, entfernt aber nicht selbst den Eintrag aus Supabase `schema_migrations`/Migrationshistorie. Falls ein Rollback nach erfolgreicher Registrierung erforderlich wird, muss die Migrationshistorie separat über den dafür vorgesehenen Supabase-Migrationsprozess abgeglichen werden. Keine manuelle Löschung von Migrationshistorieneinträgen als Teil dieses SQL-Rollbacks.
- Das Rollback bricht ab, sobald Ereignis-/Auditdaten vorhanden sind oder Folgepaketobjekte installiert wurden. Bei Datenbestand ist Recovery/Restore statt Löschen erforderlich.
- Der Backup-/PITR-Status von PROD konnte mit den verfügbaren Werkzeugen nicht unabhängig verifiziert werden. Vor der tatsächlichen Ausführung ist dieser Punkt im Supabase-Projekt zu kontrollieren.

**Abschlussstatus: Paket 3 erfolgreich in PROD ausgeführt und read-only nachkontrolliert.**

## PROD-Ausführung – 14.11.2026

- **Status:** erfolgreich in Supabase PROD ausgeführt und nachkontrolliert.
- **Projekt:** `qdugtpzgefpswnnqbusd` (Jugendmannschaft, PostgreSQL 17.6).
- **Registrierte Migration:** Version `20261114174854`, Name `e05_prod_paket_03_suspension_foundation_20261114`. Die von Supabase vergebene Versionsnummer weicht vom lokalen Dateipräfix ab; dies ist der tatsächliche Eintrag in der PROD-Migrationshistorie.
- **Freigegebene SQL-Datei:** `supabase/migrations/20261114180000_e05_prod_paket_03_suspension_foundation.sql`, Git-Blob-SHA `7f519980342bcde70379d884144a231a864a9de2`.
- **Tabellen:** `training_suspensions` und `training_suspension_audit` vorhanden.
- **RLS:** auf beiden Tabellen aktiviert; jeweils eine Policy vorhanden.
- **Indizes:** 4 auf Sperren, 2 auf Sperren-Audit.
- **Audit:** Guard-Funktion vorhanden; 2 nicht-interne Audit-Trigger vorhanden.
- **Rechte:** authenticated darf Sperren lesen, nicht direkt einfügen; anon darf nicht lesen. Paket-2-RPC bleibt EXECUTE für authenticated; kein EXECUTE für anon/service_role.
- **RPC:** Live-Definition von `award_training_behavior_event(...)` enthält die Sperrenlogik.
- **Datenbestand:** unmittelbar nach Migration 0 Sperren und 0 Sperren-Audit-Einträge; keine bestehenden Ereignisdaten wurden verändert.
- **Backup/PITR:** kein unabhängiger Backup-/PITR-Nachweis. Gemäß dokumentierter Einschränkung des Supabase-Free-Plans wurde dies nicht als Release-Blocker behandelt.
- **Rollback:** nicht ausgeführt; nur für einen nötigen, gesondert geprüften Wiederherstellungsfall vorgesehen.
