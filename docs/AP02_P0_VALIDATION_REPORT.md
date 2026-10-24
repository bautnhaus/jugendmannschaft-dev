# AP02 P0 – Validierungsbericht

Stand: 24.10.2026  
Geprüfter Branch: `feature/ap02-additive-team-roles`  
Ergebnis: **NICHT ausführungsfreigegeben**

## Prüfungen durchgeführt

- Dateien im Branch erneut abgerufen und Commit-Stände geprüft.
- SQL-Migration strukturell gelesen: ein BEGIN/COMMIT-Paar, neun Funktionsdefinitionen, fünf neue/ersetzte Policies.
- Frontend nach Legacy-Aufrufen durchsucht.
- Live-Definitionen von `add_team_member_by_email`, `admin_set_trainer_label`, `delete_my_account` und `get_team_trainers` read-only geprüft.
- Keine SQL-Migration ausgeführt und keine Edge Function deployed.

## Gefundene Blocker / offene Risiken

### 1. Mehrere Mannschaften pro Benutzer
Das Frontend wählt in `loadApp()` weiterhin `members[0].team_id`. Die Abfrage ist nicht sortiert und bietet keine explizite Mannschaftsauswahl. Wenn ein Benutzer künftig mehrere Mannschaften hat, ist die Auswahl nicht deterministisch und der erforderliche explizite Kontext fehlt. Vor AP02-Multi-Team-Freigabe muss die App einen Team-Kontext auswählen und speichern.

### 2. Alte Rollen-RPCs bleiben erreichbar
Die Live-Funktionen `add_team_member_by_email` und `get_team_trainers` lesen/schreiben weiterhin `team_members.role`. Der neue Frontend-Kandidat verwendet diese beiden Funktionen nicht mehr für die normale Rollenverwaltung, aber sie sind weiterhin in der Datenbank vorhanden. Vor Freigabe müssen EXECUTE-Rechte geprüft und die alten Funktionen entweder kompatibel umgestellt oder für authentifizierte Clients entzogen werden. Nicht unüberlegt löschen, da weitere Aufrufer existieren könnten.

### 3. Kontolöschung ist nicht kompatibel
Die Live-Funktion `delete_my_account()` löscht `team_members`, `profiles` und `auth.users`, aber nicht die neuen Rollen-/Vereinsdatensätze und anonymisiert keine Historie. Das ist ein bestätigter offener Sicherheits-/Datenintegritätsfall. Die Funktion darf nicht als AP02-fertig gelten; Kontolöschung muss separat neu entworfen und getestet werden.

### 4. Vereins- und Super-Admin-Kontext noch nicht umgesetzt
Der Rollen-Cutover gibt Super Admin absichtlich keine impliziten Rechte über die Team-Helferfunktionen. Club-Admin- und Super-Admin-Aktionen benötigen einen expliziten Verein-/Teamkontext und eigene RLS-/RPC-Tests. Diese Funktionen sind nicht Bestandteil dieses P0-Cutovers.

### 5. RLS-Policy für player_positions weiterhin separat zu korrigieren
Im Live-System existieren permissive Mitgliedschafts-Policies neben Admin-Policies für INSERT/DELETE. Diese können die gewünschte Admin-Beschränkung aushebeln. Die vorliegende Migration ersetzt diese Policies noch nicht. Das muss in einem koordinierten Cutover erledigt werden, bevor die entsprechenden Berechtigungsregeln als sicher gelten.

### 6. Edge Function – Auth-/Konfigurationstest offen
Die neue Datei reicht den Authorization-Header an den User-Client weiter und prüft Team-Admin-Rechte per RPC. Das ist im Quelltext plausibel, aber noch nicht mit der tatsächlichen DEV-Konfiguration getestet. Die Umgebungsvariablen, CORS-Origin, Invite-Redirect und die aktuelle Supabase-Key-Konfiguration müssen gegen die DEV-URL verifiziert werden. Die Funktion wurde nicht deployed.

### 7. SQL noch nicht gegen eine isolierte Datenbank ausgeführt
Die Migration ist strukturell geprüft, aber es gab keinen tatsächlichen Parser-/Apply-Test in einer isolierten Supabase/Postgres-Testinstanz. Deshalb können Syntax-, Privilegien- und Laufzeitfehler noch nicht ausgeschlossen werden. Der harte Paritäts-Preflight ist vorhanden, ersetzt aber keinen vollständigen Testlauf.

### 8. UI- und Funktionsregressionstests fehlen
Der Frontend-Quelltext wurde durchsucht, aber nicht in einem Browser mit Trainer- und Admin-Konto getestet. Rollenwechsel, Einladung, Trainings, Spieltage, Spielerpositionen und Kontoeinstellungen sind nicht verifiziert.

## Nächste sichere Schritte

1. Legacy-RPCs und alle Aufrufer inventarisieren; Rechte gezielt prüfen.
2. Team-Auswahl / expliziten Kontext klären, bevor mehrere Mannschaften pro Benutzer unterstützt werden.
3. Kontolöschung und `player_positions`-Policies in separate, geprüfte Änderungen aufnehmen.
4. SQL in einer isolierten Testdatenbank validieren; danach DEV-Backup und Preflight.
5. Erst dann Migration in DEV anwenden, Postflight ausführen, Edge Function deployen und Frontend-Tests durchführen.
6. Erst nach dokumentierter Testfreigabe PR zur Review freigeben.

## Schlussfolgerung

Der Branch ist ein brauchbarer **Implementierungsentwurf**, aber kein ausführungsreifer Cutover. Nicht mergen, nicht auf DEV anwenden und nicht deployen, bis die Blocker abgearbeitet und die Tests dokumentiert sind.

## Nacharbeit im Feature-Branch – 24.10.2026

Die folgenden Blocker wurden als Codeänderungen ergänzt; sie sind weiterhin **nicht auf DEV angewendet**:

- [x] Entfernt die permissiven Mitgliedschafts-Policies für `player_positions` INSERT/DELETE; die vorhandenen Admin-Policies bleiben die maßgeblichen Schreibregeln.
- [x] Entzieht authentifizierten/anon/public Aufrufern EXECUTE auf die alten Ein-Rollen-RPCs `add_team_member_by_email` und `get_team_trainers`.
- [x] Entzieht EXECUTE auf die bisher unsichere `delete_my_account()`-Funktion, bis Anonymisierung und Rollen-/Vereinsdaten korrekt behandelt werden.
- [x] Frontend zeigt bei mehr als einer Mannschaft einen sicheren Fehler, statt willkürlich `members[0]` als Kontext zu wählen.
- [x] Frontend-Kontolöschung ist vorübergehend deaktiviert und erklärt den Grund.

## Verbleibende Validierung

- [ ] SQL gegen eine echte isolierte PostgreSQL/Supabase-Instanz ausführen, nicht nur strukturell prüfen.
- [ ] Privilegien und RLS im echten DEV-Cutover nachweisen.
- [ ] Frontend-Syntaxprüfung und Browser-Regressionstests ausführen.
- [ ] Edge Function mit der tatsächlichen DEV-Umgebung testen.
- [ ] Explizite Mannschaftsauswahl implementieren, bevor Benutzer mit mehreren Mannschaften unterstützt werden.
- [ ] Kontolöschung/Anonymisierung als eigenes fachliches und technisches Paket neu entwerfen.
- [ ] Prüfen, ob andere, nicht im Frontend gefundene Aufrufer die deaktivierten Legacy-RPCs verwenden.

Diese Nacharbeit reduziert konkrete Risiken, ersetzt aber keinen Testlauf. Der PR bleibt Draft und die Migration bleibt nicht freigegeben.

## Isolierter PostgreSQL-Lauf – erster Befund

GitHub Actions hat die Fixture erfolgreich erstellt und die Rollen-Parität gesät. Der erste tatsächliche Apply-Test stoppte bei der Migration wegen fehlerhafter Abschluss-Begrenzer in zwei PL/pgSQL-Funktionen (`prevent_last_team_admin_removal` und `log_team_role_change`). Die SQL-Datei wurde korrigiert; der nächste Lauf muss die korrigierte Revision erneut anwenden und die Postflight-Prüfungen ausführen. Der fehlgeschlagene Lauf hat nur die kurzlebige Testdatenbank verwendet; DEV und PROD blieben unberührt.

## Weitere Prüfung – Trainer-Login

Beim Abgleich der neuen RLS-Regel mit dem Frontend fiel auf, dass `get_team_trainers_v2` nur für Admins gedacht ist, die App den RPC aber zuvor bei jedem Login aufgerufen hätte. Dadurch wäre der normale Trainer-Login fehlgeschlagen. Der Frontend-Kandidat wurde korrigiert: Nur Nutzer mit Teamrolle `admin` laden die Admin-Rollenliste; Trainer erhalten eine leere Admin-Liste und rufen die Admin-RPC nicht auf.

Zusätzlich wurde die CI um Syntaxprüfungen für die Inline-JavaScript-Blöcke der HTML-App und die `invite-trainer` Edge Function erweitert. Der Lauf für diese Revision ist noch ausstehend.
