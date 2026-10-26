# AP02 – Testprotokoll Vereinsverwaltung

**Stand:** 26.10.2026  
**Umgebung:** DEV – Supabase-Projekt `pzazqvvoruqnqhcorbwx`  
**Arbeitsbranch:** `feature/ap02-club-frontend-dev`  
**Release-Status:** Nicht für PROD freigegeben. PR #2 bleibt Draft und wird nicht gemergt.

## 1. Ziel und Status von AP02

Die Vereinsverwaltung ermöglicht berechtigten Vereinsadmins die Einsicht in Vereinsmitglieder und Spieler, die Verwaltung von Vereinsrollen sowie das Entfernen von Mitgliedern unter Einhaltung der Schutzregeln.

**Status: Noch nicht abschließbar.** Die Kernabläufe wurden manuell erfolgreich getestet, aber bei der read-only Prüfung der Rollenmodellierung wurde ein sicherheitsrelevanter Punkt erkannt, der vor Abschluss geklärt und behoben werden muss.

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
- `is_club_admin`

Feststellungen:

- Die Verwaltungsfunktionen prüfen serverseitig die angemeldete Identität und die Berechtigung für den angefragten Verein.
- Die Funktionen sind `SECURITY DEFINER`; ihr Berechtigungsmodell und Suchpfad bleiben Bestandteil der Sicherheitsprüfung.
- Anonyme Benutzer haben keine EXECUTE-Berechtigung auf die geprüften Verwaltungsfunktionen; `authenticated` hat EXECUTE.
- Rollenänderungen sind auf `member` und `club_admin` beschränkt.
- Im Code sind Schutzregeln vorgesehen, die das Herabstufen bzw. Entfernen des letzten Vereinsadmins und das Entfernen von Mitgliedern mit Mannschaftsrollen verhindern sollen.

**Nicht praktisch getestet:** Der Schutz des letzten Vereinsadmins wurde nicht durch einen riskanten manuellen Änderungsversuch ausgelöst. Ein Test darf nicht dazu führen, dass der Verein ohne Admin verbleibt.

## 4. Sicherheitsrelevanter offener Punkt – Vereinsrollen sind nicht vereinsbezogen

Die Tabelle `club_member_roles` enthält derzeit `user_id` und `role`, aber keinen `club_id`. Die Rollenvergabe ist damit global pro Benutzer gespeichert. Die Funktion `is_club_admin(p_club_id)` prüft zwar zusätzlich, ob der Benutzer Mitglied des angefragten Vereins ist, aber die Rolle `club_admin` selbst ist nicht an genau diesen Verein gebunden.

**Risiko:** Wenn ein Benutzer Vereinsmitglied in mehreren Vereinen ist und in einem davon die Rolle `club_admin` erhält, kann diese globale Rolle dazu führen, dass er auch in weiteren Vereinen, in denen er Mitglied ist, als Vereinsadmin erkannt wird. Das ist anhand der aktuellen Tabellen- und Funktionsdefinitionen ein plausibles Sicherheitsrisiko. Mit nur einem Verein in DEV lässt es sich derzeit nicht per regulärem Mehrvereins-Test reproduzieren.

**Konsequenz:** AP02 wird noch nicht als abgeschlossen markiert. Vor dem Abschluss muss das Rollenmodell so angepasst oder anderweitig sicher abgegrenzt werden, dass Vereinsadmins nur im jeweils zugewiesenen Verein Verwaltungsrechte haben. Dabei müssen alle betroffenen Funktionen und bestehende Daten berücksichtigt werden; keine Schnelländerung ohne Bestandsaufnahme.

## 5. Noch offene Tests

| ID | Test | Warum offen / nächster Schritt |
|---|---|---|
| AP02-T08 | Zugriff eines Vereinsadmins auf einen fremden Verein | In DEV existiert aktuell nur ein Verein. Zuerst Rollenmodell korrigieren, danach mit sicherem zweiten Testverein oder isoliertem Testkontext prüfen. |
| AP02-T09 | Letzten Vereinsadmin herabstufen/entfernen | Nicht destruktiv praktisch getestet. Sicheren Testaufbau mit mindestens zwei Vereinsadmins vorbereiten. |
| AP02-T10 | Mitglied ohne Mannschaftsrollen entfernen | Noch nicht als separater erfolgreicher Löschfall bestätigt. Nur mit ausdrücklich entbehrlichem Testkonto und nach Prüfung der Auswirkungen testen. |

## 6. Bekannte DEV-Testbedingungen

- In der DEV-Datenbank existiert zum Prüfzeitpunkt ein Verein: `AP02 – Testverein DEV`.
- Das zugeordnete Team `Jugendmannschaft DEV` enthält 22 Spieler.
- Ein erfolgreicher UI-Test ersetzt keinen vollständigen Sicherheitstest.
- Globale Superadmins werden durch `is_club_admin` derzeit für alle Vereins-IDs als berechtigt behandelt. Das entspricht der vorgesehenen Plattformadmin-Rolle; die UI verlangt weiterhin eine explizite Vereinsauswahl.
- Die bereits abgestimmten UI/UX-Zielbilder bleiben verbindlich. Die aktuelle Phase priorisiert Funktions- und Berechtigungsprüfung; der UI-Abgleich ist weiterhin als späterer Umsetzungsschritt eingeplant.

## 7. Nächste Schritte

1. Das Vereinsrollenmodell und alle betroffenen Funktionen gezielt untersuchen.
2. Eine sichere, vereinsbezogene Berechtigungslogik planen und in DEV umsetzen; Datenmigration und bestehende Zuordnungen dabei berücksichtigen.
3. Die AP02-Tests nach der Korrektur wiederholen, insbesondere Vereinsisolation und Schutz des letzten Admins.
4. AP02 erst dann abschließen, wenn der Sicherheitsblocker behoben und die notwendigen Tests erfolgreich sind.
5. Danach gezielte AP03-Bestandsaufnahme durchführen: Rollenmatrix, Berechtigungsregeln, vorhandene Schutzmechanismen und verbleibende Lücken.
6. Anschließend die Verwaltungsseiten mit dem abgestimmten Ziel-UI vergleichen und die UI/UX-Anpassungen planen.

## 8. Release-/Branch-Schutz

Dieses Protokoll dokumentiert ausschließlich den DEV-Arbeitsstand. Es ist keine PROD-Freigabe. PR #2 bleibt offen und Draft; es wird nicht gemergt.
