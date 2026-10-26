# AP03 – Bestandsaufnahme Rollen, Berechtigungen und Sicherheitsprüfpunkte

**Stand:** 26.10.2026  
**Umgebung:** ausschließlich DEV – Supabase-Projekt `pzazqvvoruqnqhcorbwx`  
**Dokumentationsbranch:** `feature/ap03-roles-permissions-inventory`  
**Zweck:** vorhandene Ergebnisse zusammenführen und aktuelle Lücken gezielt bestimmen  
**Änderungsumfang dieser Bestandsaufnahme:** nur Dokumentation und read-only Prüfungen; keine Datenbankänderung, kein Deployment, keine PROD-Änderung.

## 1. Ergebnis in Kürze

**Wir beginnen nicht bei null.** Als bestehende Grundlagen wurden wiederverwendet:

- [AP02-Testprotokoll vom 26.10.2026](AP02_TESTPROTOKOLL_2026-10-26.md)
- [AP02 P0 DEV-Testmatrix](AP02_P0_DEV_TEST_MATRIX.md)
- [AP02 P0 Execution Readiness](AP02_P0_EXECUTION_READINESS.md)
- [AP02 P0 Validierungsbericht](AP02_P0_VALIDATION_REPORT.md)
- [Zentraler Projektkontext](../PROJECT_CONTEXT_updated.md)
- [DEV-Datenbank-Changelog](../DB_CHANGELOG_DEV_updated.md)

Die älteren Dokumente vom 24.10.2026 sind wertvolle historische Prüfbelege. Einige Aussagen darin sind inzwischen überholt: Das aktuelle Supabase-Migrationsprotokoll weist die Teamrollen-Migration vom 25.10.2026 sowie die Vereins-Sicherheits- und Mitgliederverwaltungs-Migrationen vom 25./26.10.2026 als ausgeführt aus. Deshalb werden historische Befunde nicht ungeprüft als heutiger Zustand übernommen.

**AP02-Status:** Für den aktuellen DEV-Umfang dokumentarisch abgeschlossen, mit offenen manuellen Integrationstests. Keine PROD-Freigabe. PR #2 bleibt Draft/unmerged.

## 2. Geprüfte Quellen und Grenzen

### Aktuell read-only geprüft am 26.10.2026

- Supabase-Tabellen, Spalten, Schlüssel, Fremdschlüssel und RLS-Aktivierung im Schema `public`
- Supabase-Migrationsprotokoll
- aktuelle RLS-Policies aus `pg_policies`
- ausgewählte Funktionssignaturen, `SECURITY DEFINER`, Suchpfad und EXECUTE-Rechte
- Supabase Security Advisors
- vorhandene AP02-Dokumente und Projektkontext im GitHub-Branch

### Nicht durch diese Bestandsaufnahme bewiesen

- vollständige Penetrations- oder Sicherheitstests
- negative UI-/RPC-Integrationstests für jede Rolle
- Fremdvereinszugriff mit einem zweiten Testverein
- tatsächliche Kontolöschung/Anonymisierung
- sämtliche möglichen Aufrufpfade der Edge Function `invite-trainer`
- PROD-Schema und PROD-Berechtigungen

Die Bestandsaufnahme ist daher ein konsolidierter Prüfstand, keine Sicherheitszertifizierung.

## 3. Aktueller DEV-Daten- und Rollenstand

Read-only Schema- und Bestandsabfrage:

- Vereine: 1 – `AP02 – Testverein DEV`
- Mannschaften: 1 – `Jugendmannschaft DEV`
- Spieler: 22
- `team_members`: 2 Mitgliedschaftszeilen
- `team_member_roles`: 3 Rollen-Zeilen
- `club_members`: 3 Vereinsmitgliedschaften
- `club_member_roles`: 1 Vereinsadmin-Rollenzeile
- `global_user_roles`: 1 Superadmin-Rollenzeile
- `team_role_change_log`: 14 Protokolleinträge

Die drei Teamrollen-Zeilen bei zwei Teammitgliedschaften zeigen, dass mindestens ein Teammitglied mehr als eine Teamrolle hat. Die Ein-Rollen-Annahme aus den historischen Dokumenten ist damit nicht mehr der aktuelle Zustand.

Eine gezielte Paritätsabfrage fand keine fehlende Teammitgliedschaft für die geprüften Rollenpaare und keine Legacy-Rolle ohne passende Rolle in `team_member_roles`. Das ist ein begrenzter Konsistenzbefund, kein vollständiger Integritätsbeweis für alle denkbaren Zustände.

### Aktuelle Produktentscheidung

- Ein Nutzer gehört höchstens einem Verein an.
- `club_members.user_id` ist Primärschlüssel; `club_member_roles` speichert `user_id` und `role`, nicht `club_id`.
- Mehrfachmitgliedschaften sind ausdrücklich nicht Teil des aktuellen Umfangs.
- Globaler Superadmin, Vereinsadmin und Mannschaftsrollen sind unterschiedliche Berechtigungskontexte.
- Globaler Superadmin soll beim Einstieg keinen Verein automatisch auswählen.

## 4. Bereits vorhandene Schutzmaßnahmen – aktueller Befund

### 4.1 Teamrollen

- `team_member_roles` ist im aktuellen DEV vorhanden und enthält die Rollen `admin` und `trainer`.
- Die Legacy-Tabelle `team_members` besteht weiter als Mitgliedschafts-/Metadatensatz.
- `player_positions` hat aktuell nur eine SELECT-Policy für Teammitglieder sowie INSERT/DELETE-Policies, die Team-Admin-Rechte verlangen und beim INSERT die Teamzugehörigkeit von Spieler und Position vergleichen. Die zuvor dokumentierte permissive Mitgliedschafts-Schreibpolicy ist im aktuellen DEV nicht vorhanden.
- EXECUTE auf die alten Funktionen `add_team_member_by_email`, `get_team_trainers` und `delete_my_account()` ist für `authenticated` aktuell entzogen.
- `admin_add_team_role`, `admin_remove_team_role` und `get_team_trainers_v2` sind für authentifizierte Nutzer aufrufbar; ihre serverseitigen Berechtigungsprüfungen und tatsächlichen Aufrufpfade bleiben zu testen.
- Die Funktion `prevent_last_team_admin_removal()` ist als Triggerfunktion vorhanden; direkte EXECUTE-Berechtigung für `authenticated` ist entzogen.

### 4.2 Vereinsrollen

- Vereinsmitglieder, Vereinsrollen und globale Superadmin-Rollen sind im aktuellen Schema vorhanden.
- Vereinsverwaltungs-RPCs sind für `authenticated` ausführbar und als `SECURITY DEFINER` markiert. Die vorgesehenen internen Rollenprüfungen wurden in AP02 code-geprüft; der tatsächliche negative Integrationstest ist nicht für alle Fälle abgeschlossen.
- `club_members` und `club_member_roles` haben RLS aktiviert. Die gelisteten SELECT-Policies beschränken die Einsicht auf die eigene Mitgliedschaft, Vereinsadmins bzw. Superadmins gemäß jeweiliger Policy.
- Der Schutz vor Entfernen/Herabstufen des letzten Vereinsadmins ist im Funktionscode vorgesehen, aber im AP02-Testprotokoll nicht praktisch durch UI/RPC-Integration nachgewiesen.

## 5. Aktuelle Prüfpunkte aus der RLS-Übersicht

Die folgenden Punkte sind **Prüf- bzw. fachliche Klärungspunkte**, nicht automatisch bestätigte ausnutzbare Sicherheitslücken.

### P1 – Rollen- und Schreibrechte fachlich abgleichen

Aktuelle Policies erlauben Teammitgliedern (nicht nur Admins) unter anderem Schreiboperationen bei `players`, `trainings`, `training_series`, `matchdays`, `attendance`, `matchday_players`, `training_responses` und teils zugehörigen Tabellen.

Nächster Schritt: mit der beabsichtigten Rollenmatrix abgleichen. Besonders zu entscheiden ist, welche Aktionen Trainer ausführen dürfen und welche ausschließlich Teamadmins vorbehalten bleiben sollen. Nicht pauschal auf Admin-only umstellen, bevor die Produktregeln feststehen.

### P1 – Trainerteilnahme-Policies

Die Policies für `training_trainers` und `matchday_trainers` prüfen in ihrer aktuellen Bedingung, ob der aufrufende Nutzer Teammitglied ist. Die Bedingung bindet nicht erkennbar die zu bearbeitende Zeile an `auth.uid()`. Prüfen, ob jedes Teammitglied absichtlich die Teilnahmezuordnung anderer Trainer ändern darf. Positiv- und Negativtests erforderlich.

### P1 – Matchday-Anwesenheit: DELETE-Konsistenz

Die INSERT-/UPDATE-Policies von `matchday_attendance` prüfen, ob Spieler und Spieltag zum selben Team gehören. Die DELETE-Policy prüft dagegen nur die Mitgliedschaft im Team des Spieltags. Prüfen, ob eine zusätzliche Spieler-Team-Konsistenzprüfung beim Löschen erforderlich ist.

### P1 – Security-Definer-Funktionen und minimale Rechte

Der Supabase Security Advisor meldet 20 für `authenticated` ausführbare `SECURITY DEFINER`-Funktionen. Dieser Advisor-Befund ist ein Prüfhinweis, nicht automatisch ein Fehler: Einige RPCs müssen für angemeldete Nutzer erreichbar sein. Für jede Funktion sind Zweck, interne Autorisierung, benötigte Aufrufer und EXECUTE-Rechte einzeln zu inventarisieren. Keine pauschale Rechteentziehung ohne Abhängigkeitsprüfung.

### P2 – Technische Härtung

- `public.set_updated_at()` hat laut Advisor einen veränderlichen `search_path`; festen Suchpfad und Triggerabhängigkeiten prüfen.
- Supabase Auth meldet, dass der Schutz gegen kompromittierte/geleakte Passwörter deaktiviert ist. Entscheidung und mögliche Aktivierung separat planen.
- Die alte Funktion `delete_my_account()` ist aktuell nicht für `authenticated` ausführbar. Kontolöschung und Anonymisierung sind separat fachlich/technisch neu zu entwerfen; keine Reaktivierung ohne vollständige Behandlung von Teamrollen, Vereinsmitgliedschaften, Historie und letztem Admin.

## 6. AP02-Tests, die weiterhin offen sind

Diese Punkte bleiben aus dem AP02-Testprotokoll übernommen und werden nicht als bestanden gewertet:

- **AP02-T08:** Zugriff eines Vereinsadmins auf einen fremden Verein – mit nur einem DEV-Verein nicht sicher praktisch testbar.
- **AP02-T09:** letzter Vereinsadmin herabstufen/entfernen – Code-Schutz geprüft, Integrationstest nicht durchgeführt.
- **AP02-T10:** erfolgreiches Entfernen eines Mitglieds ohne Mannschaftsrollen – kein ausdrücklich entbehrliches Testkonto vorhanden.

Keine bestehenden Mitglieder zu Testzwecken entfernen und keine Schutzregeln per Direktänderung umgehen.

## 7. Wiederverwendungsregister

| Vorhandene Quelle | Wiederverwendbare Erkenntnisse | Umgang in AP03 |
|---|---|---|
| AP02-Testprotokoll 26.10.2026 | Manuelle Testergebnisse T01–T07, offene T08–T10, Ein-Verein-pro-Nutzer-Regel | Maßgebliche Quelle für AP02-UI-Tests und Einschränkungen |
| AP02 P0 Testmatrix | Gewünschte Rollen-, Last-Admin-, RLS- und Regressionstests | Als Testkatalog wiederverwenden; Status je Test neu bestätigen |
| AP02 P0 Execution Readiness | Ursprüngliche Architekturprobleme im Ein-Rollen-Modell und Cutover-Anforderungen | Historische Ausgangslage, nicht als aktueller Zustand behandeln |
| AP02 P0 Validierungsbericht | SQL-/CI-Testbelege, damalige Blocker und koordinierte Cutover-Risiken | Historisch; mit aktuellem Migrationsprotokoll abgleichen |
| PROJECT_CONTEXT_updated.md | frühere RLS-/RPC-/Kontolöschungsbefunde und offene Fachentscheidungen | Grundlage für gezielte Lückenprüfung |
| DB_CHANGELOG_DEV_updated.md | dokumentierte DB-Änderungen | Mit tatsächlichem DEV-Migrationsprotokoll abgleichen |

## 8. Empfohlene nächste Arbeitsschritte für AP03

1. Eine konkrete Rollen-/Berechtigungsmatrix für Global Superadmin, Vereinsadmin, Teamadmin und Trainer erstellen – jede Aktion mit Lesen/Erstellen/Ändern/Löschen.
2. Die Matrix mit den aktuellen RLS-Policies und RPCs abgleichen. Zuerst die fachlichen Entscheidungen zu Schreibrechten klären; keine pauschalen Policy-Änderungen.
3. Die markierten P1-Punkte prüfen: Trainerteilnahme, Matchday-Anwesenheit-DELETE, Schreibrechte auf Trainings/Spieltage/Spieler und direkte RPC-Aufrufe.
4. Pro Funktion EXECUTE-Rechte, `SECURITY DEFINER`, `search_path`, interne Autorisierung und tatsächliche Aufrufer dokumentieren.
5. Einen sicheren Testaufbau für T08–T10 planen, ohne bestehende Konten oder Vereinsdaten zu gefährden.
6. Danach gezielte DEV-Änderungen mit positiven, negativen und Regressionstests planen. PROD bleibt bis zu einer separaten Prüfung und ausdrücklichen Freigabe unverändert.

## 9. Schutzregeln für die weitere Arbeit

- Keine Datenbankänderungen im Rahmen dieser Bestandsaufnahme.
- Keine Änderung an PROD.
- Keine PR-Merges ohne ausdrückliche Freigabe.
- Historische Befunde als historisch kennzeichnen; nur aktuelle Read-only-Prüfungen als aktuellen Befund bezeichnen.
- Keine pauschale Rechteentziehung für `SECURITY DEFINER`-Funktionen.
- Keine Testlöschung bestehender Nutzer/Mitglieder.
