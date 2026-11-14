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


## 8. Isolierter PostgreSQL-CI-Test

- Workflow: `.github/workflows/e05-prod-package-06-ci.yml`
- Lauf: [GitHub Actions 43638965684](https://github.com/bautnhaus/jugendmannschaft/actions/runs/43638965684)
- Commit: `0c6eba7b873e424de2b56ae887eb0550b8342691`
- PostgreSQL: 17.6
- Ergebnis: `success`

Erfolgreich ausgeführt:
1. Paket-1–3-Baseline.
2. Paket-4-Baseline und Paket 5.
3. Matchday-Players-Testfixture.
4. Paket-6-Migration.
5. Assertions für RPC, Advisory-Lock, Nominierungstrigger und ACL.
6. Guarded Paket-6-Rollback.
7. Rollback-Assertions.

Während der Vorbereitung wurden zwei reale Abweichungen der isolierten Testbasis korrigiert: Die PROD-Baseline enthält nach Paket 5 noch keine `matchday_players`-Tabelle in der CI-Fixture und Paket 6 muss den fehlenden Nominierungsschutz-Trigger in PROD selbst anlegen. Der finale Lauf enthält die angepasste Fixture und bestand.

**Testgrenze:** Der CI-Lauf prüft Migration, Funktionstext/ACL, Triggerinstallation und Rollback auf PostgreSQL 17.6. Er führt keine authentifizierten End-to-End-Widerrufe mit echten Rollen-/Spieler-/Spieltagdaten und keinen echten parallelen Transaktionen durch. Diese fachlichen Tests bleiben vor einem späteren Frontend-Rollout in DEV zu absolvieren.

## 9. Freigabestatus

Paket 6 ist nach erfolgreichem isoliertem CI-Lauf zur ausdrücklichen PROD-Ausführungsfreigabe vorbereitet. Es wurde weder in DEV noch PROD ausgeführt. GitHub `main` bleibt unverändert.
 

## 10. PROD-Ausführung und Nachkontrolle – 14.11.2026

- **Freigabe:** ausdrücklich erteilt durch den Nutzer am 14.11.2026.
- **Projekt:** Supabase PROD `qdugtpzgefpswnnqbusd`, Region `eu-west-1`, PostgreSQL `17.6.1.166`.
- **Migrationseintrag:** `20261114211343 e05_prod_paket_06_atomic_exception_revocation_20261114`.
- **Ausführung:** erfolgreich über Supabase Migration API; keine Fehler zurückgegeben.
- **Ausgeführte Quelle:** vorbereitete Paket-6-Migration aus `develop`, Git-Blob-SHA vor Ausführung `1f7eac877c6edbc5873617e4118c4721cb1f2bc6`.
- **Nachkontrolle:** Migration ist in der PROD-Migrationshistorie registriert.
- `revoke_suspension_exception(uuid,text)`: vorhanden, Eigentümer `postgres`, SECURITY DEFINER, fester `search_path=pg_catalog, public, auth`; EXECUTE für `authenticated`, nicht für `anon` oder `service_role`.
- `prevent_suspended_matchday_nomination()`: vorhanden, SECURITY INVOKER, fester `search_path=pg_catalog, public`.
- Trigger `matchday_players_prevent_suspended_nomination`: vorhanden als BEFORE INSERT OR UPDATE OF matchday_id, player_id. Die beiden vorher bestehenden Aktivspieler-Trigger sind weiterhin vorhanden.
- Produktivdaten nach Ausführung: 0 Ausnahmen, 0 Sperren, 0 Audit-Zeilen, 0 Widerrufs-Audit-Zeilen. Keine Produktivdatensätze wurden durch die Migration verändert.
- **Rollback:** nicht ausgeführt.
- **DEV:** unverändert.
- **GitHub main / Frontend:** unverändert; kein Index-Deploy.

### Abgrenzung der Prüfung

Die Struktur-, Trigger-, Funktions- und ACL-Nachkontrolle ist erfolgreich. Es wurden bewusst keine künstlichen Widerrufe oder Testdatensätze in PROD angelegt. Damit sind authentifizierte Rollen-End-to-End-Tests, der reale Nominierungsentfernungsfall und ein echter Paralleltransaktionstest nicht in PROD durchgeführt. Diese Tests sind vor dem Frontend-Rollout in DEV bzw. einer isolierten Testumgebung auszuführen.

Der Security Advisor meldet weiterhin allgemeine, bereits vorhandene Hinweise im Projekt (u. a. zahlreiche SECURITY DEFINER-RPCs sowie mutable search_path bei `public.set_updated_at`). Die Ausgabe ist projektweit und belegt nicht, dass diese Hinweise durch Paket 6 verursacht wurden. Keine pauschale Berechtigungsänderung im Rahmen dieses Pakets vorgenommen.

### Technische Ausführungsnotiz zur SQL-Identität

Die über Supabase `apply_migration` übermittelte SQL-Fassung wurde aus der freigegebenen GitHub-Migration mit derselben DDL und Funktionslogik zusammengestellt; Kommentare und Formatierung wurden dabei teilweise gekürzt. Der Blob-SHA `1f7eac877c6edbc5873617e4118c4721cb1f2bc6` bezeichnet daher die geprüfte GitHub-Basisdatei, nicht einen byte-identischen Hash des an die API übermittelten SQL-Strings. Die nach Ausführung aus PROD ausgelesenen Funktionsdefinitionen, ACLs und Trigger bestätigen die beabsichtigten Objekte und Eigenschaften.
