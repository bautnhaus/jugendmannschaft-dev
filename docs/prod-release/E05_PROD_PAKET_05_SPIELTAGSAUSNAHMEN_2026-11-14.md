# E05 PROD Paket 5 – Spieltagsausnahmen bei Sperren

- Stand: 14.11.2026
- Status: Freigabekandidat vorbereitet auf `develop`; nicht ausgeführt.
- Zielprojekt: Supabase PROD `qdugtpzgefpswnnqbusd`.
- DEV-Quelle: Migrationen `20261108160747 e05_package_05_matchday_suspension_exception` und `20261108161109 e05_package_05_fix_exception_team_snapshot`.
- DEV-Live-Referenz: `grant_suspension_exception(uuid,uuid,text)` wurde am 14.11.2026 read-only aus DEV ausgelesen. Tabellenstruktur, Indizes, Constraints, RLS-Policy und ACL wurden ebenfalls katalogisiert.
- Paketfolge: nach PROD Paket 4; vor Paket 6 (Widerruf).
- Ausführungsstatus: keine SQL-Ausführung in PROD oder DEV im Rahmen dieser Vorbereitung.

## 1. Umfang

Ermöglicht Trainer, Mannschaftsadmins und Superadmins im ausgewählten Mannschaftskontext, für eine offene Sperre eine begründungspflichtige Ausnahme für genau den aktuell zugeordneten, geplanten Spieltag zu erteilen.

Die RPC schreibt einen Snapshot der Mannschaft, des Spielers, des Spieltags und des handelnden Kontos, protokolliert `exception_granted` in `training_suspension_audit` und stößt die Neuzuordnung der offenen Sperren über die Paket-4-Funktion `e05_assign_player_suspensions` an.

Paket 5 enthält nicht den Widerruf. Dieser bleibt Paket 6.

## 2. PROD-Vorprüfung (read-only, 14.11.2026)

- Pakete 1–4 in PROD-Migrationshistorie registriert.
- `training_suspensions` und `training_suspension_audit` vorhanden.
- `training_suspension_exceptions` fehlt.
- `grant_suspension_exception(uuid,uuid,text)` fehlt.
- Paket-4-Zuordnungsfunktion vorhanden.
- Sperrenbestand: 0; Sperren-Auditbestand: 0.
- Somit ist das Paket-5-Zielobjekt in PROD noch nicht vorhanden; die Migration enthält zusätzliche Guards gegen bereits vorhandene/teilweise installierte Objekte.

## 3. Enthaltene Dateien

- Migration: `supabase/migrations/20261114193000_e05_prod_paket_05_matchday_suspension_exception.sql`
- Rollback: `supabase/rollback/20261114193000_e05_prod_paket_05_matchday_suspension_exception_rollback.sql`
- Nachkontrolle: `docs/prod-release/E05_PROD_PAKET_05_SPIELTAGSAUSNAHMEN_TESTQUERIES_2026-11-14.sql`

Die Migration konsolidiert den finalen DEV-Live-Stand der beiden registrierten DEV-Migrationen in eine einzelne PROD-Migration. Sie erstellt die Ausnahmentabelle, Constraints, Indizes, SELECT-RLS-Policy und die SECURITY DEFINER-RPC. Direkte Client-Schreibrechte auf der Tabelle werden nicht vergeben; EXECUTE auf der RPC erhält ausschließlich `authenticated`.

## 4. Sicherheits- und Datenwirkung

- Kein Update/Löschen bestehender Sperren, Spieler oder Spieltage durch die Migration.
- Die bestehende RLS-Policy auf `training_suspension_audit` wird gezielt erweitert, damit Audit-Einträge mit `exception_id` für berechtigte Teammitglieder sichtbar sind; andere Policies bleiben unverändert.
- Kein Widerruf und keine automatische Nominierungsentfernung.
- RPC validiert Authentifizierung, Pflichtbegründung, offenen Sperrenstatus, Team-/Saisonzugehörigkeit, aktuellen Sperrspieltag und Status `planned`.
- RPC serialisiert Änderungen über Spieler- und Sperrenzeilensperren.
- Snapshot- und Audit-Einträge entstehen erst bei tatsächlicher Erteilung einer Ausnahme.
- Die Migration selbst legt keine Ausnahmedatensätze an.

## 5. Rollback

Guarded und ohne CASCADE. Bricht ab, wenn Paket 6/Widerrufsobjekte vorhanden sind, Ausnahmen existieren oder Audit-Einträge auf Ausnahmen verweisen. Bei Abbruch keine automatische Datenbereinigung. Rollback nur nach gesonderter Freigabe.

## 6. Test-/Freigabegates

Vor PROD-Ausführung:
1. Backup-/PITR-Wiederherstellungspunkt gemäß Betriebsprozess bestätigen.
2. Migration und Rollback-SHA unmittelbar vor Ausführung mit diesem Freigabestand abgleichen.
3. Paket-1–4-Abhängigkeiten und Objekt-Guards erneut read-only prüfen.

Nach Ausführung:
1. Nachkontroll-SQL ausführen.
2. Tabellenstruktur, RLS, Policy, Indizes, Funktionseigentümer, SECURITY DEFINER, search_path und ACL prüfen.
3. Browser-Praxistest mit Trainerkonto: gültige Ausnahme, fehlende Begründung, fremde Mannschaft, falscher Spieltag, nicht offene Sperre.
4. Browser-Praxistest mit Mannschaftsadmin und Superadmin im ausgewählten Mannschaftskontext.
5. Prüfen, dass Ausnahme-Audit und automatische Neuzuordnung der Sperre korrekt geschrieben werden.

## 7. Freigabegrenze

Dieses Paket ist zur Prüfung und ausdrücklichen Freigabe vorbereitet. Es wurde nicht in Supabase ausgeführt und ist nicht in der PROD-Migrationshistorie registriert. Die Freigabe zur Vorbereitung ist keine Ausführungsfreigabe. PROD und GitHub `main` bleiben unverändert.

## 8. Abweichungshinweis

Die ursprünglichen DEV-Migrationsdateien wurden anhand ihrer registrierten Versionsnummern identifiziert. Die PROD-Migration wurde aus dem aktuell live ausgelesenen DEV-Funktions- und Tabellenschema zusammengestellt, nicht als byte-identische Kopie der ursprünglichen DEV-Dateien. Die Snapshot-Korrektur aus der zweiten DEV-Migration ist im finalen Live-Stand enthalten. Diese Konsolidierung ist im Rahmen der Freigabe bewusst offengelegt.

## 9. Ergänzende Audit-Abweichung gegenüber PROD

Der erneute Schemaabgleich hat eine bislang nicht dokumentierte Paket-4/5-Abweichung sichtbar gemacht: In PROD ist `training_suspension_audit.suspension_id` noch NOT NULL; `exception_id` und `changed_by_snapshot` fehlen. Der DEV-Live-Stand erlaubt genau einen Bezug je Audit-Zeile (Sperre oder Ausnahme). Ohne diese Anpassung würde die Grant-RPC beim Schreiben des Ausnahme-Audits in PROD scheitern. Paket 5 enthält daher die notwendige, eng begrenzte Audit-Schema- und Policy-Erweiterung. Der Rollback stellt die bisherige Policy und NOT-NULL-Eigenschaft wieder her und bricht ab, sobald Ausnahme-Auditdaten existieren.


## 10. Isolierter PostgreSQL-CI-Test – erfolgreich abgeschlossen

Für Paket 5 wurde ein eigener GitHub-Actions-Workflow ergänzt:
- `.github/workflows/e05-prod-package-05-ci.yml`
- `docs/prod-release/test-package-05/assertions.sql`
- `docs/prod-release/test-package-05/rollback_assertions.sql`

Der Workflow baut eine frische PostgreSQL-17.6-Testdatenbank auf, stellt die dokumentierten Paket-1–4-Baselines her, führt die exakte Paket-5-Migration aus, prüft Tabellen/RLS/ACL/RPC/search_path/Indizes/Audit-Linkage und Append-only-Trigger und führt anschließend den guarded Rollback samt Assertions aus.

**Ergebnis:** [GitHub Actions Run 43635963976](https://github.com/bautnhaus/jugendmannschaft/actions/runs/43635963976), Commit `c899805befdcd5e6e5d4affc68f052ba47bdf969`, Status `success`. Alle Schritte erfolgreich: PostgreSQL 17.6 bereitgestellt, Paket-1–3-Baseline aufgebaut, Paket 4 angewendet und geprüft, Paket-5-Migration exakt ausgeführt, Struktur/RLS/ACL/RPC/search_path/Indizes/Audit-Linkage geprüft, guarded Rollback ausgeführt und Rollback-Assertions bestanden.

**Fehlerkorrektur:** Der erste echte Testlauf zeigte einen Fehler in der Testhülle: Die zweite negative Audit-Prüfung erwartete eine Foreign-Key-Verletzung, tatsächlich greift die `training_suspension_audit_one_subject_check`-Constraint früher. Der Test wurde auf `check_violation` korrigiert und in einem neuen vollständigen Lauf erneut ausgeführt. Die Migration selbst war in beiden Läufen erfolgreich.

**Testgrenze:** Der CI-Lauf prüft Schema, Berechtigungen, Audit-Constraints und den Rollback auf einer isolierten leeren PostgreSQL-17.6-Basis. Er ersetzt nicht den späteren DEV-/PROD-Praxistest der Grant-RPC mit realen Teammitgliedern, offenen Sperren und geplanten Spieltagen. Paket 5 ist damit technisch für die ausdrückliche PROD-Freigabe vorbereitet; noch nicht in PROD ausgeführt.
