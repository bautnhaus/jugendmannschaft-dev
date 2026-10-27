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


### 17.7 Ergänzende Bestätigung: Archivierung/Reaktivierung ist serverseitig geschützt

Die Triggerfunktion `protect_player_active_status()` wurde direkt aus DEV ausgelesen. Sie weist eine Änderung von `players.active` zurück, wenn der Aufrufer kein Teamadmin der bisherigen Mannschaft ist. Damit ist die Admin-only-Regel für Archivierung/Reaktivierung nicht nur eine UI-Schranke, sondern zusätzlich in der Datenbank verankert.

Die Funktion `cleanup_matchday_recommendations_before_player_delete()` löscht vor einem physischen Spieler-DELETE zugehörige Empfehlungsläufe. Im normalen Frontend wird ein Spieler jedoch archiviert statt physisch gelöscht. Der Trigger ist daher ein Aufräumschutz für direkte/andere Löschpfade, nicht der primäre Archivierungsmechanismus.


## 18. Umsetzung AP03-Sicherheitskorrekturen – 26.10.2026

### Änderungen in DEV

Die folgenden Migrationen wurden im Supabase-Projekt `pzazqvvoruqnqhcorbwx` angewendet:

- `ap03_security_fixes_v1_dev` – Club-Mitgliedschaft beim Setzen einer Teamrolle, Schutz gegen direkte Änderung von `players.team_id`, Trainerrechte für Positionszuordnungen bei gleicher Mannschaft, konsistente DELETE-Policy für `matchday_attendance`, atomare RPC `save_player_with_positions`.
- `ap03_security_fixes_hardening_v1_dev` – EXECUTE-Rechte auf die Triggerfunktion `prevent_player_team_change()` für PUBLIC/anon/authenticated entzogen.

Die zugehörigen SQL-Dateien liegen im Branch `feature/ap03-security-fixes` unter `supabase/migrations/`.

### Frontend

`index.html` im Branch wurde angepasst: Anlegen und Bearbeiten eines Spielers verwenden nun `save_player_with_positions`, damit Stammdaten und Positionszuordnungen in einer Datenbanktransaktion gespeichert werden. Bei einem Fehler werden beide Teile zurückgerollt; es gibt keinen Zwischenzustand mit aktualisierten Stammdaten und fehlgeschlagenen Positionszuordnungen.

### Durchgeführte technische Prüfungen

- [x] Migrationen sind im DEV-Migrationsprotokoll eingetragen.
- [x] RLS-Policy `player_positions_insert` erlaubt Teammitgliedern das Verknüpfen von Positionen, wenn Spieler und Position zum selben Team gehören.
- [x] RLS-Policy `player_positions_delete` begrenzt das Entfernen von Positionszuordnungen auf Teammitglieder der Mannschaft des Spielers.
- [x] RLS-Policy `matchday_attendance_delete` verlangt nun, dass Spieler und Spieltag derselben Mannschaft angehören.
- [x] Trigger-Test: direkte Änderung von `players.team_id` wurde mit SQLSTATE 42501 abgewiesen; keine Änderung blieb bestehen.
- [x] RPC-Aufruf `save_player_with_positions` wurde als authentifizierter Teamadmin in einer zurückgerollten Transaktion ausgeführt.
- [x] RPC-Aufruf `save_player_with_positions` wurde als authentifizierter Trainer in einer zurückgerollten Transaktion ausgeführt. Der Spieler blieb unverändert und die ursprüngliche Positionszuordnung blieb erhalten.
- [x] `admin_add_team_role` wurde als Teamadmin für die bereits vorhandene eigene Rolle in einer zurückgerollten Transaktion ausgeführt.
- [x] EXECUTE auf `prevent_player_team_change()` ist für anon und authenticated entzogen.

### Noch nicht sicher praktisch testbar

- Cross-Club-Einladungsversuch: In DEV existiert nur ein Verein. Die Funktion prüft den anderen Verein serverseitig; ein realer Negativtest braucht einen isolierten zweiten Verein bzw. Testnutzer.
- Cross-Team-Positions- und Anwesenheitstest: In DEV existiert nur eine Mannschaft. Die neuen Bedingungen wurden strukturell ausgelesen, aber ein Negativtest mit zwei Teams wurde nicht durchgeführt.
- UI-Test auf dem veröffentlichten DEV-Webauftritt: Der Frontend-Code ist nur auf dem separaten GitHub-Branch gespeichert; es wurde kein Deployment vorgenommen. Vor Merge/Deployment ist die Änderung auf dem tatsächlichen DEV-Frontend zu testen.
- Kein Test hat produktive Daten verändert; die Funktionstests liefen mit Rollback.

### Deployment-/Release-Status

- DEV-Datenbankmigrationen: angewendet.
- Frontend: geändert, aber nicht deployed.
- Branch: `feature/ap03-security-fixes`.
- Kein PR-Merge, kein GitHub-Pages-Deployment und keine PROD-Änderung.


### Ergänzende Prüfung nach der Dokumentation

- [x] `save_player_with_positions` wurde zusätzlich als authentifizierter Trainer zum Anlegen eines neuen Spielers samt Position in einer Transaktion aufgerufen; danach wurde zurückgerollt. Die Nachabfrage bestätigte, dass der temporäre Testspieler nicht gespeichert wurde.
- [x] Die beiden Migrationsdateien wurden auf die tatsächlich von Supabase registrierten Versionsnummern ausgerichtet: `20261026210356_ap03_security_fixes_v1_dev.sql` und `20261026210440_ap03_security_fixes_hardening_v1_dev.sql`. Damit stimmen Dateinamen und DEV-Migrationshistorie überein.


## 19. AP03-Abschlussprüfung – Status zum 26.10.2026

### Verifiziert
- Die DEV-Migrationshistorie enthält `20261026210356 ap03_security_fixes_v1_dev` und `20261026210440 ap03_security_fixes_hardening_v1_dev`.
- Die aktiven DEV-Policies für `player_positions` und `matchday_attendance` entsprechen den in Abschnitt 18 beschriebenen Korrekturen.
- Die Bestandsabfrage findet derzeit keine Teamrollen, deren Nutzer keine Vereinsmitgliedschaft beim Verein der Mannschaft haben.
- Die veröffentlichte `jugendmannschaft-dev:main/index.html` enthält den Aufruf `save_player_with_positions`.
- Nutzerseitig bestätigt: Anmeldung/rollenabhängiger Einstieg bestanden; Spieler neu anlegen, bearbeiten und speichern nach Reload bestanden.
- Nutzerseitig bestätigt: Rollenbearbeitung bietet nur „Vereinsmitglied“ und „Vereinsadmin“. Dies ist der Vereinsrollen-Dialog; Teamrollen werden getrennt verwaltet. Die Übersichtlichkeit der Verwaltungswege wird als separates UI-Folgepaket geführt.

### Weiterhin offen – vor AP03-Abschluss entscheiden
1. **Einladung / anderes Vereinskonto:** Codepfad prüft die Vereinsgrenze; negativer Integrationstest fehlt, da in DEV nur ein Verein vorhanden ist.
2. **Cross-Team-Tests:** Direkte Positions- und Anwesenheitszugriffe mit IDs einer zweiten Mannschaft nicht praktisch getestet, da DEV nur eine Mannschaft hat.
3. **Letzter Admin:** Serverseitiger Schutz wurde im Code geprüft; vollständiger isolierter Integrationstest steht aus.
4. **Rollenänderungen und Invite-Flow:** Praktischer End-to-End-Test für neues Mitglied, Vereinsmitgliedschaft und Teamrolle nach dem aktuellen Deployment noch nicht dokumentiert.
5. **Browser-Regression:** Nutzer hat die Kernabläufe für Spieler bestätigt; ein kompletter Regressionstest aller AP02/AP03-Verwaltungsabläufe steht aus.

### Abschlussbewertung
AP03 ist **implementiert und teilweise verifiziert, aber noch nicht vollständig abgeschlossen**. Die verbliebenen Punkte betreffen vor allem fehlende isolierte Negativ-/Integrationstests, nicht bekannte reproduzierte Datenfehler. Keine weitere UI-Restrukturierung gehört zum AP03-Umfang. Das UI-Folgepaket bleibt separat vorgemerkt. Kein PROD-Deploy und kein Merge wurden durch diese Abschlussprüfung ausgelöst.


## 7. Nachprüfung Sicherheitsadvisor und gezielte Härtung (26.10.2026)

### Durchgeführte Korrektur
- Supabase Security Advisor meldete `function_search_path_mutable` für `public.set_updated_at()`.
- DEV-Funktion wurde mit `ALTER FUNCTION public.set_updated_at() SET search_path = pg_catalog, public` gehärtet.
- Nachprüfung bestätigte `search_path=pg_catalog, public`; die Funktion ist keine `SECURITY DEFINER`-Funktion und `EXECUTE` ist weder für `anon` noch `authenticated` gewährt.
- Die Änderung ist im DEV-Branch als Migration dokumentiert: `supabase/migrations/20261026221800_ap03_set_updated_at_search_path_hardening_dev.sql`.

### Verbleibende Supabase-Security-Advisor-Hinweise
- `authenticated_security_definer_function_executable`: 21 Funktionen. Der Advisor weist darauf hin, dass angemeldete Nutzer diese `SECURITY DEFINER`-Funktionen aufrufen können. Das ist nicht automatisch ein Berechtigungsfehler: mehrere Funktionen prüfen intern die Identität/Rolle und sind für App-Funktionen vorgesehen. Trotzdem müssen alle 21 Einträge systematisch einzeln bewertet werden. Diese Prüfung ist noch nicht abgeschlossen; wir entziehen keine Rechte pauschal, da dadurch legitime App-Abläufe ausfallen könnten.
- `auth_leaked_password_protection`: Schutz gegen bekannte kompromittierte Passwörter ist deaktiviert. Die Einstellung muss im Supabase-Auth-Dashboard geprüft und bei Verträglichkeit mit dem Login-/Passwortprozess aktiviert werden. Diese Einstellung wurde in diesem Schritt nicht verändert.
- Der Advisor meldet nach der `set_updated_at`-Korrektur weiterhin die beiden oben genannten Kategorien; eine vollständige Bereinigung der Advisor-Warnungen ist nicht erreicht.

### Abschlussstatus nach dieser Nachprüfung
- **Erledigt:** gezielte `search_path`-Härtung von `set_updated_at()` in DEV und Verifikation der Funktionseinstellung/Ausführungsrechte.
- **Noch offen:** notwendige Ausführungsrechte der 21 `SECURITY DEFINER`-Funktionen einzeln bewerten; Einstellung für kompromittierte Passwörter im Dashboard prüfen; Cross-Club-/Cross-Team-Integrationstests mit geeigneten Testdaten; praktischer Test zum Schutz des letzten Admins; vollständiger Browser-Regressionstest.
- **Umfang:** keine pauschalen Rechteänderungen, keine UI-Restrukturierung, kein PROD-Deploy und kein Merge.

AP03 bleibt **implementiert und teilweise verifiziert, nicht vollständig sicherheitsabgenommen**. Die vorgenannten offenen Prüfungen sind ausdrücklich dokumentiert.


## 8. Einzelbewertung der 21 SECURITY DEFINER-Funktionen (26.10.2026)

Prüfgrundlage: aktuelle DEV-Funktionsdefinitionen, ACLs und Supabase Security Advisor. Dies ist eine Code-/Berechtigungsprüfung, kein vollständiger Penetrationstest. Die 21 Funktionen sind im Schema `public` für `authenticated` ausführbar. Der Aufruf ist bei mehreren Funktionen absichtlich erforderlich; deshalb wurden keine Rechte pauschal entzogen.

| Funktion | Bewertung der internen Prüfung | Einschätzung EXECUTE für authenticated |
|---|---|---|
| `admin_add_club_member(uuid,uuid,text)` | Prüft Anmeldung, Vereinsadmin/Superadmin, erlaubte Vereinsrolle, Verein und Zielkonto; blockiert Mitgliedschaft in anderem Verein. | Erforderlich für Vereinsverwaltung; behalten, weitere Negativtests offen. |
| `admin_add_club_member_by_email(uuid,text,text)` | Prüft Anmeldung, Vereinsadmin, Rolle und E-Mail; delegiert an geprüfte `admin_add_club_member`. | Erforderlich für Verwaltungsablauf; behalten. |
| `admin_add_team_role(uuid,uuid,text)` | Prüft Teamadmin, erlaubte Teamrolle, Zielkonto, Teamexistenz und Vereinszugehörigkeit; schreibt Legacy- und normalisierte Rollentabelle. | Erforderlich für Teamrollenverwaltung; behalten. Cross-Club-Test offen. |
| `admin_create_team(uuid,text,integer)` | Prüft Anmeldung/Vereinsadmin, Namen, Kadergröße und Verein; macht Ersteller zum Teamadmin. | Erforderlich für Vereinsverwaltung; behalten. |
| `admin_remove_club_member(uuid,uuid)` | Prüft Vereinsadmin, Mitgliedschaft, fehlende Teamrollen und schützt letzten Vereinsadmin; sperrt Vereinszeile gegen parallele Änderungen. | Erforderlich; behalten. Letzter-Admin-Integrationstest offen. |
| `admin_remove_team_role(uuid,uuid,text)` | Prüft Teamadmin und erlaubte Rolle; sperrt Teamzeile und schützt letzten Teamadmin. | Erforderlich; behalten. Letzter-Admin-Test offen. |
| `admin_set_club_member_role(uuid,uuid,text)` | Prüft Vereinsadmin, erlaubte Rolle, Vereinsmitgliedschaft; schützt letzten Vereinsadmin und sperrt Vereinszeile. | Erforderlich; behalten. Praktischer Negativtest offen. |
| `admin_set_trainer_label(uuid,text,text)` | Prüft Teamadmin, nichtleeres Label, vorhandenes Konto und Teamrolle. | Erforderlich für Teamverwaltung; behalten. |
| `get_club_members(uuid)` | Prüft Vereinsadmin vor Rückgabe von E-Mail-Adressen und Teamrollen für den angegebenen Verein. | Erforderlich für Mitgliederverwaltung; behalten. |
| `get_club_members_v2(uuid)` | Prüft Vereinsadmin vor Rückgabe von Mitglieds- und Teamrolleninformationen. | Erforderlich für aktuelle Mitgliederansicht; behalten. |
| `get_club_players(uuid)` | Prüft Vereinsadmin und begrenzt Spielerabfrage auf Mannschaften dieses Vereins. | Erforderlich für Vereinsübersicht; behalten. |
| `get_team_trainers_v2(uuid)` | Prüft Teamadmin vor Rückgabe von Teamrollen und E-Mail-Adressen. | Erforderlich für Teamverwaltung; behalten. |
| `is_club_admin(uuid)` | Nutzt `auth.uid()`; prüft Superadmin oder Clubmitgliedschaft plus Vereinsadminrolle. | Als Hilfsfunktion für RLS/RPC nötig; behalten. Kann als boolesche Abfrage Vereinsrollenstatus offenlegen, aber nur für den angegebenen Verein. |
| `is_club_member(uuid)` | Nutzt `auth.uid()` und prüft nur eigene Mitgliedschaft im angegebenen Verein. | Hilfsfunktion für Policies; behalten. |
| `is_super_admin()` | Nutzt `auth.uid()` und prüft die globale Rolle des angemeldeten Kontos. | Hilfsfunktion für Policies/RPC; behalten. |
| `is_team_admin(uuid)` | Nutzt `auth.uid()` und prüft eigene Adminrolle im angegebenen Team. | Hilfsfunktion für Policies/RPC; behalten. |
| `is_team_admin(uuid,uuid)` | Prüft Adminrolle für eine beliebige übergebene Benutzer-ID und Team-ID, ohne die übergebene Benutzer-ID auf `auth.uid()` zu begrenzen. | **Gezielt prüfen:** liefert authentifizierten Nutzern einen Rollen-Wahrheitswert für fremde IDs. Vermutlich interne Hilfsfunktion; nicht ohne Abhängigkeitsanalyse entziehen, aber aus öffentlicher RPC-Oberfläche entfernen/privatisieren, falls kein Clientaufruf nötig. |
| `is_team_member(uuid)` | Nutzt `auth.uid()` und prüft eigene Mitgliedschaft im angegebenen Team. | Hilfsfunktion für RLS/RPC; behalten. |
| `is_team_member(uuid,uuid)` | Prüft Mitgliedschaft für eine beliebige Benutzer-ID und Team-ID, ohne Selbstbindung an `auth.uid()`. | **Gezielt prüfen:** kann Mitgliedschaftsstatus fremder IDs offenlegen. Wahrscheinlich interne Hilfsfunktion; Client-Notwendigkeit und RLS-Abhängigkeiten prüfen, ggf. aus öffentlicher RPC-Oberfläche entfernen/privatisieren. |
| `log_team_role_change()` | Triggerfunktion protokolliert Rollenänderung anhand von `NEW/OLD` und `auth.uid()`; kein normaler RPC-Parameter. | Als Triggerfunktion behalten; nicht direkt als API gedacht. ACL sollte nur nötige Trigger-/Owner-Ausführung zulassen. Advisor-Eintrag ist hier wahrscheinlich ein False Positive für direkten API-Aufruf, trotzdem Exposure/ACL separat kontrollieren. |
| `save_player_with_positions(...)` | Prüft Anmeldung, Pflichtname, Level/Fuß/Geburtsjahr, eigene Teammitgliedschaft und dass Positions-IDs zum selben Team gehören; Update sperrt Spielerzeile und blockiert Teamwechsel. | Erforderlich für atomaren Frontend-Speichervorgang; behalten. Cross-Team-Negativtest offen. |

### Querschnittsergebnis
- Bei den Verwaltungs- und Datenfunktionen sind relevante interne Autorisierungsprüfungen vorhanden; die Bewertung beruht auf den aktuell ausgelesenen Funktionsdefinitionen.
- Zwei überladene Hilfsfunktionen (`is_team_admin(uuid,uuid)`, `is_team_member(uuid,uuid)`) akzeptieren eine beliebige Benutzer-ID und geben Rollen-/Mitgliedschaftsstatus zurück. Das ist der deutlichste konkrete Härtungskandidat: prüfen, ob sie nur intern gebraucht werden, und bei fehlendem legitimen Clientbedarf aus dem exponierten API-Schema entfernen oder die EXECUTE-Rechte so gestalten, dass RLS-/RPC-Abhängigkeiten erhalten bleiben.
- Die übrigen 19 Funktionen haben entweder eigene Identitäts-/Rollenprüfungen, sind Authentifizierungs-Hilfsfunktionen, oder werden als Triggerfunktion verwendet. Das begründet keine pauschale Freigabe: negative Autorisierungstests fehlen teilweise.
- Alle 21 Einträge sind aktuell für `authenticated` ausführbar. Der Supabase-Advisor-Hinweis bleibt bestehen, bis die Funktionen aus dem exponierten Schema/EXECUTE-Pfad entfernt werden oder der Advisor für diese Architektur bewusst als erwarteter Hinweis dokumentiert wird.
- Keine Berechtigungen wurden in diesem Schritt geändert. Nächster sinnvoller Schritt: Abhängigkeiten der beiden Funktionen mit beliebiger Benutzer-ID (RLS-Policies, andere Funktionen und Frontend-Aufrufe) ermitteln; danach eine eng begrenzte DEV-Migration planen.



## 9. Abhängigkeitsprüfung und begrenzte DEV-Härtung der Teamrollen-Hilfsfunktionen (26.10.2026)

### Abhängigkeiten
- Die einparametrigen Funktionen `is_team_admin(uuid)` und `is_team_member(uuid)` werden von mehreren RLS-Policies direkt verwendet und bleiben für `authenticated` ausführbar.
- Die zweiparametrigen Überladungen `is_team_admin(uuid,uuid)` und `is_team_member(uuid,uuid)` werden von den geprüften SECURITY DEFINER-Verwaltungs-RPCs verwendet, darunter `admin_add_team_role` und `admin_set_trainer_label`. Die RLS-Policies verwenden direkt die einparametrigen Varianten.
- Die zweiparametrigen Varianten akzeptieren beliebige Benutzer-IDs und geben einen Rollen-/Mitgliedschaftsstatus zurück. Ein direkter Aufruf durch normale angemeldete Clients ist nach den untersuchten Abhängigkeiten nicht erforderlich.

### Umgesetzte DEV-Migration
- `REVOKE EXECUTE ON FUNCTION public.is_team_admin(uuid, uuid) FROM PUBLIC, anon, authenticated;`
- `REVOKE EXECUTE ON FUNCTION public.is_team_member(uuid, uuid) FROM PUBLIC, anon, authenticated;`
- Die Migration wurde auf DEV angewendet. Eigentümer-/postgres-Ausführung bleibt möglich; die einparametrigen Varianten bleiben unverändert.
- Nachprüfung bestätigte: beide zweiparametrigen Funktionen haben `anon_exec=false` und `authenticated_exec=false`; die einparametrigen Varianten bleiben für `authenticated` ausführbar.
- Supabase Security Advisor zeigt nun 19 statt 21 Warnungen dieser Kategorie.

### Status und Einschränkungen
- Dies ist eine gezielte Reduktion unnötiger direkter RPC-Aufrufe, keine vollständige Bereinigung der SECURITY DEFINER-Warnungen.
- Ein vollständiger Browser-Regressions-/Integrationstest für alle internen RPC-Aufrufe nach dem Entzug der EXECUTE-Rechte steht noch aus. Die Funktionsaufrufe innerhalb der SECURITY DEFINER-Funktionen sollten in einem isolierten Test noch verifiziert werden.
- Keine PROD-Änderung und kein Merge.


## 10. Ergänzende AP03-Abschlussprüfungen – 26.10.2026

### Interne RPC-Aufrufe nach Einschränkung der Teamrollen-Hilfsfunktionen

- [x] `admin_add_team_role` und `admin_set_trainer_label` wurden ausgelesen: beide sind `SECURITY DEFINER` und gehören `postgres`; beide rufen die zweiparametrige Variante `is_team_admin(uuid,uuid)` intern auf.
- [x] Kontrollierter Transaktionstest mit Rollback: beide Verwaltungsfunktionen liefen nach Entzug der direkten `EXECUTE`-Rechte ohne Berechtigungsfehler durch.
- [x] Die Nachkontrolle bestätigte, dass bestehende Teamrollen und Bezeichnungen unverändert blieben.

### Schutz des letzten Administrators

- [x] Kontrollierter Test von `admin_remove_team_role`: Versuch, die einzige Teamadminrolle zu entfernen, wurde mit SQLSTATE `23514` `(check_violation)` blockiert. Nachkontrolle: weiterhin genau eine Teamadminrolle.
- [x] Kontrollierter Test von `admin_set_club_member_role`: Versuch, die einzige Vereinsadminrolle auf `member` herabzustufen, wurde mit SQLSTATE `23514` blockiert. Nachkontrolle: weiterhin genau eine Vereinsadminrolle.
- Beide Tests liefen innerhalb zurückgerollter Transaktionen; es wurden keine dauerhaften Rollenänderungen vorgenommen.

### Nutzerseitiger DEV-Praxistest

Am 26.10.2026 hat der Nutzer folgende Tests auf dem veröffentlichten DEV-Webauftritt ausdrücklich als bestanden bestätigt:

- [x] Spieler speichern und nach Neuladen prüfen.
- [x] Mitglieder-/Teamrolle ansehen oder ändern.
- [x] Trainer-/Teamrollenverwaltung öffnen.

Diese Bestätigung ergänzt die zuvor dokumentierten SQL- und Codeprüfungen. Sie ist kein vollständiger Browser-Regressionstest sämtlicher App-Funktionen.

### Aktueller Security-Advisor-Stand

- `authenticated_security_definer_function_executable`: 19 Hinweise nach Einschränkung der beiden zweiparametrigen Teamrollen-Hilfsfunktionen (zuvor 21).
- `auth_leaked_password_protection`: weiterhin als Warnung gemeldet; die Einstellung wurde nicht verändert.
- Die 19 verbleibenden Hinweise wurden nicht pauschal mit `REVOKE EXECUTE` behandelt, da mehrere RPCs von der App benötigt werden und individuelle Autorisierungsprüfungen enthalten. Die Warnungen sind damit eingeordnet, aber nicht vollständig beseitigt.
- Die Passwortschutz-Einstellung muss im Supabase-Dashboard geprüft und entsprechend der Sicherheitsentscheidung aktiviert werden. Das kann nicht durch SQL allein abgeschlossen werden.

### Abschlussbewertung

**AP03 DEV-Umsetzung und die in diesem Dokument aufgeführten gezielten Prüfungen sind durchgeführt.** Die zuletzt geänderten internen Funktionsrechte, die beiden Last-Admin-Schutzfälle und die drei vom Nutzer bestätigten UI-Abläufe wurden geprüft.

Folgende Grenzen bleiben ausdrücklich bestehen:
1. Cross-Club- und Cross-Team-Negativtests sind mangels zweitem Verein/Team nicht durchgeführt.
2. Kein vollständiger Browser-Regressionstest aller App-Funktionen wurde durchgeführt.
3. Die Einstellung zum Schutz vor geleakten Passwörtern bleibt im Supabase-Dashboard offen.
4. 19 Security-Advisor-Hinweise bleiben bestehen und sind nicht automatisch als ausnutzbare Lücken bewertet; sie müssen bei künftigen Änderungen weiter überwacht werden.

Diese Punkte werden als **Restpunkte/Risikoakzeptanz** dokumentiert und blockieren nicht die Dokumentation der bereits umgesetzten DEV-Arbeiten. Sie dürfen jedoch nicht als bestandene Tests ausgegeben werden. Vor einer PROD-Übernahme ist eine separate Freigabe mit Migrationen, Frontend-Stand und Rückfallplan erforderlich.

**Release-Sperre:** keine PROD-Änderung, kein Merge und keine Veröffentlichung durch diese Dokumentationsaktualisierung.


## 11. Fortsetzung der AP03-Sicherheitsprüfung – 26.10.2026

### 11.1 Triggerfunktion `log_team_role_change()`

- Die Funktion ist eine `SECURITY DEFINER`-Triggerfunktion mit festem `search_path = pg_catalog, public`.
- Zwei aktive Trigger binden sie an `team_member_roles`: `audit_team_role_insert` (AFTER INSERT) und `audit_team_role_delete` (AFTER DELETE).
- Sie schreibt Rollenänderungen in `team_role_change_log`; sie ist kein regulärer Frontend-RPC.
- In DEV wurde `EXECUTE` für `PUBLIC`, `anon` und `authenticated` entzogen. Der Funktionsbesitzer behält die notwendigen Rechte.
- Nachkontrolle: `authenticated` und `anon` haben keine direkte EXECUTE-Berechtigung mehr; beide Trigger sind weiterhin registriert.
- Ein kontrollierter Rollenlösch-Test prüfte, dass der Trigger innerhalb der Testtransaktion einen Audit-Eintrag erzeugte; anschließend wurde die Testtransaktion zurückgerollt. Die vorhandenen Rollen-/Auditdaten wurden nicht dauerhaft verändert.
- Der Security Advisor meldet nun 18 statt 19 Hinweise zu für `authenticated` ausführbaren SECURITY DEFINER-Funktionen.

### 11.2 Noch ausstehende Arbeiten

1. Die verbleibenden 18 Advisor-Einträge weiter einzeln nach Zweck, Berechtigungsprüfung und tatsächlichem Frontend-/RLS-Aufrufpfad bewerten. Keine pauschalen Rechteentziehungen.
2. Regressionsprüfungen der Verwaltungs-RPCs und Trigger nach den Berechtigungsänderungen fortsetzen.
3. Die registrierten DEV-Migrationen mit den Dateien im Branch abgleichen. Bei nicht vorhandenen Migrationsdateien müssen diese reproduzierbar im Feature-Branch ergänzt werden.
4. Nach Abschluss dieses Abgleichs dieses Dokument mit dem vollständigen Prüfstatus und den nicht testbaren Fällen aktualisieren.

### 11.3 Aktuelle Grenzen

- Der Cross-Club- und Cross-Team-Negativtest bleibt mangels zweitem Verein bzw. zweitem Team offen.
- Die Supabase-Einstellung zum Schutz vor bekannten kompromittierten Passwörtern ist aufgrund der verfügbaren Tarifoptionen nicht aktivierbar; dies ist eine dokumentierte Plattform-/Tarifgrenze, kein Nachweis kompromittierter Konten.
- Kein Merge, keine PROD-Migration und kein PROD-Deployment.


### 11.4 Migrationsabgleich – Zwischenergebnis

- Die beiden Hauptmigrationen `20261026210356_ap03_security_fixes_v1_dev.sql` und `20261026210440_ap03_security_fixes_hardening_v1_dev.sql` sind im Branch vorhanden.
- Die Migration zur Einschränkung der direkten EXECUTE-Rechte auf `log_team_role_change()` wurde neu als `20261026225811_ap03_restrict_log_team_role_change_execute_dev.sql` im Branch dokumentiert und stimmt mit dem registrierten DEV-Migrationsnamen überein.
- Die Migration zur Einschränkung der zweiparametrigen Teamrollen-Hilfsfunktionen wurde als `20261026222403_ap03_restrict_internal_team_role_helpers_dev.sql` ergänzt.
- Beim `set_updated_at()`-Hardening besteht eine historische Versionsabweichung: Die DEV-Migrationshistorie führt Version `20261026221728`, während bereits eine Datei mit Zeitstempel `20261026221800` im Branch lag. Eine Datei mit der registrierten Version `20261026221728` wurde ergänzt. Beide enthalten denselben idempotenten `ALTER FUNCTION ... SET search_path`-Befehl; die doppelte historische Datei ist als Bereinigungs-/Konsolidierungspunkt zu beachten, bevor ein vollständig neu aufgebautes Schema über diese Dateien reproduziert wird.
- Dieser Abgleich ist damit verbessert, aber noch nicht als vollständige Reproduktion einer frischen Datenbank bewertet: Vor einer solchen Aussage müssen alle registrierten Migrationen gegen den Branchbestand und ihre Reihenfolge geprüft werden.


## 12. AP03 Gesamtinventur – erster konsolidierter Snapshot (27.10.2026)

Diese Inventur wurde bewusst read-only durchgeführt. Während der Inventur wurden keine weiteren Berechtigungen oder Datenbankobjekte verändert.

### 12.1 Datenbankmigrationen

- Das DEV-Migrationsprotokoll enthält 18 Einträge insgesamt: AP01 (5), AP02 (8) und AP03 (5).
- Für die vier AP03-Änderungsgruppen sind SQL-Dateien im Branch vorhanden: Hauptkorrekturen, Triggerrechte für `prevent_player_team_change`, `set_updated_at()`-search_path, interne zweiparametrige Teamrollen-Hilfsfunktionen und Trigger-Auditfunktion (die Hauptkorrekturen und Hardening sind dabei zwei separate Hauptdateien; insgesamt liegen derzeit fünf AP03-Dateien vor).
- Versionsabweichung: DEV führt `20261026221728 ap03_set_updated_at_search_path_hardening`; im Branch liegen sowohl `20261026221728_ap03_set_updated_at_search_path_hardening.sql` als auch die ältere Datei `20261026221800_ap03_set_updated_at_search_path_hardening_dev.sql`. Beide enthalten denselben `ALTER FUNCTION`-Befehl. Dies ist eine Versions-/Duplikatbereinigung, keine abweichende Datenbanklogik.
- Für eine vollständige Neuaufsetzung ist der gesamte Satz aller 18 historischen Migrationen einschließlich ihrer Reihenfolge und Datei-Existenz noch abschließend gegen den Branchbestand zu verifizieren; der vorliegende Snapshot allein belegt noch keine vollständige Fresh-Install-Reproduzierbarkeit.

### 12.2 Tabellen, RLS und Tabellenrechte

- 25 Tabellen/partitionierte Tabellen im Schema `public`; RLS ist auf allen 25 aktiviert. Keine der geprüften Tabellen hat RLS deaktiviert.
- RLS-Aktivierung allein beweist nicht die Korrektheit jeder Policy. Policies wurden vollständig aus `pg_policies` ausgelesen; die Rollen- und Teamgrenzen sowie Trainerteilnahme-Zuordnungen bleiben zentrale Regressionstestbereiche.
- Bei mehreren fachlichen Tabellen bestehen ACL-Einträge für `anon` und/oder breite Rechte für `authenticated`. Da RLS zusätzlich greift, ist dies nicht automatisch ein Datenzugriffsbypass. Die Kombination aus Tabellen-ACL, Rollen-spezifischen Policies und tatsächlichem API-Zugriff muss im finalen Test als Einheit bewertet werden. Keine pauschale ACL-Änderung während dieser Inventur.

### 12.3 Trigger und Triggerfunktionen

Die aktuelle Inventur fand unter anderem:
- `set_updated_at()` an `matchday_attendance`, `matchdays`, `players`, `seasons`, `teams` und `trainings`; der feste Suchpfad `pg_catalog, public` ist gesetzt.
- `prevent_player_team_change()` an `players`; direkte EXECUTE-Rechte für `anon` und `authenticated` sind entzogen.
- `log_team_role_change()` mit zwei Triggern an `team_member_roles`; direkte EXECUTE-Rechte für `anon` und `authenticated` sind entzogen.
- `prevent_last_team_admin_removal()` als verzögerten Constraint-Trigger auf `team_member_roles`.
- `cleanup_matchday_recommendations_before_player_delete()` als SECURITY DEFINER-Triggerfunktion vor dem Löschen von Spielern.
- `protect_player_active_status()` und `require_active_player_for_new_assignment()` sind Triggerfunktionen ohne SECURITY DEFINER, haben aber aktuell laut ACL-Abfrage EXECUTE-Rechte für `anon` und `authenticated`. Wegen des Trigger-Rückgabetyps ist das nicht gleichbedeutend mit einem normalen RPC-Aufruf; ihre Rechte werden als Kandidaten für gezielte ACL-Härtung in der Maßnahmenliste geführt, nicht während der Inventur verändert.

### 12.4 SECURITY DEFINER und Advisor

- Der Security Advisor meldet 18 `authenticated_security_definer_function_executable`-Hinweise. Die noch gelisteten Funktionen sind überwiegend Verwaltungs-/Lesefunktionen und eigene Rollenprüfer, die für die angemeldete App erreichbar sein sollen; jede muss durch einen angemessenen Negativtest abgesichert sein.
- Die Funktionen mit beliebiger Benutzer-ID (`is_team_admin(uuid,uuid)`, `is_team_member(uuid,uuid)`) sind für direkte EXECUTE-Aufrufe durch `authenticated` und `anon` bereits gesperrt; interne Verwaltungs-RPC-Aufrufe wurden zuvor in Rollback-Transaktionen geprüft.
- `log_team_role_change()` ist nicht mehr direkt ausführbar durch `authenticated` oder `anon`; die Triggerbindung bleibt vorhanden.
- `auth_leaked_password_protection` bleibt eine separat dokumentierte Tarif-/Plattformgrenze und ist nicht durch SQL lösbar.

### 12.5 Konsolidierte offene Punkte – keine neuen Einzelaufträge

1. Vollständiger Abgleich aller 18 registrierten Migrationen gegen die Dateien im Branch.
2. Prüfung der verdächtigen breiten Tabellen-ACLs gegen RLS-Policies und tatsächlichen Clientbedarf.
3. Bewertung der beiden Triggerfunktionen mit breiten EXECUTE-Rechten.
4. Negativtests für Rollen-/Vereinsgrenzen, Cross-Team-Positions-/Anwesenheitszuordnung und Trainerteilnahme-Zuordnungen; Fälle ohne zweite Testmannschaft bzw. zweiten Verein als nicht testbar kennzeichnen.
5. Regression der Kernabläufe nach allen bereits angewendeten AP03-Berechtigungsänderungen.
6. Abschlussbericht mit verbleibenden Advisor-Warnungen, Tarifgrenze, Testgrenzen und explizitem DEV-only-Status.

**Inventurstatus:** Der Schema-/Berechtigungs-Snapshot ist erhoben. Die Punkte oben sind die zusammengeführte Restliste; während der weiteren Inventur werden keine weiteren punktuellen Rechteänderungen vorgenommen. PROD bleibt unangetastet.


## 13. Abarbeitung der konsolidierten Restliste – Befund zur Tabellen-ACL (27.10.2026)

Die erste Restlisten-Prüfung hat einen priorisierten Befund ergeben. Es wurden noch keine Rechte geändert.

### 13.1 Migrationen – Ergebnis

- Die fünf AP03-Dateien sind im Feature-Branch vorhanden.
- Die erwarteten Dateien für die 13 AP01-/AP02-Migrationen wurden unter den anhand des DEV-Migrationsprotokolls erwarteten Pfaden im Feature-Branch nicht gefunden. Auch die geprüften Standardzweige der beiden Projekt-Repositories lieferten diese Dateipfade nicht.
- Daraus folgt: Der vollständige historische Migrationssatz ist derzeit nicht aus den bekannten Pfaden belegbar. Die 18 Einträge im Supabase-Migrationsprotokoll sind vorhanden, aber eine saubere Neuinstallation aus dem GitHub-Branch ist noch nicht nachgewiesen. Die älteren Migrationen dürfen nicht aus aktuellen Datenbankdefinitionen rekonstruiert oder blind neu angewendet werden; es muss zunächst der tatsächliche Ablageort bzw. die Quelle der historischen SQL-Dateien ermittelt werden.
- Die doppelte set_updated_at()-Datei bleibt ein separater Konsolidierungspunkt.

### 13.2 Tabellenrechte – priorisierter Befund

- 77 RLS-Policies im Schema public; alle 77 sind ausschließlich für authenticated definiert. Es wurden keine Policies für anon gefunden.
- Gleichzeitig weist die Rechteabfrage direkte Tabellenrechte für anon auf mehreren fachlichen Tabellen aus, darunter attendance, matchday_trainers, matchdays, player_positions, players, positions, profiles, seasons, team_member_roles, team_role_change_log, training_players, training_responses, training_series, training_trainers und trainings.
- In den abgefragten Grants erscheinen für anon teilweise auch TRUNCATE. TRUNCATE wird nicht durch RLS-Policies geschützt. Dieser Befund ist deshalb höher zu priorisieren als kosmetische Advisor-Warnungen und muss vor einer Abschlussfreigabe geklärt werden.
- Es wurden keine Änderungen vorgenommen, weil zunächst zu unterscheiden ist, welche Rechte direkt gewährt, über PUBLIC geerbt oder von den zugrunde liegenden ACLs/Default Grants bereitgestellt werden und welche Grants die frühere AP02-Migration tatsächlich zurückgenommen hat. Der Befund wird nicht als bestätigter ausnutzbarer Angriff bezeichnet, aber auch nicht als harmlos eingestuft.

### 13.3 Nicht-SECURITY-DEFINER-Triggerfunktionen

- protect_player_active_status() und require_active_player_for_new_assignment() sind Triggerfunktionen (kein normaler Frontend-RPC) und haben laut Privilegienabfrage EXECUTE für anon und authenticated.
- Diese Rechte sind ein Kandidat für eine gezielte Einschränkung, aber gegenüber dem Tabellen-ACL-Befund nachrangig. Vor einer Änderung wird geprüft, ob die Triggerfunktion über Triggerkontext weiter funktioniert und ob ein direkter Funktionsaufruf überhaupt technisch möglich ist.

### 13.4 Status nach dieser Prüfrunde

- Migrationen: nicht vollständig aus Git reproduzierbar; historische Ablage/Quelle offen.
- Tabellenrechte: auffällige direkte anon-Grants, einschließlich angezeigter TRUNCATE-Privilegien; vor Abschluss klären.
- RLS: auf allen 25 Tabellen aktiviert; 77 Policies, alle für authenticated.
- Keine neuen Berechtigungsänderungen in dieser Prüfrunde.
- Nächster Schritt: tatsächliche effektive ACLs und PUBLIC-Grants mit has_table_privilege und aclexplode auflösen und danach eine einzige gebündelte Korrekturliste erstellen. Keine Änderungen an PROD.


## 14. Gebündelte DEV-Korrektur nach ACL-Befund (27.10.2026)

Auf Basis der effektiven Rechteabfrage wurden zwei gezielte Migrationen in DEV angewendet und im Feature-Branch als SQL-Dateien dokumentiert. PROD wurde nicht verändert.

### 14.1 Anonyme Tabellenrechte und TRUNCATE

Migration: 20261027051456 / ap03_revoke_anon_table_access_and_truncate_dev

- `REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anon`
- `REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM authenticated`
- Nachkontrolle mit `has_table_privilege`: keine der 25 geprüften öffentlichen Tabellen hat noch SELECT, INSERT, UPDATE, DELETE oder TRUNCATE für `anon`; `authenticated` hat auf keiner der geprüften Tabellen TRUNCATE.
- Die Korrektur passt zum aktuellen Policy-Bestand: keine RLS-Policy für anon, alle 77 gefundenen Policies sind für authenticated. Für authentifizierte Nutzer wurden die üblichen CRUD-Rechte nicht pauschal entzogen.

### 14.2 Direkte EXECUTE-Rechte auf Triggerfunktionen

Migration: 20261027051509 / ap03_restrict_trigger_function_execute_dev

- Direkte EXECUTE-Rechte auf `protect_player_active_status()` und `require_active_player_for_new_assignment()` wurden für PUBLIC, anon und authenticated entzogen.
- Nachkontrolle: beide Funktionen haben weiterhin aktive Triggerbindungen (1 bzw. 4 Trigger); `log_team_role_change()` hat weiterhin zwei Triggerbindungen. Direkte EXECUTE-Rechte für anon/authenticated sind bei allen drei Triggerfunktionen entzogen.
- Die Trigger bleiben registriert. Ein vollständiger funktionaler End-to-End-Test nach dieser Rechteänderung ist noch Teil der Regressionrunde; die Katalogkontrolle allein ist kein Ersatz dafür.

### 14.3 Reststatus

- Security Advisor: weiterhin 18 Hinweise zu SECURITY DEFINER-Funktionen, die authenticated direkt aufrufen kann. Diese müssen nach Aufrufzweck und serverseitiger Autorisierung einzeln bewertet werden; nicht pauschal sperren.
- Historische AP01-/AP02-Migrationsdateien sind an den erwarteten Pfaden nicht auffindbar. Der vollständige Migrationsbestand kann noch nicht aus dem Feature-Branch reproduziert werden. Nicht rekonstruieren oder erneut anwenden, solange der Originalinhalt nicht aus einer verlässlichen Quelle vorliegt.
- Cross-Club-/Cross-Team-Negativtests sind wegen fehlender zweiter Testentitäten weiterhin nicht ausführbar.
- Die nächste Regressionrunde soll sich auf vorhandene Kernabläufe und Rollback-Tests konzentrieren; nach diesem Abschnitt keine weitere ACL-Änderung ohne zusammengefassten Befund.


## 15. Vorprüfung der verbleibenden SECURITY DEFINER-Warnungen (27.10.2026)

Die 18 Advisor-Hinweise wurden in einem zusammengefassten Katalog erneut mit Funktionsdefinitionen und Aufrufzweck abgeglichen. Es wurden keine weiteren EXECUTE-Rechte verändert.

- Verwaltungsfunktionen wie admin_add_club_member, admin_add_club_member_by_email, admin_add_team_role, admin_create_team, admin_remove_club_member, admin_remove_team_role, admin_set_club_member_role und admin_set_trainer_label referenzieren auth.uid() und die jeweilige Club-/Team-Admin-Prüfung. Diese sollen für die angemeldete App erreichbar bleiben, sofern die zugehörigen Negativtests bestehen.
- Lesefunktionen get_club_members, get_club_members_v2, get_club_players und get_team_trainers_v2 referenzieren auth.uid() sowie eine Club-/Team-Berechtigungsprüfung; ihre Ausgabe und Fremdteam-Negativtests bleiben Bestandteil der Regression.
- is_club_admin, is_club_member, is_super_admin, is_team_admin(uuid) und is_team_member(uuid) sind Auth-Kontext-Helfer, die von RLS bzw. App-Logik gebraucht werden. Ihre direkten Rückgabewerte sind keine Geheimnisse; sie müssen aber an den aktuellen auth.uid()-Kontext gebunden bleiben.
- save_player_with_positions referenziert auth.uid() und validiert die Teammitgliedschaft sowie die Positionszuordnung; diese RPC ist für das Frontend erforderlich.
- Die zweiparametrigen Teamrollen-Helfer und die drei reinen Triggerfunktionen sind bereits für direkte Aufrufe durch anon/authenticated gesperrt und erscheinen nicht mehr als die hier verbleibenden 18 Advisor-Funde.
- Diese Prüfung ist ein statischer Plausibilitätscheck, kein Beweis, dass jede Funktion fehlerfrei autorisiert. Der Security Advisor warnt weiterhin, weil diese SECURITY DEFINER-RPCs absichtlich für authenticated ausführbar sind. Ein Entfernen aller Warnungen würde die App-Funktionen beeinträchtigen oder eine gezielte Architekturänderung erfordern.


## 16. Regressionrunde nach den ACL-Korrekturen (27.10.2026)

### Automatisierte DB-/Katalogprüfungen

- PASS: Alle 25 geprüften Tabellen im Schema public haben RLS aktiviert.
- PASS: Nach den Korrekturen hat anon auf keiner geprüften Tabelle SELECT, INSERT, UPDATE, DELETE oder TRUNCATE; authenticated hat auf keiner geprüften Tabelle TRUNCATE.
- PASS: Die direkten EXECUTE-Rechte von anon/authenticated sind für `log_team_role_change()`, `protect_player_active_status()` und `require_active_player_for_new_assignment()` entzogen.
- PASS: Die Katalogabfrage bestätigt, dass `log_team_role_change()` weiterhin zwei Triggerbindungen hat, `protect_player_active_status()` eine und `require_active_player_for_new_assignment()` vier.
- PASS: Negativtest in DEV: Ein Insert in `training_players` mit einem inaktiven Spieler wurde durch die Triggerfunktion mit SQLSTATE 23514 (`check_violation`) abgewiesen. Der Test wurde in einem inneren Ausnahmeblock ausgeführt; die unzulässige Zuordnung wurde nicht gespeichert.
- PASS (früherer AP03-Test): Entfernen der einzigen Team-Admin-Rolle und Herabstufen des einzigen Club-Admins wurden mit SQLSTATE 23514 blockiert; die Admin-Zählungen blieben unverändert.
- PASS (manueller DEV-Test, vorher bestätigt): Spieler speichern und nach Neuladen prüfen; Team-/Mitgliederrollen ansehen und ändern; Trainer-/Teamrollenverwaltung öffnen.

### Noch nicht bestanden bzw. nicht ausgeführt

- OFFEN: Vollständiger End-to-End-Test der UI nach den letzten ACL-Korrekturen (Training, Spieltag, Spieleranlage/-bearbeitung, Rollenverwaltung). Die Katalog- und SQL-Prüfungen ersetzen diesen Test nicht.
- OFFEN: Positivtest der aktiven Spielerzuordnung über die reguläre App sowie Update-Triggerpfade.
- NICHT TESTBAR MIT AKTUELLEN DEV-DATEN: Cross-Club-/Cross-Team-Isolation, da keine zweite unabhängige Testorganisation bzw. kein zweites Testteam vorhanden ist.
- OFFEN: Vollständige Reproduzierbarkeit aller AP01-/AP02-Migrationen aus GitHub; die historischen SQL-Dateien fehlen an den geprüften Pfaden.
- WEITERHIN WARNUNG: 18 SECURITY DEFINER-Funktionen sind absichtlich für authenticated ausführbar und bleiben einzeln auf ihre Autorisierung zu prüfen. Supabase warnt weiterhin; die Warnung ist kein automatischer Beweis einer ausnutzbaren Schwachstelle.
- TARIFBEDINGT OFFEN: Schutz gegen bekannte kompromittierte Passwörter ist im verwendeten Supabase-Tarif nicht verfügbar.

### Regressionsergebnis

Die gezielten ACL-Prüfungen und der Negativtest für inaktive Spieler sind bestanden. AP03 ist dennoch NICHT abschließend freigegeben, weil der vollständige UI-End-to-End-Test, Cross-Club-/Cross-Team-Tests und die historische Migrationsreproduzierbarkeit offen sind. Keine Änderung an PROD; kein Merge.


## 17. Nachlaufende Regression und benötigte AP01/AP02-Unterlagen (27.10.2026)

### Weitere Prüfungen

- Erneute Katalogkontrolle bestätigt: anon hat keine direkten CRUD-/TRUNCATE-Rechte auf den öffentlichen Tabellen; authenticated hat kein TRUNCATE. Alle 25 Tabellen behalten RLS.
- Die drei Triggerfunktionen sind weiterhin an die erwarteten Trigger gebunden und für direkte Ausführung durch anon/authenticated gesperrt.
- Der Negativtest für inaktive Spielerzuordnung wurde bestanden.
- Ein positiver Insert-/Update-Test für aktive Spielerzuordnungen wurde vorbereitet, aber die SQL-Ausführung mit temporären Schreiboperationen wurde durch die Ausführungs-Sicherheitskontrolle blockiert. Deshalb wird er ausdrücklich als NICHT AUSGEFÜHRT geführt; keine Aussage über ein erfolgreiches Ergebnis.
- Ein vollständiger UI-End-to-End-Test kann aus den verfügbaren Datenbank-/GitHub-Werkzeugen nicht simuliert werden. Er bleibt als manueller Test in DEV erforderlich.

### Historische Migrationen

Die AP01-/AP02-Migrationsdateien sind in den bisher geprüften Repository-Pfaden nicht auffindbar. Der Nutzer hat weitere lokale AP01-/AP02-Dokumentationen und kann diese bereitstellen. Diese Unterlagen werden benötigt, um die Original-SQLs bzw. Migrationsinhalte verlässlich zuzuordnen. Bis dahin keine Rekonstruktion und kein Neuaufbau aus Vermutungen.

### Abschlussgrenze

Die SQL-seitigen ACL-Nachkontrollen und der Negativtest sind erfolgreich. Positive Schreibpfade, manuelle UI-Regression, Cross-Club-/Cross-Team-Tests und vollständige Migrationsreproduzierbarkeit sind weiterhin offen. AP03 ist nicht freigegeben; keine PROD-Änderung und kein Merge.


## 18. Abgleich lokaler AP01/AP02-Unterlagen und Live-Nachkontrolle (27.10.2026)

### Supabase-Migrationshistorie (Live, DEV)

Die aktuelle Liste der registrierten Migrationen wurde erneut aus dem DEV-Projekt `pzazqvvoruqnqhcorbwx` gelesen. Sie enthält 20 Versionen. Für AP01 sind die fünf registrierten Versionen von `20261022195046` bis `20261023032020` vorhanden; für AP02 sind die acht Versionen von `20261023203742` bis `20261026150017` vorhanden; AP03 umfasst die sieben Versionen von `20261026210356` bis `20261027051509`.

Die Live-Abfrage zu den beiden ähnlich benannten `set_updated_at`-Migrationen bestätigt ausschließlich `20261026221728 ap03_set_updated_at_search_path_hardening` in der Datenbankhistorie. Die Version `20261026221800` ist nicht registriert.

### Lokale Archivpakete: belastbare Einordnung

- AP01-Abschluss-/Release-Unterlagen enthalten Bestandsaufnahme, ACL-Befunde, Trigger/Eventtrigger-Hinweise, Testgrenzen und Migrationshistorie-Hinweise. Sie dokumentieren unter anderem, dass Migration A (Last-Admin-Schutz) und Migration B (signaturgenaue EXECUTE-Entzüge) ausgeführt wurden. Die AP01-Pakete enthalten auch Entwurfs-/Prüf-SQL, aber keine vollständige, kanonische Sammlung aller ausgeführten historischen Migrationsdateien.
- Das Paket `AP02_Migrationspaket_v1.0.0` enthält `20261023_ap02_foundation_v1.sql` sowie Preflight-, Postflight-, Test- und Rollback-SQL. Die darin enthaltene Datei ist eine fachliche Paketdatei; sie beweist nicht allein, dass ihr Inhalt bytegenau der registrierten Migration `20261023203742 ap02_foundation_v1_0_0_dev` entspricht.
- Die AP02-Technikpakete kennzeichnen `AP02_migration_01_foundation_DRAFT.sql` und `AP02_migration_02_roles_cutover_DRAFT.sql` ausdrücklich als Entwürfe/nicht ausführen. Auch die P0-Cutover-Versionen `CANDIDATE` und `REVIEW`, sowie die Rechtebasis-Datei `AP02_P0_1_Rechtebasis_ENTWURF_NICHT_AUSFUEHREN.sql`, sind keine Autorisierung zur Ausführung.
- Die Rollback- und Baseline-Pakete sind Dokumentation/Prüfgrundlage, keine Aufforderung, sie jetzt auszuführen.

### Read-only Postflight-Ergebnisse (DEV)

| Prüfung | Ergebnis |
|---|---:|
| Öffentliche Tabellen mit RLS | 25 von 25 |
| RLS-Policies insgesamt | 77 |
| Policies mit Rolle ausschließlich `authenticated` | 77 |
| Legacy-Teamrollen ohne passende normalisierte Rolle | 0 |
| Legacy-Mitgliedschaften ohne irgendeine normalisierte Rolle | 0 |
| Öffentliche Tabellen ohne RLS | 0 |
| Tabellen mit direkten `anon`-SELECT/INSERT/UPDATE/DELETE/TRUNCATE-Rechten | 0 |
| Tabellen mit `authenticated`-TRUNCATE-Recht | 0 |

Die Prüfungen waren lesend und haben keine Daten geändert.

### Aktuelle Advisor-Nachkontrolle (DEV)

- Security Advisor: 18 Warnungen zu `SECURITY DEFINER`-Funktionen, die `authenticated` ausführen darf; die Funktionen müssen jeweils anhand ihrer Autorisierungslogik bewertet werden. Nicht pauschal widerrufen.
- Security Advisor: 1 Warnung für deaktivierten Schutz gegen bekannte kompromittierte Passwörter; im aktuellen Tarif laut bisheriger Projektprüfung nicht verfügbar.
- Performance Advisor: 15 Hinweise auf nicht abgedeckte Fremdschlüssel-Indizes, 15 Hinweise zu RLS-Policies mit wiederholt ausgewerteten Auth-Ausdrücken und 2 ungenutzte Indizes. Diese sind Performance-Arbeit, keine nachgewiesenen Sicherheitslücken; Änderungen sind nicht Teil dieses AP03-Sicherheitsnachlaufs.

### Repository-Bereinigung

Die Datei `supabase/migrations/20261026221800_ap03_set_updated_at_search_path_hardening_dev.sql` enthielt denselben einzelnen ALTER-FUNCTION-Befehl wie die kanonische, registrierte Migration `20261026221728_ap03_set_updated_at_search_path_hardening.sql`, war aber nicht als eigene Migration in Supabase registriert. Die redundante Datei wurde ausschließlich aus dem Branch `feature/ap03-security-fixes` entfernt. Die registrierte Migration und Datenbank wurden dabei nicht verändert.

### Weiterhin offen / Grenzen

- Historische Migrationsdateien lassen sich aus den gelieferten Unterlagen nicht für jede registrierte Version eindeutig bytegenau rekonstruieren. Keine SQL-Datei wurde aus einem Entwurf rekonstruiert oder erneut ausgeführt.
- Vollständiger manueller UI-End-to-End-Test nach den letzten ACL-Änderungen bleibt offen.
- Positiver Insert-/Update-Test aktiver Spielerzuordnungen bleibt NICHT AUSGEFÜHRT.
- Cross-Club-/Cross-Team-Isolation kann mangels zweiter unabhängiger Testorganisation/-mannschaft nicht belastbar nachgewiesen werden.
- Die 18 `SECURITY DEFINER`-Warnungen bleiben gezielt zu prüfen.

### Status

Die fünf nächsten Arbeitsschritte wurden soweit mit lesenden Prüfungen und einer klar belegten Bereinigung möglich ausgeführt. AP03 bleibt NICHT freigegeben. Kein Merge und keine PROD-Änderung.
