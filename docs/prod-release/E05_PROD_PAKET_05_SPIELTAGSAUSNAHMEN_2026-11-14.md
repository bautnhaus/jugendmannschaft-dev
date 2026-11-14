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
- Keine bestehenden RLS-Policies auf anderen Tabellen werden geändert.
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
