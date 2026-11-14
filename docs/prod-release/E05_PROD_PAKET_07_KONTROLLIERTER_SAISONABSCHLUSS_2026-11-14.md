# E05 PROD Paket 7 – Kontrollierter Saisonabschluss

- **Paket:** E05 PROD Paket 7
- **Fachlicher Umfang:** kontrollierter Abschluss einer Team-Saison und revisionssicheres Ablösen offener Sperren derselben Saison.
- **Status:** vorbereitet zur Freigabe; noch nicht in PROD ausgeführt.
- **DEV-Projekt:** `pzazqvvoruqnqhcorbwx`
- **PROD-Projekt:** `qdugtpzgefpswnnqbusd`
- **DEV-Quellen:**
  - `docs/E05_PAKET_07_SAISONABSCHLUSS_2026-11-08.sql` (Blob-SHA `2626c07c212a84481fe532f4b83083bc2aac90f5`)
  - `docs/E05_PAKET_07_FIX_AUDIT_RLS_SUPERADMIN_2026-11-08.sql` (Blob-SHA `0b94492f3c30133107f2b328ef8328e0317f51f0`)
  - DEV-Abnahme: `docs/E05_PAKET_07_ABNAHME_UND_AUSFUEHRUNG_2026-11-08.md` (Blob-SHA `eeb5febee8c9816a8a760e2c1c9dda982462e1e7`)

## 1. Fachlicher Umfang

RPC `public.close_team_season(p_season_id uuid,p_reason text)` schließt genau eine aktive Saison eines Teams.

Bei erfolgreichem Abschluss:
1. Saison `is_active=false`.
2. Offene Sperren nur für dieselbe Team-/Saisonkombination wechseln auf `expired`.
3. Für jede abgelöste Sperre wird ein `expired`-Audit mit altem/neuem Zustand, Grund, Akteur und Zeitpunkt geschrieben.
4. Ein Eintrag in `team_season_closure_audit` protokolliert Saison, Team, Benutzer, Zeitpunkt, Begründung und Anzahl abgelaufener Sperren.
5. Karten-, Trainings-, Sperren- und Ausnahmehistorie bleibt erhalten.

Keine Folgesaison wird angelegt. Keine Kartenhistorie, Nominierungen, tatsächlichen Einsätze oder bereits abgeleisteten Sperren werden verändert.

## 2. Berechtigungen und Schutz

- Authentifizierung und nichtleere Begründung zwingend.
- Mannschaftsadmin oder Super Admin mit globaler Rolle und ausdrücklich ausgewähltem Teamkontext.
- Saison wird vor Prüfung/Änderung mit `FOR UPDATE` gesperrt.
- Unbekannte oder bereits geschlossene Saison wird abgewiesen.
- Nur offene Sperren des exakten Teams und der exakten Saison werden abgelöst.
- Alles läuft atomar; Fehler beim Sperren-Audit oder Saisonabschluss-Audit rollen alle Änderungen zurück.
- Audit-Tabelle ist RLS-geschützt und append-only.
- Audit-Lesepolicy enthält den in DEV nachträglich korrigierten Super-Admin-Kontext: `is_team_member(team_id) OR has_selected_team_context(team_id)`.

## 3. PROD-Bestandsprüfung (read-only, 14.11.2026)

- PROD-Migrationshistorie enthält Pakete 1–6; Paket 7 ist noch nicht registriert.
- `team_season_closure_audit` existiert in PROD nicht.
- `close_team_season(uuid,text)` und die Paket-7-Append-only-Triggerfunktion existieren nicht.
- Basistabellen `teams`, `seasons`, `team_member_roles`, `global_user_roles`, `training_suspensions`, `training_suspension_audit` und `profiles` sind vorhanden.
- `has_selected_team_context(uuid)` und `is_team_member(uuid)` sind vorhanden.
- PROD hat 2 Saisons, davon 2 aktiv; 0 offene Sperren. Die Migration selbst schließt keine Saison und verändert keine vorhandenen Saison-/Sperrendatensätze.
- Vorhandene PROD-Saison-Spalten `id, team_id, name, start_date, end_date, is_active, created_at, updated_at` entsprechen den in der DEV-Funktion verwendeten Feldern.

## 4. PROD-Anpassung gegenüber DEV

Die DEV-Umsetzung bestand aus zwei Migrationen:
- `20261108180535 e05_package_07_controlled_season_closure`
- `20261108180944 e05_package_07_fix_season_audit_context_rls`

Für PROD wird die korrigierte RLS-Policy direkt in die Paketmigration übernommen. Es wird keine zunächst unvollständige Policy angelegt. Fachliche RPC-Logik und Auditstruktur folgen der DEV-Quelle.

## 5. Migration und Rollback

- Migration: `supabase/migrations/20261114220000_e05_prod_paket_07_controlled_season_closure.sql`
- Rollback: `supabase/rollback/20261114220000_e05_prod_paket_07_controlled_season_closure_rollback.sql`
- Rollback ist absichtlich guarded: Er bricht ab, sobald Saisonabschluss-Auditdaten existieren. Er stellt weder eine geschlossene Saison noch abgelaufene Sperren wieder her. Deshalb nur vor produktiver Verwendung möglich.
- Migration ist transaktional und enthält Preflight-Prüfungen auf Voraussetzungen und bereits vorhandene Paketobjekte.

## 6. Prüfplan vor und nach Freigabe

### Struktur / ACL / RLS
1. Tabelle, Spalten, FK/Unique/Checks und RLS vorhanden.
2. Audit-SELECT für `authenticated`, mit Mitgliedschaft oder ausgewähltem Teamkontext.
3. Direkte INSERT/UPDATE/DELETE-Rechte für `authenticated` und `anon` fehlen.
4. Append-only-Trigger blockiert UPDATE/DELETE/TRUNCATE.
5. RPC SECURITY DEFINER, fester Search Path, EXECUTE für authenticated, nicht für anon.
6. Triggerfunktion nicht direkt durch API-Rollen ausführbar.

### Funktionale Tests (nur DEV/isolierte CI)
- Berechtigter Admin schließt aktive Saison mit Begründung.
- Offene gelbe und rote Sperren derselben Saison werden abgelöst und einzeln auditiert.
- Bereits abgeleistete Sperren bleiben unverändert.
- Sperren anderer Teams/Saisons bleiben unverändert.
- Saisonabschluss-Audit enthält korrekte Metadaten und Anzahl.
- Historische Ereignisse, Ausnahmen, Nominierungen und Einsätze bleiben erhalten.
- Negativ: unauthenticated, Trainer ohne Adminrolle, Super Admin ohne Teamkontext, leere Begründung, unbekannte Saison, doppelte Schließung.
- Audit-Manipulation wird abgewiesen.
- Fehler während Auditierung rollt die Gesamttransaktion zurück.

### Testgrenze
CI/isolierte Tests ersetzen keine authentifizierten End-to-End-Tests mit echten Supabase-Rollen. Vor einem Frontend-Rollout müssen die DEV-Rollenfälle und der Saisonabschluss mit synthetischen Daten praktisch geprüft sein. Es werden keine Testdaten in PROD angelegt.

## 7. Freigabegrenze

Diese Vorbereitung ist **keine Ausführungsfreigabe**. Die Migration wird erst nach einer separaten ausdrücklichen Freigabe in Supabase PROD ausgeführt. GitHub `main`, Frontend-Index und PROD-Daten bleiben bis dahin unverändert.
