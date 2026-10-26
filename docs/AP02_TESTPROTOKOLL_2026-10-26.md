# AP02 – Testprotokoll Vereinsverwaltung

**Stand:** 26.10.2026  
**Umgebung:** DEV – Supabase-Projekt `pzazqvvoruqnqhcorbwx`  
**Arbeitsbranch:** `feature/ap02-club-frontend-dev`  
**Release-Status:** Nicht für PROD freigegeben. PR #2 bleibt Draft und wird nicht gemergt.

## 1. Ziel von AP02

Die Vereinsverwaltung ermöglicht berechtigten Vereinsadmins die Einsicht in Vereinsmitglieder und Spieler, die Verwaltung von Vereinsrollen sowie das Entfernen von Mitgliedern unter Einhaltung der Schutzregeln. Die Vereinsverwaltung ist funktional noch nicht abschließend abgenommen.

## 2. Manuelle Tests – Ergebnis

| ID | Test | Erwartetes Ergebnis | Ergebnis |
|---|---|---|---|
| AP02-T01 | Vereinsadmin öffnet die Mitgliederliste | Mitglieder werden angezeigt | **Bestanden** – vom Nutzer bestätigt |
| AP02-T02 | Vereinsadmin sieht Spieler nach Mannschaft | Spieler werden korrekt angezeigt; aktuell 22 Spieler im zugeordneten DEV-Team | **Bestanden** – vom Nutzer bestätigt |
| AP02-T03 | Mitgliederliste nach Mannschaft filtern | Filter funktioniert | **Bestanden** – im vorherigen Testdurchlauf vom Nutzer bestätigt |
| AP02-T04 | Vereinsrolle eines geeigneten Mitglieds ändern | Rolle wird gespeichert und bleibt nach Neuladen bestehen | **Bestanden** – vom Nutzer bestätigt |
| AP02-T05 | Mitglied mit vorhandener Mannschaftsrolle entfernen | Entfernung wird blockiert; verständlicher Hinweis auf zuerst zu entfernende Mannschaftsrollen erscheint | **Bestanden** – vom Nutzer bestätigt |
| AP02-T06 | Superadmin anmelden | Plattformverwaltung öffnet sich; es wird kein Verein automatisch ausgewählt | **Bestanden** – vom Nutzer bestätigt |
| AP02-T07 | Vereinsadmin nach vorheriger Superadmin-Sitzung anmelden | Es wird nur die Vereinsverwaltung angezeigt, nicht das zuvor sichtbare Plattformadmin-Panel | **Bestanden** – nach Korrektur vom Nutzer bestätigt |

## 3. Technische Prüfung der Schutzfunktionen

Am 26.10.2026 wurden die Definitionen der folgenden DEV-Datenbankfunktionen read-only geprüft:

- `get_club_members_v2`
- `get_club_players`
- `admin_set_club_member_role`
- `admin_remove_club_member`
- `is_club_admin`

Feststellungen aus der Funktionsprüfung:

- Die vier Verwaltungsfunktionen prüfen serverseitig die angemeldete Identität und die Berechtigung für den angefragten Verein.
- Rollenänderungen sind auf `member` und `club_admin` beschränkt.
- Ein letzter Vereinsadmin soll nicht herabgestuft werden können.
- Ein letzter Vereinsadmin soll nicht entfernt werden können.
- Eine Mitgliedschaft soll nicht entfernt werden, solange das Mitglied noch einer Mannschaft des Vereins zugeordnet ist (sowohl normalisierte Rollen als auch Legacy-Zuordnungen werden berücksichtigt).
- Die Funktionen verwenden `SECURITY DEFINER`; ihre Berechtigungen und ihr Suchpfad müssen deshalb Teil der weiteren Sicherheitsprüfung bleiben.

**Hinweis:** Die obigen Punkte zum letzten Vereinsadmin wurden anhand des Funktionscodes geprüft, aber nicht durch einen riskanten manuellen Änderungsversuch praktisch ausgelöst. Ein Test darf nicht dazu führen, dass der Verein ohne Admin verbleibt.

## 4. Noch offene Tests

| ID | Test | Warum offen / nächster Schritt |
|---|---|---|
| AP02-T08 | Zugriff eines Vereinsadmins auf einen fremden Verein | In DEV existiert aktuell nur ein Verein. Für einen echten Isolationstest wird eine sichere Möglichkeit benötigt, einen zweiten Testverein anzulegen oder einen isolierten Testkontext zu verwenden. |
| AP02-T09 | Letzten Vereinsadmin herabstufen/entfernen | Nicht destruktiv praktisch getestet. Vor einem Test muss ein sicherer Testaufbau mit mindestens zwei Vereinsadmins vorhanden sein. |
| AP02-T10 | Mitglied ohne Mannschaftsrollen entfernen | Noch nicht als separater erfolgreicher Löschfall bestätigt. Nur mit ausdrücklich entbehrlichem Testkonto und nach Prüfung der Auswirkungen testen. |

## 5. Bekannte Einschränkungen / Hinweise

- In der DEV-Datenbank existiert zum Prüfzeitpunkt ein Verein: `AP02 – Testverein DEV`.
- Das zugeordnete Team `Jugendmannschaft DEV` enthält 22 Spieler.
- Ein erfolgreicher UI-Test ersetzt keinen vollständigen Sicherheitstest. Insbesondere die Trennung zwischen Vereinen ist noch nicht praktisch bestätigt.
- Globale Superadmins werden durch `is_club_admin` derzeit für alle Vereins-IDs als berechtigt behandelt. Das entspricht der vorgesehenen Plattformadmin-Rolle; die UI verlangt weiterhin eine explizite Vereinsauswahl.
- UI/UX-Zielbilder und frühere Designabstimmungen bleiben verbindlich. Die aktuelle AP02-Phase priorisiert die Funktions- und Berechtigungsprüfung; eine spätere UI-Abgleichs- und Umsetzungsphase ist vorgesehen.

## 6. Nächste Schritte

1. AP02-Testprotokoll aktuell halten und noch offene Punkte nachverfolgen.
2. Sichere Testmöglichkeit für den vereinsübergreifenden Isolationstest schaffen.
3. Danach gezielte AP03-Bestandsaufnahme durchführen: Rollenmatrix, Berechtigungsregeln, bereits implementierte Schutzmechanismen und verbleibende Lücken.
4. Anschließend die Verwaltungsseiten mit dem abgestimmten Ziel-UI vergleichen und die UI/UX-Anpassungen planen.
5. DEV zuerst testen; PROD nicht ändern, solange keine gesonderte Freigabe vorliegt.

## 7. Release-/Branch-Schutz

Dieses Protokoll dokumentiert ausschließlich den DEV-Arbeitsstand. Es ist keine PROD-Freigabe. PR #2 bleibt offen und Draft; es wird nicht gemergt.
