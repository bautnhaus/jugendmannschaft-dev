# KADAssist / E05 – PROD Release Paket 2
## Trainingsereignis vergeben (RPC)

- **Status:** Release-Kandidat – noch nicht freigegeben und nicht in PROD ausgeführt
- **Zielumgebung:** Supabase PROD
- **Projekt-ID:** `qdugtpzgefpswnnqbusd`
- **Vorbereitung:** 14.11.2026
- **DEV-Referenz:** Supabase DEV `pzazqvvoruqnqhcorbwx`
- **DEV-Ausführungsdatum:** 08.11.2026
- **DEV-Quelle:** `docs/E05_PAKET_02_AWARD_TRAINING_BEHAVIOR_EVENT_2026-11-08.sql`
- **DEV-Quell-Blob-SHA:** `405dd49e07c871e8756b7c2f6d70919726b05294`
- **DEV-Ausführungs-/Testprotokoll:** `docs/E05_PAKET_02_FREIGABE_UND_AUSFUEHRUNG_2026-11-08.md`
- **PROD-SQL:** `docs/prod-release/E05_PROD_PAKET_02_TRAININGSEVENT_RPC_2026-11-14.sql`
- **Rollback:** `docs/prod-release/E05_PROD_PAKET_02_TRAININGSEVENT_RPC_2026-11-14_ROLLBACK.sql`

## 1. Ziel und Umfang

Paket 2 legt ausschließlich die RPC an:

`public.award_training_behavior_event(uuid, uuid, text, text)`

Sie vergibt eine gelbe Karte, rote Karte oder einen positiven Stern und schreibt den Ereignisdatensatz sowie den zugehörigen Audit-Eintrag atomar.

Die RPC ermittelt Team, Saison, Trainings-/Spieler-Snapshots, Akteur und Zeitpunkt serverseitig. Der Client übergibt nur Trainings-ID, Spieler-ID, Ereignistyp und optionalen Grund.

## 2. Verbindliche Herkunft und Reihenfolge

Maßgeblich ist die tatsächlich am 08.11.2026 in DEV ausgeführte SQL-Fassung `docs/E05_PAKET_02_AWARD_TRAINING_BEHAVIOR_EVENT_2026-11-08.sql`. Das PROD-SQL übernimmt diese Funktionsimplementierung und ergänzt ausschließlich ein PROD-Vorbedingungs-Gate.

**Paket 2 bleibt bewusst auf dem damaligen Funktionsumfang.** Die inzwischen in DEV live vorhandene gleichnamige RPC ist später erweitert worden und enthält bereits Sperrenauslösung/-abgleich. Sie ist nicht die Paket-2-Fassung und wird nicht vorgezogen.

Chronologische Abfolge:
1. Paket 1 – Ereignistabellen und Ereignis-Audit (in PROD am 14.11.2026 erfolgreich ausgeführt).
2. **Paket 2 – Ereignisvergabe-RPC (dieses Paket).**
3. Paket 3 – Sperrenfundament und automatische Sperrenauslösung; ersetzt die RPC um die Sperrenlogik.

Paket 2 darf daher nicht mit der späteren Live-DEV-Funktion verwechselt werden. Es erstellt noch keine Sperre. Vor dem produktiven Trainerworkflow muss die nachfolgende Sperren-Lifecycle-Stufe abgeschlossen und abgenommen sein. Die E05-Frontend-Anbindung darf nicht vor dem Abschluss der erforderlichen Folgepakete produktiv aktiviert werden.

## 3. Funktionsumfang und serverseitige Prüfungen

- Authentifizierung über `auth.uid()`; keine clientseitige Actor-ID.
- Training und Spieler werden gesperrt (`FOR UPDATE`) und müssen existieren.
- Spieler muss aktiv sein und zum Team des Trainings gehören.
- Training darf nicht abgesagt sein.
- Akteur muss für genau dieses Team die Rolle `trainer` oder `admin` besitzen. Superadmin nur mit ausgewähltem Teamkontext.
- Tatsächliche Anwesenheit muss über `attendance.present = true` bestätigt sein.
- Saison wird aus dem Training übernommen, wenn sie aktiv und teamgleich ist. Bei fehlender Trainings-Saison muss genau eine aktive Saison des Teams existieren.
- Ereignistyp ausschließlich `yellow_card`, `red_card`, `positive_star`.
- Gelbe und rote Karte benötigen einen nichtleeren Grund; beim Stern ist der Grund optional.
- Eindeutigkeitsindizes aus Paket 1 verhindern zweite aktive Karten bzw. Sterne desselben Spielers im selben Training; Karte und Stern dürfen koexistieren.
- Ereignis und Audit werden innerhalb derselben Transaktion geschrieben. Auditfehler rollt den Vorgang vollständig zurück.

## 4. Read-only-Prüfung des PROD-Ausgangszustands

Supabase PROD `qdugtpzgefpswnnqbusd`, PostgreSQL 17.6, geprüft am 14.11.2026:

| Prüfpunkt | Ergebnis |
|---|---|
| Paket-1-Ereignistabelle vorhanden | Ja |
| Paket-1-Audit-Tabelle vorhanden | Ja |
| Paket-2-RPC vorhanden | Nein |
| Paket-3-Tabelle `training_suspensions` vorhanden | Nein |
| Paket-3-Tabelle `training_suspension_audit` vorhanden | Nein |
| `trainings`, `players`, `attendance`, `seasons` vorhanden | Ja |
| `team_member_roles`, `global_user_roles` vorhanden | Ja |
| `auth.uid()` vorhanden | Ja |
| `has_selected_team_context(uuid)` vorhanden | Ja |

Erforderliche Felder wurden im PROD-Katalog bestätigt:
- `trainings`: `id`, `team_id`, `training_date`, `name`, `status`, `season_id`
- `players`: `id`, `team_id`, `name`, `active`
- `attendance`: `training_id`, `player_id`, `present`
- `seasons`: `id`, `team_id`, `name`, `is_active`
- `team_member_roles`: `team_id`, `user_id`, `role`
- `global_user_roles`: `user_id`, `role`

Das Vorbedingungs-Gate im SQL bricht ab, falls Paket 1 fehlt, die RPC bereits existiert, Paket-3-Objekte vorgezogen wurden oder erforderliche Bestandsobjekte fehlen.

## 5. DEV-Ausführung und dokumentierte Tests

Das DEV-Protokoll bestätigt die erfolgreiche Ausführung am 08.11.2026 und folgende Nachweise:
- Funktionssignatur vorhanden, `SECURITY DEFINER`.
- EXECUTE für `authenticated`; nicht für `anon` und `service_role`.
- Positivpfad mit Trainer, aktivem Spieler, bestätigter Anwesenheit und aktiver Saison.
- Ereignis und Audit-Eintrag gemeinsam erzeugt; Testtransaktion zurückgerollt.
- Fehlender Kartengrund wird mit SQLSTATE `22023` abgewiesen.
- Weitere dokumentierte Negativ-/Grenztests: fehlende Teamrolle, unbekannte/fremde Spielerreferenz, fehlende Anwesenheit, abgesagtes Training, ungültiger Ereignistyp, Duplikatkarte, Duplikatstern; Karte plus Stern zulässig.

**Nachweisgrenze aus dem DEV-Protokoll:** Die späteren Ergänzungen enthalten unterschiedliche Aussagen dazu, ob inaktiver Spieler und fehlende/mehrdeutige aktive Saison tatsächlich separat getestet wurden. Diese Fälle werden deshalb nicht als abschließend nachgewiesene DEV-Tests gewertet. Der konkrete Fall „Akteur hat ausschließlich eine Rolle in einem anderen Team“ wurde laut Protokoll ebenfalls nicht separat getestet.

## 6. PROD-Auswirkung

- Eine neue SECURITY-DEFINER-RPC wird angelegt/ersetzt.
- EXECUTE wird explizit nur an `authenticated` vergeben; `PUBLIC`, `anon` und `service_role` werden entzogen.
- Keine bestehenden Tabellen, Daten, Rollen, Policies oder Trigger werden geändert.
- Keine Sperrentabellen oder Sperrenlogik werden angelegt.
- Keine Ereignis- oder Auditdatensätze werden durch die Migration selbst geschrieben.
- Das Paket ist nicht als alleiniger produktiver Trainerworkflow gedacht; Paket 3 folgt in der festgelegten Reihenfolge.

## 7. Rollback

Rollback-Datei: `docs/prod-release/E05_PROD_PAKET_02_TRAININGSEVENT_RPC_2026-11-14_ROLLBACK.sql`.

Sie entfernt ausschließlich die Paket-2-RPC und nur dann, wenn:
- die RPC vorhanden ist;
- Paket-3-Sperrentabellen und abhängige Sperrenlogik nicht vorhanden sind.

Es wird kein `CASCADE` verwendet. Tabellen und Ereignisdaten bleiben unangetastet. Sobald Paket 3 die RPC erweitert oder davon abhängige Sperrenlogik installiert, darf Paket 2 nicht isoliert zurückgebaut werden.

## 8. Isolierter PostgreSQL-Test

- Workflow: `.github/workflows/e05-prod-package-02-test.yml`
- Testumgebung: temporärer PostgreSQL-17.6-Dienst in GitHub Actions; keine Verbindung zu Supabase DEV/PROD.
- Fixture: Paket-1-Schema plus minimale Bestandsobjekte und Auth-/Teamrollen-Simulation.
- Assertions: SECURITY DEFINER, fester search_path, EXECUTE-ACL, Positivpfad, atomarer Audit-Eintrag, Karte+Stern, Duplikatkarte, fehlende Anwesenheit, abgesagtes Training, fehlender Kartengrund und fehlende Teamrolle.
- Zusätzlich wird der guarded Rollback vor Paket 3 ausgeführt.

**CI-Status:** Der Workflow ist angelegt und der erste Lauf wird nach Abschluss der Workflow-Ausführung hier mit Run-ID und Ergebnis ergänzt. Bis ein grüner Lauf auf dem finalen SQL-/Test-Commit verifiziert ist, bleibt die technische Freigabeschranke offen.

## 9. Freigabe- und Ausführungscheckliste

- [x] Originale DEV-Paket-2-SQL-Datei und Ausführungsprotokoll gefunden
- [x] Chronologische Abgrenzung zu Paket 3 geklärt
- [x] PROD-Paket-1-Abhängigkeit read-only bestätigt
- [x] PROD-Bestandsobjekte und erforderliche Spalten read-only geprüft
- [x] PROD-Vorbedingungs-Gate erstellt
- [x] Rollback mit Abhängigkeits-Gate erstellt
- [x] Isolierter PostgreSQL-17.6-Testlauf erfolgreich und verifiziert
- [x] CI-Nachweis in diesem Dokument ergänzt
- [ ] Finale Freigabe durch Nutzer
- [ ] Unmittelbare PROD-Vorprüfung und SQL-Hash-Abgleich
- [ ] In PROD ausgeführt
- [ ] Nachkontrollen bestanden und protokolliert

**Aktueller Status: vorbereitet; noch nicht zur Ausführung freigegeben.** Keine SQL-Ausführung in Supabase DEV oder PROD durch diese Vorbereitung. GitHub `main` unverändert.


## 10. Technischer Abschluss der Vorbereitung

Die drei Release-Artefakte und der isolierte PostgreSQL-Test sind vollständig vorbereitet. Der CI-Lauf hat die konkrete Paket-2-RPC einschließlich der Paket-1-Abhängigkeit erfolgreich ausgeführt und anschließend den Rückbau vor Paket 3 geprüft.

GitHub-Referenzen auf `develop`:
- PROD-SQL: `docs/prod-release/E05_PROD_PAKET_02_TRAININGSEVENT_RPC_2026-11-14.sql`
- Rollback: `docs/prod-release/E05_PROD_PAKET_02_TRAININGSEVENT_RPC_2026-11-14_ROLLBACK.sql`
- CI-Test: `docs/prod-release/test-package-02/`
- Workflow: `.github/workflows/e05-prod-package-02-test.yml`

**Freigabestatus:** technisch validierter Release-Kandidat. Die Migration wurde nicht in Supabase ausgeführt. Für die Ausführung sind weiterhin die ausdrückliche Nutzerfreigabe und die unmittelbar vorherige read-only PROD-Vorprüfung erforderlich.
