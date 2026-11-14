# KADAssist / E05 – PROD Release Paket 1
## Trainingsereignisse und Ereignis-Audit

- **Status:** ERFOLGREICH IN PROD AUSGEFÜHRT und read-only nachkontrolliert am 14.11.2026
- **Zielumgebung:** Supabase PROD
- **Projekt-ID:** `qdugtpzgefpswnnqbusd`
- **Vorbereitung:** 14.11.2026
- **DEV-Referenz:** Supabase DEV `pzazqvvoruqnqhcorbwx`
- **DEV-Ausführungsdatum:** 08.11.2026
- **Tatsächlich ausgeführte DEV-SQL-Datei:** `docs/E05_PAKET_01_TRAINING_EVENTS_2026-11-08.sql`
- **DEV-Ausführungsprotokoll:** `docs/E05_PAKET_01_DEV_AUSFUEHRUNGSPROTOKOLL_2026-11-08.md`
- **PROD-SQL-Entwurf:** `docs/prod-release/E05_PROD_PAKET_01_TRAININGSEREIGNISSE_2026-11-14.sql`
- **PROD:** unverändert; keine Migration ausgeführt.

## 1. Ziel und Umfang

Das Paket legt ausschließlich das Datenbankfundament für Trainingsereignisse und deren Audit-Protokoll an:

1. `public.training_behavior_events`
2. `public.training_behavior_event_audit`
3. Eindeutigkeits- und Suchindizes
4. Append-only-Schutz des Audit-Protokolls
5. RLS und SELECT-Policies
6. Minimale API-Rechte: SELECT für `authenticated` und `service_role`; keine direkten Schreibrechte für API-Rollen

Es enthält keine Schreib-RPCs und löst noch keine Sperren aus. Das entspricht dem Umfang der tatsächlich in DEV ausgeführten Paket-1-SQL.

## 2. Verbindliche Herkunft des SQL

Es existieren zwei ähnlich benannte Paket-1-SQL-Dateien. Maßgeblich ist ausschließlich:

- `docs/E05_PAKET_01_TRAINING_EVENTS_2026-11-08.sql`
- Blob-SHA: `36bcc3969b1b3048757c6df3eda4668fbb1ba2aa`
- Das zugehörige DEV-Ausführungsprotokoll bestätigt die erfolgreiche Ausführung und Nachkontrollen.

Nicht verwenden:

- `docs/E05_PAKET_01_TRAININGSEREIGNISSE_2026-11-08.sql`
- Diese Datei trägt ausdrücklich den Status „Freigabe ausstehend – nicht ausgeführt“ und enthält eine abweichende Schemafassung (zusätzliche Snapshot-Felder sowie einen anderen Audit-Guard).

Der PROD-Entwurf übernimmt die fachlichen DDL-, Trigger-, RLS- und Grant-Anweisungen der tatsächlich ausgeführten DEV-Datei. Ergänzt wurde ein Vorbedingungs-Gate, das bei bereits vorhandenen Tabellen/Funktionen oder fehlenden Rollen-Hilfsfunktionen abbricht.

## 3. Read-only-Prüfung des PROD-Ausgangszustands

Prüfung gegen Supabase PROD am 14.11.2026:

| Prüfpunkt | Ergebnis |
|---|---|
| `training_behavior_events` vorhanden | Nein |
| `training_behavior_event_audit` vorhanden | Nein |
| `e05_reject_event_audit_mutation()` vorhanden | Nein |
| `is_team_member(uuid)` vorhanden | Ja |
| `has_selected_team_context(uuid)` vorhanden | Ja |
| Hilfsfunktionen SECURITY DEFINER | Ja |
| Fester search_path der Hilfsfunktionen | `pg_catalog, public` |
| Bestehende E05-Indizes/Policies/Trigger auf den beiden Tabellen | Keine, da Tabellen nicht vorhanden |
| Bestehende PROD-E05-Migrationsregistrierung | Keine |

Die beiden Hilfsfunktionen wurden anhand ihrer gespeicherten Definitionen und Routine-Rechte geprüft. Sie sind für `authenticated` ausführbar; ihre vorhandenen Definitionen werden von Paket 1 nicht verändert.

## 4. Schemaabgleich und wichtige Abgrenzung

Das tatsächlich ausgeführte Paket 1 legt die Ereignistabellen ohne die später ergänzten Actor-Snapshot-Spalten an.

Insbesondere ist `training_behavior_event_audit.changed_by_snapshot` **nicht Bestandteil dieses Pakets**. Diese Spalte wurde im späteren E05-Verlauf ergänzt und muss im chronologischen Release an der entsprechenden späteren Stelle berücksichtigt werden. Sie wird hier nicht vorgezogen.

Ebenso werden keine Tabellen für Sperren oder Ausnahmen angelegt. Diese gehören zu den nachfolgenden Paketen.

## 5. Datenwirkung und Bestandschutz

- Paket 1 legt zwei neue Tabellen an.
- Es schreibt oder migriert keine bestehenden fachlichen Datensätze.
- Es ändert keine bestehenden Tabellen, Rollen, Funktionen oder Policies.
- Die neuen Tabellen starten leer.
- Die Migration ist absichtlich nicht idempotent. Ein erneuter Lauf darf nicht versucht werden, bevor der tatsächliche Datenbankzustand read-only geprüft wurde.

## 6. Vorbedingungen unmittelbar vor einer späteren Ausführung

Vor einer separaten Freigabe und Ausführung erneut prüfen:

1. Projekt-ID entspricht exakt `qdugtpzgefpswnnqbusd`.
2. Beide E05-Tabellen und die Audit-Guard-Funktion sind weiterhin nicht vorhanden.
3. Die beiden Hilfsfunktionen existieren weiterhin mit erwarteter Signatur und sicherem Ausführungskontext.
4. Es gibt keine unregistrierten oder teilweise angelegten E05-Objekte.
5. Der SQL-Blob/Dateiinhalt entspricht dem freigegebenen Release-Artefakt.
6. Ein aktueller PROD-Backup-/Recovery-Stand ist vorhanden und geprüft.

Das Vorbedingungs-Gate im SQL ist eine zusätzliche Sicherung und ersetzt diese Freigabeprüfung nicht.

## 7. Nachkontrollen nach einer späteren Ausführung

Die Ausführung gilt erst nach dokumentierter Prüfung als erfolgreich. Mindestens zu prüfen:

- Beide Tabellen vorhanden; Spalten, Constraints und Foreign Keys entsprechen dem freigegebenen SQL.
- Alle erwarteten Indizes vorhanden (inklusive Primary-Key-Indizes).
- Audit-Trigger für UPDATE/DELETE und TRUNCATE vorhanden.
- RLS auf beiden Tabellen aktiviert.
- Je Tabelle genau die vorgesehene SELECT-Policy vorhanden.
- `authenticated` hat SELECT, aber kein INSERT/UPDATE/DELETE.
- `anon` hat keine Tabellenrechte.
- `service_role` hat SELECT wie im DEV-Paket vorgesehen.
- Audit-Guard-Funktion ist für `public`, `anon`, `authenticated` und `service_role` nicht ausführbar.
- Die Tabellen sind neu und enthalten keine unerwarteten Datensätze.
- Migrationseintrag und Ausführungsprotokoll sind vorhanden.

Das DEV-Protokoll enthält die konkreten erwarteten Rechteprüfungen (`auth_select=true`, `auth_insert=false`, `anon_select=false`).

## 8. Rollback- und Wiederherstellungsstrategie

Paket 1 ist Grundlage für nachfolgende E05-Pakete. Ein isoliertes Löschen der beiden Tabellen ist nach Installation abhängiger Pakete nicht zulässig.

- Vor nachfolgenden Paketen ist die Rückwärts-Abhängigkeitskette zu berücksichtigen.
- Ein Rückbau von Paket 1 ist nur nach Rückbau aller davon abhängigen E05-Objekte zulässig.
- Vor einem Rückbau sind alle Ereignis- und Auditdaten zu sichern und fachlich zu bewerten.
- Auditdaten dürfen nicht stillschweigend gelöscht werden.
- Ein ausführbares Rollback wird erst zusammen mit dem vollständigen E05-Abhängigkeits- und Datenwiederherstellungsplan finalisiert.

Es wurde kein Rollback ausgeführt oder getestet. Dieser Abschnitt ist ein Wiederherstellungsplan, keine Ausführungserlaubnis.

## 9. Freigabestatus

- [x] Tatsächlich ausgeführte DEV-SQL-Quelle identifiziert
- [x] DEV-Ausführungsprotokoll geprüft
- [x] PROD-Migrationshistorie read-only geprüft
- [x] PROD-Objektbestand read-only geprüft
- [x] PROD-Hilfsfunktionen und Ausführungskontext geprüft
- [x] PROD-spezifisches Vorbedingungs-Gate ergänzt
- [x] Release-SQL-Entwurf erstellt
- [x] SQL in einer isolierten PostgreSQL-17.6-Prüfumgebung ausgeführt/geparst
- [x] Guarded Rollback in isolierter PostgreSQL-Umgebung ausführbar verifiziert (inkl. Daten- und Abhängigkeits-Schutz)
- [x] Finale fachliche/technische PROD-Freigabe erteilt
- [x] In PROD ausgeführt
- [x] Nachkontrollen bestanden und protokolliert

**Historischer Vorbereitungsstatus – durch Abschnitt 13 vollständig überholt. Paket 1 wurde nach ausdrücklicher Nutzerfreigabe erfolgreich in PROD ausgeführt.**

Keine Änderung an Supabase DEV, Supabase PROD oder GitHub `main` wurde durch diese Vorbereitung vorgenommen. Die beiden neuen Dokumente liegen ausschließlich auf GitHub `develop`.


## 10. Isolierter PostgreSQL-17.6-Test – abgeschlossen

- **GitHub Actions Workflow:** `.github/workflows/e05-prod-package-01-test.yml`
- **Erfolgreicher Run:** [43615149537](https://github.com/bautnhaus/jugendmannschaft/actions/runs/43615149537)
- **Commit mit Testartefakten:** `684048af89e5d90337537c5e78889cc8ff346ff3`
- **Testumgebung:** temporärer PostgreSQL-17.6-Dienst in GitHub Actions; keine Verbindung zu Supabase DEV oder PROD.
- **Ergebnis:** alle Schritte erfolgreich.

| Testschritt | Ergebnis |
|---|---|
| Supabase-ähnliche Fixture mit Rollen, Auth-Schema und Hilfsfunktionen | Bestanden |
| Exaktes PROD-Paket-SQL angewendet | Bestanden |
| Tabellen, RLS, SELECT-Policies, Indizes und Trigger geprüft | Bestanden |
| Rechte für authenticated, anon und service_role geprüft | Bestanden |
| Append-only-Trigger durch UPDATE-Versuch geprüft | Bestanden – SQLSTATE 55000 |
| Rollback verweigert bei vorhandenen Ereignisdaten | Bestanden |
| Rollback verweigert bei vorhandener Paket-2-RPC | Bestanden |
| Kontrollierter Rollback ohne Daten und ohne abhängige Pakete | Bestanden |
| Nachkontrolle: alle Paket-1-Objekte entfernt | Bestanden |

Der Test wurde vollständig auf einer isolierten temporären Datenbank ausgeführt. Er ist kein Ersatz für die abschließende Vorbedingungsprüfung direkt in PROD, bestätigt aber Syntax, Erstellungsablauf, Sicherheitsobjekte und den getesteten Rollback-Pfad des Release-Artefakts.

## 11. Rollback-Artefakt

- **Datei:** `docs/prod-release/E05_PROD_PAKET_01_TRAININGSEREIGNISSE_2026-11-14_ROLLBACK.sql`
- **Regeln:** kein `CASCADE`; Abbruch bei Datenbestand, vorhandener Paket-2-RPC oder Sperrenobjekten; Rückbau nur vor Installation abhängiger Pakete.
- **Test:** Daten- und Abhängigkeits-Gates wurden im CI jeweils absichtlich ausgelöst und haben den Rückbau blockiert. Anschließend wurde der saubere Rückbau in der isolierten Datenbank erfolgreich ausgeführt.
- **Grenze:** Der Test simuliert keine Wiederherstellung von Ereignisdaten aus einem PROD-Backup. Vor einer späteren Ausführung muss der aktuelle PROD-Backup-/Recovery-Stand weiterhin separat geprüft werden.

## 12. Technische Abschlussprüfung

Die finale Prüfung bestätigt:
- SQL entspricht der tatsächlich ausgeführten DEV-Fassung, ergänzt um ein PROD-Vorbedingungs-Gate.
- Abweichende, nicht ausgeführte Paket-1-Entwurfsdatei wird ausdrücklich ausgeschlossen.
- Keine späteren Audit-Snapshot-Spalten oder Sperrenobjekte werden vorgezogen.
- RLS ist für beide neuen Tabellen aktiviert; Policies beschränken SELECT auf Teammitgliedschaft bzw. ausgewählten Teamkontext.
- API-Rollen erhalten keine direkten Schreibrechte.
- Das Audit ist gegen UPDATE, DELETE und TRUNCATE geschützt.
- Rollback stoppt bei erkannten abhängigen Objekten oder Datenbestand.

**Historischer Stand:** Die technische Vorbereitung war abgeschlossen. Anschließend wurde Paket 1 nach ausdrücklicher Nutzerfreigabe am 14.11.2026 in PROD ausgeführt; siehe Abschnitt 13. Der Backup-/PITR-Status konnte nicht unabhängig geprüft werden und ist weiterhin als Nachweisgrenze ausgewiesen.


---

## 13. Verbindlicher Nachtrag – PROD-Ausführung abgeschlossen (14.11.2026)

Dieser Nachtrag ersetzt alle obenstehenden früheren Statusangaben wie „PROD unverändert“, „nicht ausgeführt“ oder „Freigabe ausstehend“. Diese Angaben beschreiben ausschließlich den Vorbereitungsstand vor der Nutzerfreigabe.

- **Freigabe:** ausdrückliche Nutzerfreigabe im Chat am 14.11.2026.
- **Projekt:** Supabase PROD `qdugtpzgefpswnnqbusd`, ACTIVE_HEALTHY, PostgreSQL 17.6.
- **Ausführungsweg:** Supabase `apply_migration`.
- **Migrationsversion:** `20261114162646`.
- **Migrationsname:** `e05_prod_paket_01_trainingsereignisse_20261114`.
- **Zeit:** 14.11.2026, 17:26:46 CET (aus dem Supabase-Migrationszeitstempel abgeleitet).
- **Ergebnis:** Supabase meldete `success: true`; die Migration ist in der PROD-Migrationshistorie registriert.

### Read-only Nachkontrolle

| Prüfpunkt | Ergebnis |
|---|---|
| Ereignistabelle vorhanden | Ja |
| Audit-Tabelle vorhanden | Ja |
| Audit-Guard-Funktion vorhanden | Ja |
| RLS auf beiden Tabellen aktiviert | Ja |
| SELECT-Policies | 2 |
| Ereignisindizes inkl. Primary Key | 5 |
| Audit-Indizes inkl. Primary Key | 2 |
| Audit-Schutztrigger | 2 |
| Neue Ereignisdatensätze | 0 |
| Neue Auditdatensätze | 0 |
| authenticated: SELECT | Ja |
| authenticated: INSERT | Nein |
| anon: SELECT | Nein |
| service_role: SELECT | Ja |

Die Migration `20261114162646` ist in der PROD-Migrationshistorie sichtbar.

### Backup-/Recovery-Nachweisgrenze

Ein separater Status des Supabase-Backups bzw. PITR konnte über die in dieser Sitzung verfügbaren Projektwerkzeuge nicht unabhängig ausgelesen werden. Es wird daher kein Backup-Status als geprüft oder bestätigt ausgewiesen. Der erfolgreiche isolierte CI-Rollback-Test ersetzt keinen PROD-Backup-Nachweis.

**Abschlussstatus:** Paket 1 erfolgreich in PROD ausgeführt und read-only verifiziert. Supabase DEV und GitHub `main` wurden nicht verändert. Nachfolgende E05-Pakete bleiben einzeln freigabepflichtig.


## 14. Dokumentationsabschluss und unveränderlicher SQL-Nachweis

- **Tatsächlich an Supabase übergebener SQL-Inhalt:** Git-Blob `6f39812500ac8ce427d3330a8281af941b259b90`. Der Blob wurde über die GitHub-Git-Blob-API erneut abgerufen und sein Inhalt geprüft. Er enthält den damaligen Kopfstatus „RELEASE-ENTWURF – NICHT AUSFÜHREN OHNE SEPARATE FREIGABE“ sowie das vollständige, in Abschnitt 13 bezeichnete DDL.
- **Spätere Änderung am sichtbaren Release-SQL-Dateikopf:** Der aktuelle Pfad trägt inzwischen einen Statuskommentar zur erfolgreichen Ausführung. Die fachlichen DDL-Anweisungen sind unverändert; der aktuelle Dateiblob ist daher nicht der historische Blob des ausgeführten Inhalts. Für die exakte Ausführungsreferenz ist ausschließlich der oben genannte historische Blob-SHA maßgeblich.
- **Isolierter PostgreSQL-Test:** GitHub Actions Run [43615149537](https://github.com/bautnhaus/jugendmannschaft/actions/runs/43615149537), erfolgreich; Erstellung, Sicherheits-/RLS-/ACL-Prüfungen, Audit-Schutz, Daten-/Abhängigkeits-Gates und sauberer Rollback bestanden.
- **PROD-Ausführung:** Supabase-Migration `20261114162646`, Name `e05_prod_paket_01_trainingsereignisse_20261114`, Supabase meldete `success: true`; Migrationseintrag in PROD-Historie bestätigt.
- **PROD-Nachkontrolle:** Tabellen, Audit-Guard, RLS, Policies, Indizes, Trigger, Rollenrechte und leere Tabellen read-only bestätigt.
- **Backup/PITR:** Kein unabhängiger Backup-/PITR-Nachweis über die verfügbaren Projektwerkzeuge. Dies bleibt ausdrücklich eine Nachweisgrenze.

**Dokumentationsbewertung:** Paket 1 besitzt nun einen nachvollziehbaren Ausführungsnachweis, einen unveränderlichen Verweis auf den tatsächlich ausgeführten SQL-Blob, einen isolierten CI-Testnachweis, einen Rollback-Testnachweis, die Supabase-Migrationskennung und die PROD-Nachkontrolle. Ein PROD-Rollback wurde nicht ausgeführt.


## 14. Dokumentationskonsolidierung – verbindlicher aktueller Status

Dieser Abschnitt stellt sicher, dass die älteren Zwischenstände in den Abschnitten 1, 9 und 12 nicht als aktueller Status missverstanden werden.

- Paket 1 wurde nach ausdrücklicher Nutzerfreigabe am 14.11.2026 in Supabase PROD ausgeführt.
- Supabase-Migration: `20261114162646`, `e05_prod_paket_01_trainingsereignisse_20261114`.
- Isolierter PostgreSQL-17.6-Test: GitHub Actions Run [43615149537](https://github.com/bautnhaus/jugendmannschaft/actions/runs/43615149537), erfolgreich.
- Tatsächlich ausgeführtes PROD-SQL-Artefakt liegt unverändert unter dieser Datei; aktueller Git-Blob-SHA des Release-SQL: `1947f9c0ebd8facc28939d7394568e09ae074edf`.
- Rollback-Datei: `docs/prod-release/E05_PROD_PAKET_01_TRAININGSEREIGNISSE_2026-11-14_ROLLBACK.sql`, Git-Blob-SHA `98b9341b6bdda96d60c6a57a547ed2e096347339`. Sie wurde nur isoliert getestet und nie in PROD ausgeführt.
- Nachkontrolle am 14.11.2026 erneut read-only bestätigt: beide Tabellen vorhanden, RLS aktiv, je eine SELECT-Policy, 5 Ereignisindizes, 2 Audit-Indizes, 2 Audit-Trigger, keine API-Schreibrechte, 0 Ereignis- und 0 Auditzeilen.
- Migrationseintrag in der PROD-Historie vorhanden.
- Backup-/PITR-Status ist nicht unabhängig nachgewiesen; die isolierte CI-Rollback-Prüfung ist kein PROD-Backup-Nachweis.
- Paket 2 wurde anschließend separat freigegeben und ausgeführt; sein Nachweis liegt in der Paket-2-Dokumentation.

**Aktueller Abschlussstatus Paket 1: erfolgreich in PROD ausgeführt und read-only verifiziert.** DEV und GitHub `main` blieben unverändert.
