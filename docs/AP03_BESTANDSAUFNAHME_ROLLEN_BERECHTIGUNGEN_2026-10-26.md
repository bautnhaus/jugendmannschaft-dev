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


## 10. Vorläufige Ist-Matrix der Mannschaftsrechte

Diese Tabelle beschreibt den aktuell ausgelesenen RLS-Stand, **nicht** automatisch die gewünschte fachliche Soll-Berechtigung.

| Datenbereich / Aktion | Aktuell laut RLS | Einordnung / noch zu klären |
|---|---|---|
| Spieler lesen | Teammitglied | Bestätigt als aktueller Ist-Stand |
| Spieler erstellen / ändern | Teammitglied | Fachlich klären: Soll ein Trainer Spielerstammdaten ändern dürfen? |
| Spieler löschen | Teamadmin | Aktuell Admin-only |
| Positionen lesen | Teammitglied | Aktuell erlaubt |
| Positionen erstellen / ändern / löschen | Teamadmin | Aktuell Admin-only; INSERT prüft Spieler-/Positions-Teamzugehörigkeit |
| Trainings lesen / erstellen / ändern / löschen | Teammitglied | Fachlich klären, ob Trainer alle Trainingsaktionen ausführen dürfen |
| Trainingsserien lesen / erstellen / ändern / löschen | Teammitglied | Fachlich klären; Lösch- und Serienfolgen berücksichtigen |
| Anwesenheit Training | Teammitglied; INSERT/UPDATE/DELETE prüfen Trainings-/Spielerbezug | Aktueller Ist-Stand; Regressionstests erforderlich |
| Trainingsrückmeldungen | Teammitglied; Zuordnung wird bei INSERT/UPDATE geprüft | Prüfen, ob Trainer beliebige Rückmeldungen ändern dürfen oder ob ein engerer Ablauf vorgesehen ist |
| Spieltage lesen / erstellen / ändern / löschen | Teammitglied | Fachlich klären, ob Trainer alle Aktionen ausführen dürfen |
| Spieltagskader `matchday_players` | Teammitglied; Spieler-/Spieltag-Teambezug wird geprüft | Aktuell erlaubt |
| Spieltags-Anwesenheit `matchday_attendance` | Lesen/Schreiben Teammitglied; INSERT/UPDATE prüfen Spieler-Teambezug, DELETE prüft nur Teammitgliedschaft am Spieltag | Konsistenz beim DELETE gezielt prüfen |
| Trainerteilnahme Training/Spieltag | Mitgliedschaft des Aufrufers wird geprüft | Prüfen, ob ein Trainer Teilnahmezeilen anderer Trainer bearbeiten dürfen soll |
| Team-Mitgliedschaften `team_members` | Lesen Teammitglied; Hinzufügen/Ändern/Entfernen Teamadmin | Rollenänderungen nicht direkt über die Legacy-Rollenspalte verwalten |
| Teamrollen `team_member_roles` | Lesen eigene Rollen oder durch Teamadmin; Änderung über abgesicherte RPCs | Last-Admin-Schutz und negative RPC-Tests weiter nachweisen |
| Saisonverwaltung | Lesen Teammitglied; Schreiben Teamadmin | Aktuell Admin-only für Änderungen |
| Vereinsmitglieder / Vereinsrollen | eigene Mitgliedschaft, Vereinsadmin oder Superadmin gemäß Policy/RPC | Cross-club- und Last-admin-Tests AP02-T08/T09 offen |
| Teamrollen-Auditlog | Lesen Teamadmin | Schreibpfad erfolgt über Trigger/RPC; direkte Rechte weiter minimieren |
| Profil | Nutzer kann eigenes Profil ändern; Teamadmins können Profile im Teamkontext lesen | Vereinsadmin-Sicht auf Profile/E-Mail gesondert prüfen, falls benötigt |

## 11. Fachliche Entscheidungen, die vor Policy-Änderungen gebraucht werden

Damit wir keine funktionierenden Trainerabläufe versehentlich einschränken und auch keine zu weit gefassten Rechte ungeprüft lassen, sind diese Entscheidungen vor dem Umsetzen der Soll-Matrix zu treffen:

1. **Spielerstammdaten:** Dürfen Trainer Spieler anlegen und bearbeiten oder nur Teamadmins?
2. **Training und Trainingsserien:** Dürfen Trainer Trainings/Serien anlegen, ändern, absagen und löschen? Sind einzelne Aktionen Admin-only?
3. **Spieltage und Kader:** Dürfen Trainer Spieltage anlegen, ändern und löschen sowie Kader/Anwesenheit bearbeiten?
4. **Trainerteilnahme:** Darf jedes Teammitglied die Teilnahme anderer Trainer pflegen, oder darf ein Trainer nur die eigene Teilnahme ändern?
5. **Rückmeldungen:** Dürfen Trainer beliebige Rückmeldungen ändern, oder soll die Antwort später aus einem eigenen Spieler-/Elternkonto kommen?
6. **Vereinskontext:** Welche Vereinsdaten und E-Mail-Adressen soll ein Vereinsadmin sehen dürfen, und welche Aktionen bleiben Superadmins vorbehalten?

Bis diese Fragen fachlich geklärt sind, wird keine breite Änderung an RLS-Policies vorgenommen. Sicherheitsrelevante Inkonsistenzen wie die DELETE-Teamkonsistenz bei `matchday_attendance` und die Trainerteilnahme-Policies werden unabhängig davon gezielt technisch untersucht.


## 12. Frontend-Abgleich – tatsächlicher DEV-Branch

**Geprüfte Frontenddatei:** `index.html` im Branch `feature/ap02-club-frontend-dev`  
**Git-Blob SHA:** `64190e8dd269b61948707dc2f3d1b89fefabb8ed`  
**Geprüfte Datenbank:** Supabase DEV, read-only  
**Wichtig:** Dieser Abschnitt beschreibt den geprüften Branch-Stand. Es wurde keine Datei geändert oder deployed.

### 12.1 Vereinsverwaltung: Frontend-RPCs passen grundsätzlich zur DB

Frontend-Aufrufe:
- `get_club_members_v2(p_club_id)`
- `get_club_players(p_club_id)`
- `admin_add_club_member_by_email(p_club_id,p_email,p_role)`
- `admin_set_club_member_role(p_club_id,p_user_id,p_role)`
- `admin_remove_club_member(p_club_id,p_user_id)`

Der UI-Zugriff wird über `canManageClub` und `currentClubId` begrenzt. Die RPCs prüfen serverseitig ebenfalls `is_club_admin(p_club_id)), setzen feste Suchpfade und validieren Rolle/Mitgliedschaft. Das ist eine sinnvolle doppelte Grenze: UI-Steuerung für die Bedienung und Datenbankprüfung für Sicherheit.

**Verbleibende Grenzen:** Die negativen Tests für fremde Vereins-ID und letzten Vereinsadmin bleiben gemäß AP02-T08/T09 offen. Ein Superadmin kann laut Funktion als Vereinsadmin autorisiert werden; das entspricht dem dokumentierten Plattformmodell.

### 12.2 Teamrollen: RPCs mit Serverprüfung; UI-Last-Admin-Schutz ist nur Zusatz

Frontend verwendet `get_team_trainers_v2`, `admin_add_team_role` und `admin_remove_team_role`. Die Teamrollenliste wird nur im Admin-Zweig geladen. Die UI verhindert außerdem, dass der aktuell angemeldete Nutzer über `removeTrainer` selbst entfernt wird, und prüft den letzten Admin lokal.

Die Datenbank prüft zusätzlich:
- aufrufender Nutzer ist Teamadmin,
- Rolle ist `admin` oder `trainer`,
- Zielkonto existiert,
- letzter Teamadmin kann nicht entfernt werden.

Damit ist der Schutz nicht allein von der Oberfläche abhängig.

**P1 – Invariantenprüfung offen:** `admin_add_team_role` prüft aktuell nicht ausdrücklich, ob das Zielkonto bereits Mitglied des Vereins ist, dem die Mannschaft zugeordnet ist. Die aktuelle DEV-Datenprüfung fand keine Teamrolle ohne passende Vereinsmitgliedschaft. Das ist deshalb derzeit kein nachgewiesener Datenfehler, aber eine mögliche Lücke im serverseitig erzwungenen Ein-Verein-pro-Nutzer-Modell. Vor einer Änderung muss der Einladungspfad `invite-trainer` vollständig geprüft werden, da er Rollen/Mitgliedschaften orchestrieren kann.

### 12.3 Kritischer Befund: Trainer-Anwesenheit kann für andere Trainer geschrieben werden

Frontend schreibt direkt über Supabase:
- `training_trainers.upsert({training_id,user_id,present})`
- `matchday_trainers.upsert({matchday_id,user_id,present})`

Die aktuellen RLS-Policies für INSERT/UPDATE/DELETE prüfen, dass der **aufrufende Nutzer** Mitglied der betroffenen Mannschaft ist. Die Bedingungen binden die Zeile jedoch nicht an `auth.uid()` als Ziel-`user_id`. Daher können grundsätzlich auch andere Trainerzeilen derselben Mannschaft verändert werden, sofern die Policy-Bedingung greift.

Das Frontend zeigt diese Steuerung in den Traineranwesenheitslisten; es gibt in diesen Funktionen keine zusätzliche Adminprüfung. Ob dies fachlich gewollt ist, muss entschieden werden. Wenn Trainer ausschließlich ihre eigene Teilnahme pflegen sollen, müssen Policy und UI entsprechend enger gefasst werden. Wenn Teammitglieder bewusst alle Traineranwesenheiten pflegen dürfen, sollte dies ausdrücklich als Produktregel dokumentiert und negativ getestet werden.

**Status:** konkreter Ist-Befund aus Frontend und RLS; kein produktiver Angriffstest durchgeführt.

### 12.4 Kritischer Befund: Frontend-Admin-Guards ersetzen keine DB-Berechtigung

Die Hilfsfunktion `adminGuard()` prüft lediglich den lokalen Frontendwert `role==='admin'`. `memberGuard()` prüft nur, ob Nutzer und Team gesetzt sind. Diese Guards verbessern die Bedienung, sind aber kein Sicherheitsmechanismus gegen direkte REST-/RPC-Aufrufe.

Im Frontend werden viele Tabellen direkt angesprochen, darunter:
- `players`, `positions`, `player_positions`
- `trainings`, `training_series`, `training_players`, `training_trainers`, `training_responses`, `attendance`
- `matchdays`, `matchday_players`, `matchday_trainers`, `matchday_attendance`
- `matchday_recommendation_runs` und zugehörige Spielerzeilen

Die RLS-Policies erlauben Teammitgliedern bei mehreren dieser Tabellen Schreiboperationen, einschließlich INSERT/UPDATE/DELETE, unabhängig davon, ob die Oberfläche eine Aktion nur Admins zeigt. Das ist kein automatischer Beweis für einen Fehler, aber ein wesentlicher Rollenabgleich: Die DB muss genau die fachlich gewünschte Grenze erzwingen, weil ein Nutzer die Frontend-Guards umgehen kann.

Besonders zu prüfen sind:
1. Trainings und Trainingsserien: RLS erlaubt aktuell Teammitgliedern grundlegende Schreiboperationen; die UI verwendet an einigen Stellen `adminGuard()`, an anderen direkte Schreibzugriffe.
2. Spieltage: aktuelle RLS-Policies erlauben Teammitgliedern INSERT/UPDATE/DELETE; die UI zeigt einzelne Aktionen rollenabhängig.
3. Spieler: INSERT/UPDATE ist laut RLS Teammitgliedern erlaubt, DELETE nur Teamadmins; die UI schützt das Entfernen aus dem aktiven Kader zusätzlich mit `adminGuard()`.
4. Backup-Import: UI verlangt `adminGuard()`, führt danach aber zahlreiche direkte Tabellenoperationen aus. Die Berechtigung muss auf DB-Ebene denselben Umfang abdecken, falls ein Trainer den REST-Aufruf direkt versucht.

**Empfehlung:** Vor Änderungen eine konkrete Sollmatrix festlegen und jede Tabellenoperation mit dieser Matrix vergleichen. Keine pauschale Verschärfung, die bisher erlaubte Trainerabläufe unabsichtlich zerstört.

### 12.5 Matchday-Anwesenheit: DELETE-Policy ist breiter als INSERT/UPDATE

Das Frontend liest und schreibt `matchday_attendance` direkt. INSERT und UPDATE prüfen Spieler-Team-Konsistenz; DELETE prüft aktuell nur die Teammitgliedschaft über den Spieltag. Die UI löscht einzelne Anwesenheitszeilen nicht im normalen Ablauf, aber Backup-/Restore- und andere Datenoperationen können DELETE nutzen.

**Status:** technische Inkonsistenz bestätigt; konkrete Auswirkung hängt vom erreichbaren API-Aufruf und den Fremdschlüsselbeziehungen ab. Gezielt mit einem negativen RLS-Test prüfen und danach ggf. Policy angleichen.

### 12.6 Vereinsmitglieder- und Teamrollen-Frontend: keine direkten Rollenänderungen per Tabellenzugriff gefunden

Die geprüften UI-Aktionen für Vereinsrollen und Teamrollen verwenden die oben genannten RPCs. Die Frontenddatei liest `team_member_roles` direkt zur Ermittlung eigener Rollen, nimmt aber die eigentlichen Rollenänderungen über die RPCs vor. Das ist der richtige Grundansatz. Die RLS-Policy von `team_member_roles` erlaubt SELECT für eigene Rollen oder Teamadmins; direkte Schreib-Policies sind in der aktuellen Policy-Liste nicht vorhanden.

### 12.7 Zusammenfassung des Frontend-Abgleichs

| Bereich | Ergebnis | Nächster Schritt |
|---|---|---|
| Vereinsverwaltung-RPCs | UI und DB-Prüfung stimmen im Grundsatz überein | T08/T09 mit sicherem Testaufbau nachholen |
| Teamrollen-RPCs | Serverseitige Autorisierung und letzter Teamadmin-Schutz vorhanden | Zielmitgliedschaft im Verein prüfen; Einladungspfad untersuchen |
| Traineranwesenheit | Policies prüfen Mitgliedschaft des Aufrufers, nicht dessen Ziel-`user_id` | Fachliche Regel festlegen; bei Bedarf RLS/UI enger fassen |
| Trainings/Serien/Spieltage | UI-Guards und DB-Schreibrechte sind nicht durchgängig deckungsgleich | Sollmatrix vor Änderungen; direkte API-Tests |
| Spieltags-Anwesenheit DELETE | Spieler-Team-Konsistenz fehlt in der DELETE-Policy | gezielter negativer Test, dann ggf. korrigieren |
| Backup/Restore | UI-Admin-Guard; viele direkte Tabellenoperationen | Sicherstellen, dass RLS alle Schreibrechte wirklich begrenzt |
| Konto löschen | kein `delete_my_account`-Aufruf in der geprüften `index.html` gefunden | separaten Auth-/Edge-Function-Pfad prüfen |

## 13. Konkrete Reihenfolge für die nächste Prüfphase

1. Fachlich festlegen: Dürfen Trainer Trainings, Serien und Spieltage anlegen, ändern und löschen? Dürfen sie Spieler-Stammdaten ändern? Dürfen sie Anwesenheit anderer Trainer pflegen?
2. Den Edge-Function-Code `invite-trainer` und alle aufgerufenen RPCs prüfen, um sicherzustellen, dass Einladungen Team- und Vereinsmitgliedschaften konsistent herstellen.
3. Nicht-destruktive negative Tests planen: angemeldeter Trainer versucht Admin-Aktion direkt über REST; fremde Trainer-`user_id` in Anwesenheitszeile; Spieler aus anderem Team in Matchday-Anwesenheit; direkte RPC-Aufrufe mit fremder Team-/Vereins-ID.
4. Erst nach bestätigtem Befund und festgelegter Sollmatrix gezielte DEV-Policy-/RPC-Korrekturen als separate Migration umsetzen und testen.
5. Keine Änderung an PROD und kein PR-Merge ohne ausdrückliche Freigabe.


### 12.8 Ergänzender Befund: Einladungsweg stellt keine Vereinsmitgliedschaft sicher

Die geprüfte Edge Function `supabase/functions/invite-trainer/index.ts`:
1. authentifiziert den Aufrufer,
2. prüft über `is_team_admin(p_team_id)` dessen Teamadmin-Rolle,
3. lädt ein vorhandenes Konto oder lädt eine neue E-Mail-Adresse ein,
4. ruft `admin_add_team_role(p_team_id,p_user_id,p_role)` auf.

Die geprüfte RPC `admin_add_team_role` validiert Teamadmin, Rollenwert und Existenz des Auth-Kontos, prüft aber nicht ausdrücklich, ob das Zielkonto Mitglied des Vereins der Mannschaft ist. Sie legt nur `team_members` und `team_member_roles` an, nicht `club_members`.

Die aktuelle DEV-Konsistenzabfrage fand **keine** bestehenden Teamrollen ohne passende Mitgliedschaft im zugeordneten Verein. Das beweist jedoch nicht, dass neue Einladungen diese Invariante einhalten: Im Codepfad ist keine solche Vereinsmitgliedschaftsprüfung erkennbar. Da `invite-trainer` ein neues Konto anlegen und danach direkt eine Teamrolle setzen kann, ist das ein konkreter Prüfpunkt für das Ein-Verein-pro-Nutzer-Modell.

**Priorität: P1 – vor weiteren Änderungen am Einladungsablauf klären.** Soll jede Mannschaftszuordnung zwingend eine Vereinsmitgliedschaft voraussetzen? Falls ja, sollte die Prüfung serverseitig atomar bzw. in einem kontrollierten RPC-/Einladungsablauf durchgesetzt werden. Dabei darf ein bereits einem anderen Verein zugeordnetes Konto nicht stillschweigend übernommen werden. Keine Änderung wurde vorgenommen.


## 14. Fachliche Soll-Regeln – vom Nutzer bestätigt am 26.10.2026

Folgende Rechte sind ausdrücklich beabsichtigt und dürfen bei einer RLS-Härtung nicht versehentlich entzogen werden:

- Trainer dürfen Trainings, Trainingsserien und Spieltage ihrer Mannschaft anlegen, bearbeiten und löschen.
- Trainer dürfen die Anwesenheit anderer Trainer innerhalb ihrer eigenen Mannschaft dokumentieren und ändern.
- Teamdaten dürfen dadurch nicht teamübergreifend bearbeitet werden. Alle direkten Tabellenzugriffe müssen serverseitig auf die Mannschaft begrenzt bleiben.
- Mannschaftsadmins behalten zusätzliche Verwaltungs- und Rollenfunktionen; die genaue Admin-only-Matrix wird noch anhand der UI und Produktregeln abgeglichen.

Daraus folgt: Die zuvor dokumentierten Traineranwesenheits-Policies sind hinsichtlich der Erlaubnis, andere Trainer derselben Mannschaft zu bearbeiten, **kein Fehler**. Entscheidend ist die Begrenzung auf genau die Mannschaft, zu der der Termin gehört.

## 15. Neu priorisierte Prüfung nach fachlicher Klärung

### P1 – Matchday-Anwesenheit DELETE konsistent absichern
Die aktuelle `matchday_attendance_delete`-Policy prüft, ob der Nutzer Teammitglied des Spieltags ist, bindet den Datensatz aber nicht zusätzlich an einen Spieler derselben Mannschaft. INSERT und UPDATE prüfen diese Zuordnung bei der neuen Zeile. Das ist eine konkrete Policy-Inkonsistenz. Vor einer Änderung ist ein nicht-destruktiver Negativtest zu planen; anschließend kann die DELETE-Bedingung auf die gleiche Termin-/Spieler-Team-Konsistenz ausgerichtet werden.

### P1 – Einladungsprozess und Vereinszugehörigkeit
Der Codepfad `invite-trainer` ruft nach der Teamadmin-Prüfung `admin_add_team_role` auf. Die Funktion prüft die Vereinsmitgliedschaft des Zielkontos nicht ausdrücklich und erstellt keine `club_members)-Zuordnung. Die Bestandsabfrage fand keine existierenden Inkonsistenzen; dennoch bleibt die Durchsetzung der Ein-Verein-pro-Nutzer-Regel im Einladungsprozess offen.

### P2 – Rollenabgleich Spieler-Stammdaten und Positionen
Die aktuelle RLS erlaubt Teammitgliedern INSERT und UPDATE von `players`, während DELETE auf Teamadmins beschränkt ist. Die UI verlangt für das Entfernen/Reaktivieren Adminrechte; beim Hinzufügen/Bearbeiten von Spielern ist in den geprüften Handlern kein gleichwertiger `adminGuard()` vorhanden. Das kann beabsichtigt sein, muss aber fachlich bestätigt werden. `positions` und `player_positions` sind deutlich enger auf Teamadmins begrenzt. Nicht pauschal ändern, bevor die Sollrolle festgelegt ist.

### P2 – Empfehlungen und Zuordnungen
`matchday_recommendation_runs` erlaubt Teammitgliedern UPDATE und DELETE; `matchday_recommendation_players`, `matchday_players`, `training_players` und `training_responses` sind ebenfalls teambezogen für Teammitglieder beschreibbar. Die Policies prüfen überwiegend Teamzugehörigkeit und Zuordnungskonsistenz. Das passt grundsätzlich zur bestätigten Selbstverwaltung von Trainings und Spieltagen; ob Empfehlungsläufe gelöscht oder verändert werden dürfen, ist noch mit der fachlichen Bedeutung von Historie/Protokoll abzugleichen.

### Aktueller Stand
Nur read-only geprüft und dokumentiert. Keine RLS-Policy, RPC, Edge Function oder Frontenddatei wurde geändert. DEV-Daten und PROD sind unverändert.


### 15.1 Fachliche Ergänzung – Spieler-Stammdaten bestätigt

Am 26.10.2026 wurde zusätzlich bestätigt:

- Trainer dürfen innerhalb ihrer eigenen Mannschaft Spieler neu anlegen und vorhandene Spieler-Stammdaten bearbeiten.
- Dies umfasst insbesondere Name, Geburtsjahr, bevorzugten Fuß, Positionen, Level und weitere im Frontend gepflegte Spielerdaten.
- Die Berechtigung gilt ausschließlich für Spieler der eigenen Mannschaft. Ein Zugriff auf Spieler anderer Mannschaften darf nicht möglich sein.
- Das Entfernen aus dem aktiven Kader und die Reaktivierung bleiben gemäß aktueller Oberfläche Mannschaftsadmins vorbehalten.

Damit ist das Schreiben von Spieler-Stammdaten durch Trainer eine **beabsichtigte Berechtigung**, keine zu schließende Lücke. Die RLS-Prüfung muss weiterhin sicherstellen, dass `team_id` nicht auf eine fremde Mannschaft gesetzt oder bei einem Update auf eine fremde Mannschaft umgestellt werden kann. Die bestehende `players`-INSERT-/UPDATE-Policy prüft `is_team_member(team_id)`; ein gezielter negativer Test auf teamübergreifende Änderungen bleibt Teil der technischen Validierung.


## 16. Frontend-Handler gegen bestätigte Trainerrechte geprüft

Ergänzender Check der tatsächlichen Handler in `index.html` (Git-Blob SHA `64190e8dd269b61948707dc2f3d1b89fefabb8ed`):

- `saveNewPlayer` und `savePlayer` speichern Spielerstammdaten ohne `adminGuard()`. Das entspricht der bestätigten Soll-Regel für Trainer. Die Datenbank muss weiterhin Teamzugehörigkeit und Positionen auf dieselbe Mannschaft begrenzen.
- `deleteTraining` löscht Zuordnungen und Training direkt ohne UI-Adminprüfung. Das entspricht der bestätigten Soll-Regel, dass Trainer Trainings verwalten und löschen dürfen; die RLS begrenzt die Aktion auf Teammitglieder des betreffenden Teams.
- `saveTraining` legt Trainingstermine bzw. Serien an, ohne `adminGuard()`; dies entspricht der bestätigten Soll-Regel.
- `deleteMatchday` löscht Kaderzuordnungen und Spieltag direkt ohne UI-Adminprüfung. Das entspricht der bestätigten Soll-Regel, dass Trainer Spieltage verwalten und löschen dürfen; die RLS begrenzt die Aktionen auf das Team des Spieltags.
- `saveMatchdayRecommendation` ruft `save_matchday_recommendation` auf. Die Funktion prüft die Teammitgliedschaft des Aufrufers, doppelte/ungültige Spieler sowie die Teamzugehörigkeit und Aktivität aller empfohlenen Spieler. Sie ist keine `SECURITY DEFINER`-Funktion; die Tabellenoperationen laufen damit unter den Aufruferrechten und den Tabellen-RLS-Policies.

### Status nach fachlicher Klärung

Die Trainerrechte für Trainings, Trainingsserien, Spieltage, Anwesenheiten anderer Trainer derselben Mannschaft sowie Anlegen/Bearbeiten von Spielern sind im Wesentlichen konsistent mit den geprüften Frontend-Handlern und den Teammitgliedschafts-Policies. Diese Funktionen sind keine zu entziehenden Rechte.

Die verbleibenden konkreten technischen Prüfprioritäten bleiben:
1. Einladungsablauf und Erzwingung der Vereinsmitgliedschaft vor Vergabe einer Teamrolle.
2. `matchday_attendance_delete`: fehlende Spieler-/Team-Konsistenz im Vergleich zu INSERT.
3. Direkte REST-/RPC-Negativtests für fremde Team-IDs und Änderungen von `team_id` an Spielerdatensätzen.
4. Die Admin-only-Grenzen für Positionen, Rollen, Spielerkader-Archivierung/Reaktivierung und Backup-Import in der Datenbank bestätigen.


## 17. Vertiefte Sicherheitsprüfung – read-only Befunde vom 26.10.2026

### 17.1 Bestätigter Prüfpunkt: Teamwechsel eines Spielers über UPDATE-Policy

Die aktuelle `players`-UPDATE-Policy verwendet `is_team_member(team_id)` sowohl in `USING` als auch in `WITH CHECK`. Damit wird geprüft, dass der Nutzer zum bisherigen bzw. neuen Team gehört. Die Policy bindet die neue `team_id` aber nicht an die ursprüngliche Mannschaft.

**Folge:** Falls ein Nutzer Mitglied in mehreren Mannschaften ist, kann die Datenbankregel einen direkten UPDATE erlauben, der einen Spieler von einer Mannschaft in eine andere Mannschaft verschiebt, sofern der Nutzer beide Mannschaften verwalten/sehen darf. Das ist nicht durch einen realen API-Angriff getestet worden, aber aus der Policy-Bedingung ableitbar und widerspricht der Vorgabe, dass Trainer Spieler nur innerhalb ihrer eigenen Mannschaft bearbeiten sollen.

**Empfohlene Korrektur:** Eine zusätzliche serverseitige Regel, die das Ändern von `players.team_id` über den normalen Trainer-Schreibpfad verhindert. Falls Mannschaftswechsel später benötigt werden, sollte dies ein eigener, ausdrücklich autorisierter Admin-Prozess sein. Erst mit einem gezielten negativen Test verifizieren; keine pauschale Verschärfung der übrigen Spielerstammdaten-UPDATE-Rechte.

### 17.2 Bestätigter Frontend-/RLS-Widerspruch: Trainer können Positionen nicht zuverlässig speichern

Das Frontend `savePlayer` aktualisiert zuerst den Spielerdatensatz, löscht anschließend vorhandene `player_positions` und fügt die gewählten Positionen neu ein. Die aktuellen RLS-Policies für INSERT und DELETE auf `player_positions` verlangen jedoch `is_team_admin(team_id)`.

**Folge:** Ein Trainer ohne Adminrolle darf die Stammdaten des Spielers grundsätzlich bearbeiten, aber das Speichern der Positionen wird von der Datenbank abgewiesen. Da der Spielerdatensatz vorher aktualisiert wurde, kann es außerdem zu einer Teiländerung kommen, bei der Stammdaten gespeichert sind, Positionen aber nicht.

Das ist keine zu weit gefasste Berechtigung, sondern ein Widerspruch zur bestätigten Soll-Regel, dass Trainer Spieler einschließlich Positionen bearbeiten dürfen.

**Empfohlene Korrektur:** Den Speichervorgang atomar gestalten und Positionen für Teammitglieder derselben Mannschaft erlauben, dabei aber die Zuordnung von Spieler und Position an dasselbe Team binden. Die Änderung muss als separate DEV-Migration plus Frontend-Test erfolgen; hier wurde nichts geändert.

### 17.3 Matchday-Anwesenheit DELETE – konkreter Unterschied

`matchday_attendance_insert` und `matchday_attendance_update` prüfen, dass Spieler und Spieltag zur selben Mannschaft gehören. `matchday_attendance_delete` prüft aktuell nur, dass der Aufrufer Teammitglied der Mannschaft des Spieltags ist.

Die Fremdschlüssel sichern ab, dass Spieltag und Spieler existieren; sie erzwingen aber nicht, dass beide zur selben Mannschaft gehören. Derzeit ist kein inkonsistenter Datensatz nachgewiesen. Ein solcher Datensatz könnte aber durch frühere Daten, privilegierte Pfade oder spätere Änderungen entstehen. Die DELETE-Regel sollte daher konsistent dieselbe Spieler-/Teamzuordnung prüfen wie INSERT/UPDATE.

### 17.4 Einladungs-RPC – Ein-Verein-pro-Nutzer nicht explizit erzwungen

Die aktuell installierte `admin_add_team_role`-Funktion:
- prüft, dass der Aufrufer Teamadmin der angegebenen Mannschaft ist,
- akzeptiert nur `admin` oder `trainer`,
- prüft, dass das Zielkonto in `auth.users` existiert,
- fügt `team_members` und `team_member_roles` ein,
- prüft aber nicht, ob das Zielkonto Vereinsmitglied des Vereins ist, dem das Team zugeordnet ist, oder bereits einem anderen Verein angehört.

Da `invite-trainer` diese Funktion verwendet und selbst keine Vereinszugehörigkeit ergänzt oder prüft, ist das Ein-Verein-pro-Nutzer-Modell im Einladungsweg nicht vollständig durchgesetzt. Die aktuelle Bestandsabfrage fand keine bestehenden Fälle; die Lücke betrifft die serverseitige Durchsetzung künftiger Einladungen.

**Empfohlene Korrektur:** Vor Vergabe einer Teamrolle muss ein kontrollierter serverseitiger Ablauf prüfen, dass die Vereinsmitgliedschaft zum Teamverein passt. Für bestehende Nutzer aus einem anderen Verein muss der Vorgang fail-closed mit verständlicher Fehlermeldung abbrechen. Bei neuen Einladungen muss klar festgelegt sein, wer und wann die Vereinsmitgliedschaft anlegt; keine implizite Mehrfachmitgliedschaft und kein automatisches Umhängen bestehender Konten.

### 17.5 Priorisierung für die Korrekturphase

| Priorität | Befund | Art | Nächster Schritt |
|---|---|---|---|
| P1 | Einladungsweg erzwingt Vereinsmitgliedschaft nicht explizit | Sicherheits-/Datenmodell-Invariante | Sollablauf festlegen, dann RPC/Edge Function in DEV absichern |
| P1 | Spieler-`team_id` kann bei Mitgliedschaft in mehreren Teams potenziell verändert werden | Teamgrenzen / Datenintegrität | `team_id`-Änderung im normalen UPDATE verhindern, Negativtest |
| P1 | `matchday_attendance_delete` prüft Spieler-Team-Konsistenz nicht | RLS-Konsistenz | DELETE-Policy mit INSERT/UPDATE abgleichen |
| P1 funktional | Trainer dürfen Positionen laut Soll bearbeiten, RLS verlangt Teamadmin | Rollen-/Frontend-Widerspruch | Policy und Speichervorgang atomar korrigieren |
| P2 | Letzter Teamadmin und direkte Rollen-RPCs | bestehender Schutz, Integrationstest offen | nicht-destruktive/isolierte negative Tests vorbereiten |

### 17.6 Grenzen dieser Prüfung

Diese Ergebnisse stammen aus Definitionen der aktuellen RLS-Policies, RPCs, Constraints und Triggern sowie dem geprüften Frontend-/Edge-Function-Code. Es wurden keine schädlichen oder destruktiven API-Aufrufe durchgeführt. Ein realer Cross-Team- oder Cross-Club-Exploit ist damit nicht nachgewiesen. Die genannten Korrekturen sind Empfehlungen für die nächste DEV-Änderungsrunde, keine bereits umgesetzten Änderungen.
