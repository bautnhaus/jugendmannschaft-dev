# E05 PROD Paket 6 – Atomarer Widerruf einer Spieltagsausnahme

- Stand: 14.11.2026
- Status: Freigabekandidat in `develop`; nicht ausgeführt.
- Zielprojekt: Supabase PROD `qdugtpzgefpswnnqbusd`.
- DEV-Quelle: `docs/E05_SQL_ENTWURF_WIDERRUF_AUSNAHME_MIT_NOMINIERUNGSENTFERNUNG_2026-11-12.sql` (DEV-Ausführung 13.11.2026), SHA `5b5ac4fd8c14be5bc00ff8d4774ad1d1ac9800b0`.
- DEV-Rollback-Referenz: `docs/E05_SQL_ROLLBACK_ENTWURF_WIDERRUF_AUSNAHME_2026-11-12.sql`, SHA `630c6949faa6e45daf9c758364cb11eb86b09a65` (Review-Entwurf, nie ausgeführt).
- Paketfolge: nach PROD Paket 5.
- PROD-Ausführung: nicht erfolgt.

## 1. Fachlicher Umfang

Paket 6 ermöglicht den begründungspflichtigen Widerruf einer bestehenden Spieltagsausnahme über `revoke_suspension_exception(uuid,text)`.

Der Widerruf und eine ggf. erforderliche Entfernung einer dadurch wieder unzulässigen Nominierung erfolgen atomar:
- Spieler-/Sperren-/Ausnahme-/Spieltagszeilen werden in kontrollierter Reihenfolge gesperrt.
- Ein Advisory Lock synchronisiert den Widerruf mit parallelen Nominierungs-INSERTs/UPDATEs.
- Nach dem Widerruf werden die Sperrenziele über Paket 4 neu zugeordnet.
- Nur wenn der Spieler dadurch für genau diesen Spieltag wieder gesperrt ist, wird eine bestehende Nominierung entfernt.
- Die entfernte Nominierung wird vollständig als Snapshot im Audit gespeichert.
- Ein bereits als `played=true` dokumentierter tatsächlicher Einsatz blockiert den gesamten Widerruf. Transaktion, Ausnahmeänderung und Audit werden zurückgerollt.
- Der Widerruf wird als `exception_revoked` auditiert.

## 2. Read-only PROD-Vorprüfung (14.11.2026)

- Pakete 1–5 sind in PROD registriert; Paket 5: `20261114202342 e05_prod_paket_05_matchday_suspension_exception_20261114`.
- `training_suspension_exceptions`, `training_suspensions`, `training_suspension_audit` und `matchday_players` vorhanden.
- PROD-Ausnahmen: 0; Sperren: 0; Audit-Zeilen: 0.
- `revoke_suspension_exception(uuid,text)` fehlt.
- `prevent_suspended_matchday_nomination()` fehlt.
- `matchday_players` besitzt in PROD nur die beiden Trigger `require_active_player_change_matchday` und `require_active_player_insert_matchday`; der DEV-Nominierungsschutz-Trigger ist in PROD noch nicht vorhanden.

## 3. Wichtige PROD-Abweichung gegenüber DEV

Der DEV-SQL-Entwurf setzt voraus, dass `matchday_players_prevent_suspended_nomination` bereits existiert. Das trifft in PROD nach den Paketen 1–5 nicht zu. Paket 6 enthält deshalb PROD-spezifisch zusätzlich die Anlage dieses Triggers, gebunden an die synchronisierte Funktion `prevent_suspended_matchday_nomination()`. Ohne diese Ergänzung würde die Sperre gegen parallele Nominierungen beim Widerruf nicht zuverlässig greifen.

Die PROD-Rollback-Datei ist ebenfalls angepasst: Da die beiden Funktionen und der Trigger vor Paket 6 in PROD nicht existieren, entfernt der Rollback genau diese Paket-6-Objekte, statt DEV-Vorversionen wiederherzustellen.

## 4. Dateien

- Migration: `supabase/migrations/20261114210000_e05_prod_paket_06_atomic_exception_revocation.sql`
- Rollback: `supabase/rollback/20261114210000_e05_prod_paket_06_atomic_exception_revocation_rollback.sql`
- Assertions: `docs/prod-release/test-package-06/assertions.sql`
- Rollback-Assertions: `docs/prod-release/test-package-06/rollback_assertions.sql`
- CI-Workflow: `.github/workflows/e05-prod-package-06-ci.yml`

## 5. Rollback-Grenze

Der guarded Rollback bricht ab, sobald in `training_suspension_audit` ein `exception_revoked`-Eintrag oder ein Audit-Hinweis `nomination_removed=true` vorhanden ist. Entfernte Nominierungen werden durch den Rollback ausdrücklich nicht rekonstruiert. Eine Wiederherstellung wäre eine separate, auditgestützte Operation und ist nicht Teil dieses Pakets.

## 6. Testumfang und Freigabegates

CI muss auf PostgreSQL 17.6:
1. Paket-1–5-Baseline aufbauen.
2. Paket 6 anwenden.
3. Vorhandensein der RPC und des Nominierungstriggers prüfen.
4. SECURITY DEFINER, festen search_path und EXECUTE-ACL prüfen.
5. Advisory-Lock-Synchronisierung und Snapshot-Auditcode prüfen.
6. Guarded Rollback ausführen und prüfen, dass nur Paket-6-Objekte entfernt wurden.

Vor PROD-Ausführung:
- CI-Lauf muss grün sein.
- Freigegebene Migration und Rollback-SHA unmittelbar vor Ausführung abgleichen.
- Paket 5 und erwartete PROD-Objekte erneut read-only prüfen.

Nach PROD-Ausführung:
- Migrationseintrag und Struktur read-only prüfen.
- Praxistests mit isolierten Testdaten: Ausnahme ohne Nominierung widerrufen; Nominierung entfernen und Snapshot auditieren; `played=true` blockiert vollständig; Doppelwiderruf wird abgewiesen; unberechtigte Rolle wird abgewiesen; parallele Nominierung wird nach Widerruf vom Trigger blockiert.
- Keine Testdaten in PROD verwenden; funktionale Tests in DEV bzw. isolierter Testumgebung durchführen.

## 7. Freigabegrenze

Dieses Paket ist zur Prüfung und ausdrücklichen Freigabe vorbereitet. Keine SQL-Ausführung in DEV oder PROD, keine Änderung an `main`. Die Freigabe zur Vorbereitung ist keine Ausführungsfreigabe.
