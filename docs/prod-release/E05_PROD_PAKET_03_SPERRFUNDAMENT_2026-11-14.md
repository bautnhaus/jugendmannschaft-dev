# KADAssist / E05 – PROD Release Paket 3
## Sperrenfundament und automatische Sperrenauslösung

- **Zielumgebung:** Supabase PROD `qdugtpzgefpswnnqbusd` (PostgreSQL 17.6)
- **DEV-Referenz:** Supabase DEV `pzazqvvoruqnqhcorbwx`
- **Branch:** ausschließlich `develop`
- **Status:** Release-Kandidat in Vorbereitung; **NICHT in PROD ausgeführt**
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
- [ ] CI-Lauf erfolgreich abgeschlossen und geprüft.
- [ ] Finale SQL-/Rollback-Prüfung nach CI.
- [ ] Nutzerfreigabe zur PROD-Ausführung.
- [ ] Unmittelbare PROD-Vorprüfung und Hash-Abgleich.
- [ ] PROD-Migration ausgeführt.
- [ ] Read-only Nachkontrolle bestanden.
- [ ] DB-Migrationsjournal und Ausführungsprotokoll mit tatsächlichen Ergebnissen ergänzt.

**Aktueller Status: technischer Freigabekandidat in Vorbereitung. Nicht in PROD ausgeführt.** Keine Änderung an Supabase DEV, Supabase PROD oder GitHub `main` durch die Vorbereitung.