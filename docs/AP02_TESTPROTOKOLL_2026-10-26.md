# AP02 – Testprotokoll Vereinsverwaltung

**Stand:** 26.10.2026  
**Umgebung:** DEV – Supabase-Projekt `pzazqvvoruqnqhcorbwx`  
**Arbeitsbranch:** `feature/ap02-club-frontend-dev`  
**Release-Status:** Nicht für PROD freigegeben. PR #2 bleibt Draft und wird nicht gemergt.

## 1. Ziel und Status von AP02

Die Vereinsverwaltung ermöglicht berechtigten Vereinsadmins die Einsicht in Vereinsmitglieder und Spieler, die Verwaltung von Vereinsrollen sowie das Entfernen von Mitgliedern unter Einhaltung der Schutzregeln.

**Produktentscheidung:** Ein Nutzer kann aktuell nur Mitglied in einem Verein sein. Mehrfachmitgliedschaften werden nicht umgesetzt und sind kein Bestandteil von AP02.

## 2. Manuelle Tests – Ergebnis

| ID | Test | Erwartetes Ergebnis | Ergebnis |
|---|---|---|---|
| AP02-T01 | Vereinsadmin öffnet die Mitgliederliste | Mitglieder werden angezeigt | **Bestanden** – vom Nutzer bestätigt |
| AP02-T02 | Vereinsadmin sieht Spieler nach Mannschaft | Spieler werden korrekt angezeigt; aktuell 22 Spieler im zugeordneten DEV-Team | **Bestanden** – vom Nutzer bestätigt |
| AP02-T03 | Mitgliederliste nach Mannschaft filtern | Filter funktioniert | **Bestanden** – vom Nutzer bestätigt |
| AP02-T04 | Vereinsrolle eines geeigneten Mitglieds ändern | Rolle wird gespeichert und bleibt nach Neuladen bestehen | **Bestanden** – vom Nutzer bestätigt; anschließend wurde die Teständerung wie vereinbart zurückgenommen |
| AP02-T05 | Mitglied mit vorhandener Mannschaftsrolle entfernen | Entfernung wird blockiert; verständlicher Hinweis auf zuerst zu entfernende Mannschaftsrollen erscheint | **Bestanden** – vom Nutzer bestätigt |
| AP02-T06 | Superadmin anmelden | Plattformverwaltung öffnet sich; es wird kein Verein automatisch ausgewählt | **Bestanden** – vom Nutzer bestätigt |
| AP02-T07 | Vereinsadmin nach vorheriger Superadmin-Sitzung anmelden | Es wird nur die Vereinsverwaltung angezeigt, nicht das zuvor sichtbare Plattformadmin-Panel | **Bestanden** – nach Korrektur vom Nutzer bestätigt |

## 3. Technische Prüfung der Schutzfunktionen

Am 26.10.2026 wurden die Definitionen und Ausführungsrechte der folgenden DEV-Datenbankfunktionen read-only geprüft:

- `get_club_members_v2`
- `get_club_players`
- `admin_set_club_member_role`
- `admin_remove_club_member`
- `admin_add_club_member`
- `is_club_admin`
- `is_club_member`

Feststellungen:

- Die Verwaltungsfunktionen prüfen serverseitig die angemeldete Identität und die Berechtigung für den angefragten Verein.
- Die Funktionen sind `SECURITY DEFINER`; ihr Berechtigungsmodell und Suchpfad bleiben Bestandteil der Sicherheitsprüfung.
- Anonyme Benutzer haben keine EXECUTE-Berechtigung auf die geprüften Verwaltungsfunktionen; `authenticated` hat EXECUTE.
- Rollenänderungen sind auf `member` und `club_admin` beschränkt.
- Im Code sind Schutzregeln vorgesehen, die das Herabstufen bzw. Entfernen des letzten Vereinsadmins und das Entfernen von Mitgliedern mit Mannschaftsrollen verhindern sollen.
- `club_members` hat `user_id` als Primärschlüssel. Damit kann ein Nutzer in der aktuellen Datenstruktur nur einmal als Vereinsmitglied eingetragen sein. `admin_add_club_member` prüft zusätzlich, ob der Nutzer bereits einem anderen Verein zugeordnet ist.
- Die globale Speicherung der Vereinsrolle in `club_member_roles` ist in Verbindung mit dieser Ein-Verein-pro-Nutzer-Regel der aktuelle Datenmodellansatz. Mehrfachmitgliedschaften und vereinsbezogene Rollen je Nutzer sind ausdrücklich nicht Teil des jetzigen Umfangs.

**Nicht praktisch getestet:** Der Schutz des letzten Vereinsadmins wurde nicht durch einen riskanten manuellen Änderungsversuch ausgelöst. Ein Test darf nicht dazu führen, dass der Verein ohne Admin verbleibt.

## 4. Einordnung der Rollenmodellierung

Die Tabelle `club_member_roles` speichert `user_id` und `role`, ohne `club_id`. Für die aktuelle Produktentscheidung (ein Nutzer kann nur einem Verein angehören) ist das konsistent mit der bestehenden Struktur von `club_members`, deren Primärschlüssel `user_id` eine zweite Vereinsmitgliedschaft verhindert.

Daher wird **keine vorsorgliche Datenmodellmigration** zur Unterstützung von Mehrfachmitgliedschaften vorgenommen. Sollte sich die Produktentscheidung später ändern, müssen Mitgliedschafts- und Rollenmodell gemeinsam neu bewertet werden.

Globale Superadmins bleiben ein ausdrücklich vorgesehener Sonderfall: `is_club_admin` gibt für sie vereinsübergreifend true zurück. Die UI verlangt dennoch eine explizite Vereinsauswahl.

## 5. Noch offene Tests

| ID | Test | Warum offen / nächster Schritt |
|---|---|---|
| AP02-T08 | Zugriff eines Vereinsadmins auf einen fremden Verein | In DEV existiert aktuell nur ein Verein. Ein praktischer Isolationstest ist daher noch nicht möglich. Die Ein-Verein-pro-Nutzer-Regel ist durch den Primärschlüssel von `club_members` und die Prüfung in `admin_add_club_member` abgesichert; später mit einem sicheren zweiten Testverein erneut prüfen. |
| AP02-T09 | Letzten Vereinsadmin herabstufen/entfernen | Nicht destruktiv praktisch getestet. Sicheren Testaufbau mit mindestens zwei Vereinsadmins vorbereiten. |
| AP02-T10 | Mitglied ohne Mannschaftsrollen entfernen | Noch nicht als separater erfolgreicher Löschfall bestätigt. Nur mit ausdrücklich entbehrlichem Testkonto und nach Prüfung der Auswirkungen testen. |

## 6. Bekannte DEV-Testbedingungen

- In der DEV-Datenbank existiert zum Prüfzeitpunkt ein Verein: `AP02 – Testverein DEV`.
- Das zugeordnete Team `Jugendmannschaft DEV` enthält 22 Spieler.
- Ein erfolgreicher UI-Test ersetzt keinen vollständigen Sicherheitstest.
- Die bereits abgestimmten UI/UX-Zielbilder bleiben verbindlich. Die aktuelle Phase priorisiert Funktions- und Berechtigungsprüfung; der UI-Abgleich ist weiterhin als späterer Umsetzungsschritt eingeplant.

## 7. Nächste Schritte

1. Die noch gefahrlos möglichen AP02-Tests abschließen.
2. Offene, aktuell nicht testbare Fälle transparent dokumentieren.
3. AP02 abschließen, sobald die für den aktuellen Umfang erforderlichen Tests und Sicherheitsprüfungen erledigt sind.
4. Danach gezielte AP03-Bestandsaufnahme durchführen: Rollenmatrix, Berechtigungsregeln, vorhandene Schutzmechanismen und verbleibende Lücken.
5. Anschließend die Verwaltungsseiten mit dem abgestimmten Ziel-UI vergleichen und die UI/UX-Anpassungen planen.

## 8. Release-/Branch-Schutz

Dieses Protokoll dokumentiert ausschließlich den DEV-Arbeitsstand. Es ist keine PROD-Freigabe. PR #2 bleibt offen und Draft; es wird nicht gemergt.
